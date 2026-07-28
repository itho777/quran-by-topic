import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/home_widget_service.dart';

class BookmarksManager {
  static const String _key = 'bookmarks';
  static const String _lastReadKey = 'last_read';

  // Get all bookmarks
  static Future<List<Map<String, dynamic>>> getBookmarks() async {
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

  // Toggle bookmark (add if not exists, remove if exists)
  static Future<bool> toggleBookmark({
    required int surahId,
    required int ayahNumber,
    required String surahName,
    required String verseKey,
    required String textAr,
    required String translation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBookmarks();

    final idx = current.indexWhere((element) => element['verseKey'] == verseKey);
    bool added = false;

    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.add({
        'surahId': surahId,
        'ayahNumber': ayahNumber,
        'surahName': surahName,
        'verseKey': verseKey,
        'textAr': textAr,
        'translation': translation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      added = true;
    }

    await prefs.setString(_key, json.encode(current));
    return added;
  }

  // Check if bookmarked
  static Future<bool> isBookmarked(String verseKey) async {
    final current = await getBookmarks();
    return current.any((element) => element['verseKey'] == verseKey);
  }

  // Save Last Read
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

    // Propagate live update to Home Screen Widget
    try {
      final double progress = maxAyahs > 0 ? ((ayahNumber / maxAyahs) * 100.0).clamp(0.0, 100.0) : 0.0;
      await HomeWidgetService.instance.updateLastReadWidget(
        surahName: surahName,
        surahNo: surahId,
        ayahNo: ayahNumber,
        progress: progress,
      );
    } catch (_) {}
  }

  // Get Last Read — defaults to Al-Fatihah (1:1) on first install
  static Future<Map<String, dynamic>> getLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_lastReadKey);
    final defaultData = {
      'surahId': 1,
      'ayahNumber': 1,
      'surahName': 'Al-Fatihah',
      'timestamp': 0, // 0 indicates not yet read by user
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
