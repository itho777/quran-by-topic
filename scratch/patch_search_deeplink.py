"""
Patch: Search result → Ayah Detail with pre-selected source tab
All files read/written with latin-1 to handle special chars.
"""

def read(path):
    with open(path, 'rb') as f:
        raw = f.read()
    try:
        text = raw.decode('utf-8')
        enc = 'utf-8'
    except UnicodeDecodeError:
        text = raw.decode('latin-1')
        enc = 'latin-1'
    return text.replace('\r\n', '\n'), enc

def write(path, text, enc):
    with open(path, 'wb') as f:
        f.write(text.encode(enc))

def patch(text, old, new, label):
    if old in text:
        print(f'  [OK] {label}')
        return text.replace(old, new, 1)
    else:
        print(f'  [!!] NOT FOUND: {label}')
        return text

# ─────────────────────────────────────────────────────────────────────────────
# 1. AYAH DETAIL SCREEN
# ─────────────────────────────────────────────────────────────────────────────
print('\n=== ayah_detail_screen.dart ===')
ayah_file = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart'
ayah, enc_ayah = read(ayah_file)

# 1a. Add initialTafsir + initialTab to constructor
ayah = patch(ayah,
    "class AyahDetailScreen extends ConsumerStatefulWidget {\n"
    "  final int surahId;\n"
    "  final int ayahNumber;\n"
    "\n"
    "  const AyahDetailScreen({\n"
    "    super.key,\n"
    "    required this.surahId,\n"
    "    required this.ayahNumber,\n"
    "  });",
    "class AyahDetailScreen extends ConsumerStatefulWidget {\n"
    "  final int surahId;\n"
    "  final int ayahNumber;\n"
    "  /// Source ID to pre-select in the Tafsir tab (e.g. 'id.jalalayn').\n"
    "  final String? initialTafsir;\n"
    "  /// Tab index: 0=Translation 1=Tafsir 2=Nuzul 3=Topics 4=Related\n"
    "  final int? initialTab;\n"
    "\n"
    "  const AyahDetailScreen({\n"
    "    super.key,\n"
    "    required this.surahId,\n"
    "    required this.ayahNumber,\n"
    "    this.initialTafsir,\n"
    "    this.initialTab,\n"
    "  });",
    "constructor params")

# 1b. Add guard fields after _tagsSlots
ayah = patch(ayah,
    "  List<_ToggleSlot> _tagsSlots = [];\n",
    "  List<_ToggleSlot> _tagsSlots = [];\n"
    "  String? _lastBuiltLang;\n"
    "  bool _initialSourceApplied = false;\n",
    "_lastBuiltLang + _initialSourceApplied fields")

# 1c. Auto-jump to initialTab in initState
ayah = patch(ayah,
    "    _tabController = TabController(length: 5, vsync: this);\n"
    "    _selectedSurahId = widget.surahId;\n"
    "    _loadAllData();\n"
    "    _loadSurahsList();",
    "    _tabController = TabController(length: 5, vsync: this);\n"
    "    _selectedSurahId = widget.surahId;\n"
    "    _loadAllData();\n"
    "    _loadSurahsList();\n"
    "    // Jump to the requested tab after first frame\n"
    "    if (widget.initialTab != null || widget.initialTafsir != null) {\n"
    "      WidgetsBinding.instance.addPostFrameCallback((_) {\n"
    "        if (mounted) _tabController.animateTo(widget.initialTab ?? 1);\n"
    "      });\n"
    "    }",
    "initState tab jump")

# 1d. Guard _buildSlots against overwriting custom selections
ayah = patch(ayah,
    "  void _buildSlots() {\n"
    "    if (_currentLang == 'en') {",
    "  void _buildSlots() {\n"
    "    if (_lastBuiltLang == _currentLang &&\n"
    "        _transSlots.isNotEmpty &&\n"
    "        _tafsirSlots.isNotEmpty &&\n"
    "        _nuzulSlots.isNotEmpty &&\n"
    "        _tagsSlots.isNotEmpty) {\n"
    "      return;\n"
    "    }\n"
    "    _lastBuiltLang = _currentLang;\n"
    "    if (_currentLang == 'en') {",
    "_buildSlots guard")

# 1e. Apply initialTafsir at the END of _buildSlots (before closing brace)
ayah = patch(ayah,
    "      _tagsSlots = [\n"
    "        _ToggleSlot(_srcLabel['id']!, 'id'),\n"
    "        _ToggleSlot(_srcLabel['en']!, 'en'),\n"
    "      ];\n"
    "    }\n"
    "  }\n"
    "\n"
    "  Future<void> _loadAllData()",
    "      _tagsSlots = [\n"
    "        _ToggleSlot(_srcLabel['id']!, 'id'),\n"
    "        _ToggleSlot(_srcLabel['en']!, 'en'),\n"
    "      ];\n"
    "    }\n"
    "    // Apply initialTafsir from search deep-link (only once)\n"
    "    if (!_initialSourceApplied && widget.initialTafsir != null) {\n"
    "      _initialSourceApplied = true;\n"
    "      final targetId = widget.initialTafsir!;\n"
    "      final existingIdx = _tafsirSlots.indexWhere((s) => s.sourceId == targetId);\n"
    "      if (existingIdx != -1) {\n"
    "        _tafsirIdx = existingIdx;\n"
    "      } else {\n"
    "        final label = QuranSources.tafsirs[targetId]?.name ??\n"
    "            _srcLabel[targetId] ?? targetId;\n"
    "        _tafsirSlots[0] = _ToggleSlot(label, targetId);\n"
    "        _tafsirIdx = 0;\n"
    "      }\n"
    "    }\n"
    "  }\n"
    "\n"
    "  Future<void> _loadAllData()",
    "initialTafsir override in _buildSlots")

write(ayah_file, ayah, enc_ayah)
print(f'  Saved ({len(ayah)} bytes, enc={enc_ayah})')


# ─────────────────────────────────────────────────────────────────────────────
# 2. ROUTER.DART
# ─────────────────────────────────────────────────────────────────────────────
print('\n=== router.dart ===')
router_file = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\core\router.dart'
router, enc_router = read(router_file)

router = patch(router,
    "                  GoRoute(\n"
    "                    path: 'ayahs/:ayahNum',\n"
    "                    builder: (context, state) {\n"
    "                      final id = int.parse(state.pathParameters['id']!);\n"
    "                      final ayahNum = int.parse(state.pathParameters['ayahNum']!);\n"
    "                      return AyahDetailScreen(surahId: id, ayahNumber: ayahNum);\n"
    "                    },\n"
    "                  ),",
    "                  GoRoute(\n"
    "                    path: 'ayahs/:ayahNum',\n"
    "                    builder: (context, state) {\n"
    "                      final id = int.parse(state.pathParameters['id']!);\n"
    "                      final ayahNum = int.parse(state.pathParameters['ayahNum']!);\n"
    "                      final tafsir = state.uri.queryParameters['tafsir'];\n"
    "                      final tabStr = state.uri.queryParameters['tab'];\n"
    "                      final tab = tabStr != null ? int.tryParse(tabStr) : null;\n"
    "                      return AyahDetailScreen(\n"
    "                        surahId: id,\n"
    "                        ayahNumber: ayahNum,\n"
    "                        initialTafsir: tafsir,\n"
    "                        initialTab: tab,\n"
    "                      );\n"
    "                    },\n"
    "                  ),",
    "ayah route with tafsir+tab params")

write(router_file, router, enc_router)
print(f'  Saved ({len(router)} bytes, enc={enc_router})')


# ─────────────────────────────────────────────────────────────────────────────
# 3. SEARCH SCREEN
# ─────────────────────────────────────────────────────────────────────────────
print('\n=== search_screen.dart ===')
search_file = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\search\search_screen.dart'
search, enc_search = read(search_file)

# 3a. Update result card onTap to build URL with source params
search = patch(search,
    "          onTap: (surahId != null && ayahNum != null)\n"
    "              ? () => context.go('/surahs/$surahId/ayahs/$ayahNum')\n"
    "              : null,",
    "          onTap: (surahId != null && ayahNum != null)\n"
    "              ? () {\n"
    "                  String base = '/surahs/$surahId/ayahs/$ayahNum';\n"
    "                  final p = <String, String>{};\n"
    "                  if (sources.isNotEmpty) {\n"
    "                    final s = sources.first;\n"
    "                    final sType = s['source_type'] as String? ?? '';\n"
    "                    final sId   = s['source_id']   as String? ?? '';\n"
    "                    if (sType == 'Tafsir' && sId.isNotEmpty) {\n"
    "                      p['tab'] = '1'; p['tafsir'] = sId;\n"
    "                    } else if (sType == 'Asbabun Nuzul') {\n"
    "                      p['tab'] = '2';\n"
    "                    } else if (sType == 'Translation') {\n"
    "                      p['tab'] = '0';\n"
    "                    }\n"
    "                  } else if (matchNote == 'Tafsir') {\n"
    "                    p['tab'] = '1';\n"
    "                  } else if (matchNote == 'Asbabun Nuzul') {\n"
    "                    p['tab'] = '2';\n"
    "                  }\n"
    "                  final url = p.isEmpty ? base\n"
    "                      : '$base?' + p.entries.map((e) =>\n"
    "                          '${e.key}=${Uri.encodeComponent(e.value)}').join('&');\n"
    "                  context.go(url);\n"
    "                }\n"
    "              : null,",
    "result card onTap with source URL")

# 3b. Update _SourceExcerpt widget call to pass sourceId, surahId, ayahNum
search = patch(search,
    "                            _SourceExcerpt(\n"
    "                              sourceName: sources[i]['source_name'] as String? ?? '',\n"
    "                              sourceType: sources[i]['source_type'] as String? ?? '',\n"
    "                              text: sources[i]['text'] as String? ?? '',\n"
    "                              query: query,\n"
    "                              color: _sourceColor(sources[i]['source_type'] as String? ?? ''),\n"
    "                            ),",
    "                            _SourceExcerpt(\n"
    "                              sourceName: sources[i]['source_name'] as String? ?? '',\n"
    "                              sourceType: sources[i]['source_type'] as String? ?? '',\n"
    "                              sourceId: sources[i]['source_id'] as String? ?? '',\n"
    "                              text: sources[i]['text'] as String? ?? '',\n"
    "                              query: query,\n"
    "                              color: _sourceColor(sources[i]['source_type'] as String? ?? ''),\n"
    "                              surahId: surahId,\n"
    "                              ayahNum: ayahNum,\n"
    "                            ),",
    "_SourceExcerpt widget call")

# 3c. Update _SourceExcerpt class declaration
search = patch(search,
    "class _SourceExcerpt extends StatelessWidget {\n"
    "  final String sourceName;\n"
    "  final String sourceType;\n"
    "  final String text;\n"
    "  final String query;\n"
    "  final Color color;\n"
    "\n"
    "  const _SourceExcerpt({\n"
    "    required this.sourceName,\n"
    "    required this.sourceType,\n"
    "    required this.text,\n"
    "    required this.query,\n"
    "    required this.color,\n"
    "  });",
    "class _SourceExcerpt extends StatelessWidget {\n"
    "  final String sourceName;\n"
    "  final String sourceType;\n"
    "  final String sourceId;\n"
    "  final String text;\n"
    "  final String query;\n"
    "  final Color color;\n"
    "  final int? surahId;\n"
    "  final int? ayahNum;\n"
    "\n"
    "  const _SourceExcerpt({\n"
    "    required this.sourceName,\n"
    "    required this.sourceType,\n"
    "    required this.sourceId,\n"
    "    required this.text,\n"
    "    required this.query,\n"
    "    required this.color,\n"
    "    this.surahId,\n"
    "    this.ayahNum,\n"
    "  });",
    "_SourceExcerpt class declaration")

# 3d. Wrap _SourceExcerpt.build Container with InkWell
search = patch(search,
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    return Container(\n"
    "      padding: const EdgeInsets.all(10),\n"
    "      decoration: BoxDecoration(\n"
    "        color: color.withValues(alpha: 0.05),\n"
    "        borderRadius: BorderRadius.circular(10),\n"
    "        border: Border.all(color: color.withValues(alpha: 0.25)),\n"
    "      ),",
    "  String _buildTapUrl() {\n"
    "    if (surahId == null || ayahNum == null) return '';\n"
    "    final p = <String, String>{};\n"
    "    if (sourceType == 'Tafsir' && sourceId.isNotEmpty) {\n"
    "      p['tab'] = '1'; p['tafsir'] = sourceId;\n"
    "    } else if (sourceType == 'Asbabun Nuzul') {\n"
    "      p['tab'] = '2';\n"
    "    } else if (sourceType == 'Translation') {\n"
    "      p['tab'] = '0';\n"
    "    }\n"
    "    final base = '/surahs/$surahId/ayahs/$ayahNum';\n"
    "    if (p.isEmpty) return base;\n"
    "    return '$base?' + p.entries.map((e) =>\n"
    "        '${e.key}=${Uri.encodeComponent(e.value)}').join('&');\n"
    "  }\n"
    "\n"
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    final url = _buildTapUrl();\n"
    "    return Material(\n"
    "      color: Colors.transparent,\n"
    "      borderRadius: BorderRadius.circular(10),\n"
    "      child: InkWell(\n"
    "        borderRadius: BorderRadius.circular(10),\n"
    "        onTap: url.isNotEmpty ? () => context.go(url) : null,\n"
    "        child: Container(\n"
    "          padding: const EdgeInsets.all(10),\n"
    "          decoration: BoxDecoration(\n"
    "            color: color.withValues(alpha: 0.05),\n"
    "            borderRadius: BorderRadius.circular(10),\n"
    "            border: Border.all(\n"
    "              color: url.isNotEmpty\n"
    "                  ? color.withValues(alpha: 0.45)\n"
    "                  : color.withValues(alpha: 0.25)),\n"
    "          ),",
    "_SourceExcerpt.build wrapped with InkWell")

# 3e. Close the extra InkWell/Material wrapping
search = patch(search,
    "        ],\n"
    "      ),\n"
    "    );\n"
    "  }\n"
    "}\n"
    "\n"
    "/// Inline rich-text widget",
    "        ],\n"
    "      ),\n"
    "    ),\n"
    "      ),\n"
    "    );\n"
    "  }\n"
    "}\n"
    "\n"
    "/// Inline rich-text widget",
    "_SourceExcerpt closing brackets")

write(search_file, search, enc_search)
print(f'  Saved ({len(search)} bytes, enc={enc_search})')

print('\n=== Done ===')
