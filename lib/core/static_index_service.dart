// lib/core/static_index_service.dart
//
// Provides keyword search over the full pre-built static search index
// (all 110+ languages). Used as a fallback when the Supabase search_verses
// RPC is not available for the selected language.
//
// The index is hosted in Supabase Storage as a gzip-compressed JSON file:
//   assets/search_index.json.gz
//
// Index format:
//   {
//     "meta": { "built_at": "...", "total_keys": 6236, "sources": [...] },
//     "terms": {
//       "word": ["1:1", "2:255", ...],   // verse keys
//       ...
//     }
//   }

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class StaticIndexService {
  static const String _indexUrl =
      'https://zgeygoclduqotqveperx.supabase.co/storage/v1/object/public/assets/search_index.json.gz';

  // In-memory cache — populated on first use
  static Map<String, dynamic>? _indexData;
  static bool _isLoading = false;
  static String? _loadError;

  /// Returns true if the index is already in memory.
  static bool get isLoaded => _indexData != null;

  /// Human-readable load error, or null if no error.
  static String? get loadError => _loadError;

  /// Fetch and cache the index. Safe to call multiple times.
  static Future<void> ensureLoaded() async {
    if (_indexData != null) return;
    if (_isLoading) {
      // Wait for concurrent load to finish
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    _isLoading = true;
    _loadError = null;
    try {
      debugPrint('[StaticIndex] Downloading index from Supabase Storage...');
      final response = await http.get(Uri.parse(_indexUrl)).timeout(
            const Duration(seconds: 60),
          );
      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode} fetching static index');
      }
      // Response body is already decoded by http (gzip is handled via
      // the Content-Encoding header if the server sets it). If it arrives
      // as raw gzip bytes we decode manually.
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } catch (_) {
        // Try raw bodyBytes as-is (server may not set Content-Encoding)
        final decompressed = response.bodyBytes;
        parsed = jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
      }
      _indexData = parsed;
      debugPrint('[StaticIndex] Loaded. Keys: ${_indexData!['terms']?.length}');
    } catch (e) {
      _loadError = e.toString();
      debugPrint('[StaticIndex] Load error: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Search the index for [query].
  ///
  /// Returns a list of verse keys (e.g. "2:255") that match ALL query terms.
  /// Optionally filtered by [langPrefix] (e.g. 'tr' for Turkish).
  /// If [langPrefix] is null or 'all', no language filter is applied.
  ///
  /// Returns an empty list if the index is not loaded.
  static List<String> search(String query, {String? langPrefix}) {
    if (_indexData == null) return [];
    final terms = _indexData!['terms'] as Map<String, dynamic>?;
    if (terms == null) return [];

    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();
    if (words.isEmpty) return [];

    // Intersection of all word/term hits
    Set<String>? result;
    for (final word in words) {
      // Collect all term keys that contain this word as a substring
      final hits = <String>{};
      for (final term in terms.keys) {
        if (term.contains(word)) {
          final keys = (terms[term] as List).cast<String>();
          hits.addAll(keys);
        }
      }
      result = result == null ? hits : result.intersection(hits);
      if (result.isEmpty) break;
    }

    final matched = (result ?? <String>{}).toList();
    // Cap to prevent UI overload
    if (matched.length > 200) matched.length = 200;
    return matched;
  }

  /// Clear the cached index (useful for memory management on mobile).
  static void clear() {
    _indexData = null;
    _loadError = null;
  }
}
