import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Client for the tafsir-web-search Worker — the same ladder the full-web app
/// uses, so a query cannot answer differently on the phone than in the browser.
///
///   semantic mode: Cloudflare Workers AI + pgvector
///     -> Meilisearch -> Algolia -> Supabase keyword
///   keyword mode:  Meilisearch
///     -> Cloudflare Workers AI + pgvector -> Algolia -> Supabase keyword
///
/// The Worker names the rung that produced the rows. Callers must label the
/// result with [SearchOutcome.label], never with the mode the user picked: a
/// keyword answer to a semantic query stays labelled keyword.

const String kSearchWorkerUrl =
    'https://tafsir-web-search.wandering-flower-6702.workers.dev/api/search';

/// The Worker answers a cold bge-m3 query in ~3 s. Ten seconds leaves room for
/// a slow mobile link without turning a dead host into a 20 s freeze before the
/// local index is tried.
const Duration _kWorkerTimeout = Duration(seconds: 10);

class SearchSnippet {
  const SearchSnippet({
    required this.text,
    this.kind = '',
    this.source = '',
    this.lang = '',
  });

  final String text;
  final String kind;
  final String source;
  final String lang;

  /// `translations` -> `Translation`, `tafsirs` -> `Tafsir`, and so on. Matches
  /// the `source_type` values the search results UI already renders.
  String get sourceType {
    switch (kind) {
      case 'tafsirs':
        return 'Tafsir';
      case 'asbabun_nuzul':
        return 'Asbabun Nuzul';
      case 'transliterations':
        return 'Transliteration';
      default:
        return 'Translation';
    }
  }

  Map<String, dynamic> toContextSource() => {
        'text': text,
        'source_name': source,
        'source_id': source,
        'source_type': sourceType,
      };

  factory SearchSnippet.fromJson(Map<String, dynamic> j) => SearchSnippet(
        text: (j['text'] as String? ?? '').trim(),
        kind: j['kind'] as String? ?? '',
        source: j['source'] as String? ?? '',
        lang: j['lang'] as String? ?? '',
      );
}

class SearchHit {
  const SearchHit({
    required this.verseKey,
    this.textAr = '',
    this.translationText = '',
    this.sourceId = '',
    this.kind = '',
    this.lang = '',
    this.score = 0,
    this.snippets = const [],
  });

  final String verseKey;
  final String textAr;
  final String translationText;
  final String sourceId;
  final String kind;
  final String lang;
  final double score;
  final List<SearchSnippet> snippets;

  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
        verseKey: j['verse_key'] as String? ?? '',
        textAr: j['text_ar'] as String? ?? '',
        translationText: j['translation_text'] as String? ?? '',
        sourceId: j['source_id'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        lang: j['lang'] as String? ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
        snippets: (j['snippets'] as List?)
                ?.whereType<Map>()
                .map((e) => SearchSnippet.fromJson(Map<String, dynamic>.from(e)))
                .where((s) => s.text.isNotEmpty)
                .toList() ??
            const [],
      );
}

class SearchAttempt {
  const SearchAttempt({
    required this.method,
    required this.status,
    this.reason = '',
    this.ms = 0,
    this.rows = 0,
  });

  final String method;
  final String status;
  final String reason;
  final int ms;
  final int rows;

  factory SearchAttempt.fromJson(Map<String, dynamic> j) => SearchAttempt(
        method: j['method'] as String? ?? '',
        status: j['status'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        ms: (j['ms'] as num?)?.toInt() ?? 0,
        rows: (j['rows'] as num?)?.toInt() ?? 0,
      );
}

class SearchOutcome {
  const SearchOutcome({
    required this.hits,
    required this.method,
    required this.label,
    required this.provider,
    required this.requestedMode,
    this.fellBack = false,
    this.notice = '',
    this.attempts = const [],
  });

  final List<SearchHit> hits;
  final String method;
  final String label;
  final String provider;
  final String requestedMode;
  final bool fellBack;
  final String notice;
  final List<SearchAttempt> attempts;

  bool get isEmpty => hits.isEmpty;

  factory SearchOutcome.fromJson(Map<String, dynamic> j) {
    final results = (j['results'] as List?)
            ?.whereType<Map>()
            .map((e) => SearchHit.fromJson(Map<String, dynamic>.from(e)))
            .where((h) => h.verseKey.contains(':'))
            .toList() ??
        const <SearchHit>[];
    return SearchOutcome(
      hits: results,
      method: j['searchMethod'] as String? ?? '',
      label: j['searchLabel'] as String? ?? '',
      provider: j['searchProvider'] as String? ?? '',
      requestedMode: j['requestedMode'] as String? ?? '',
      fellBack: j['fellBack'] == true,
      notice: j['notice'] as String? ?? '',
      attempts: (j['attempts'] as List?)
              ?.whereType<Map>()
              .map((e) => SearchAttempt.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}

class SearchApi {
  SearchApi._();

  static final SearchApi instance = SearchApi._();

  final http.Client _client = http.Client();

  /// Why the last call returned null — surfaced in the search screen's trace so
  /// "no results" can name a blocked host, a timeout or an HTTP code.
  String? lastError;

  /// The full-web app calls this Worker from tafseer.id; the same origin and
  /// referer travel with the app's request so edge rules treat it the same way.
  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Origin': 'https://tafseer.id',
    'Referer': 'https://tafseer.id/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/126.0.0.0 Mobile Safari/537.36 TafseerApp/3.3',
  };

  /// Runs the server-side ladder for [query].
  ///
  /// Returns `null` only when the Worker could not be reached or answered with
  /// something unusable — callers then run their own offline stack. An empty
  /// [SearchOutcome] means the ladder ran and found nothing, which is a result,
  /// not an error.
  Future<SearchOutcome?> search(
    String query, {
    required bool semantic,
    String lang = 'id',
    int limit = 50,
    Map<String, bool>? options,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    lastError = null;

    try {
      final res = await _client
          .post(
            Uri.parse(kSearchWorkerUrl),
            headers: {..._headers, 'Accept-Language': lang},
            body: jsonEncode({
              'query': trimmed,
              'lang': lang,
              'limit': limit,
              'mode': semantic ? 'semantic' : 'keyword',
              if (options != null) 'options': {...options, 'lang': lang},
            }),
          )
          .timeout(_kWorkerTimeout);

      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode}';
        debugPrint('[SearchApi] Worker HTTP ${res.statusCode}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] != true) {
        lastError = 'worker error: ${decoded is Map ? decoded['error'] : decoded}';
        debugPrint('[SearchApi] Worker error: ${decoded is Map ? decoded['error'] : decoded}');
        return null;
      }
      return SearchOutcome.fromJson(Map<String, dynamic>.from(decoded));
    } on TimeoutException {
      lastError = 'timeout after ${_kWorkerTimeout.inSeconds}s';
      debugPrint('[SearchApi] Worker timed out');
      return null;
    } catch (e) {
      lastError = e is SocketException
          ? 'socket: ${e.osError?.message ?? e.message}'
          : e.toString();
      debugPrint('[SearchApi] Worker unreachable: $e');
      return null;
    }
  }
}
