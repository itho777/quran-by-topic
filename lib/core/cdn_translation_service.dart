import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// CdnTranslationService
/// ─────────────────────
/// Serves the 108 non-primary translations from pre-built JSON files stored in
/// Supabase Storage (public CDN).  Each file is downloaded once and cached on
/// device for instant subsequent access.
///
/// File format on CDN:
///   {
///     "source_id": "en.pickthall",
///     "name":      "Pickthall (English)",
///     "language":  "EN",
///     "verses": {
///       "1:1": "In the name of Allah, the Beneficent, the Merciful.",
///       "1:2": "Praise be to Allah, Lord of the Worlds,",
///       ...
///     }
///   }
///
/// Usage:
///   final text = await CdnTranslationService.instance.getVerse('en.pickthall', '2:255');
///
class CdnTranslationService {
  CdnTranslationService._();
  static final CdnTranslationService instance = CdnTranslationService._();

  // ── Config ────────────────────────────────────────────────────────────────
  static const String _cdnBase =
      'https://zgeygoclduqotqveperx.supabase.co/storage/v1/object/public/quran-index';

  /// Cache version — bump to evict cached files on breaking format changes.
  static const int _cacheVersion = 1;

  // ── In-memory cache: sourceId → { verseKey → text } ──────────────────────
  final Map<String, Map<String, String>> _loaded = {};

  // ── Pending load futures (prevents duplicate downloads) ───────────────────
  final Map<String, Future<Map<String, String>?>> _pending = {};

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the translation text for [verseKey] from [sourceId],
  /// downloading and caching the source file if necessary.
  /// Returns null if the source is unavailable.
  Future<String?> getVerse(String sourceId, String verseKey) async {
    final verses = await _getVerses(sourceId);
    return verses?[verseKey];
  }

  /// Returns all verses for [sourceId]. Useful for offline surah reading.
  Future<Map<String, String>?> getAllVerses(String sourceId) =>
      _getVerses(sourceId);

  /// Returns the display name of [sourceId] if already loaded, else null.
  String? getCachedName(String sourceId) => _meta[sourceId];

  /// Pre-fetches a set of sources in parallel (e.g. user's selected languages).
  Future<void> prefetch(List<String> sourceIds) async {
    await Future.wait(sourceIds.map((id) => _getVerses(id)));
  }

  /// Removes the on-disk cache for [sourceId] (to reclaim space).
  Future<void> evict(String sourceId) async {
    _loaded.remove(sourceId);
    _meta.remove(sourceId);
    final file = await _cacheFile(sourceId);
    if (await file.exists()) await file.delete();
  }

  /// Clears all cached translation files from disk.
  Future<void> clearAll() async {
    _loaded.clear();
    _meta.clear();
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ── Metadata cache (sourceId → display name) ──────────────────────────────
  final Map<String, String> _meta = {};

  // ── Internal load logic ───────────────────────────────────────────────────

  Future<Map<String, String>?> _getVerses(String sourceId) async {
    // Already in memory
    if (_loaded.containsKey(sourceId)) return _loaded[sourceId];

    // Deduplicate concurrent calls for the same source
    if (_pending.containsKey(sourceId)) return _pending[sourceId];

    final future = _loadSource(sourceId);
    _pending[sourceId] = future;
    try {
      final result = await future;
      if (result != null) _loaded[sourceId] = result;
      return result;
    } finally {
      _pending.remove(sourceId);
    }
  }

  Future<Map<String, String>?> _loadSource(String sourceId) async {
    // 1. Try on-disk cache first
    try {
      final file = await _cacheFile(sourceId);
      if (await file.exists()) {
        final raw = await file.readAsString();
        return _parsePayload(raw);
      }
    } catch (e) {
      debugPrint('[CDN] Cache read failed for $sourceId: $e');
    }

    // 2. Download from CDN
    try {
      final url = '$_cdnBase/$sourceId.json';
      debugPrint('[CDN] Fetching $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[CDN] HTTP ${response.statusCode} for $sourceId');
        return null;
      }

      final body = utf8.decode(response.bodyBytes);

      // Save to disk cache (non-fatal)
      try {
        final file = await _cacheFile(sourceId);
        await file.parent.create(recursive: true);
        await file.writeAsString(body);
      } catch (e) {
        debugPrint('[CDN] Cache write failed for $sourceId (non-fatal): $e');
      }

      return _parsePayload(body);
    } catch (e) {
      debugPrint('[CDN] Download failed for $sourceId: $e');
      return null;
    }
  }

  /// Parses the CDN JSON payload in a background isolate.
  Future<Map<String, String>?> _parsePayload(String body) async {
    try {
      final parsed = await compute(_decodePayload, body);
      if (parsed == null) return null;
      // Cache display name
      final sid = parsed['source_id'];
      final name = parsed['name'];
      if (sid is String && name is String) _meta[sid] = name;
      // Return verses map
      final verses = parsed['verses'];
      if (verses is Map) {
        return verses.map((k, v) => MapEntry(k as String, v as String));
      }
      return null;
    } catch (e) {
      debugPrint('[CDN] Parse failed: $e');
      return null;
    }
  }

  // ── Cache path helpers ────────────────────────────────────────────────────

  Future<Directory> _cacheDir() async {
    final base = kIsWeb
        ? Directory('/cache') // web: not used (in-memory only)
        : await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'cdn_translations_v$_cacheVersion'));
  }

  Future<File> _cacheFile(String sourceId) async {
    final dir = await _cacheDir();
    // Sanitize sourceId → safe filename
    final safe = sourceId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return File(p.join(dir.path, '$safe.json'));
  }

  // ── Isolate helper ────────────────────────────────────────────────────────
  static Map<String, dynamic>? _decodePayload(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
