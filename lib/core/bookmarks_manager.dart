import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/home_widget_service.dart';

/// Hybrid bookmark manager. Supabase is source of truth when logged in.
///
/// Sync scheme:
///   - getBookmarks(): pull from Supabase → overwrite local cache.
///   - toggleBookmark(): await Supabase upsert/delete, then update local cache.
///   - syncOnLogin(): bidirectional merge — push local-only up, pull remote-only down.
///   - Guest: local only, zero Supabase calls.
class BookmarksManager {
  static const String _key = 'bookmarks';
  static const String _lastReadKey = 'last_read';

  static SupabaseClient get _db => Supabase.instance.client;
  static User? get _user => _db.auth.currentUser;

  // ── Local helpers ──────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _localGet() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    try {
      final decoded = json.decode(data) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _localSet(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(list));
  }

  // ── Supabase helpers ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _remoteGet() async {
    final user = _user;
    if (user == null) return [];
    try {
      final rows = await _db
          .from('bookmarks')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      // Normalize remote rows to the same shape as local entries
      return (rows as List).map((r) {
        return {
          'surahId': r['surah_id'] as int,
          'ayahNumber': r['ayah_number'] as int,
          'surahName': r['surah_name'] as String,
          'verseKey': r['verse_key'] as String,
          'textAr': r['text_ar'] as String? ?? '',
          'translation': r['translation'] as String? ?? '',
          'timestamp': r['created_at'] != null
              ? DateTime.parse(r['created_at'] as String)
                    .millisecondsSinceEpoch
              : 0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _remoteUpsert(Map<String, dynamic> b) async {
    final user = _user;
    if (user == null) return;
    try {
      await _db.from('bookmarks').upsert(
        {
          'user_id': user.id,
          'surah_id': b['surahId'] as int,
          'ayah_number': b['ayahNumber'] as int,
          'surah_name': b['surahName'] as String,
          'verse_key': b['verseKey'] as String,
          'text_ar': b['textAr'] as String? ?? '',
          'translation': b['translation'] as String? ?? '',
        },
        onConflict: 'user_id,verse_key',
      );
    } catch (_) {}
  }

  static Future<void> _remoteDelete(String verseKey) async {
    final user = _user;
    if (user == null) return;
    try {
      await _db
          .from('bookmarks')
          .delete()
          .eq('user_id', user.id)
          .eq('verse_key', verseKey);
    } catch (_) {}
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Get all bookmarks. Prefer remote when logged in; local as fallback.
  static Future<List<Map<String, dynamic>>> getBookmarks() async {
    if (_user != null) {
      final remote = await _remoteGet();
      if (remote.isNotEmpty) {
        // Keep local in sync so guest mode still works after logout
        await _localSet(remote);
        return remote;
      }
      // Remote empty — maybe first login with existing local bookmarks.
      // Return local (caller will see them; use syncOnLogin to push).
    }
    return await _localGet();
  }

  /// Toggle bookmark — add if absent, remove if present.
  /// Returns true if added, false if removed.
  static Future<bool> toggleBookmark({
    required int surahId,
    required int ayahNumber,
    required String surahName,
    required String verseKey,
    required String textAr,
    required String translation,
  }) async {
    final current = await _localGet();
    final idx = current.indexWhere((e) => e['verseKey'] == verseKey);
    bool added;

    if (idx >= 0) {
      current.removeAt(idx);
      added = false;
      await _remoteDelete(verseKey); // awaited
    } else {
      final entry = {
        'surahId': surahId,
        'ayahNumber': ayahNumber,
        'surahName': surahName,
        'verseKey': verseKey,
        'textAr': textAr,
        'translation': translation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      current.add(entry);
      added = true;
      await _remoteUpsert(entry); // awaited
    }

    await _localSet(current);
    return added;
  }

  /// Check if a verse is bookmarked (local check — fast).
  static Future<bool> isBookmarked(String verseKey) async {
    final current = await _localGet();
    return current.any((e) => e['verseKey'] == verseKey);
  }

  /// Merge local and remote bookmarks. Call once after login.
  /// Pushes local-only items to remote, pulls remote-only items to local.
  static Future<void> syncOnLogin() async {
    final user = _user;
    if (user == null) return;

    final local = await _localGet();
    final remote = await _remoteGet();

    final remoteKeys = remote.map((e) => e['verseKey'] as String).toSet();
    final localKeys = local.map((e) => e['verseKey'] as String).toSet();

    // Push local-only to remote
    final toPush = local.where((e) => !remoteKeys.contains(e['verseKey']));
    for (final b in toPush) {
      await _remoteUpsert(b);
    }

    // Pull remote-only to local
    final toPull = remote.where((e) => !localKeys.contains(e['verseKey']));
    if (toPull.isNotEmpty) {
      final merged = [...local, ...toPull];
      await _localSet(merged);
    }
  }

  // ── Last Read ──────────────────────────────────────────────────────────────

  static Future<void> saveLastRead({
    required int surahId,
    required int ayahNumber,
    required String surahName,
    int maxAyahs = 50,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'surahId': surahId,
      'ayahNumber': ayahNumber,
      'surahName': surahName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_lastReadKey, json.encode(data));

    try {
      final double progress =
          maxAyahs > 0 ? ((ayahNumber / maxAyahs) * 100.0).clamp(0.0, 100.0) : 0.0;
      await HomeWidgetService.instance.updateLastReadWidget(
        surahName: surahName,
        surahNo: surahId,
        ayahNo: ayahNumber,
        progress: progress,
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_lastReadKey);
    final defaultData = {
      'surahId': 1,
      'ayahNumber': 1,
      'surahName': 'Al-Fatihah',
      'timestamp': 0,
    };
    if (data == null) return defaultData;
    try {
      final decoded = json.decode(data) as Map<String, dynamic>?;
      return decoded ?? defaultData;
    } catch (_) {
      return defaultData;
    }
  }
}
