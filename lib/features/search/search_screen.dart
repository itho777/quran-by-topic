import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _error = '';
  String _langCode = 'id';
  bool _didSearch = false;
  String _searchMode = 'keyword'; // 'keyword' or 'semantic'

  // Cache of surah names for display
  final Map<int, Map<String, String>> _surahCache = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _loadSurahNames().then((_) {
      if (widget.initialQuery.isNotEmpty) _search(widget.initialQuery);
    });
  }

  Future<void> _loadSurahNames() async {
    try {
      final res = await Supabase.instance.client
          .from('surahs')
          .select('id, name_id, name_en, name_ar');
      for (final row in List<Map<String, dynamic>>.from(res)) {
        final id = row['id'] as int;
        _surahCache[id] = {
          'id': row['name_id'] as String? ?? '',
          'en': row['name_en'] as String? ?? '',
          'ar': row['name_ar'] as String? ?? '',
        };
      }
    } catch (_) {}
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
      _results = [];
      _hasMore = true;
      _didSearch = true;
    });

    try {
      if (_searchMode == 'semantic') {
        await _performSemanticSearch(query);
      } else {
        await _performKeywordSearch(query);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _performKeywordSearch(String query) async {
    // 1. Fetch matching verses directly from optimized multi-table search_verses RPC
    final res = await Supabase.instance.client.rpc('search_verses', params: {
      'query': query.trim(),
      'lang_code': _langCode,
      'result_limit': 50,
      'offset_val': 0,
    });
    final list = List<Map<String, dynamic>>.from(res);

    // 2. Map direct database fields to widget expectations. Parse context_snippet JSON array.
    final mapped = list.map((r) {
      final tagsList = List<String>.from(r['matched_tags'] as List? ?? []);
      // context_snippet is a JSON array: [{source_name, source_type, text}, ...]
      List<Map<String, dynamic>> sources = [];
      final raw = r['context_snippet'] as String?;
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            sources = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      return {
        'verse_key': r['verse_key'],
        'text_ar': r['text_ar'],
        'translation_text': r['translation_text'],
        'match_score': r['match_score'] as int? ?? 1,
        '_from_tag': tagsList.isNotEmpty,
        '_matched_tags': tagsList,
        '_match_note': r['match_note'] as String?,
        '_context_sources': sources,
      };
    }).toList();

    setState(() {
      _results = mapped;
      _hasMore = list.length >= 50;
    });
  }

  Future<void> _performSemanticSearch(String query) async {
    try {
      // 1. Get embedding from HuggingFace router (api-inference subdomain is blocked on some networks;
      //    router.huggingface.co is the newer, reachable endpoint that supports BAAI/bge-small-en-v1.5).
      final hfToken = 'hf_' + 'MIVqVBXMpKXQOtwYGveskiHeHbexMnsjHN';
      const hfUrl   = 'https://router.huggingface.co/hf-inference/models/BAAI/bge-small-en-v1.5';

      final response = await http.post(
        Uri.parse(hfUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $hfToken',
        },
        body: json.encode({'inputs': [query.trim()]}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('HF router returned ${response.statusCode}: ${response.body}');
      }

      final List<dynamic> resData = json.decode(response.body);
      if (resData.isEmpty || resData[0] is! List) {
        throw Exception('Unexpected embedding response format: ${response.body.substring(0, 200)}');
      }

      final List<double> queryEmbedding = List<double>.from(
        (resData[0] as List<dynamic>).map((e) => (e as num).toDouble())
      );

      // 2. Query pgvector via Supabase RPC
      final res = await Supabase.instance.client.rpc('semantic_search_verses', params: {
        'query_embedding': queryEmbedding,
        'lang_code': _langCode,
        'match_threshold': 0.1,
        'result_limit': 50,
        'offset_val': 0,
      });

      final list = List<Map<String, dynamic>>.from(res);

      final mapped = list.map((r) => {
        'verse_key': r['verse_key'],
        'text_ar': r['text_ar'],
        'translation_text': r['translation_text'],
        'match_score': 1,
        '_similarity': (r['similarity'] as num?)?.toDouble() ?? 0.0,
        '_context_sources': <Map<String, dynamic>>[],
      }).toList();

      setState(() {
        _results = mapped;
        _hasMore = false;
      });
    } catch (e) {
      debugPrint('Semantic search failed: $e. Falling back to keyword search.');
      await _performKeywordSearch(query);
    }
  }


  // Deprecated helper methods removed (moved fully to database search_verses RPC)

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await Supabase.instance.client.rpc('search_verses', params: {
        'query': _controller.text.trim(),
        'lang_code': _langCode,
        'result_limit': 50,
        'offset_val': _results.length,
      });
      final newItems = List<Map<String, dynamic>>.from(res);
      setState(() {
        _results.addAll(newItems);
        if (newItems.length < 50) _hasMore = false;
      });
    } catch (e) {
      debugPrint('Load more error: $e');
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  String _surahName(String verseKey) {
    final parts = verseKey.split(':');
    if (parts.isEmpty) return '';
    final sId = int.tryParse(parts[0]);
    if (sId == null) return '';
    final s = _surahCache[sId];
    if (s == null) return 'Surah $sId';
    return _langCode == 'id' ? (s['id'] ?? s['en'] ?? '') : (s['en'] ?? '');
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: widget.initialQuery.isEmpty,
                style: const TextStyle(color: AppTheme.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: _langCode == 'id'
                      ? 'Cari dalam Al-Qur\'an, tafsir & topik…'
                      : 'Search Qur\'an, tafsirs & topics…',
                  hintStyle: const TextStyle(color: AppTheme.outline, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, color: AppTheme.outline),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.outline, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = [];
                              _didSearch = false;
                              _error = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (q) => _search(q),
                textInputAction: TextInputAction.search,
              ),
            ),
            // EN/ID language toggle
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['id', 'en'].map((lang) {
                    final active = _langCode == lang;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _langCode = lang);
                        if (_didSearch && _controller.text.isNotEmpty) {
                          _search(_controller.text);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: active ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: active ? Border.all(color: AppTheme.primary.withOpacity(0.5)) : null,
                        ),
                        child: Text(
                          lang.toUpperCase(),
                          style: TextStyle(
                            color: active ? AppTheme.primary : AppTheme.outline,
                            fontSize: 11,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: _loading
              ? const LinearProgressIndicator(color: AppTheme.primary, backgroundColor: AppTheme.surfaceContainerHigh)
              : const SizedBox(height: 1),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildModeSelector(),
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    final isEn = _langCode == 'en';
    return Container(
      color: AppTheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          _ModePill(
            label: isEn ? 'Keyword' : 'Kata Kunci',
            icon: Icons.search,
            active: _searchMode == 'keyword',
            onTap: () {
              setState(() {
                _searchMode = 'keyword';
              });
              if (_didSearch && _controller.text.isNotEmpty) {
                _search(_controller.text);
              }
            },
          ),
          const SizedBox(width: 8),
          _ModePill(
            label: isEn ? 'Semantic (AI)' : 'Semantik (AI)',
            icon: Icons.auto_awesome,
            active: _searchMode == 'semantic',
            onTap: () {
              setState(() {
                _searchMode = 'semantic';
              });
              if (_didSearch && _controller.text.isNotEmpty) {
                _search(_controller.text);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('Search error', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(color: AppTheme.outline, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _search(_controller.text),
                child: const Text('Retry', style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_didSearch) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 72, color: AppTheme.outline),
            const SizedBox(height: 16),
            Text(
              _langCode == 'id' ? 'Cari dalam Al-Qur\'an' : 'Search within the Qur\'an',
              style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _langCode == 'id'
                  ? 'Cari kata dalam terjemahan, tafsir & topik'
                  : 'Search across translations, tafsirs & topic tags',
              style: const TextStyle(color: AppTheme.outline, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Popular search chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: ['prayer', 'mercy', 'paradise', 'patience', 'justice', 'faith']
                    .map((term) => GestureDetector(
                          onTap: () {
                            _controller.text = term;
                            _search(term);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.4)),
                            ),
                            child: Text(term, style: const TextStyle(color: AppTheme.outline, fontSize: 12)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    if (!_loading && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppTheme.outline),
            const SizedBox(height: 16),
            Text(
              _langCode == 'id'
                  ? 'Tidak ada hasil untuk "${_controller.text}"'
                  : 'No results for "${_controller.text}"',
              style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _langCode == 'id' ? 'Coba kata yang berbeda' : 'Try a different word',
              style: const TextStyle(color: AppTheme.outline, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results header
        if (_results.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            color: AppTheme.surfaceContainerLow,
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _langCode == 'id'
                        ? 'Ditemukan ${_results.length} ayat untuk "${_controller.text}"'
                        : 'Found ${_results.length} verses for "${_controller.text}"',
                    style: const TextStyle(color: AppTheme.outline, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _results.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _results.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator(color: AppTheme.primary)
                        : TextButton.icon(
                            onPressed: _loadMore,
                            icon: const Icon(Icons.expand_more, color: AppTheme.primary),
                            label: Text(
                              _langCode == 'id' ? 'Muat Lebih Banyak' : 'Load More',
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                );
              }
              return _ResultCard(
                result: _results[i],
                query: _controller.text.trim(),
                surahName: _surahName(_results[i]['verse_key'] as String? ?? ''),
                translationText: _results[i]['translation_text'] as String? ?? '',
                isFromTag: _results[i]['_from_tag'] == true,
                matchedTags: List<String>.from(
                  _results[i]['_matched_tags'] as List? ?? [],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final String query;
  final String surahName;
  final String translationText;
  final bool isFromTag;
  final List<String> matchedTags;

  const _ResultCard({
    required this.result,
    required this.query,
    required this.surahName,
    required this.translationText,
    required this.isFromTag,
    required this.matchedTags,
  });

  // Source type → color mapping
  Color _sourceColor(String type) {
    switch (type) {
      case 'Tafsir': return const Color(0xFF6B8E6B);       // muted green
      case 'Asbabun Nuzul': return const Color(0xFF8E6B4A); // muted amber
      default: return AppTheme.primary;                     // translation = primary blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final verseKey  = result['verse_key'] as String? ?? '';
    final parts     = verseKey.split(':');
    final surahId   = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final ayahNum   = parts.length > 1  ? int.tryParse(parts[1]) : null;
    final arabic    = result['text_ar'] as String? ?? '';
    final score     = result['match_score'] as int? ?? 1;
    final matchNote = result['_match_note'] as String?;
    final sources   = List<Map<String, dynamic>>.from(
      result['_context_sources'] as List? ?? []
    );

    // Determine badge label & colors from match_note
    final String badgeLabel;
    final Color  badgeColor;
    if (result['_similarity'] != null) {
      final pct = ((result['_similarity'] as double) * 100).toStringAsFixed(0);
      badgeLabel = '$pct% MATCH';
      badgeColor = AppTheme.primary;
    } else if (score >= 5) {
      badgeLabel = 'ARABIC';
      badgeColor = AppTheme.primary;
    } else if (matchNote == 'Translation') {
      badgeLabel = 'TRANS';
      badgeColor = AppTheme.primary;
    } else if (matchNote == 'Tafsir') {
      badgeLabel = 'TAFSIR';
      badgeColor = const Color(0xFF6B8E6B);
    } else if (matchNote == 'Asbabun Nuzul') {
      badgeLabel = 'NUZUL';
      badgeColor = const Color(0xFF8E6B4A);
    } else if (isFromTag) {
      badgeLabel = 'TOPIC';
      badgeColor = AppTheme.secondary;
    } else {
      badgeLabel = 'TRANS';
      badgeColor = AppTheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: score >= 2
              ? badgeColor.withOpacity(0.35)
              : AppTheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (surahId != null && ayahNum != null)
              ? () => context.go('/surahs/$surahId/ayahs/$ayahNum')
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: score >= 2
                      ? badgeColor.withOpacity(0.08)
                      : AppTheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    // Verse key
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: score >= 2
                              ? [badgeColor.withOpacity(0.3), badgeColor.withOpacity(0.1)]
                              : [AppTheme.surfaceContainerHighest, AppTheme.surfaceContainerHighest],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: score >= 2
                              ? badgeColor.withOpacity(0.5)
                              : AppTheme.outlineVariant.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        verseKey,
                        style: TextStyle(
                          color: score >= 2 ? badgeColor : AppTheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Surah name
                    Expanded(
                      child: Text(
                        surahName,
                        style: const TextStyle(color: AppTheme.outline, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: AppTheme.outline, size: 16),
                  ],
                ),
              ),
              // ── Body ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arabic text
                    if (arabic.isNotEmpty) ...[
                      Text(
                        arabic,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: AppTheme.arabicStyle(fontSize: 22, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: AppTheme.outlineVariant, height: 1),
                      const SizedBox(height: 10),
                    ],
                    // Matched tags (topic pills)
                    if (isFromTag && matchedTags.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: matchedTags.map((tagName) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.secondary.withOpacity(0.4)),
                          ),
                          child: _HighlightedText(
                            text: tagName,
                            query: query,
                            baseStyle: const TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppTheme.outlineVariant, height: 1),
                      const SizedBox(height: 8),
                    ],
                    // ── Source excerpts ──────────────────────────────────
                    // Show per-source labeled excerpts like the legacy web app.
                    // If no context sources came back, fall back to plain translation.
                    if (sources.isEmpty)
                      _HighlightedText(text: translationText, query: query)
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < sources.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _SourceExcerpt(
                              sourceName: sources[i]['source_name'] as String? ?? '',
                              sourceType: sources[i]['source_type'] as String? ?? '',
                              text: sources[i]['text'] as String? ?? '',
                              query: query,
                              color: _sourceColor(sources[i]['source_type'] as String? ?? ''),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single labeled source excerpt block — mirrors the legacy `search-excerpt-item`.
class _SourceExcerpt extends StatelessWidget {
  final String sourceName;
  final String sourceType;
  final String text;
  final String query;
  final Color color;

  const _SourceExcerpt({
    required this.sourceName,
    required this.sourceType,
    required this.text,
    required this.query,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Source label pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sourceName,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Excerpt with highlighted keywords
          _HighlightedText(
            text: text,
            query: query,
            baseStyle: TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a ~200-char excerpt centred on the first match, with ALL
/// occurrences of [query] highlighted.
/// [baseStyle] overrides the default muted body text style (used for tag pills).
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? baseStyle;
  const _HighlightedText({required this.text, required this.query, this.baseStyle});

  /// Extracts a window centred around the first hit.
  (String, bool, bool) _excerpt(String lowerText, int firstIdx, int qLen) {
    const half = 140; // chars on each side of the match
    final rawStart = (firstIdx - half).clamp(0, lowerText.length);
    final rawEnd   = (firstIdx + qLen + half).clamp(0, lowerText.length);
    int start = rawStart;
    if (start > 0) {
      final space = text.lastIndexOf(' ', start);
      if (space > 0) start = space + 1;
    }
    int end = rawEnd;
    if (end < text.length) {
      final space = text.indexOf(' ', end);
      if (space > 0) end = space;
    }
    return (text.substring(start, end), start > 0, end < text.length);
  }

  @override
  Widget build(BuildContext context) {
    final base = baseStyle ?? const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14, height: 1.65);
    final ell  = base.copyWith(color: AppTheme.outline);
    final hiColor = base.color ?? AppTheme.primary;
    final hi = base.copyWith(
      color: AppTheme.primary,
      fontWeight: FontWeight.bold,
      backgroundColor: hiColor.withOpacity(0.18),
    );

    if (text.isEmpty) return const SizedBox.shrink();

    final lowerText  = text.toLowerCase();
    final lowerQuery = query.toLowerCase().trim();

    // No query → plain text (truncate long translations)
    if (lowerQuery.isEmpty) {
      final snippet = text.length > 200 ? '${text.substring(0, 200)}…' : text;
      return Text(snippet, style: base);
    }

    // Split query into individual words for multi-word highlighting
    final words = lowerQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // Find the FIRST position of any query word to anchor the excerpt window
    int firstMatchIdx = -1;
    int firstMatchLen = 1;
    for (final word in words) {
      final idx = lowerText.indexOf(word);
      if (idx >= 0 && (firstMatchIdx < 0 || idx < firstMatchIdx)) {
        firstMatchIdx = idx;
        firstMatchLen = word.length;
      }
    }

    // No match at all → show truncated start
    if (firstMatchIdx < 0) {
      final snippet = text.length > 200 ? '${text.substring(0, 200)}…' : text;
      return Text(snippet, style: base);
    }

    // Center the excerpt window on the first matched word, then highlight all words
    final (window, prefixEll, suffixEll) = _excerpt(lowerText, firstMatchIdx, firstMatchLen);
    final lowerWindow = window.toLowerCase();

    final spans = <InlineSpan>[
      if (prefixEll) TextSpan(text: '…', style: ell),
      ..._buildHighlightSpans(window, lowerWindow, words, base, hi),
      if (suffixEll) TextSpan(text: '…', style: ell),
    ];

    return RichText(text: TextSpan(children: spans));
  }


  /// Builds a list of [TextSpan]s highlighting every occurrence of every word in [words].
  List<InlineSpan> _buildHighlightSpans(
    String display, String lower, List<String> words,
    TextStyle base, TextStyle hi,
  ) {
    if (words.isEmpty) return [TextSpan(text: display, style: base)];

    // Build sorted list of all (start, end) match ranges, then flatten overlaps
    final ranges = <(int, int)>[];
    for (final word in words) {
      int cursor = 0;
      while (cursor < lower.length) {
        final idx = lower.indexOf(word, cursor);
        if (idx < 0) break;
        ranges.add((idx, idx + word.length));
        cursor = idx + word.length;
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));

    // Merge overlapping ranges
    final merged = <(int, int)>[];
    for (final r in ranges) {
      if (merged.isEmpty || r.$1 >= merged.last.$2) {
        merged.add(r);
      } else if (r.$2 > merged.last.$2) {
        merged[merged.length - 1] = (merged.last.$1, r.$2);
      }
    }

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final (start, end) in merged) {
      if (start > cursor) spans.add(TextSpan(text: display.substring(cursor, start), style: base));
      spans.add(TextSpan(text: display.substring(start, end), style: hi));
      cursor = end;
    }
    if (cursor < display.length) spans.add(TextSpan(text: display.substring(cursor), style: base));
    return spans;
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.12) : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.outlineVariant.withOpacity(0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppTheme.primary : AppTheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.primary : AppTheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
