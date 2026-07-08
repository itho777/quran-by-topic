import re

# ─── Fix 1: mushaf_screen.dart ────────────────────────────────────────────────
mushaf_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(mushaf_path, 'rb') as f:
    raw = f.read()
try:
    text = raw.decode('utf-8'); enc = 'utf-8'
except UnicodeDecodeError:
    text = raw.decode('latin-1'); enc = 'latin-1'

# --- Fix 1a: _onImageTapped - remove _studyPanelOpen = true ---
old1a = """        setState(() {

          _studyPanelOpen = true;

          _menusVisible = true;

        });

        ref.read(hideNavBarProvider.notifier).state = false;

        _selectVerse(match);\n"""
new1a = """        // Study panel is only manually toggled — do NOT open on verse tap
        setState(() {
          _menusVisible = true;
        });
        ref.read(hideNavBarProvider.notifier).state = false;
        _selectVerse(match);\n"""

if old1a in text:
    text = text.replace(old1a, new1a, 1)
    print("[1a] Removed _studyPanelOpen=true from _onImageTapped")
else:
    print("[1a] WARNING: _onImageTapped target not found!")

# --- Fix 1b: _onVerseSelectedBySurahAyah - remove _studyPanelOpen = true ---
old1b = """      setState(() {

        _studyPanelOpen = true;

        _menusVisible = true;

      });

      ref.read(hideNavBarProvider.notifier).state = false;

      _selectVerse(match);

    }\n"""
new1b = """      // Study panel is only manually toggled — do NOT open on verse select
      setState(() {
        _menusVisible = true;
      });
      ref.read(hideNavBarProvider.notifier).state = false;
      _selectVerse(match);

    }\n"""

if old1b in text:
    text = text.replace(old1b, new1b, 1)
    print("[1b] Removed _studyPanelOpen=true from _onVerseSelectedBySurahAyah")
else:
    print("[1b] WARNING: _onVerseSelectedBySurahAyah target not found!")

# --- Fix 1c: Fix bottom padding - don't change based on _studyMenuBarVisible ---
old1c = "                            bottom: showStudyPanel\n                                ? (_studyMenuBarVisible ? 280.0 : 230.0)\n                                : (_menusVisible ? 90.0 : 20.0),"
new1c = "                            // Fixed padding when study panel is open — avoids blank space on menu-bar auto-hide\n                            bottom: showStudyPanel ? 280.0 : (_menusVisible ? 90.0 : 20.0),"

if old1c in text:
    text = text.replace(old1c, new1c, 1)
    print("[1c] Fixed bottom padding to not depend on _studyMenuBarVisible")
else:
    print("[1c] WARNING: bottom padding target not found!")

with open(mushaf_path, 'wb') as f:
    f.write(text.encode(enc))
print("mushaf_screen.dart saved.\n")

# ─── Fix 2: ayah_detail_screen.dart ───────────────────────────────────────────
ayah_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(ayah_path, 'rb') as f:
    raw = f.read()
try:
    text2 = raw.decode('utf-8'); enc2 = 'utf-8'
except UnicodeDecodeError:
    text2 = raw.decode('latin-1'); enc2 = 'latin-1'

# --- Fix 2a: Make tab jump in _loadAllData use direct index assignment (not animateTo) ---
old2a = """      // Jump to the requested tab NOW that the TabBar is rendered
      if (mounted && (widget.initialTab != null || widget.initialTafsir != null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tabController.animateTo(widget.initialTab ?? 1);
        });
      }"""
new2a = """      // Jump to the requested tab NOW that the TabBar is rendered.
      // Use direct index assignment (no animation) so it's instant and reliable.
      if (mounted && (widget.initialTab != null || widget.initialTafsir != null)) {
        final targetTab = widget.initialTab ?? 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabController.index != targetTab) {
            _tabController.index = targetTab;
          }
        });
      }"""

if old2a in text2:
    text2 = text2.replace(old2a, new2a, 1)
    print("[2a] Fixed _loadAllData tab jump to use direct index assignment")
else:
    print("[2a] WARNING: _loadAllData animateTo target not found!")

# --- Fix 2b: In didUpdateWidget, also use direct index assignment ---
old2b = """      // Immediately switch to the requested tab before data reload
      if (widget.initialTab != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tabController.animateTo(widget.initialTab!);
        });
      }"""
new2b = """      // Immediately switch to the requested tab BEFORE data reload
      // Use direct assignment so there's no animation delay or missed frame
      if (widget.initialTab != null) {
        final targetTab = widget.initialTab!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabController.index != targetTab) {
            _tabController.index = targetTab;
          }
        });
      }"""

if old2b in text2:
    text2 = text2.replace(old2b, new2b, 1)
    print("[2b] Fixed didUpdateWidget tab jump to use direct index assignment")
else:
    print("[2b] WARNING: didUpdateWidget animateTo target not found!")

with open(ayah_path, 'wb') as f:
    f.write(text2.encode(enc2))
print("ayah_detail_screen.dart saved.\n")
print("All patches done!")
