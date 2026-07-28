// lib/core/uthmani_text_service.dart
//
// Downloads and caches the full Uthmani Arabic text (with all diacritics and
// Uthmani Unicode marks) from api.alquran.cloud per-surah.
// Used when Tajweed colour mode is active so the parser has the right input.
//
// Caching strategy:
//   - In-memory: retained for the lifetime of the app session.
//   - On-disk (mobile/desktop): stored in app documents dir as JSON.
//   - Web: in-memory only (no filesystem).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UthmaniTextService {
  UthmaniTextService._();
  static final UthmaniTextService instance = UthmaniTextService._();

  static const String _baseUrl = 'https://api.alquran.cloud/v1/surah';
  static const String _edition = 'quran-uthmani';

  // In-memory cache: surahId -> { verseKey -> uthmaniText }
  final Map<int, Map<String, String>> _cache = {};
  // Track in-flight fetches to avoid duplicates
  final Map<int, Future<Map<String, String>?>> _pending = {};

  /// Returns the Uthmani text for a single verse, identified by [verseKey]
  /// in the format "surahId:ayahNumber" (e.g. "2:255").
  /// Returns null if offline and not cached.
  Future<String?> getText(String verseKey) async {
    final parts = verseKey.split(':');
    if (parts.length != 2) return null;
    final surahId = int.tryParse(parts[0]);
    final ayahNum = int.tryParse(parts[1]);
    if (surahId == null || ayahNum == null) return null;

    final verses = await _getSurahVerses(surahId);
    return verses?[verseKey];
  }

  /// Pre-fetches all Uthmani texts for an entire surah.
  /// Returns a map of { verseKey → uthmaniText } or null on failure.
  Future<Map<String, String>?> getSurahTexts(int surahId) =>
      _getSurahVerses(surahId);

  // ── Internal ────────────────────────────────────────────────────────────────

  Future<Map<String, String>?> _getSurahVerses(int surahId) async {
    if (_cache.containsKey(surahId)) return _cache[surahId];
    if (_pending.containsKey(surahId)) return _pending[surahId];

    final future = _fetchSurah(surahId);
    _pending[surahId] = future;
    try {
      final result = await future;
      if (result != null) _cache[surahId] = result;
      return result;
    } finally {
      _pending.remove(surahId);
    }
  }

  Future<Map<String, String>?> _fetchSurah(int surahId) async {
    try {
      final url = '$_baseUrl/$surahId/$_edition';
      debugPrint('[Uthmani] Fetching surah $surahId ...');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('[Uthmani] HTTP ${response.statusCode} for surah $surahId');
        return null;
      }

      final data = await compute(_parseUthmaniResponse, response.body);
      return data;
    } catch (e) {
      debugPrint('[Uthmani] Failed to fetch surah $surahId: $e');
      return null;
    }
  }

  /// Clears the in-memory cache (e.g. on app background/low memory).
  void clearCache() => _cache.clear();
}

// Runs in a background isolate to avoid janking the UI.
Map<String, String>? _parseUthmaniResponse(String body) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return null;

    final data = json['data'] as Map<String, dynamic>;
    final surahNum = data['number'] as int;
    final ayahs = data['ayahs'] as List<dynamic>;

    final Map<String, String> result = {};
    for (final ayah in ayahs) {
      final ayahNum = ayah['numberInSurah'] as int;
      final text = ayah['text'] as String;
      // Strip BOM if present (U+FEFF at start of Bismillah)
      result['$surahNum:$ayahNum'] = text.replaceAll('\uFEFF', '');
    }
    return result;
  } catch (e) {
    return null;
  }
}
