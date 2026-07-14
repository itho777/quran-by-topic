import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/static_index_service.dart';
import '../../core/local_db.dart';
import '../../core/cdn_translation_service.dart';

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
  String _offlineMessage = '';
  String _langCode = 'id';
  bool _didSearch = false;
  String _searchMode = 'keyword'; // 'keyword' or 'semantic'

  // Phase 2: static multilingual index results
  List<Map<String, dynamic>> _staticResults = [];
  bool _staticLoading = false;
  bool _staticExpanded = false;

  // Cache of surah names for display
  final Map<int, Map<String, String>> _surahCache = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    // Warm up static index in background so it's ready when user searches
    StaticIndexService.instance.ensureLoaded();
    StaticIndexService.instance.addListener(_onStaticIndexReady);
  }

  void _onStaticIndexReady() {
    if (mounted) setState(() {});
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
      _loadingStatus = _langCode == 'id' ? 'Mencari...' : 'Searching...';
      _error = '';
      _offlineMessage = '';
      _results = [];
      _hasMore = true;
      _didSearch = true;
    });

    int attempts = 0;
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
        if (isTimeout && attempts < 1) {
          attempts++;
          // Brief pause before retry
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        setState(() => _error = isTimeout
            ? 'Search timed out. Please try again or narrow your query.'
            : e.toString());
        break;
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _performKeywordSearch(String query) async {
    // ── Phase 1: DB search (fast GIN index, EN/ID/AR) ──────────────────────
    List<Map<String, dynamic>> list = [];
    bool isOffline = false;
    try {
      final res = await Supabase.instance.client.rpc('search_verses', params: {
        'p_query': query.trim(),
        'p_lang_code': _langCode,
        'p_result_limit': 100,
        'p_offset_val': 0,
      });
      list = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[Search] DB search failed (offline fallback): $e');
      isOffline = true;
    }

    if (isOffline) {
      setState(() {
        _results = [];
        _hasMore = false;
        _staticResults = [];
        _staticExpanded = false;
        _offlineMessage = _langCode == 'id'
            ? 'Koneksi internet bermasalah. Mencari di indeks offline lokal...'
            : 'Offline mode. Searching local offline index...';
      });
      await _runPhase2Search(query, alreadyFoundKeys: {});
      return;
    }

    // Map DB fields to widget format, parse context_snippet JSON
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

      final queryLower = query.toLowerCase();
      final words = queryLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

      bool hasQuranMatch = false;
      bool hasTranslationMatch = false;
      bool hasTafsirMatch = false;
      bool hasNuzulMatch = false;
      bool hasTagMatch = false;

      final arText = (r['text_ar'] as String? ?? '').toLowerCase();
      if (words.isNotEmpty && words.every((w) => arText.contains(w))) {
        hasQuranMatch = true;
      }
      if (tagsList.isNotEmpty) hasTagMatch = true;

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

      bool keep = false;
      if (_searchQuran && hasQuranMatch) keep = true;
      if (_searchTranslation && hasTranslationMatch) keep = true;
      if (_searchTafsir && hasTafsirMatch) keep = true;
      if (_searchNuzul && hasNuzulMatch) keep = true;
      if (_searchTag && hasTagMatch) keep = true;
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

    // Show Phase 1 results immediately
    setState(() {
      _results = mapped;
      _hasMore = list.length >= 100;
      _staticResults = [];
    _staticExpanded = false;
    });

    // ── Phase 2: Static index search (all 111 languages) ───────────────────
    // Run asynchronously so Phase 1 results are already showing
    _runPhase2Search(query, alreadyFoundKeys: mapped.map((r) => r['verse_key'] as String).toSet());
  }

  Future<void> _runPhase2Search(String query, {required Set<String> alreadyFoundKeys}) async {
    final service = StaticIndexService.instance;
    if (!service.isReady) {
      setState(() => _staticLoading = true);
      await service.ensureLoaded();
      if (!service.isReady) {
        setState(() => _staticLoading = false);
        return;
      }
    }

    setState(() => _staticLoading = true);
    try {
      final hits = await service.search(query, maxResults: 60);
      // Remove verse_keys already shown in Phase 1
      final newHits = hits.where((h) => !alreadyFoundKeys.contains(h.verseKey)).toList();
      if (newHits.isEmpty) {
        setState(() => _staticLoading = false);
        return;
      }

      // Fetch verse data from DB for the new keys
      final keys = newHits.map((h) => h.verseKey).take(40).toList();
      final arMap = <String, String>{};
      final transMap = <String, String>{};
      final sourceId = _langCode == 'id' ? 'id.kemenag' : 'en.sahih';

      // ── Base verse + primary translation lookup ──────────────────────────
      try {
        final dbRes = await Supabase.instance.client
            .from('verses')
            .select('verse_key, text_ar')
            .inFilter('verse_key', keys);

        for (final row in List<Map<String, dynamic>>.from(dbRes)) {
          arMap[row['verse_key'] as String] = row['text_ar'] as String? ?? '';
        }

        final transRes = await Supabase.instance.client
            .from('translations')
            .select('verse_key, text')
            .eq('source_id', sourceId)
            .inFilter('verse_key', keys);

        for (final row in List<Map<String, dynamic>>.from(transRes)) {
          transMap[row['verse_key'] as String] = row['text'] as String? ?? '';
        }
      } catch (dbErr) {
        debugPrint('[Phase2] DB query failed, attempting local cache fallback: $dbErr');
        // Offline / Cache fallback:
        for (final vk in keys) {
          final cachedVerse = await LocalDatabase.instance.getVerse(vk);
          if (cachedVerse != null) {
            arMap[vk] = cachedVerse['text_ar'] as String? ?? '';
          }
          final cachedTrans = await LocalDatabase.instance.getTextData('translations', vk, sourceId);
          if (cachedTrans != null) {
            transMap[vk] = cachedTrans;
          }
        }
      }

      // ── Phase 2 excerpt enrichment ───────────────────────────────────────
      // Strategy:
      //   1. DB ilike query  — primary translations (id/en) still in Supabase
      //   2. CDN in-memory   — any CDN sources already downloaded this session
      //   3. CDN download    — fetch a broad set of CDN sources and search them
      // Result: highlighted excerpt for whatever language the user searched in.
      final Map<String, List<Map<String, dynamic>>> sourceExcerpts = {};

      const sourceNames = <String, String>{
        'id.kemenag':      'Kemenag RI',
        'id.kemenag2':     'Kemenag RI (2019)',
        'en.sahih':        'Sahih International',
        'en.hilali':       'Hilali & Khan',
        'en.pickthall':    'Pickthall',
        'nl.keyzer':       'Keyzer (Dutch)',
        'nl.leemhuis':     'Leemhuis (Dutch)',
        'nl.siregar':      'Siregar (Dutch)',
        'de.bubenheim':    'Bubenheim (German)',
        'de.khoury':       'Khoury (German)',
        'de.aburida':      'Abu Rida (German)',
        'de.zaidan':       'Zaidan (German)',
        'tr.ates':         'Ates (Turkish)',
        'tr.bulac':        'Bulac (Turkish)',
        'tr.diyanet':      'Diyanet (Turkish)',
        'fr.hamidullah':   'Hamidullah (French)',
        'bs.korkut':       'Korkut (Bosnian)',
        'bs.mlivo':        'Mlivo (Bosnian)',
        'es.garcia':       'García (Spanish)',
        'es.cortes':       'Cortés (Spanish)',
        'es.bornez':       'Bornez (Spanish)',
        'ru.kuliev':       'Kuliev (Russian)',
        'ru.krachkovsky':  'Krachkovsky (Russian)',
        'ru.osmanov':      'Osmanov (Russian)',
        'ur.maududi':      'Maududi (Urdu)',
        'ur.jalandhry':    'Jalandhry (Urdu)',
        'pt.elhayek':      'El-Hayek (Portuguese)',
        'ms.basmeih':      'Basmeih (Malay)',
        'it.piccardo':     'Piccardo (Italian)',
        'no.berg':         'Berg (Norwegian)',
        'sv.bernstrom':    'Bernström (Swedish)',
        'pl.bielawskiego': 'Bielawskiego (Polish)',
        'ro.grigore':      'Grigore (Romanian)',
      };

      void _addExcerpt(String vk, String sid, String txt, List<String> qWords) {
        final lowerTxt = txt.toLowerCase();
        if (!qWords.any((w) => lowerTxt.contains(w))) return;
        final name = sourceNames[sid] ?? sid;
        sourceExcerpts.putIfAbsent(vk, () => []);
        // Avoid duplicates
        if (sourceExcerpts[vk]!.any((e) => e['source_id'] == sid)) return;
        sourceExcerpts[vk]!.add({
          'source_name': name,
          'source_type': 'Translation',
          'source_id':   sid,
          'text':        txt,
        });
      }

      try {
        final queryWords = query.trim().toLowerCase()
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 3)
            .toList();

        if (queryWords.isNotEmpty) {
          final firstWord = queryWords.first;
          final cdn = CdnTranslationService.instance;

          // ── Step 1: DB ilike (only primary sources that are in Supabase) ──
          try {
            final dbRows = await Supabase.instance.client
                .from('translations')
                .select('verse_key, source_id, text')
                .inFilter('verse_key', keys)
                .ilike('text', '%$firstWord%');
            for (final row in List<Map<String, dynamic>>.from(dbRows)) {
              _addExcerpt(
                row['verse_key'] as String? ?? '',
                row['source_id'] as String? ?? '',
                row['text']      as String? ?? '',
                queryWords,
              );
            }
          } catch (dbEx) {
            debugPrint('[Phase2] DB excerpt query failed: $dbEx');
          }

          // ── Step 2: CDN in-memory (instant, no network) ──────────────────
          final cachedHits = cdn.searchLoaded(keys, firstWord);
          for (final entry in cachedHits.entries) {
            for (final vkEntry in entry.value.entries) {
              _addExcerpt(vkEntry.key, entry.key, vkEntry.value, queryWords);
            }
          }

          // ── Step 3: CDN download fallback (if nothing found yet) ─────────
          // Download a broad set of non-primary CDN translation files and
          // search them locally. They are cached after first download.
          final stillEmpty = sourceExcerpts.isEmpty ||
              keys.every((k) => (sourceExcerpts[k]?.isEmpty ?? true));
          if (stillEmpty) {
          const cdnSources = [
              // Dutch (all 3 exist on CDN — bedekking is in nl.siregar)
              'nl.keyzer', 'nl.leemhuis', 'nl.siregar',
              // German
              'de.bubenheim', 'de.khoury', 'de.aburida', 'de.zaidan',
              // French
              'fr.hamidullah',
              // Turkish
              'tr.ates', 'tr.bulac', 'tr.diyanet',
              // Bosnian
              'bs.korkut', 'bs.mlivo',
              // Spanish
              'es.garcia', 'es.cortes', 'es.bornez',
              // Russian
              'ru.kuliev', 'ru.krachkovsky', 'ru.osmanov',
              // Urdu
              'ur.maududi', 'ur.jalandhry',
              // Portuguese
              'pt.elhayek',
              // Malay
              'ms.basmeih',
              // Italian
              'it.piccardo',
              // Norwegian
              'no.berg',
              // Swedish
              'sv.bernstrom',
              // Polish
              'pl.bielawskiego',
              // Romanian
              'ro.grigore',
            ];
            final cdnHits = await cdn.searchCdnSources(cdnSources, keys, firstWord);
            for (final entry in cdnHits.entries) {
              for (final vkEntry in entry.value.entries) {
                _addExcerpt(vkEntry.key, entry.key, vkEntry.value, queryWords);
              }
            }
          }
        }
      } catch (excerptErr) {
        debugPrint('[Phase2] Excerpt enrichment skipped: $excerptErr');
      }

      final staticMapped = newHits
          .where((h) => arMap.containsKey(h.verseKey))
          .map((h) {
            final excerpts = sourceExcerpts[h.verseKey] ?? <Map<String, dynamic>>[];
            return <String, dynamic>{
              'verse_key': h.verseKey,
              'text_ar': arMap[h.verseKey] ?? '',
              'translation_text': transMap[h.verseKey] ?? '',
              'match_score': h.score,
              '_from_tag': false,
              '_matched_tags': <String>[],
              '_match_note': 'Multilingual',
              '_context_sources': excerpts,
              '_is_static': true,
            };
          })
          .toList();

      if (mounted && staticMapped.isNotEmpty) {
        setState(() => _staticResults = staticMapped);
      }
    } catch (e) {
      debugPrint('[Phase2] Static search error: $e');
    } finally {
      if (mounted) setState(() => _staticLoading = false);
    }
  }

  Future<void> _performSemanticSearch(String query) async {
    try {
      setState(() {
        _loadingStatus = _langCode == 'id'
            ? 'Mencari makna dengan AI...'
            : 'Searching meaning with AI...';
      });

      // Query database-side semantic search RPC
      final res = await Supabase.instance.client.rpc('semantic_search_verses_by_text', params: {
        'query_text': query.trim(),
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
        'p_query': _controller.text.trim(),
        'p_lang_code': _langCode,
        'p_result_limit': 50,
        'p_offset_val': _results.length,
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
    StaticIndexService.instance.removeListener(_onStaticIndexReady);
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
                              _offlineMessage = '';
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
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
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
                  }).toList(),
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

    if (!_loading && _results.isEmpty && _staticResults.isEmpty && !_staticLoading) {
      return Column(
        children: [
          if (_offlineMessage.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, size: 18, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _offlineMessage,
                      style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
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
            ),
          ),
        ],
      );
    }

    final isEn = _langCode == 'en';
    final totalFound = _results.length;
    // Combine: Phase 1 results + (if expanded) Phase 2 static results
    final displayList = [
      ..._results,
      if (_staticExpanded) ..._staticResults,
    ];

    return Column(
      children: [
        if (_offlineMessage.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 18, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _offlineMessage,
                    style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
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
                    isEn
                        ? 'Found $totalFound verses for "${_controller.text}"'
                        : 'Ditemukan $totalFound ayat untuk "${_controller.text}"',
                    style: TextStyle(color: AppTheme.outline, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                // Static index status indicator
                if (_staticLoading)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayList.length + (_hasMore ? 1 : 0) + (_staticResults.isNotEmpty || _staticLoading ? 1 : 0),
            itemBuilder: (context, i) {
              // "Load More" button for Phase 1
              if (i == _results.length && _hasMore && !_staticExpanded) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: _loadingMore
                        ? CircularProgressIndicator(color: AppTheme.primary)
                        : TextButton.icon(
                            onPressed: _loadMore,
                            icon: Icon(Icons.expand_more, color: AppTheme.primary),
                            label: Text(
                              isEn ? 'Load More' : 'Muat Lebih Banyak',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                );
              }

              // Phase 2 "Also found in" expandable header
              final staticHeaderIndex = _results.length + (_hasMore ? 1 : 0);
              if (i == staticHeaderIndex && (_staticResults.isNotEmpty || _staticLoading)) {
                return _MultilingualHeader(
                  count: _staticResults.length,
                  isLoading: _staticLoading,
                  isExpanded: _staticExpanded,
                  isEn: isEn,
                  onTap: () => setState(() => _staticExpanded = !_staticExpanded),
                );
              }

              // Phase 2 results (when expanded)
              final resultIndex = i >= staticHeaderIndex + 1
                  ? i - staticHeaderIndex - 1 + _results.length
                  : i;

              if (resultIndex >= displayList.length) return const SizedBox.shrink();

              final r = displayList[resultIndex];
              return _ResultCard(
                result: r,
                query: _controller.text.trim(),
                surahName: _surahName(r['verse_key'] as String? ?? ''),
                translationText: r['translation_text'] as String? ?? '',
                isFromTag: r['_from_tag'] == true,
                matchedTags: List<String>.from(r['_matched_tags'] as List? ?? []),
                isMultilingual: r['_is_static'] == true,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Expandable header for Phase 2 multilingual results
class _MultilingualHeader extends StatelessWidget {
  final int count;
  final bool isLoading;
  final bool isExpanded;
  final bool isEn;
  final VoidCallback onTap;

  const _MultilingualHeader({
    required this.count,
    required this.isLoading,
    required this.isExpanded,
    required this.isEn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: count > 0 ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF8E6BAE).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.language, size: 16, color: Color(0xFF8E6BAE)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Also found in other languages' : 'Juga ditemukan dalam bahasa lain',
                    style: TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isLoading)
                    Text(
                      isEn ? 'Searching 111 languages…' : 'Mencari 111 bahasa…',
                      style: TextStyle(color: AppTheme.outline, fontSize: 11),
                    )
                  else if (count > 0)
                    Text(
                      isEn ? '$count additional verses matched' : '$count ayat tambahan ditemukan',
                      style: TextStyle(color: AppTheme.outline, fontSize: 11),
                    )
                  else
                    Text(
                      isEn ? 'No additional results' : 'Tidak ada hasil tambahan',
                      style: TextStyle(color: AppTheme.outline, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF8E6BAE)),
              )
            else if (count > 0)
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.outline,
                size: 20,
              ),
          ],
        ),
      ),
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
  final bool isMultilingual;

  const _ResultCard({
    required this.result,
    required this.query,
    required this.surahName,
    required this.translationText,
    required this.isFromTag,
    required this.matchedTags,
    this.isMultilingual = false,
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
    if (isMultilingual) {
      badgeLabel = 'MULTILANG';
      badgeColor = const Color(0xFF8E6BAE);
    } else if (result['_similarity'] != null) {
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
                      : '$base?${p.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
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
    return '$base?${p.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
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
