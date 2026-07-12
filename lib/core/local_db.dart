import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;

/// A singleton wrapper around a SQLite database used for offline caching of
/// translations, tafsirs, Mushaf pages, audio files, and download manifests.
class LocalDatabase {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static final LocalDatabase instance = LocalDatabase._();

  LocalDatabase._();

  /// Deprecated: use [LocalDatabase.instance] directly instead.
  static Future<LocalDatabase> getInstance() async {
    return instance;
  }

  // ---------------------------------------------------------------------------
  // Database initialisation
  // ---------------------------------------------------------------------------

  Database? _db;

  static const String _dbName = 'tafseer_cache.db';
  static const int _dbVersion = 1;

  /// Lazily opens (and caches) the underlying [Database].
  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        await _onCreate(db, newVersion);
      },
      onOpen: (db) async {
        await _onCreate(db, _dbVersion);
      },
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // -- surahs ----------------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS surahs (
        id             INTEGER PRIMARY KEY,
        name_en        TEXT    NOT NULL,
        name_id        TEXT    NOT NULL,
        name_ar        TEXT    NOT NULL,
        translation_en TEXT,
        translation_id TEXT,
        ayas           INTEGER,
        type           TEXT
      )
    ''');

    // -- verses ----------------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS verses (
        id              INTEGER PRIMARY KEY,
        sura_id         INTEGER NOT NULL,
        ayah_number     INTEGER NOT NULL,
        verse_key       TEXT    NOT NULL UNIQUE,
        text_ar         TEXT    NOT NULL,
        transliteration TEXT
      )
    ''');

    // -- translations ----------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS translations (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        verse_key  TEXT    NOT NULL,
        source_id  TEXT    NOT NULL,
        text       TEXT    NOT NULL,
        cached_at  INTEGER,
        UNIQUE(verse_key, source_id)
      )
    ''');

    // -- tafsirs ---------------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS tafsirs (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        verse_key  TEXT    NOT NULL,
        source_id  TEXT    NOT NULL,
        text       TEXT    NOT NULL,
        cached_at  INTEGER,
        UNIQUE(verse_key, source_id)
      )
    ''');

    // -- asbabun_nuzul ---------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS asbabun_nuzul (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        verse_key  TEXT    NOT NULL,
        source_id  TEXT    NOT NULL,
        text       TEXT    NOT NULL,
        cached_at  INTEGER,
        UNIQUE(verse_key, source_id)
      )
    ''');

    // -- mushaf_pages ----------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS mushaf_pages (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        page_num  INTEGER UNIQUE,
        file_path TEXT    NOT NULL,
        cached_at INTEGER
      )
    ''');

    // -- audio_files -----------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS audio_files (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        reciter_id TEXT    NOT NULL,
        surah_num  INTEGER NOT NULL,
        file_path  TEXT    NOT NULL,
        cached_at  INTEGER,
        UNIQUE(reciter_id, surah_num)
      )
    ''');

    // -- download_manifest -----------------------------------------------------
    // source_type values : 'translation' | 'tafsir' | 'nuzul' | 'mushaf' | 'audio'
    // status values      : 'idle' | 'downloading' | 'paused' | 'completed' | 'error'
    batch.execute('''
      CREATE TABLE IF NOT EXISTS download_manifest (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        source_type      TEXT    NOT NULL,
        source_id        TEXT    NOT NULL,
        label            TEXT    NOT NULL,
        total_items      INTEGER DEFAULT 0,
        downloaded_items INTEGER DEFAULT 0,
        status           TEXT    DEFAULT 'idle',
        started_at       INTEGER,
        completed_at     INTEGER,
        UNIQUE(source_type, source_id)
      )
    ''');

    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Surahs
  // ---------------------------------------------------------------------------

  /// Persists the list of all [surahs] to local SQLite database.
  Future<void> saveSurahs(List<Map<String, dynamic>> surahs) async {
    if (kIsWeb) return;
    final db = await database;
    final batch = db.batch();
    for (final s in surahs) {
      batch.insert(
        'surahs',
        {
          'id': s['id'],
          'name_en': s['name_en'] ?? '',
          'name_id': s['name_id'] ?? '',
          'name_ar': s['name_ar'] ?? '',
          'translation_en': s['translation_en'] ?? '',
          'translation_id': s['translation_id'] ?? '',
          'ayas': s['ayas'],
          'type': s['type'] ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Returns the cached list of all surahs from SQLite database.
  Future<List<Map<String, dynamic>>> getSurahs() async {
    if (kIsWeb) return [];
    final db = await database;
    return db.query('surahs', orderBy: 'id ASC');
  }

  /// Returns the cached surah by [surahId] or `null`.
  Future<Map<String, dynamic>?> getSurah(int surahId) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(
      'surahs',
      where: 'id = ?',
      whereArgs: [surahId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ---------------------------------------------------------------------------
  // Verses
  // ---------------------------------------------------------------------------

  /// Persists a list of [verses] belonging to [suraId] to SQLite database.
  Future<void> saveVerses(List<Map<String, dynamic>> verses, int suraId) async {
    if (kIsWeb) return;
    final db = await database;
    final batch = db.batch();
    for (final v in verses) {
      batch.insert(
        'verses',
        {
          'id': v['id'],
          'sura_id': suraId,
          'ayah_number': v['ayah_number'],
          'verse_key': v['verse_key'],
          'text_ar': v['text_ar'] ?? '',
          'transliteration': v['transliteration'] ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Returns the cached list of verses for [suraId] ordered by ayah number.
  Future<List<Map<String, dynamic>>> getVerses(int suraId) async {
    if (kIsWeb) return [];
    final db = await database;
    return db.query(
      'verses',
      where: 'sura_id = ?',
      whereArgs: [suraId],
      orderBy: 'ayah_number ASC',
    );
  }

  /// Returns the cached verse details for [verseKey] or `null`.
  Future<Map<String, dynamic>?> getVerse(String verseKey) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(
      'verses',
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ---------------------------------------------------------------------------
  // Text data (translations / tafsirs / asbabun_nuzul)
  // ---------------------------------------------------------------------------

  /// Upserts a text row into [table] (one of `translations`, `tafsirs`,
  /// `asbabun_nuzul`).
  Future<void> saveTextData(
    String table,
    String verseKey,
    String sourceId,
    String text,
  ) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      table,
      {
        'verse_key': verseKey,
        'source_id': sourceId,
        'text': text,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the cached text for [verseKey] / [sourceId] in [table], or
  /// `null` when no row exists.
  Future<String?> getTextData(
    String table,
    String verseKey,
    String sourceId,
  ) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(
      table,
      columns: ['text'],
      where: 'verse_key = ? AND source_id = ?',
      whereArgs: [verseKey, sourceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['text'] as String?;
  }

  /// Returns a map of source_id -> text for a given [verseKey] in [table].
  Future<Map<String, String>> getAllTextDataForVerse(
    String table,
    String verseKey,
  ) async {
    if (kIsWeb) return {};
    final db = await database;
    final rows = await db.query(
      table,
      columns: ['source_id', 'text'],
      where: 'verse_key = ?',
      whereArgs: [verseKey],
    );
    return {
      for (final r in rows)
        r['source_id'] as String: r['text'] as String
    };
  }

  /// Returns a map of verse_key -> text for a list of [verseKeys] and [sourceId] in [table].
  Future<Map<String, String>> getBatchTextData(
    String table,
    String sourceId,
    List<String> verseKeys,
  ) async {
    if (kIsWeb) return {};
    if (verseKeys.isEmpty) return {};
    final db = await database;
    
    // SQLite can handle up to 999 parameters. Splitting or formatting:
    final placeholders = List.filled(verseKeys.length, '?').join(',');
    final rows = await db.query(
      table,
      columns: ['verse_key', 'text'],
      where: 'source_id = ? AND verse_key IN ($placeholders)',
      whereArgs: [sourceId, ...verseKeys],
    );
    return {
      for (final r in rows)
        r['verse_key'] as String: r['text'] as String
    };
  }

  // ---------------------------------------------------------------------------
  // Mushaf pages
  // ---------------------------------------------------------------------------

  /// Upserts the local [filePath] for a Mushaf [pageNum].
  Future<void> saveMushafPage(int pageNum, String filePath) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'mushaf_pages',
      {
        'page_num': pageNum,
        'file_path': filePath,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the local file path for Mushaf [pageNum], or `null` if not cached.
  Future<String?> getMushafPage(int pageNum) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(
      'mushaf_pages',
      columns: ['file_path'],
      where: 'page_num = ?',
      whereArgs: [pageNum],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['file_path'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Audio files
  // ---------------------------------------------------------------------------

  /// Upserts the local [filePath] for [reciterId] / [surahNum].
  Future<void> saveAudioFile(
    String reciterId,
    int surahNum,
    String filePath,
  ) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'audio_files',
      {
        'reciter_id': reciterId,
        'surah_num': surahNum,
        'file_path': filePath,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the local file path for [reciterId] / [surahNum], or `null`.
  Future<String?> getAudioFile(String reciterId, int surahNum) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(
      'audio_files',
      columns: ['file_path'],
      where: 'reciter_id = ? AND surah_num = ?',
      whereArgs: [reciterId, surahNum],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['file_path'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Download manifest
  // ---------------------------------------------------------------------------

  /// Upserts a row in `download_manifest`.
  Future<void> upsertManifest({
    required String sourceType,
    required String sourceId,
    required String label,
    int totalItems = 0,
    int downloadedItems = 0,
    String status = 'idle',
  }) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'download_manifest',
      {
        'source_type': sourceType,
        'source_id': sourceId,
        'label': label,
        'total_items': totalItems,
        'downloaded_items': downloadedItems,
        'status': status,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns every row in `download_manifest`.
  Future<List<Map<String, dynamic>>> getAllManifests() async {
    if (kIsWeb) return [];
    final db = await database;
    return db.query('download_manifest');
  }

  /// Returns the manifest row for [sourceType] / [sourceId], or `null`.
  Future<Map<String, dynamic>?> getManifest(
    String sourceType,
    String sourceId,
  ) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(
      'download_manifest',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: [sourceType, sourceId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Returns the number of rows in [table] that match [sourceId].
  Future<int> countCached(String table, String sourceId) async {
    if (kIsWeb) return 0;
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $table WHERE source_id = ?',
      [sourceId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Deletes all rows in [table] for [sourceId].
  Future<void> deleteSource(String table, String sourceId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
      table,
      where: 'source_id = ?',
      whereArgs: [sourceId],
    );
  }

  /// Deletes all rows from `mushaf_pages`.
  Future<void> deleteMushafPages() async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('mushaf_pages');
  }

  /// Deletes audio rows for [reciterId].  If [surahNum] is provided, only that
  /// surah is deleted; otherwise all surahs for the reciter are removed.
  Future<void> deleteAudioFiles(String reciterId, {int? surahNum}) async {
    if (kIsWeb) return;
    final db = await database;
    if (surahNum != null) {
      await db.delete(
        'audio_files',
        where: 'reciter_id = ? AND surah_num = ?',
        whereArgs: [reciterId, surahNum],
      );
    } else {
      await db.delete(
        'audio_files',
        where: 'reciter_id = ?',
        whereArgs: [reciterId],
      );
    }
  }
}
