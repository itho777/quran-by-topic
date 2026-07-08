import os

home_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\home\home_screen.dart"
search_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\search\search_screen.dart"

# ─── 1. Modify home_screen.dart ───
with open(home_file, 'r', encoding='utf-8') as f:
    home_content = f.read()

# Add state variables inside class _HomeScreenState
old_state_start = "class _HomeScreenState extends ConsumerState<HomeScreen> {"
new_state_start = """class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Advanced search options state
  bool _showAdvanced = false;
  bool _searchQuran = true;
  bool _searchTranslation = true;
  bool _searchTafsir = true;
  bool _searchNuzul = true;
  bool _searchTag = true;
  bool _semanticSearch = false;"""

home_content = home_content.replace(old_state_start, new_state_start, 1)

# Replace _doSearch()
old_do_search = """  void _doSearch() {
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      context.go('/search?q=${Uri.encodeComponent(q)}');
    }
  }"""

new_do_search = """  void _doSearch() {
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      final params = <String, String>{
        'q': q,
      };
      if (_semanticSearch) {
        params['mode'] = 'semantic';
      } else {
        params['mode'] = 'keyword';
        final List<String> sources = [];
        if (_searchQuran) sources.add('quran');
        if (_searchTranslation) sources.add('translation');
        if (_searchTafsir) sources.add('tafsir');
        if (_searchNuzul) sources.add('nuzul');
        if (_searchTag) sources.add('tag');
        params['sources'] = sources.join(',');
      }
      final uri = Uri(
        path: '/search',
        queryParameters: params,
      );
      context.go(uri.toString());
    }
  }"""

home_content = home_content.replace(old_do_search, new_do_search, 1)

# Replace TextField onSubmitted + search field padding
old_search_field = """                          // Search field
                          TextField(
                            controller: _searchController,
                            style: TextStyle(color: AppTheme.onSurface),
                            decoration: InputDecoration(
                              hintText: isEn ? 'Search within Qur\'an' : 'Cari dalam Al-Qur\'an',
                              prefixIcon: Icon(Icons.search, color: AppTheme.outline),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: AppTheme.outline),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _doSearch(),
                            textInputAction: TextInputAction.search,
                          ),
                          const SizedBox(height: 16),"""

new_search_field = """                          // Search field
                          TextField(
                            controller: _searchController,
                            style: TextStyle(color: AppTheme.onSurface),
                            decoration: InputDecoration(
                              hintText: isEn ? 'Search within Qur\'an' : 'Cari dalam Al-Qur\'an',
                              prefixIcon: Icon(Icons.search, color: AppTheme.outline),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: AppTheme.outline),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _doSearch(),
                            textInputAction: TextInputAction.search,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                icon: Icon(
                                  _showAdvanced ? Icons.tune : Icons.tune_outlined,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                                label: Text(
                                  isEn ? 'Advanced Search' : 'Pencarian Lanjutan',
                                  style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showAdvanced = !_showAdvanced;
                                  });
                                },
                              ),
                              if (_searchController.text.trim().isNotEmpty)
                                TextButton(
                                  onPressed: _doSearch,
                                  child: Text(
                                    isEn ? 'SEARCH' : 'CARI',
                                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          if (_showAdvanced) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            isEn ? 'Semantic (AI) Search' : 'Pencarian Semantik (AI)',
                                            style: TextStyle(
                                              color: AppTheme.onSurface,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Switch(
                                        value: _semanticSearch,
                                        activeColor: AppTheme.primary,
                                        onChanged: (val) {
                                          setState(() {
                                            _semanticSearch = val;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  if (!_semanticSearch) ...[
                                    const Divider(height: 20),
                                    Text(
                                      isEn ? 'SEARCH WITHIN CATEGORIES:' : 'CARI DI DALAM KATEGORI:',
                                      style: TextStyle(
                                        color: AppTheme.outline,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        _buildAdvancedCheckbox(
                                          label: isEn ? 'Arabic Text' : 'Teks Arab',
                                          value: _searchQuran,
                                          onChanged: (val) => setState(() => _searchQuran = val ?? true),
                                        ),
                                        _buildAdvancedCheckbox(
                                          label: isEn ? 'Translation' : 'Terjemahan',
                                          value: _searchTranslation,
                                          onChanged: (val) => setState(() => _searchTranslation = val ?? true),
                                        ),
                                        _buildAdvancedCheckbox(
                                          label: isEn ? 'Tafsir' : 'Tafsir',
                                          value: _searchTafsir,
                                          onChanged: (val) => setState(() => _searchTafsir = val ?? true),
                                        ),
                                        _buildAdvancedCheckbox(
                                          label: isEn ? 'Asbabun Nuzul' : 'Asbabun Nuzul',
                                          value: _searchNuzul,
                                          onChanged: (val) => setState(() => _searchNuzul = val ?? true),
                                        ),
                                        _buildAdvancedCheckbox(
                                          label: isEn ? 'Topics / Tags' : 'Topik / Tag',
                                          value: _searchTag,
                                          onChanged: (val) => setState(() => _searchTag = val ?? true),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),"""

home_content = home_content.replace(old_search_field.replace('\r\n', '\n'), new_search_field.replace('\r\n', '\n'))
home_content = home_content.replace(old_search_field, new_search_field)

# Add helper checkbox widget at the bottom of the _HomeScreenState class
old_class_end = "  Widget _buildQuickGrid(bool isEn) {"
new_class_end = """  Widget _buildAdvancedCheckbox({
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
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: AppTheme.onSurface, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickGrid(bool isEn) {"""

home_content = home_content.replace(old_class_end, new_class_end, 1)

with open(home_file, 'w', encoding='utf-8') as f:
    f.write(home_content)
print("home_screen.dart patched successfully!")


# ─── 2. Modify search_screen.dart ───
with open(search_file, 'r', encoding='utf-8') as f:
    search_content = f.read()

# Add advanced options state variables to SearchScreen
old_search_state = "class _SearchScreenState extends State<SearchScreen> {"
new_search_state = """class _SearchScreenState extends State<SearchScreen> {
  // Advanced search options state
  bool _searchQuran = true;
  bool _searchTranslation = true;
  bool _searchTafsir = true;
  bool _searchNuzul = true;
  bool _searchTag = true;
  bool _showAdvancedOptions = false;
  bool _initializedParams = false;"""

search_content = search_content.replace(old_search_state, new_search_state, 1)

# Modify initState and add didChangeDependencies + _initializeFromQueryParams
old_init_state = """  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _loadSurahNames().then((_) {
      if (widget.initialQuery.isNotEmpty) _search(widget.initialQuery);
    });
  }"""

new_init_state = """  @override
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
  }"""

search_content = search_content.replace(old_init_state.replace('\r\n', '\n'), new_init_state.replace('\r\n', '\n'))
search_content = search_content.replace(old_init_state, new_init_state)

# Replace _performKeywordSearch to perform client-side filtering on categories
old_keyword_search = """  Future<void> _performKeywordSearch(String query) async {
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
  }"""

new_keyword_search = """  Future<void> _performKeywordSearch(String query) async {
    // 1. Fetch matching verses directly from optimized multi-table search_verses RPC
    final res = await Supabase.instance.client.rpc('search_verses', params: {
      'query': query.trim(),
      'lang_code': _langCode,
      'result_limit': 100, // retrieve slightly more for filtering overhead
      'offset_val': 0,
    });
    final list = List<Map<String, dynamic>>.from(res);

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
      final words = queryLower.split(RegExp(r'\\s+')).where((w) => w.isNotEmpty).toList();

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
  }"""

search_content = search_content.replace(old_keyword_search.replace('\r\n', '\n'), new_keyword_search.replace('\r\n', '\n'))
search_content = search_content.replace(old_keyword_search, new_keyword_search)

# Add tuning Icon button under actions list
old_app_bar_actions = """            IconButton(
              icon: Icon(Icons.settings_outlined, color: AppTheme.outline),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),"""

new_app_bar_actions = """            IconButton(
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
            ),"""

search_content = search_content.replace(old_app_bar_actions.replace('\r\n', '\n'), new_app_bar_actions.replace('\r\n', '\n'))
search_content = search_content.replace(old_app_bar_actions, new_app_bar_actions)

# Update buildBody to output the advanced options panel
old_build_body = """  Widget _buildBody() {
    return Column(
      children: [
        _buildModeSelector(),
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }"""

new_build_body = """  Widget _buildBody() {
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
  }"""

search_content = search_content.replace(old_build_body.replace('\r\n', '\n'), new_build_body.replace('\r\n', '\n'))
search_content = search_content.replace(old_build_body, new_build_body)

# Handle mode selector toggle synchronisation with the state
old_mode_selector = """  Widget _buildModeSelector() {
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
  }"""

new_mode_selector = """  Widget _buildModeSelector() {
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
  }"""

search_content = search_content.replace(old_mode_selector.replace('\r\n', '\n'), new_mode_selector.replace('\r\n', '\n'))
search_content = search_content.replace(old_mode_selector, new_mode_selector)

with open(search_file, 'w', encoding='utf-8') as f:
    f.write(search_content)
print("search_screen.dart patched successfully!")
