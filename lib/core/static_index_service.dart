// lib/core/static_index_service.dart
//
// Provides keyword search over the full pre-built static search index
// (all 110+ languages). Used as a fallback and Phase 2 multilingual search.
//
// The index is hosted in Supabase Storage as a gzip-compressed JSON file:
//   assets/search_index.json.gz

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

class StaticIndexHit {
  final String verseKey;
  final int score;

  StaticIndexHit(this.verseKey, this.score);
}

class StaticIndexService extends ChangeNotifier {
  StaticIndexService._();
  static final StaticIndexService instance = StaticIndexService._();

  static const String _indexUrl =
      'https://zgeygoclduqotqveperx.supabase.co/storage/v1/object/public/assets/search_index.json.gz';

  Map<String, dynamic>? _indexData;
  bool _isLoading = false;
  String? _loadError;

  bool get isReady => _indexData != null;
  String? get loadError => _loadError;

  void setIndexForTesting(Map<String, String> index) {
    _indexData = index;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (_indexData != null) return;
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;

    try {
      debugPrint('[StaticIndex] Downloading index from Supabase Storage...');
      final response = await http.get(Uri.parse(_indexUrl)).timeout(
            const Duration(seconds: 60),
          );
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} fetching static index');
      }

      // Check if response is gzipped
      List<int> bytes = response.bodyBytes;
      if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        debugPrint('[StaticIndex] Gzip header detected. Decompressing...');
        bytes = GZipDecoder().decodeBytes(bytes);
      }

      final decodedString = utf8.decode(bytes);
      final parsed = jsonDecode(decodedString) as Map<String, dynamic>;
      _indexData = parsed;
      debugPrint('[StaticIndex] Loaded. Keys: ${_indexData!.length}');
      notifyListeners();
    } catch (e) {
      _loadError = e.toString();
      debugPrint('[StaticIndex] Load error: $e');
    } finally {
      _isLoading = false;
    }
  }

  // Stop words set
  static const Set<String> _stopWords = {
    'the', 'of', 'it', 'is', 'in', 'and', 'to', 'a', 'for', 'with', 'on', 'by', 'at', 'an', 'this', 'that', 'from', 'as', 'are', 'was', 'were', 'or'
  };

  Future<List<StaticIndexHit>> search(String query, {int? maxResults}) async {
    if (_indexData == null) return [];
    final terms = _indexData!;

    final rawWords = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Filter stop words and short words
    final words = rawWords.where((w) {
      if (w.length < 3) return false;
      if (_stopWords.contains(w)) return false;
      return true;
    }).toList();

    if (words.isEmpty) return [];

    // Map: verseKey -> score
    final scoreMap = <String, int>{};

    for (final word in words) {
      // Find term matches
      for (final term in terms.keys) {
        int termScore = 0;
        if (term == word) {
          termScore = 2; // Exact match
        } else if (word.length >= 4 && term.startsWith(word)) {
          termScore = 1; // Prefix match
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

    // Sort by score descending, then by verse_key order
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
