import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// CdnTranslationService
/// ─────────────────────
/// Serves the non-primary translations, transliterations, tafsirs and
/// asbabun-nuzul sources from the public R2 tree at https://data.tafseer.id/v1.
///
/// Layout — one file per (source, surah), 3-digit zero-padded surah number:
///   translations/{sourceId}/001.json
///   transliterations/{sourceId}/001.json
///   tafsirs/{sourceId}/001.json
///   asbabun_nuzul/{sourceId}/001.json
///
/// Each file is a flat map with no wrapper:
///   { "1:1": "In the name of Allah, the Beneficent, the Merciful.",
///     "1:2": "Praise be to Allah, Lord of the Worlds," }
///
/// The category a source lives under is read from `manifest.json` (fetched
/// once and cached). Sparse sources answer 404 for a surah that has no rows;
/// that is treated as an empty map.
///
/// Usage:
///   final text = await CdnTranslationService.instance.getVerse('en.pickthall', '2:255');
///
class CdnTranslationService {
  CdnTranslationService._();
  static final CdnTranslationService instance = CdnTranslationService._();

  // ── Config ────────────────────────────────────────────────────────────────
  static const String _cdnBase = 'https://data.tafseer.id/v1';

  /// Cache version — bump to evict cached files on breaking format changes.
  /// v2: per-(sourceId, surah) files from the R2 tree (v1 held whole sources).
  static const int _cacheVersion = 2;

  /// Cloudflare in front of data.tafseer.id rejects requests carrying a default
  /// library User-Agent with HTTP 1010, so identify ourselves explicitly.
  static const String _userAgent =
      'tafseer_id-mobile/3.2 (+https://tafseer.id)';

  static const Map<String, String> _headers = {
    'User-Agent': _userAgent,
    'Accept': 'application/json',
  };

  /// Source categories that exist under the R2 tree.
  static const Set<String> _categories = {
    'translations',
    'transliterations',
    'tafsirs',
    'asbabun_nuzul',
  };

  static const int _surahCount = 114;

  /// Parallel per-surah downloads per source.
  static const int _maxConcurrent = 10;

  // ── In-memory cache: sourceId → { verseKey → text } ──────────────────────
  final Map<String, Map<String, String>> _loaded = {};

  /// Surahs already resolved (downloaded, read from disk, or 404) per source.
  final Map<String, Set<int>> _loadedSurahs = {};

  /// Pending per-surah loads: 'sourceId|surah' → future.
  final Map<String, Future<Map<String, String>?>> _pendingSurah = {};

  /// Pending whole-source loads (all 114 surahs) → future.
  final Map<String, Future<Map<String, String>?>> _pendingFull = {};

  // ── Metadata cache (sourceId → display name) ──────────────────────────────
  final Map<String, String> _meta = {};

  // ── Manifest (sourceId → category), fetched once ──────────────────────────
  Map<String, String>? _sourceCategory;
  Future<Map<String, String>>? _manifestPending;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the translation text for [verseKey] from [sourceId], downloading
  /// only the surah that [verseKey] belongs to.
  /// Returns null if the source or the verse is unavailable.
  Future<String?> getVerse(String sourceId, String verseKey) async {
    final surah = _surahOf(verseKey);
    if (surah == null) return null;
    final verses = await _loadSurah(sourceId, surah);
    if (verses != null) return verses[verseKey];
    // A failed surah fetch may still be covered by an earlier full load.
    return _loaded[sourceId]?[verseKey];
  }

  /// Returns all verses for [sourceId] across the 114 surahs.
  /// Returns null when nothing could be resolved (offline, no cache).
  Future<Map<String, String>?> getAllVerses(String sourceId) =>
      _loadAllSurahs(sourceId);

  /// Returns the display name of [sourceId] if already loaded, else null.
  String? getCachedName(String sourceId) => _meta[sourceId];

  /// Pre-fetches a set of sources in parallel (e.g. user's selected languages).
  Future<void> prefetch(List<String> sourceIds) async {
    await Future.wait(sourceIds.map((id) => _loadAllSurahs(id)));
  }

  /// Scans all **already-in-memory** loaded sources for [queryWord] across
  /// [verseKeys]. Returns a map of { sourceId → { verseKey → matchedText } }.
  /// This is instant (no network) — use before trying CDN downloads.
  Map<String, Map<String, String>> searchLoaded(
      List<String> verseKeys, String queryWord) {
    final result = <String, Map<String, String>>{};
    final lower = queryWord.toLowerCase();
    for (final entry in _loaded.entries) {
      for (final vk in verseKeys) {
        final text = entry.value[vk];
        if (text != null && text.toLowerCase().contains(lower)) {
          result.putIfAbsent(entry.key, () => {})[vk] = text;
        }
      }
    }
    return result;
  }

  /// Loads [sourceIds] from the R2 tree (cached after first call) and checks
  /// each for [queryWord] in the provided [verseKeys].
  /// Returns { sourceId → { verseKey → matchedText } }.
  Future<Map<String, Map<String, String>>> searchCdnSources(
      List<String> sourceIds,
      List<String> verseKeys,
      String queryWord) async {
    final result = <String, Map<String, String>>{};
    final lower = queryWord.toLowerCase();
    await Future.wait(sourceIds.map((sid) async {
      try {
        final verses = await _loadAllSurahs(sid);
        if (verses == null) return;
        for (final vk in verseKeys) {
          final text = verses[vk];
          if (text != null && text.toLowerCase().contains(lower)) {
            result.putIfAbsent(sid, () => {})[vk] = text;
          }
        }
      } catch (_) {}
    }));
    return result;
  }

  /// Removes every cached surah file for [sourceId] (to reclaim space).
  Future<void> evict(String sourceId) async {
    _loaded.remove(sourceId);
    _loadedSurahs.remove(sourceId);
    _meta.remove(sourceId);
    if (!kIsWeb) {
      try {
        final dir = await _sourceDir(sourceId);
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (e) {
        debugPrint('[R2] Cache evict failed for $sourceId: $e');
      }
    }
  }

  /// Clears all cached source files from disk.
  Future<void> clearAll() async {
    _loaded.clear();
    _loadedSurahs.clear();
    _meta.clear();
    _sourceCategory = null;
    if (!kIsWeb) {
      try {
        final dir = await _cacheDir();
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (e) {
        debugPrint('[R2] Cache clear failed: $e');
      }
    }
  }

  // ── Internal load logic ───────────────────────────────────────────────────

  /// Resolves a single surah, deduplicating concurrent callers.
  Future<Map<String, String>?> _loadSurah(String sourceId, int surah) {
    final loadedSurahs = _loadedSurahs[sourceId];
    if (loadedSurahs != null && loadedSurahs.contains(surah)) {
      return Future.value(_surahSlice(sourceId, surah));
    }
    final key = '${_safeSourceId(sourceId)}|$surah';
    return _pendingSurah.putIfAbsent(
      key,
      () => _resolveSurah(sourceId, surah)
          .whenComplete(() => _pendingSurah.remove(key)),
    );
  }

  Future<Map<String, String>?> _resolveSurah(String sourceId, int surah) async {
    final map = await _fetchSurah(sourceId, surah);
    if (map != null) {
      _loaded.putIfAbsent(sourceId, () => <String, String>{}).addAll(map);
      _loadedSurahs.putIfAbsent(sourceId, () => <int>{}).add(surah);
    }
    return map;
  }

  /// Resolves all 114 surahs for [sourceId] with bounded concurrency.
  Future<Map<String, String>?> _loadAllSurahs(String sourceId) async {
    final pending = _pendingFull[sourceId];
    if (pending != null) return pending;
    final future = _fetchAllSurahs(sourceId);
    _pendingFull[sourceId] = future;
    try {
      return await future;
    } finally {
      _pendingFull.remove(sourceId);
    }
  }

  Future<Map<String, String>?> _fetchAllSurahs(String sourceId) async {
    var resolved = 0;
    await _runBounded(List<Future<void> Function()>.generate(
      _surahCount,
      (i) => () async {
        final map = await _loadSurah(sourceId, i + 1);
        if (map != null) resolved++;
      },
    ));
    if (resolved == 0) {
      final merged = _loaded[sourceId];
      if (merged == null || merged.isEmpty) return null;
    }
    return _loaded[sourceId] ?? <String, String>{};
  }

  /// Fetches one surah file: on-disk cache first, then the R2 tree.
  /// Returns null only on a hard failure (network error / unexpected status).
  Future<Map<String, String>?> _fetchSurah(String sourceId, int surah) async {
    final name = _surahFile(surah);

    // 1. On-disk cache
    if (!kIsWeb) {
      try {
        final file = await _surahCacheFile(sourceId, surah);
        if (await file.exists()) {
          final cached = _decodeVerses(await file.readAsString());
          if (cached != null) return cached;
        }
      } catch (e) {
        debugPrint('[R2] Cache read failed for $sourceId/$name: $e');
      }
    }

    // 2. Download
    try {
      final category = await _categoryFor(sourceId);
      final url =
          '$_cdnBase/$category/${Uri.encodeComponent(sourceId)}/$name.json';
      debugPrint('[R2] Fetching $url');

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) {
        // Sparse source — this surah simply has no rows. Cache the negative.
        if (!kIsWeb) {
          try {
            final file = await _surahCacheFile(sourceId, surah);
            await file.parent.create(recursive: true);
            await file.writeAsString('{}');
          } catch (e) {
            debugPrint('[R2] Cache write failed for $sourceId/$name (non-fatal): $e');
          }
        }
        return const <String, String>{};
      }

      if (response.statusCode != 200) {
        debugPrint('[R2] HTTP ${response.statusCode} for $url');
        return null;
      }

      final body = utf8.decode(response.bodyBytes);

      // Save to disk cache (non-fatal)
      if (!kIsWeb) {
        try {
          final file = await _surahCacheFile(sourceId, surah);
          await file.parent.create(recursive: true);
          await file.writeAsString(body);
        } catch (e) {
          debugPrint('[R2] Cache write failed for $sourceId/$name (non-fatal): $e');
        }
      }

      return _decodeVerses(body);
    } catch (e) {
      debugPrint('[R2] Download failed for $sourceId/$name: $e');
      return null;
    }
  }

  // ── Manifest (sourceId → category) ────────────────────────────────────────

  Future<Map<String, String>> _ensureManifest() async {
    final cached = _sourceCategory;
    if (cached != null) return cached;

    final pending = _manifestPending;
    if (pending != null) return pending;

    final future = _loadManifest();
    _manifestPending = future;
    try {
      return await future;
    } finally {
      _manifestPending = null;
    }
  }

  Future<Map<String, String>> _loadManifest() async {
    // 1. On-disk copy (survives offline launches).
    if (!kIsWeb) {
      try {
        final file = await _manifestFile();
        if (await file.exists()) {
          final parsed = _parseManifest(await file.readAsString());
          if (parsed.isNotEmpty) {
            _sourceCategory = parsed;
            return parsed;
          }
        }
      } catch (e) {
        debugPrint('[R2] Manifest cache read failed: $e');
      }
    }

    // 2. Network
    final body = await _getText('$_cdnBase/manifest.json');
    if (body != null) {
      final parsed = _parseManifest(body);
      if (parsed.isNotEmpty) {
        _sourceCategory = parsed;
        if (!kIsWeb) {
          try {
            final file = await _manifestFile();
            await file.parent.create(recursive: true);
            await file.writeAsString(body);
          } catch (e) {
            debugPrint('[R2] Manifest cache write failed (non-fatal): $e');
          }
        }
        return parsed;
      }
    }

    // 3. Unknown — callers fall back to the id-suffix heuristic.
    return const <String, String>{};
  }

  Map<String, String> _parseManifest(String body) {
    final out = <String, String>{};
    try {
      final root = jsonDecode(body);
      if (root is! Map) return out;
      final sources = root['sources'];
      if (sources is! Map) return out;
      for (final entry in sources.entries) {
        final category = entry.key;
        if (category is! String || !_categories.contains(category)) continue;
        final list = entry.value;
        if (list is! List) continue;
        for (final item in list) {
          if (item is! Map) continue;
          final id = item['id'];
          if (id is! String || id.isEmpty) continue;
          out[id] = category;
          final name = item['name'];
          if (name is String && name.isNotEmpty) _meta[id] = name;
        }
      }
    } catch (e) {
      debugPrint('[R2] Manifest parse failed: $e');
    }
    return out;
  }

  /// Category a [sourceId] lives under, from the manifest when known.
  Future<String> _categoryFor(String sourceId) async {
    final manifest = await _ensureManifest();
    final category = manifest[sourceId];
    if (category != null && _categories.contains(category)) return category;
    return _fallbackCategory(sourceId);
  }

  /// Deterministic category derived from the source id alone, used when the
  /// manifest is unavailable (first run offline, CDN error).
  static String _fallbackCategory(String sourceId) {
    final id = sourceId.toLowerCase();
    if (id.endsWith('.transliteration') || id.contains('translit')) {
      return 'transliterations';
    }
    if (id.endsWith('_nuzul') || id == 'en.wahidi') return 'asbabun_nuzul';
    return 'translations';
  }

  // ── HTTP ──────────────────────────────────────────────────────────────────

  Future<String?> _getText(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        debugPrint('[R2] HTTP ${response.statusCode} for $url');
        return null;
      }
      return utf8.decode(response.bodyBytes);
    } catch (e) {
      debugPrint('[R2] Fetch failed for $url: $e');
      return null;
    }
  }

  // ── Bounded concurrency ───────────────────────────────────────────────────

  static Future<void> _runBounded(
    List<Future<void> Function()> tasks, {
    int concurrency = _maxConcurrent,
  }) async {
    if (tasks.isEmpty) return;
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= tasks.length) return;
        try {
          await tasks[index]();
        } catch (e) {
          debugPrint('[R2] Batch task failed: $e');
        }
      }
    }

    final workers = tasks.length < concurrency ? tasks.length : concurrency;
    await Future.wait(List.generate(workers, (_) => worker()));
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Decodes a per-surah payload: a flat `{ "2:255": "text" }` map.
  static Map<String, String>? _decodeVerses(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final out = <String, String>{};
      decoded.forEach((key, value) {
        if (key is String && value is String) out[key] = value;
      });
      return out;
    } catch (e) {
      debugPrint('[R2] Verse payload parse failed: $e');
      return null;
    }
  }

  Map<String, String> _surahSlice(String sourceId, int surah) {
    final merged = _loaded[sourceId];
    if (merged == null) return const <String, String>{};
    final prefix = '$surah:';
    final out = <String, String>{};
    for (final entry in merged.entries) {
      if (entry.key.startsWith(prefix)) out[entry.key] = entry.value;
    }
    return out;
  }

  // ── Cache path helpers ────────────────────────────────────────────────────

  Future<Directory> _cacheDir() async {
    final base = kIsWeb
        ? Directory('/cache') // web: not used (in-memory only)
        : await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'cdn_translations_v$_cacheVersion'));
  }

  Future<Directory> _sourceDir(String sourceId) async {
    final dir = await _cacheDir();
    return Directory(p.join(dir.path, _safeSourceId(sourceId)));
  }

  Future<File> _surahCacheFile(String sourceId, int surah) async {
    final dir = await _sourceDir(sourceId);
    return File(p.join(dir.path, '${_surahFile(surah)}.json'));
  }

  Future<File> _manifestFile() async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, '_manifest.json'));
  }

  static String _safeSourceId(String sourceId) =>
      sourceId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  static String _surahFile(int surah) => surah.toString().padLeft(3, '0');

  /// Surah number of a "surah:ayah" verse key, or null when malformed.
  static int? _surahOf(String verseKey) {
    final colon = verseKey.indexOf(':');
    if (colon <= 0) return null;
    final surah = int.tryParse(verseKey.substring(0, colon));
    if (surah == null || surah < 1 || surah > _surahCount) return null;
    return surah;
  }
}
