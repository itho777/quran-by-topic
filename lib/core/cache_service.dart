import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'local_db.dart';

/// A singleton service that provides transparent, on-the-go caching for:
/// - Text content (translations, tafsirs, asbabun nuzul)
/// - Mushaf SVG pages
/// - Audio files
///
/// Text data is stored in SQLite via [LocalDatabase]; binary assets are saved to
/// the device's documents directory and their paths are recorded in SQLite.
class CacheService {
  static CacheService? _instance;

  CacheService._(this._db, this._dio);

  /// Returns the shared [CacheService] instance, creating it on first call.
  static Future<CacheService> getInstance() async {
    if (_instance == null) {
      final db = LocalDatabase.instance;
      final dio = Dio();
      _instance = CacheService._(db, dio);
    }
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final LocalDatabase _db;
  final Dio _dio;

  // ---------------------------------------------------------------------------
  // Text data
  // ---------------------------------------------------------------------------

  /// Returns cached text for [verseKey] / [sourceId] from [table].
  ///
  /// If no cached value exists, [fetcher] is called.  A non-null result from
  /// [fetcher] is persisted to the local database before being returned.
  Future<String?> getOrFetchText(
    String table,
    String verseKey,
    String sourceId,
    Future<String?> Function() fetcher,
  ) async {
    // 1. Try the local cache first.
    final cached = await _db.getTextData(table, verseKey, sourceId);
    if (cached != null) return cached;

    // 2. Fetch from the network.
    final fetched = await fetcher();
    if (fetched == null) return null;

    // 3. Persist and return.
    await _db.saveTextData(table, verseKey, sourceId, fetched);
    return fetched;
  }

  // ---------------------------------------------------------------------------
  // Mushaf pages
  // ---------------------------------------------------------------------------

  /// Returns the local path of the Mushaf SVG for [pageNum].
  ///
  /// If the file is not already cached, it is downloaded from [networkUrl],
  /// saved to `{appDocDir}/mushaf/page_{pageNum:03d}.svg`, and its path is
  /// recorded in the database.  Returns `null` on any error.
  Future<String?> getOrCacheMushafPage(int pageNum, String networkUrl) async {
    // 1. Check the database record first.
    final savedPath = await _db.getMushafPage(pageNum);
    if (savedPath != null && File(savedPath).existsSync()) {
      return savedPath;
    }

    // 2. Build the local target path.
    final docDir = await getApplicationDocumentsDirectory();
    final mushafDir = Directory(p.join(docDir.path, 'mushaf'));
    if (!mushafDir.existsSync()) {
      mushafDir.createSync(recursive: true);
    }
    final fileName = 'page_${pageNum.toString().padLeft(3, '0')}.svg';
    final filePath = p.join(mushafDir.path, fileName);

    // 3. Download.
    try {
      await _dio.download(networkUrl, filePath);
    } on DioException catch (_) {
      return null;
    } catch (_) {
      return null;
    }

    // 4. Persist the path and return.
    await _db.saveMushafPage(pageNum, filePath);
    return filePath;
  }

  // ---------------------------------------------------------------------------
  // Audio files
  // ---------------------------------------------------------------------------

  /// Returns the local path of the audio file for [reciterId] / [surahNum].
  ///
  /// If the file is not already cached, it is downloaded from [networkUrl],
  /// saved to `{appDocDir}/audio/{reciterId}/{surahNum:03d}.mp3`, and its path
  /// is recorded in the database.  [onProgress] is called during the download
  /// with (bytesReceived, totalBytes).  Returns `null` on any error.
  Future<String?> getOrCacheAudioFile(
    String reciterId,
    int surahNum,
    String networkUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    // 1. Check the database record first.
    final savedPath = await _db.getAudioFile(reciterId, surahNum);
    if (savedPath != null && File(savedPath).existsSync()) {
      return savedPath;
    }

    // 2. Build the local target path.
    final docDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docDir.path, 'audio', reciterId));
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }
    final fileName = '${surahNum.toString().padLeft(3, '0')}.mp3';
    final filePath = p.join(audioDir.path, fileName);

    // 3. Download with optional progress callback.
    try {
      await _dio.download(
        networkUrl,
        filePath,
        onReceiveProgress: onProgress != null
            ? (received, total) => onProgress(received, total)
            : null,
      );
    } on DioException catch (_) {
      return null;
    } catch (_) {
      return null;
    }

    // 4. Persist the path and return.
    await _db.saveAudioFile(reciterId, surahNum, filePath);
    return filePath;
  }

  // ---------------------------------------------------------------------------
  // Storage metrics
  // ---------------------------------------------------------------------------

  /// Returns the total size in bytes of all files in `{appDocDir}/mushaf/`.
  Future<int> getMushafStorageBytes() async {
    final docDir = await getApplicationDocumentsDirectory();
    final mushafDir = Directory(p.join(docDir.path, 'mushaf'));
    return _dirSizeBytes(mushafDir);
  }

  /// Returns the total size in bytes of audio files.
  ///
  /// If [reciterId] is provided, only that reciter's folder is measured;
  /// otherwise the entire `{appDocDir}/audio/` directory is summed.
  Future<int> getAudioStorageBytes(String? reciterId) async {
    final docDir = await getApplicationDocumentsDirectory();
    final audioBase = p.join(docDir.path, 'audio');
    final targetPath =
        reciterId != null ? p.join(audioBase, reciterId) : audioBase;
    return _dirSizeBytes(Directory(targetPath));
  }

  /// Returns the size of the SQLite database file in bytes.
  Future<int> getTextStorageBytes() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(docDir.path, 'tafseer_cache.db'));
    if (!dbFile.existsSync()) return 0;
    return dbFile.lengthSync();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Recursively sums the sizes of all files inside [dir].
  /// Returns 0 if the directory does not exist.
  int _dirSizeBytes(Directory dir) {
    if (!dir.existsSync()) return 0;
    int total = 0;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File) {
        try {
          total += entity.lengthSync();
        } catch (_) {
          // Skip files that can't be stat'd (e.g. broken symlinks).
        }
      }
    }
    return total;
  }
}
