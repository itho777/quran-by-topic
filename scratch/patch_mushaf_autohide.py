"""
Patch: Restore study menu bar auto-hide logic in mushaf_screen.dart
This version normalizes multiple consecutive newlines to single newlines
to ensure perfect pattern matching and clean up file formatting.
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
    # Normalize CRLF and double-newlines
    text = text.replace('\r\n', '\n')
    
    # We will collapse multiple empty lines to a single empty line,
    # but to match simple single newlines, let's replace all '\n\n' with '\n'
    # for the parts we patch. Or better: let's replace all double newlines in the file
    # with single newlines, which cleans up the formatting inconsistency completely!
    import re
    # Replace 2 or more newlines with a single newline to normalize the entire file.
    # Note: Dart formatting usually has single empty lines, but collapsing all double newlines
    # might remove spaces between classes/methods. Let's replace triple newlines and double newlines
    # with single empty lines, i.e., at most one blank line between code lines.
    # So '\n\n\n+' becomes '\n\n', and if there are multiple '\n\n', keep at most one.
    text = re.sub(r'\n\s*\n\s*\n+', '\n\n', text)
    text = re.sub(r'\n\s*\n+', '\n\n', text)
    
    return text, enc

def write(path, text, enc):
    # Ensure CRLF is used if that was the file standard, but standard LF is fine for Flutter/Dart.
    with open(path, 'wb') as f:
        f.write(text.encode(enc))

def patch(text, old, new, label):
    # Normalize whitespace in search pattern and target content for comparison
    def clean_space(s):
        return '\n'.join([line.strip() for line in s.split('\n') if line.strip()])
        
    old_clean = clean_space(old)
    
    # Let's do a sliding window search or partition-based search
    if old in text:
        print(f'  [OK] {label} (exact match)')
        return text.replace(old, new, 1)
        
    # If not exact match, let's try matching with normalized spaces (handling empty lines)
    # Let's split by double newlines or single newlines
    lines = text.split('\n')
    old_lines = [l.strip() for l in old.split('\n')]
    old_lines = [l for l in old_lines if l] # non-empty
    
    # Search for subsequence of lines
    match_start = -1
    for i in range(len(lines) - len(old_lines) + 1):
        match = True
        for j in range(len(old_lines)):
            if old_lines[j] not in lines[i+j]:
                match = False
                break
        if match:
            # Check if all lines match exactly when stripped
            sub = [lines[i+j].strip() for j in range(len(old_lines))]
            if sub == old_lines:
                match_start = i
                break
                
    if match_start != -1:
        print(f'  [OK] {label} (fuzzy match at line {match_start+1})')
        # Replace the range of lines
        before = '\n'.join(lines[:match_start])
        after = '\n'.join(lines[match_start + len(old_lines):])
        return before + '\n' + new + '\n' + after
        
    print(f'  [!!] NOT FOUND: {label}')
    return text

file_path = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart'
mushaf, enc = read(file_path)

# 1. State variable declarations
mushaf = patch(mushaf,
    "  bool _menusVisible = true;\n"
    "  bool _studyPanelOpen = true;\n"
    "  Timer? _menuCollapseTimer;",
    "  bool _menusVisible = true;\n"
    "  bool _studyPanelOpen = true;\n"
    "  Timer? _menuCollapseTimer;\n"
    "  bool _studyMenuBarVisible = true;\n"
    "  Timer? _studyMenuCollapseTimer;\n",
    "state variables for study auto-hide")

# 2. _scrollToActiveVerse (ensure study menu bar is open when scrolling to active verse)
mushaf = patch(mushaf,
    "    if (!_studyPanelOpen) {\n"
    "      setState(() => _studyPanelOpen = true);\n"
    "    }",
    "    if (!_studyPanelOpen || !_studyMenuBarVisible) {\n"
    "      setState(() {\n"
    "        _studyPanelOpen = true;\n"
    "        _studyMenuBarVisible = true;\n"
    "        _startStudyMenuCollapseTimer();\n"
    "      });\n"
    "    }",
    "_scrollToActiveVerse study menu bar open")

# 3. initState end (start the study menu collapse timer initially)
mushaf = patch(mushaf,
    "    // Start auto collapse timer for floating menus\n"
    "    _startMenuCollapseTimer();\n"
    "  }",
    "    // Start auto collapse timer for floating menus\n"
    "    _startMenuCollapseTimer();\n"
    "    _startStudyMenuCollapseTimer();\n"
    "  }",
    "initState auto collapse start")

# 4. dispose (cancel study menu collapse timer)
mushaf = patch(mushaf,
    "  @override\n"
    "  void dispose() {\n"
    "    _menuCollapseTimer?.cancel();",
    "  @override\n"
    "  void dispose() {\n"
    "    _menuCollapseTimer?.cancel();\n"
    "    _studyMenuCollapseTimer?.cancel();",
    "dispose timer cancel")

# 5. Timer helper methods: add _startStudyMenuCollapseTimer and _onStudyPanelInteraction, and update _onUserInteraction
mushaf = patch(mushaf,
    "  void _onUserInteraction() {\n"
    "    _startMenuCollapseTimer();\n"
    "    if (!_menusVisible) {\n"
    "      setState(() {\n"
    "        _menusVisible = true;\n"
    "      });\n"
    "      ref.read(hideNavBarProvider.notifier).state = false;\n"
    "    }\n"
    "  }",
    "  void _onUserInteraction() {\n"
    "    _startMenuCollapseTimer();\n"
    "    _startStudyMenuCollapseTimer();\n"
    "    if (!_menusVisible) {\n"
    "      setState(() {\n"
    "        _menusVisible = true;\n"
    "      });\n"
    "      ref.read(hideNavBarProvider.notifier).state = false;\n"
    "    }\n"
    "    if (!_studyMenuBarVisible) {\n"
    "      setState(() {\n"
    "        _studyMenuBarVisible = true;\n"
    "      });\n"
    "    }\n"
    "  }\n"
    "\n"
    "  void _startStudyMenuCollapseTimer() {\n"
    "    _studyMenuCollapseTimer?.cancel();\n"
    "    _studyMenuCollapseTimer = Timer(const Duration(seconds: 3), () {\n"
    "      if (mounted && _studyPanelOpen && _studyMenuBarVisible) {\n"
    "        setState(() {\n"
    "          _studyMenuBarVisible = false;\n"
    "        });\n"
    "      }\n"
    "    });\n"
    "  }\n"
    "\n"
    "  void _onStudyPanelInteraction() {\n"
    "    _startStudyMenuCollapseTimer();\n"
    "    if (!_studyMenuBarVisible) {\n"
    "      setState(() {\n"
    "        _studyMenuBarVisible = true;\n"
    "      });\n"
    "    }\n"
    "  }",
    "auto-hide helper methods")

# 6. Change study panel Container inside AnimatedPositioned to AnimatedContainer with dynamic height
mushaf = patch(mushaf,
    "          // ── Slide-Up Study Panel (Bottom) ───────────────────────────────\n"
    "          AnimatedPositioned(\n"
    "            duration: const Duration(milliseconds: 300),\n"
    "            curve: Curves.easeInOut,\n"
    "            bottom: showStudyPanel ? 0 : -320,\n"
    "            left: 0,\n"
    "            right: 0,\n"
    "            child: Container(\n"
    "              height: 270,",
    "          // ── Slide-Up Study Panel (Bottom) ───────────────────────────────\n"
    "          AnimatedPositioned(\n"
    "            duration: const Duration(milliseconds: 300),\n"
    "            curve: Curves.easeInOut,\n"
    "            bottom: showStudyPanel ? 0 : -320,\n"
    "            left: 0,\n"
    "            right: 0,\n"
    "            child: AnimatedContainer(\n"
    "              duration: const Duration(milliseconds: 250),\n"
    "              curve: Curves.easeInOut,\n"
    "              height: _studyMenuBarVisible ? 270.0 : 220.0,",
    "study panel outer AnimatedContainer")

# 7. Change Tab Navigation & Action Bar Container to AnimatedContainer with dynamic height
mushaf = patch(mushaf,
    "                  // Tab Navigation & Action Bar\n"
    "                  Container(\n"
    "                    height: 50,\n"
    "                    padding: const EdgeInsets.symmetric(horizontal: 16),\n"
    "                    decoration: BoxDecoration(\n"
    "                      border: Border(bottom: BorderSide(color: AppTheme.outlineVariant, width: 0.5)),\n"
    "                    ),",
    "                  // Tab Navigation & Action Bar\n"
    "                  AnimatedContainer(\n"
    "                    duration: const Duration(milliseconds: 250),\n"
    "                    curve: Curves.easeInOut,\n"
    "                    height: _studyMenuBarVisible ? 50.0 : 0.0,\n"
    "                    clipBehavior: Clip.antiAlias,\n"
    "                    padding: const EdgeInsets.symmetric(horizontal: 16),\n"
    "                    decoration: BoxDecoration(\n"
    "                      border: Border(bottom: BorderSide(\n"
    "                        color: _studyMenuBarVisible ? AppTheme.outlineVariant : Colors.transparent,\n"
    "                        width: 0.5,\n"
    "                      )),\n"
    "                    ),",
    "study panel header AnimatedContainer")

# 8. Update ChoiceChip tap handler to call _onStudyPanelInteraction
mushaf = patch(mushaf,
    "                                    onSelected: (sel) async {\n"
    "                                      if (sel) {\n"
    "                                        setState(() => _studyContentTab = tab);\n"
    "                                        await _loadPageTexts();\n"
    "                                      }\n"
    "                                    },",
    "                                    onSelected: (sel) async {\n"
    "                                      if (sel) {\n"
    "                                        _onStudyPanelInteraction();\n"
    "                                        setState(() => _studyContentTab = tab);\n"
    "                                        await _loadPageTexts();\n"
    "                                      }\n"
    "                                    },",
    "ChoiceChip tab selection tap")

# 9. Update source picker button tap handler
mushaf = patch(mushaf,
    "                        IconButton(\n"
    "                          icon: Icon(Icons.swap_horiz, size: 18, color: AppTheme.primary),\n"
    "                          tooltip: _currentLang == 'en' ? 'Switch source' : 'Ganti sumber',\n"
    "                          onPressed: _showSourcePicker,\n"
    "                        ),",
    "                        IconButton(\n"
    "                          icon: Icon(Icons.swap_horiz, size: 18, color: AppTheme.primary),\n"
    "                          tooltip: _currentLang == 'en' ? 'Switch source' : 'Ganti sumber',\n"
    "                          onPressed: () {\n"
    "                            _onStudyPanelInteraction();\n"
    "                            _showSourcePicker();\n"
    "                          },\n"
    "                        ),",
    "Source selector tap")

# 10. Update adjust font size button tap handler
mushaf = patch(mushaf,
    "                        IconButton(\n"
    "                          icon: Icon(Icons.format_size, size: 18, color: AppTheme.primary),\n"
    "                          onPressed: () {\n"
    "                            showModalBottomSheet(",
    "                        IconButton(\n"
    "                          icon: Icon(Icons.format_size, size: 18, color: AppTheme.primary),\n"
    "                          onPressed: () {\n"
    "                            _onStudyPanelInteraction();\n"
    "                            showModalBottomSheet(",
    "Adjust font size tap")

# 11. Update study panel content ListView listener to trigger _onStudyPanelInteraction
mushaf = patch(mushaf,
    "                  Expanded(\n"
    "                    child: _loading\n"
    "                        ? Center(child: CircularProgressIndicator(color: AppTheme.primary))\n"
    "                        : Listener(\n"
    "                            onPointerDown: (_) => _onUserInteraction(),\n"
    "                            child: ListView.builder(",
    "                  Expanded(\n"
    "                    child: _loading\n"
    "                        ? Center(child: CircularProgressIndicator(color: AppTheme.primary))\n"
    "                        : Listener(\n"
    "                            onPointerDown: (_) {\n"
    "                              _onUserInteraction();\n"
    "                              _onStudyPanelInteraction();\n"
    "                            },\n"
    "                            child: ListView.builder(",
    "ListView drag listener update")

write(file_path, mushaf, enc)
print('Finished.')
