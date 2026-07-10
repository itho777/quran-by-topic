// lib/core/download_service.dart
//
// Bulk download manager for:
//   - Text data  (translations / tafsirs / asbabun_nuzul) from Supabase
//   - Mushaf SVG pages from quran.ksu.edu.sa
//   - Audio MP3 files from quranicaudio CDN
//
// Depends on:
//   supabase_flutter, dio, sqflite (via LocalDatabase), flutter_riverpod,
//   path_provider

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_db.dart';

// ---------------------------------------------------------------------------
// CDN / storage constants
// ---------------------------------------------------------------------------

const _mushafBaseUrl =
    'https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg';

const _audioBaseUrl =
    'https://download.quranicaudio.com/quran';

const int _mushafTotalPages = 604;
const int _totalSurahs = 114;
const int _textPageSize = 500;

// ---------------------------------------------------------------------------
// DownloadProgress model
// ---------------------------------------------------------------------------

class DownloadProgress {
  const DownloadProgress({
    required this.sourceType,
    required this.sourceId,
    required this.downloaded,
    required this.total,
    required this.status,
    this.error,
  });

  /// 'translation' | 'tafsir' | 'nuzul' | 'mushaf' | 'audio'
  final String sourceType;

  /// Unique identifier for the content being downloaded.
  final String sourceId;

  final int downloaded;
  final int total;

  /// 'downloading' | 'paused' | 'completed' | 'error' | 'idle'
  final String status;

  final String? error;

  DownloadProgress copyWith({
    String? sourceType,
    String? sourceId,
    int? downloaded,
    int? total,
    String? status,
    String? error,
  }) {
    return DownloadProgress(
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      downloaded: downloaded ?? this.downloaded,
      total: total ?? this.total,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  @override
  String toString() =>
      'DownloadProgress(type=$sourceType, id=$sourceId, '
      '$downloaded/$total, status=$status, error=$error)';
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService._internal(),
);

// ---------------------------------------------------------------------------
// DownloadService
// ---------------------------------------------------------------------------

class DownloadService {
  DownloadService._internal();

  // ── dependencies ──────────────────────────────────────────────────────────

  SupabaseClient get _supabase => Supabase.instance.client;

  LocalDatabase get _db => LocalDatabase.instance;

  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // =========================================================================
  // 1. Text source download  (translations / tafsirs / asbabun_nuzul)
  // =========================================================================

  /// Streams [DownloadProgress] while fetching all rows for [sourceId] from
  /// [table] in Supabase (pages of 500) and persisting them to the local DB.
  ///
  /// [sourceType] must be one of: 'translation', 'tafsir', 'nuzul'
  /// [label] is a human-readable name stored in the manifest.
  Stream<DownloadProgress> downloadTextSource({
    required String sourceType,
    required String table,
    required String sourceId,
    required String label,
  }) async* {
    // ── initial progress ───────────────────────────────────────────────────
    DownloadProgress progress = DownloadProgress(
      sourceType: sourceType,
      sourceId: sourceId,
      downloaded: 0,
      total: 0,
      status: 'downloading',
    );
    yield progress;

    try {
      // ── 1a. count total rows ─────────────────────────────────────────────
      final countResponse = await _supabase
          .from(table)
          .select()
          .eq('source_id', sourceId)
          .count(CountOption.exact);

      final int total = countResponse.count;

      progress = progress.copyWith(total: total);
      yield progress;

      if (total == 0) {
        await _db.upsertManifest(
          sourceType: sourceType,
          sourceId: sourceId,
          label: label,
          status: 'completed',
          totalItems: 0,
          downloadedItems: 0,
        );
        yield progress.copyWith(status: 'completed');
        return;
      }

      // ── 1b. fetch pages ──────────────────────────────────────────────────
      int offset = 0;
      int downloaded = 0;

      while (offset < total) {
        final int rangeEnd = offset + _textPageSize - 1;

        final List<dynamic> rows = await _supabase
            .from(table)
            .select('verse_key, source_id, text')
            .eq('source_id', sourceId)
            .range(offset, rangeEnd);

        // ── 1c. persist batch ─────────────────────────────────────────────
        for (final row in rows) {
          final String verseKey = row['verse_key'] as String;
          final String text = row['text'] as String;

          await _db.saveTextData(table, verseKey, sourceId, text);
        }

        downloaded += rows.length;
        offset += _textPageSize;

        // ── 1d. update manifest ───────────────────────────────────────────
        await _db.upsertManifest(
          sourceType: sourceType,
          sourceId: sourceId,
          label: label,
          status: downloaded >= total ? 'completed' : 'downloading',
          totalItems: total,
          downloadedItems: downloaded,
        );

        progress = progress.copyWith(
          downloaded: downloaded,
          total: total,
          status: downloaded >= total ? 'completed' : 'downloading',
        );
        yield progress;
      }
    } catch (e, st) {
      final errorMsg = _describeError(e, st);
      yield progress.copyWith(status: 'error', error: errorMsg);
    }
  }

  // =========================================================================
  // 2. Mushaf SVG pages (1–604)
  // =========================================================================

  /// Downloads all 604 Mushaf SVG pages, skipping any already present (resume).
  ///   `{appDocDir}/mushaf/page_{pageNum:03d}.svg`
  Stream<DownloadProgress> downloadMushafPages({bool resume = false}) async* {
    const sourceType = 'mushaf';
    const sourceId = 'hafs_kfqc';

    DownloadProgress progress = DownloadProgress(
      sourceType: sourceType,
      sourceId: sourceId,
      downloaded: 0,
      total: _mushafTotalPages,
      status: 'downloading',
    );
    yield progress;

    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory mushafDir = Directory('${appDocDir.path}/mushaf');
      if (!mushafDir.existsSync()) {
        await mushafDir.create(recursive: true);
      }

      int downloaded = 0;
      for (int page = 1; page <= _mushafTotalPages; page++) {
        final String fileName = 'page_${page.toString().padLeft(3, '0')}.svg';
        final String filePath = '${mushafDir.path}/$fileName';
        final String url =
            '$_mushafBaseUrl/${page.toString().padLeft(3, '0')}.svg';

        // Skip pages already on disk when resuming
        final alreadyExists = File(filePath).existsSync();
        if (alreadyExists) {
          downloaded++;
          progress = progress.copyWith(
            downloaded: downloaded,
            status: downloaded == _mushafTotalPages ? 'completed' : 'downloading',
          );
          yield progress;
          continue;
        }

        try {
          await _dio.download(url, filePath);
          await _db.saveMushafPage(page, filePath);
        } catch (e) {
          // ignore: avoid_print
          print('[DownloadService] Mushaf page $page failed: $e');
        }

        downloaded++;
        await _db.upsertManifest(
          sourceType: sourceType,
          sourceId: sourceId,
          label: 'Hafs Smart v2',
          status: downloaded >= _mushafTotalPages ? 'completed' : 'downloading',
          totalItems: _mushafTotalPages,
          downloadedItems: downloaded,
        );

        progress = progress.copyWith(
          downloaded: downloaded,
          status: downloaded >= _mushafTotalPages ? 'completed' : 'downloading',
        );
        yield progress;
      }
    } catch (e, st) {
      yield progress.copyWith(
        status: 'error',
        error: _describeError(e, st),
      );
    }
  }

  // =========================================================================
  // 3. Single audio surah
  // =========================================================================

  /// Downloads one MP3 file and saves it to:
  ///   `{appDocDir}/audio/{reciterId}/{surahNum:03d}.mp3`
  Stream<DownloadProgress> downloadAudioSurah({
    required String reciterId,
    required int surahNum,
  }) async* {
    const sourceType = 'audio';
    final String sourceId = '${reciterId}_${surahNum.toString().padLeft(3, '0')}';

    DownloadProgress progress = DownloadProgress(
      sourceType: sourceType,
      sourceId: sourceId,
      downloaded: 0,
      total: 1,
      status: 'downloading',
    );
    yield progress;

    try {
      final String filePath =
          await _audioFilePath(reciterId: reciterId, surahNum: surahNum);
      final String url = _audioUrl(reciterId: reciterId, surahNum: surahNum);

      await _dio.download(url, filePath);

      await _db.saveAudioFile(
        reciterId,
        surahNum,
        filePath,
      );

      await _db.upsertManifest(
        sourceType: sourceType,
        sourceId: sourceId,
        label: 'Audio $reciterId surah $surahNum',
        status: 'completed',
        totalItems: 1,
        downloadedItems: 1,
      );

      yield progress.copyWith(downloaded: 1, status: 'completed');
    } catch (e, st) {
      yield progress.copyWith(
        status: 'error',
        error: _describeError(e, st),
      );
    }
  }

  // =========================================================================
  // 4. All 114 audio surahs for a reciter
  // =========================================================================

  /// Downloads all 114 surahs for [reciterId], skipping any already on disk (resume).
  Stream<DownloadProgress> downloadAllAudioSurahs({
    required String reciterId,
    required String reciterName,
    bool resume = false,
  }) async* {
    const sourceType = 'audio';

    DownloadProgress progress = DownloadProgress(
      sourceType: sourceType,
      sourceId: reciterId,
      downloaded: 0,
      total: _totalSurahs,
      status: 'downloading',
    );
    yield progress;

    try {
      int downloaded = 0;
      for (int surahNum = 1; surahNum <= _totalSurahs; surahNum++) {
        final String filePath =
            await _audioFilePath(reciterId: reciterId, surahNum: surahNum);
        final String url = _audioUrl(reciterId: reciterId, surahNum: surahNum);

        // Skip files already present when resuming
        if (File(filePath).existsSync()) {
          downloaded++;
          progress = progress.copyWith(
            downloaded: downloaded,
            status: downloaded == _totalSurahs ? 'completed' : 'downloading',
          );
          yield progress;
          continue;
        }

        try {
          await _dio.download(url, filePath);
          await _db.saveAudioFile(reciterId, surahNum, filePath);
        } catch (e) {
          // Non-fatal per surah — log and continue.
          // ignore: avoid_print
          print('[DownloadService] Audio $reciterId/$surahNum failed: $e');
        }

        downloaded++;
        await _db.upsertManifest(
          sourceType: sourceType,
          sourceId: reciterId,
          label: reciterName,
          status: downloaded >= _totalSurahs ? 'completed' : 'downloading',
          totalItems: _totalSurahs,
          downloadedItems: downloaded,
        );

        progress = progress.copyWith(
          downloaded: downloaded,
          status: downloaded >= _totalSurahs ? 'completed' : 'downloading',
        );
        yield progress;
      }
    } catch (e, st) {
      yield progress.copyWith(
        status: 'error',
        error: _describeError(e, st),
      );
    }
  }

  // =========================================================================
  // 5. Delete text source
  // =========================================================================

  /// Removes all local rows for [sourceId] from [table] and resets its
  /// manifest entry to 'idle'.
  Future<void> deleteTextSource(
    String table,
    String sourceType,
    String sourceId,
  ) async {
    await _db.deleteSource(table, sourceId);
    await _db.upsertManifest(
      sourceType: sourceType,
      sourceId: sourceId,
      label: '',
      status: 'idle',
      totalItems: 0,
      downloadedItems: 0,
    );
  }

  // =========================================================================
  // 6. Delete Mushaf pages
  // =========================================================================

  Future<void> deleteMushafPages() async {
    const sourceId = 'hafs_smart_v2';

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory mushafDir = Directory('${appDocDir.path}/mushaf');

    if (mushafDir.existsSync()) {
      await mushafDir.delete(recursive: true);
    }

    await _db.deleteMushafPages();
    await _db.upsertManifest(
      sourceType: 'mushaf',
      sourceId: sourceId,
      label: 'Hafs Smart v2',
      status: 'idle',
      totalItems: 0,
      downloadedItems: 0,
    );
  }

  // =========================================================================
  // 7. Delete single audio surah
  // =========================================================================

  Future<void> deleteAudioSurah(String reciterId, int surahNum) async {
    final String filePath =
        await _audioFilePath(reciterId: reciterId, surahNum: surahNum);
    final File file = File(filePath);
    if (file.existsSync()) await file.delete();

    await _db.deleteAudioFiles(reciterId, surahNum: surahNum);

    // Reset the per-surah manifest entry.
    final String sourceId =
        '${reciterId}_${surahNum.toString().padLeft(3, '0')}';
    await _db.upsertManifest(
      sourceType: 'audio',
      sourceId: sourceId,
      label: 'Audio $reciterId surah $surahNum',
      status: 'idle',
      totalItems: 1,
      downloadedItems: 0,
    );
  }

  // =========================================================================
  // 8. Delete all audio surahs for a reciter
  // =========================================================================

  Future<void> deleteAllAudioSurahs(String reciterId) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory reciterDir =
        Directory('${appDocDir.path}/audio/$reciterId');

    if (reciterDir.existsSync()) {
      await reciterDir.delete(recursive: true);
    }

    await _db.deleteAudioFiles(reciterId);

    // Reset the whole-reciter manifest entry.
    await _db.upsertManifest(
      sourceType: 'audio',
      sourceId: reciterId,
      label: reciterId,
      status: 'idle',
      totalItems: _totalSurahs,
      downloadedItems: 0,
    );
  }

  // =========================================================================
  // Private helpers
  // =========================================================================

  /// Returns the local file path for an audio surah, creating the directory
  /// if necessary.
  Future<String> _audioFilePath({
    required String reciterId,
    required int surahNum,
  }) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory reciterDir =
        Directory('${appDocDir.path}/audio/$reciterId');

    if (!reciterDir.existsSync()) {
      await reciterDir.create(recursive: true);
    }

    final String fileName =
        '${surahNum.toString().padLeft(3, '0')}.mp3';
    return '${reciterDir.path}/$fileName';
  }

  /// Constructs the remote CDN URL for an audio surah.
  String _audioUrl({
    required String reciterId,
    required int surahNum,
  }) {
    final String surahPadded = surahNum.toString().padLeft(3, '0');
    return '$_audioBaseUrl/$reciterId/$surahPadded.mp3';
  }

  /// Returns a concise, safe description of an error for surfacing in
  /// [DownloadProgress.error].
  String _describeError(Object e, StackTrace st) {
    if (e is DioException) {
      return 'Network error: ${e.message ?? e.type.name}';
    }
    if (e is PostgrestException) {
      return 'Supabase error (${e.code}): ${e.message}';
    }
    return e.toString();
  }
}
