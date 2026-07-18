// lib/core/static_index_service.dart
//
// Provides keyword search over the full pre-built static search index.
// The index is loaded from:
//   1. A locally downloaded file (app documents dir):  search_index.json.gz
//   2. Fallback: Supabase Storage (online only, old compressed copy)
//
// The user can trigger a download of the latest index from GitHub via
// downloadFromGitHub(), which stores it locally for offline use.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class StaticIndexHit {
  final String verseKey;
  final int score;
  StaticIndexHit(this.verseKey, this.score);
}

class StaticIndexService extends ChangeNotifier {
  StaticIndexService._();
  static final StaticIndexService instance = StaticIndexService._();

  // Primary: raw GitHub (rich, always fresh, no size limit)
  static const String _githubIndexUrl =
      'https://raw.githubusercontent.com/itho777/quran-by-topic/main/data/search_index.json.gz';

  // Fallback: Supabase Storage (old copy)
  static const String _supabaseIndexUrl =
      'https://zgeygoclduqotqveperx.supabase.co/storage/v1/object/public/assets/search_index.json.gz';

  static const String _localFileName = 'search_index.json.gz';

  Map<String, dynamic>? _indexData;
  bool _isLoading = false;
  bool _isDownloading = false;
  String? _loadError;
  double _downloadProgress = 0.0;  // 0.0 – 1.0
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  bool get isReady => _indexData != null;
  bool get isLoading => _isLoading;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  String? get loadError => _loadError;

  void setIndexForTesting(Map<String, dynamic> index) {
    _indexData = index;
    notifyListeners();
  }

  // ─── Local file path ─────────────────────────────────────────────────────

  Future<File?> _localFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_localFileName');
    } catch (_) {
      return null;
    }
  }

  /// Returns true if a locally downloaded index exists on disk.
  Future<bool> hasLocalIndex() async {
    final f = await _localFile();
    return f != null && f.existsSync();
  }

  /// Returns the size of the local index file in bytes (0 if missing).
  Future<int> localIndexSizeBytes() async {
    final f = await _localFile();
    if (f == null || !f.existsSync()) return 0;
    return f.lengthSync();
  }

  // ─── Load index into memory ───────────────────────────────────────────────

  Future<void> ensureLoaded() async {
    if (_indexData != null) return;
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      // 1. Try local file first
      final localFile = await _localFile();
      if (localFile != null && localFile.existsSync()) {
        debugPrint('[StaticIndex] Loading from local file...');
        final bytes = await localFile.readAsBytes();
        await _parseBytes(bytes);
        if (_indexData != null) {
          debugPrint('[StaticIndex] Loaded from local file. Keys: ${_indexData!.length}');
          return;
        }
      }

      // 2. Online: Try Supabase Storage fallback (no progress — background warm-up)
      if (!kIsWeb) {
        // On mobile, skip auto-online download; require explicit user download.
        debugPrint('[StaticIndex] No local index found. User must download it from settings.');
        _loadError = 'no_local_index';
        return;
      }

      // Web: download from Supabase directly
      debugPrint('[StaticIndex] Downloading from Supabase Storage...');
      final response = await http.get(Uri.parse(_supabaseIndexUrl)).timeout(
        const Duration(seconds: 90),
      );
      if (response.statusCode == 200) {
        await _parseBytes(response.bodyBytes);
        debugPrint('[StaticIndex] Loaded from Supabase. Keys: ${_indexData?.length}');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _loadError = e.toString();
      debugPrint('[StaticIndex] Load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _parseBytes(List<int> bytes) async {
    List<int> raw = bytes;
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      debugPrint('[StaticIndex] Decompressing gzip...');
      raw = GZipDecoder().decodeBytes(bytes);
    }
    final str = utf8.decode(raw);
    _indexData = jsonDecode(str) as Map<String, dynamic>;
  }

  // ─── Download from GitHub with progress ──────────────────────────────────

  /// Downloads the latest search index from GitHub raw URL and stores it locally.
  /// Calls [onProgress] with (received, total) bytes. Returns null on success,
  /// or an error message on failure.
  Future<String?> downloadFromGitHub({
    void Function(int received, int total)? onProgress,
  }) async {
    if (_isDownloading) return 'Download already in progress';
    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadedBytes = 0;
    _totalBytes = 0;
    notifyListeners();

    try {
      final localFile = await _localFile();
      if (localFile == null) {
        _isDownloading = false;
        notifyListeners();
        return 'Cannot access local storage';
      }

      final request = http.Request('GET', Uri.parse(_githubIndexUrl));
      final response = await http.Client().send(request).timeout(const Duration(seconds: 300));

      if (response.statusCode != 200) {
        _isDownloading = false;
        notifyListeners();
        return 'HTTP ${response.statusCode}';
      }

      _totalBytes = response.contentLength ?? 0;
      final sink = localFile.openWrite();
      final received = <int>[];

      await response.stream.forEach((chunk) {
        received.addAll(chunk);
        sink.add(chunk);
        _downloadedBytes = received.length;
        if (_totalBytes > 0) {
          _downloadProgress = _downloadedBytes / _totalBytes;
        }
        onProgress?.call(_downloadedBytes, _totalBytes);
        notifyListeners();
      });

      await sink.close();
      debugPrint('[StaticIndex] Download complete. ${received.length} bytes written to ${localFile.path}');

      // Re-parse freshly downloaded file
      _indexData = null;
      await _parseBytes(received);
      debugPrint('[StaticIndex] Re-indexed. Keys: ${_indexData?.length}');

      _downloadProgress = 1.0;
      _isDownloading = false;
      notifyListeners();
      return null; // success
    } catch (e) {
      debugPrint('[StaticIndex] Download error: $e');
      _isDownloading = false;
      notifyListeners();
      return e.toString();
    }
  }

  /// Delete the local downloaded index file (for re-download / storage cleanup).
  Future<void> deleteLocalIndex() async {
    final f = await _localFile();
    if (f != null && f.existsSync()) {
      await f.delete();
      _indexData = null;
      notifyListeners();
    }
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  static const Set<String> _stopWords = {
    'the', 'of', 'it', 'is', 'in', 'and', 'to', 'a', 'for', 'with',
    'on', 'by', 'at', 'an', 'this', 'that', 'from', 'as', 'are',
    'was', 'were', 'or',
  };

  Future<List<StaticIndexHit>> search(String query, {int? maxResults}) async {
    if (_indexData == null) return [];
    final terms = _indexData!;

    final rawWords = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final words = rawWords.where((w) {
      if (w.length < 3) return false;
      if (_stopWords.contains(w)) return false;
      return true;
    }).toList();

    if (words.isEmpty) return [];

    final scoreMap = <String, int>{};

    for (final word in words) {
      for (final term in terms.keys) {
        int termScore = 0;
        if (term == word) {
          termScore = 2;
        } else if (word.length >= 4 && term.startsWith(word)) {
          termScore = 1;
        }

        if (termScore > 0) {
          final val = terms[term];
          if (val is String) {
            final entries = val.split(',');
            for (final entry in entries) {
              final key = entry.split('_')[0].trim();
              if (key.isNotEmpty) {
                scoreMap[key] = (scoreMap[key] ?? 0) + termScore;
              }
            }
          }
        }
      }
    }

    final hits = scoreMap.entries
        .map((e) => StaticIndexHit(e.key, e.value))
        .toList();

    hits.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.verseKey.compareTo(b.verseKey);
    });

    if (maxResults != null && hits.length > maxResults) {
      return hits.sublist(0, maxResults);
    }
    return hits;
  }
}
