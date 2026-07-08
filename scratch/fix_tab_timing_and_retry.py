"""
Fix:
  1. ayah_detail_screen.dart – tab jump now happens AFTER loading completes
  2. search_screen.dart      – auto-retry once on PostgreSQL error 57014
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
    print(f'  [!!] NOT FOUND: {label}')
    return text

# ─────────────────────────────────────────────────────────────────────────────
# 1. ayah_detail_screen.dart – move tab jump to post-load
# ─────────────────────────────────────────────────────────────────────────────
print('\n=== ayah_detail_screen.dart ===')
ayah_file = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart'
ayah, enc = read(ayah_file)

# 1a. Remove the addPostFrameCallback from initState (we'll move the jump to after load)
ayah = patch(ayah,
    "    // Jump to the requested tab after first frame\n"
    "    if (widget.initialTab != null || widget.initialTafsir != null) {\n"
    "      WidgetsBinding.instance.addPostFrameCallback((_) {\n"
    "        if (mounted) _tabController.animateTo(widget.initialTab ?? 1);\n"
    "      });\n"
    "    }",
    "    // Tab jump is scheduled in _loadAllData once data is ready",
    "remove premature tab jump from initState")

# 1b. After setState({ _loading = false }) succeeds, schedule the tab jump
# The target block is the setState that sets _loading = false after data loads
ayah = patch(ayah,
    "      setState(() {\n"
    "        _surah = surahRes;\n"
    "        _verse = verseRes;\n"
    "        _topics = List<Map<String, dynamic>>.from(tagRes);\n"
    "        _isBookmarked = isBookmarked;\n"
    "        _loading = false;\n"
    "      });",
    "      setState(() {\n"
    "        _surah = surahRes;\n"
    "        _verse = verseRes;\n"
    "        _topics = List<Map<String, dynamic>>.from(tagRes);\n"
    "        _isBookmarked = isBookmarked;\n"
    "        _loading = false;\n"
    "      });\n"
    "      // Jump to the requested tab NOW that the TabBar is rendered\n"
    "      if (mounted && (widget.initialTab != null || widget.initialTafsir != null)) {\n"
    "        WidgetsBinding.instance.addPostFrameCallback((_) {\n"
    "          if (mounted) _tabController.animateTo(widget.initialTab ?? 1);\n"
    "        });\n"
    "      }",
    "tab jump after data loaded")

# 1c. Also handle didUpdateWidget for the same tab (when same widget is reused by GoRouter)
ayah = patch(ayah,
    "    if (oldWidget.surahId != widget.surahId || oldWidget.ayahNumber != widget.ayahNumber) {\n"
    "      _selectedSurahId = widget.surahId;\n"
    "      _ayahController.text = widget.ayahNumber.toString();\n"
    "      _isPlaying = false;\n"
    "      _audioPlayer.stop();\n"
    "      _loadAllData();\n"
    "    }",
    "    if (oldWidget.surahId != widget.surahId ||\n"
    "        oldWidget.ayahNumber != widget.ayahNumber ||\n"
    "        oldWidget.initialTafsir != widget.initialTafsir ||\n"
    "        oldWidget.initialTab != widget.initialTab) {\n"
    "      _selectedSurahId = widget.surahId;\n"
    "      _ayahController.text = widget.ayahNumber.toString();\n"
    "      _isPlaying = false;\n"
    "      _audioPlayer.stop();\n"
    "      // Reset so _buildSlots re-applies the new initialTafsir\n"
    "      _initialSourceApplied = false;\n"
    "      _loadAllData();\n"
    "    }",
    "didUpdateWidget handles initialTafsir changes")

write(ayah_file, ayah, enc)
print(f'  Saved ({len(ayah)} bytes)')

# ─────────────────────────────────────────────────────────────────────────────
# 2. search_screen.dart – auto-retry once on 57014
# ─────────────────────────────────────────────────────────────────────────────
print('\n=== search_screen.dart ===')
search_file = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\search\search_screen.dart'
search, enc_s = read(search_file)

# Wrap _performKeywordSearch call in auto-retry for 57014
search = patch(search,
    "    try {\n"
    "      if (_searchMode == 'semantic') {\n"
    "        await _performSemanticSearch(query);\n"
    "      } else {\n"
    "        await _performKeywordSearch(query);\n"
    "      }\n"
    "    } catch (e) {\n"
    "      setState(() => _error = e.toString());\n"
    "    } finally {\n"
    "      setState(() => _loading = false);\n"
    "    }",
    "    int _attempts = 0;\n"
    "    while (true) {\n"
    "      try {\n"
    "        if (_searchMode == 'semantic') {\n"
    "          await _performSemanticSearch(query);\n"
    "        } else {\n"
    "          await _performKeywordSearch(query);\n"
    "        }\n"
    "        break; // success\n"
    "      } catch (e) {\n"
    "        final isTimeout = e.toString().contains('57014') ||\n"
    "            e.toString().contains('statement timeout') ||\n"
    "            e.toString().contains('query_canceled');\n"
    "        if (isTimeout && _attempts < 1) {\n"
    "          _attempts++;\n"
    "          // Brief pause before retry\n"
    "          await Future.delayed(const Duration(milliseconds: 600));\n"
    "          continue;\n"
    "        }\n"
    "        setState(() => _error = isTimeout\n"
    "            ? 'Search timed out. Please try again or narrow your query.'\n"
    "            : e.toString());\n"
    "        break;\n"
    "      } finally {\n"
    "        if (!(_loading)) break; // already cleared\n"
    "      }\n"
    "    }\n"
    "    setState(() => _loading = false);",
    "auto-retry on 57014 statement timeout")

write(search_file, search, enc_s)
print(f'  Saved ({len(search)} bytes)')

print('\n=== Done ===')
