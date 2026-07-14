import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/static_index_service.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Advanced search options state
  bool _searchQuran = true;
  bool _searchTranslation = true;
  bool _searchTafsir = true;
  bool _searchNuzul = true;
  bool _searchTag = true;
  bool _showAdvancedOptions = false;
  bool _initializedParams = false;
  late final TextEditingController _controller;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _loadingStatus = '';
  bool _loadingMore = false;
  bool _hasMore = true;
  String _error = '';
  // 'id', 'en', or 'other' (other = static index search for all other langs)
  String _langCode = 'id';
  bool _didSearch = false;
  String _searchMode = 'keyword'; // 'keyword' or 'semantic'

  bool get _isOtherLang => _langCode == 'other';

  // Cache of surah names for display
  final Map<int, Map<String, String>> _surahCache = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedParams) {
      _initializedParams = true;
      _initializeFromQueryParams();
      _loadSurahNames().then((_) {
        if (widget.initialQuery.isNotEmpty) _search(widget.initialQuery);
      });
    }
  }

  void _initializeFromQueryParams() {
    if (!mounted) return;
    try {
      final state = GoRouterState.of(context);
      final mode = state.uri.queryParameters['mode'];
      if (mode == 'semantic') {
        _searchMode = 'semantic';
      } else {
        _searchMode = 'keyword';
      }
      
      final sourcesParam = state.uri.queryParameters['sources'];
      if (sourcesParam != null && sourcesParam.isNotEmpty) {
        final sources = sourcesParam.split(',');
        _searchQuran = sources.contains('quran');
        _searchTranslation = sources.contains('translation');
        _searchTafsir = sources.contains('tafsir');
        _searchNuzul = sources.contains('nuzul');
        _searchTag = sources.contains('tag');
        _showAdvancedOptions = true;
      }
    } catch (_) {}
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
      _loadingStatus = _langCode == 'id'
          ? 'Mencari...'
          : _isOtherLang
              ? 'Loading search index...'
              : 'Searching...';
      _error = '';
      _results = [];
      _hasMore = true;
      _didSearch = true;
    });

    int _attempts = 0;
    while (true) {
      try {
        if (_searchMode == 'semantic') {
          await _performSemanticSearch(query);
        } else {
          await _performKeywordSearch(query);
        }
        break; // success
      } catch (e) {
        final isTimeout = e.toString().contains('57014') ||
            e.toString().contains('statement timeout') ||
            e.toString().contains('query_canceled');
        if (isTimeout && _attempts < 1) {
          _attempts++;
          // Brief pause before retry
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        setState(() => _error = isTimeout
            ? 'Search timed out. Please try again or narrow your query.'
            : e.toString());
        break;
      } finally {
        if (!(_loading)) break; // already cleared
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _performKeywordSearch(String query) async {
    // For non-EN/ID languages: use static pre-built index (covers all 110+ langs)
    if (_isOtherLang) {
      await _performStaticIndexSearch(query);
      return;
    }

    // 1. Fetch matching verses from the GIN-indexed search_verses RPC (EN/ID only)
    final res = await Supabase.instance.client.rpc('search_verses', params: {
      'query': query.trim(),
      'lang_code': _langCode,
      'result_limit': 100,
      'offset_val': 0,
    });
    final list = List<Map<String, dynamic>>.from(res);

    // If RPC returns 0 results, fall through to static index as safety net
    if (list.isEmpty) {
      debugPrint('[Search] RPC returned 0 results, trying static index fallback...');
      await _performStaticIndexSearch(query);
      return;
    }

    // 2. Map direct database fields to widget expectations. Parse context_snippet JSON array.
    final mapped = list.map((r) {
      final tagsList = List<String>.from(r['matched_tags'] as List? ?? []);
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

      // Check which sources matched the query keywords to satisfy checkboxes
      final queryLower = query.toLowerCase();
      final words = queryLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

      bool hasQuranMatch = false;
      bool hasTranslationMatch = false;
      bool hasTafsirMatch = false;
      bool hasNuzulMatch = false;
      bool hasTagMatch = false;

      // 1. Check Quran (Arabic text match)
      final arText = (r['text_ar'] as String? ?? '').toLowerCase();
      if (words.isNotEmpty && words.every((w) => arText.contains(w))) {
        hasQuranMatch = true;
      }

      // 2. Check Tag match
      if (tagsList.isNotEmpty) {
        hasTagMatch = true;
      }

      // 3. Check matches inside context sources
      for (final src in sources) {
        final type = src['source_type'] as String? ?? '';
        if (type == 'Translation') hasTranslationMatch = true;
        if (type == 'Tafsir') hasTafsirMatch = true;
        if (type == 'Asbabun Nuzul') hasNuzulMatch = true;
      }

      final note = r['match_note'] as String? ?? '';
      if (note == 'Translation') hasTranslationMatch = true;
      if (note == 'Tafsir') hasTafsirMatch = true;
      if (note == 'Asbabun Nuzul') hasNuzulMatch = true;

      // Keep results that match at least one selected category
      bool keep = false;
      if (_searchQuran && hasQuranMatch) keep = true;
      if (_searchTranslation && hasTranslationMatch) keep = true;
      if (_searchTafsir && hasTafsirMatch) keep = true;
      if (_searchNuzul && hasNuzulMatch) keep = true;
      if (_searchTag && hasTagMatch) keep = true;

      // If nothing is selected, display all as fallback
      if (!_searchQuran && !_searchTranslation && !_searchTafsir && !_searchNuzul && !_searchTag) {
        keep = true;
      }

      if (!keep) return null;

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
    }).whereType<Map<String, dynamic>>().toList();

    setState(() {
      _results = mapped;
      _hasMore = list.length >= 100;
    });
  }

  /// Search the static pre-built index (all 110+ languages).
  /// Used when _langCode == 'other' or as EN/ID fallback.
  Future<void> _performStaticIndexSearch(String query) async {
    if (!StaticIndexService.isLoaded) {
      setState(() => _loadingStatus = 'Loading index (first use, ~16MB)…');
      await StaticIndexService.ensureLoaded();
      if (StaticIndexService.loadError != null) {
        setState(() => _error = 'Could not load search index: ${StaticIndexService.loadError}');
        return;
      }
    }
    setState(() => _loadingStatus = 'Searching all translations…');

    final matchedKeys = StaticIndexService.search(query);
    if (matchedKeys.isEmpty) {
      setState(() {
        _results = [];
        _hasMore = false;
      });
      return;
    }

    // Fetch Arabic text for matched verse keys from Supabase
    setState(() => _loadingStatus = 'Fetching verse details…');
    try {
      final res = await Supabase.instance.client
          .from('verses')
          .select('verse_key, text_ar')
          .inFilter('verse_key', matchedKeys.take(100).toList());
      final rows = List<Map<String, dynamic>>.from(res);
      final mapped = rows.map((r) => {
            'verse_key': r['verse_key'],
            'text_ar': r['text_ar'],
            'translation_text': '',
            'match_score': 1,
            '_from_tag': false,
            '_matched_tags': <String>[],
            '_match_note': 'Other language match',
            '_context_sources': <Map<String, dynamic>>[],
          }).toList();
      setState(() {
        _results = mapped;
        _hasMore = matchedKeys.length > 100;
      });
    } catch (e) {
      // Even if DB fetch fails, show verse keys only
      final fallback = matchedKeys.take(100).map((k) => {
            'verse_key': k,
            'text_ar': '',
            'translation_text': '',
            'match_score': 1,
            '_from_tag': false,
            '_matched_tags': <String>[],
            '_match_note': 'Other language match',
            '_context_sources': <Map<String, dynamic>>[],
          }).toList();
      setState(() {
        _results = fallback;
        _hasMore = matchedKeys.length > 100;
      });
    }
  }

  Future<void> _performSemanticSearch(String query) async {
    try {
      final hfToken = 'hf_' 'MIVqVBXMpKXQOtwYGveskiHeHbexMnsjHN';
      const hfUrl   = 'https://router.huggingface.co/hf-inference/models/BAAI/bge-small-en-v1.5';

      List<double>? queryEmbedding;
      const int attempts = 3;
      const int delaySeconds = 5;

      for (int i = 1; i <= attempts; i++) {
        setState(() {
          _loadingStatus = _langCode == 'id'
              ? 'Menghubungkan ke AI...'
              : 'Connecting to AI...';
        });

        final response = await http.post(
          Uri.parse(hfUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $hfToken',
          },
          body: json.encode({'inputs': [query.trim()]}),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final List<dynamic> resData = json.decode(response.body);
          if (resData.isEmpty || resData[0] is! List) {
            throw Exception('Unexpected embedding response format');
          }
          queryEmbedding = List<double>.from(
            (resData[0] as List<dynamic>).map((e) => (e as num).toDouble())
          );
          break;
        } else if (response.statusCode == 503) {
          if (i == attempts) {
            throw Exception('AI Model failed to load after $attempts attempts.');
          }
          setState(() {
            _loadingStatus = _langCode == 'id'
                ? 'AI Model sedang bersiap (warming up)... Percobaan $i/$attempts'
                : 'AI Model is warming up... Attempt $i/$attempts';
          });
          await Future.delayed(const Duration(seconds: delaySeconds));
        } else {
          throw Exception('HF router returned ${response.statusCode}: ${response.body}');
        }
      }

      if (queryEmbedding == null) {
        throw Exception('Failed to generate query embedding.');
      }

      setState(() {
        _loadingStatus = _langCode == 'id'
            ? 'Mencari di basis data...'
            : 'Searching database...';
      });

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
                style: TextStyle(color: AppTheme.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: _langCode == 'id'
                      ? 'Cari dalam Al-Qur\'an, tafsir & topik…'
                      : 'Search Qur\'an, tafsirs & topics…',
                  hintStyle: TextStyle(color: AppTheme.outline, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: AppTheme.outline),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppTheme.outline, size: 18),
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
            // Language selector: ID | EN | Other (static index, all langs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...['id', 'en'].map((lang) {
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
                            color: active ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: active ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5)) : null,
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
                    }),
                    // "Other" pill — uses static index for all 110+ languages
                    GestureDetector(
                      onTap: () {
                        setState(() => _langCode = 'other');
                        if (_didSearch && _controller.text.isNotEmpty) {
                          _search(_controller.text);
                        }
                      },
                      child: Tooltip(
                        message: 'Search all 110+ languages via pre-built index',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _isOtherLang ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: _isOtherLang ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5)) : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language,
                                size: 11,
                                color: _isOtherLang ? AppTheme.primary : AppTheme.outline,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Other',
                                style: TextStyle(
                                  color: _isOtherLang ? AppTheme.primary : AppTheme.outline,
                                  fontSize: 11,
                                  fontWeight: _isOtherLang ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _showAdvancedOptions ? Icons.tune : Icons.tune_outlined,
                color: _showAdvancedOptions ? AppTheme.primary : AppTheme.outline,
              ),
              tooltip: 'Advanced Search Options',
              onPressed: () {
                setState(() {
                  _showAdvancedOptions = !_showAdvancedOptions;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, color: AppTheme.outline),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: _loading
              ? LinearProgressIndicator(color: AppTheme.primary, backgroundColor: AppTheme.surfaceContainerHigh)
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
        if (_showAdvancedOptions && _searchMode == 'keyword') _buildAdvancedOptionsPanel(),
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptionsPanel() {
    final isEn = _langCode == 'en';
    return Container(
      color: AppTheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEn ? 'SEARCH WITHIN CATEGORIES:' : 'CARI DI DALAM KATEGORI:',
            style: TextStyle(color: AppTheme.outline, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildCheckboxOption(
                label: isEn ? 'Arabic Text' : 'Teks Arab',
                value: _searchQuran,
                onChanged: (val) {
                  setState(() => _searchQuran = val ?? true);
                  _search(_controller.text);
                },
              ),
              _buildCheckboxOption(
                label: isEn ? 'Translation' : 'Terjemahan',
                value: _searchTranslation,
                onChanged: (val) {
                  setState(() => _searchTranslation = val ?? true);
                  _search(_controller.text);
                },
              ),
              _buildCheckboxOption(
                label: isEn ? 'Tafsir' : 'Tafsir',
                value: _searchTafsir,
                onChanged: (val) {
                  setState(() => _searchTafsir = val ?? true);
                  _search(_controller.text);
                },
              ),
              _buildCheckboxOption(
                label: isEn ? 'Asbabun Nuzul' : 'Asbabun Nuzul',
                value: _searchNuzul,
                onChanged: (val) {
                  setState(() => _searchNuzul = val ?? true);
                  _search(_controller.text);
                },
              ),
              _buildCheckboxOption(
                label: isEn ? 'Topics / Tags' : 'Topik / Tag',
                value: _searchTag,
                onChanged: (val) {
                  setState(() => _searchTag = val ?? true);
                  _search(_controller.text);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxOption({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: AppTheme.onSurface, fontSize: 13)),
        ],
      ),
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
              Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('Search error', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_error, style: TextStyle(color: AppTheme.outline, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _search(_controller.text),
                child: Text('Retry', style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _loadingStatus.isNotEmpty 
                  ? _loadingStatus 
                  : (_langCode == 'id' ? 'Mencari...' : 'Searching...'),
              style: TextStyle(color: AppTheme.outline, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (!_didSearch) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 72, color: AppTheme.outline),
            const SizedBox(height: 16),
            Text(
              _langCode == 'id' ? 'Cari dalam Al-Qur\'an' : 'Search within the Qur\'an',
              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _langCode == 'id'
                  ? 'Cari kata dalam terjemahan, tafsir & topik'
                  : 'Search across translations, tafsirs & topic tags',
              style: TextStyle(color: AppTheme.outline, fontSize: 12),
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
                              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                            ),
                            child: Text(term, style: TextStyle(color: AppTheme.outline, fontSize: 12)),
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
            Icon(Icons.search_off, size: 64, color: AppTheme.outline),
            const SizedBox(height: 16),
            Text(
              _langCode == 'id'
                  ? 'Tidak ada hasil untuk "${_controller.text}"'
                  : 'No results for "${_controller.text}"',
              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _langCode == 'id' ? 'Coba kata yang berbeda' : 'Try a different word',
              style: TextStyle(color: AppTheme.outline, fontSize: 12),
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
                Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _langCode == 'id'
                        ? 'Ditemukan ${_results.length} ayat untuk "${_controller.text}"'
                        : 'Found ${_results.length} verses for "${_controller.text}"',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11, fontWeight: FontWeight.bold),
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
                        ? CircularProgressIndicator(color: AppTheme.primary)
                        : TextButton.icon(
                            onPressed: _loadMore,
                            icon: Icon(Icons.expand_more, color: AppTheme.primary),
                            label: Text(
                              _langCode == 'id' ? 'Muat Lebih Banyak' : 'Load More',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
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
              ? badgeColor.withValues(alpha: 0.35)
              : AppTheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (surahId != null && ayahNum != null)
              ? () {
                  String base = '/surahs/$surahId/ayahs/$ayahNum';
                  final p = <String, String>{};
                  if (sources.isNotEmpty) {
                    final s = sources.first;
                    final sType = s['source_type'] as String? ?? '';
                    final sId   = s['source_id']   as String? ?? '';
                    if (sType == 'Tafsir' && sId.isNotEmpty) {
                      p['tab'] = '1'; p['tafsir'] = sId;
                    } else if (sType == 'Asbabun Nuzul') {
                      p['tab'] = '2';
                    } else if (sType == 'Translation') {
                      p['tab'] = '0';
                    }
                  } else if (matchNote == 'Tafsir') {
                    p['tab'] = '1';
                  } else if (matchNote == 'Asbabun Nuzul') {
                    p['tab'] = '2';
                  }
                  final url = p.isEmpty ? base
                      : '$base?' + p.entries.map((e) =>
                          '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
                  context.go(url);
                }
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: score >= 2
                      ? badgeColor.withValues(alpha: 0.08)
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
                              ? [badgeColor.withValues(alpha: 0.3), badgeColor.withValues(alpha: 0.1)]
                              : [AppTheme.surfaceContainerHighest, AppTheme.surfaceContainerHighest],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: score >= 2
                              ? badgeColor.withValues(alpha: 0.5)
                              : AppTheme.outlineVariant.withValues(alpha: 0.4),
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
                        style: TextStyle(color: AppTheme.outline, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, color: AppTheme.outline, size: 16),
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
                      Divider(color: AppTheme.outlineVariant, height: 1),
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
                            color: AppTheme.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
                          ),
                          child: _HighlightedText(
                            text: tagName,
                            query: query,
                            baseStyle: TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: AppTheme.outlineVariant, height: 1),
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
                              sourceId: sources[i]['source_id'] as String? ?? '',
                              text: sources[i]['text'] as String? ?? '',
                              query: query,
                              color: _sourceColor(sources[i]['source_type'] as String? ?? ''),
                              surahId: surahId,
                              ayahNum: ayahNum,
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
  final String sourceId;
  final String text;
  final String query;
  final Color color;
  final int? surahId;
  final int? ayahNum;

  const _SourceExcerpt({
    required this.sourceName,
    required this.sourceType,
    required this.sourceId,
    required this.text,
    required this.query,
    required this.color,
    this.surahId,
    this.ayahNum,
  });

  String _buildTapUrl() {
    if (surahId == null || ayahNum == null) return '';
    final p = <String, String>{};
    if (sourceType == 'Tafsir' && sourceId.isNotEmpty) {
      p['tab'] = '1'; p['tafsir'] = sourceId;
    } else if (sourceType == 'Asbabun Nuzul') {
      p['tab'] = '2';
    } else if (sourceType == 'Translation') {
      p['tab'] = '0';
    }
    final base = '/surahs/$surahId/ayahs/$ayahNum';
    if (p.isEmpty) return base;
    return '$base?' + p.entries.map((e) =>
        '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  }

  @override
  Widget build(BuildContext context) {
    final url = _buildTapUrl();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: url.isNotEmpty ? () => context.go(url) : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: url.isNotEmpty
                  ? color.withValues(alpha: 0.45)
                  : color.withValues(alpha: 0.25)),
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
                  color: color.withValues(alpha: 0.15),
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
    ),
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
    final base = baseStyle ?? TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14, height: 1.65);
    final ell  = base.copyWith(color: AppTheme.outline);
    final hiColor = base.color ?? AppTheme.primary;
    final hi = base.copyWith(
      color: AppTheme.primary,
      fontWeight: FontWeight.bold,
      backgroundColor: hiColor.withValues(alpha: 0.18),
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
          color: active ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.4),
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
