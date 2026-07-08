import re

# ─── 1. Fix mushaf_screen.dart ────────────────────────────────────────────────
mushaf_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(mushaf_path, 'rb') as f:
    raw = f.read()
try:
    text = raw.decode('utf-8'); enc = 'utf-8'
except UnicodeDecodeError:
    text = raw.decode('latin-1'); enc = 'latin-1'

# --- 1a. Disable auto-hide timer for study panel menu ---
old_timer = """  void _startStudyMenuCollapseTimer() {
    _studyMenuCollapseTimer?.cancel();
    _studyMenuCollapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _studyPanelOpen && _studyMenuBarVisible) {
        setState(() {
          _studyMenuBarVisible = false;
        });
      }
    });
  }"""

new_timer = """  void _startStudyMenuCollapseTimer() {
    // Disable auto-hide of study panel menu entirely to keep it visible
    _studyMenuCollapseTimer?.cancel();
  }"""

if old_timer in text:
    text = text.replace(old_timer, new_timer, 1)
    print("Disabled study menu collapse timer")
else:
    # Try alternate spacing
    alt_timer = """  void _startStudyMenuCollapseTimer() {
    _studyMenuCollapseTimer?.cancel();
    _studyMenuCollapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _studyPanelOpen && _studyMenuBarVisible) {
        setState(() {
          _studyMenuBarVisible = false;
        });
      }
    });
  }"""
    # Clean whitespace and try to find it
    print("Timer not replaced directly, searching with regex...")
    text, count = re.subn(
        r"void _startStudyMenuCollapseTimer\(\)\s*\{.*?\}",
        "void _startStudyMenuCollapseTimer() {\n    _studyMenuCollapseTimer?.cancel();\n  }",
        text,
        flags=re.DOTALL
    )
    print(f"Replaced timer via regex: {count} matches")

# --- 1b. Fix toggle icon to chrome_reader_mode_outlined ---
old_icon = """                          _studyPanelOpen ? Icons.expand_more : Icons.menu_book_outlined,"""
new_icon = """                          _studyPanelOpen ? Icons.expand_more : Icons.chrome_reader_mode_outlined,"""

if old_icon in text:
    text = text.replace(old_icon, new_icon, 1)
    print("Updated toggle icon to chrome_reader_mode_outlined")
else:
    text, count = re.subn(
        r"_studyPanelOpen \? Icons\.expand_more : Icons\.menu_book_outlined",
        "_studyPanelOpen ? Icons.expand_more : Icons.chrome_reader_mode_outlined",
        text
    )
    print(f"Updated toggle icon via regex: {count} matches")

# --- 1c. Fix bottom padding when study panel is closed ---
# It should be showStudyPanel ? 280.0 : 20.0 (no extra padding when menus visible)
old_padding = """                            // Fixed padding when study panel is open — avoids blank space on menu-bar auto-hide
                            bottom: showStudyPanel ? 280.0 : (_menusVisible ? 90.0 : 20.0),"""
new_padding = """                            // Fixed padding when study panel is open — avoids blank space on menu-bar auto-hide
                            bottom: showStudyPanel ? 280.0 : 20.0,"""

if old_padding in text:
    text = text.replace(old_padding, new_padding, 1)
    print("Updated bottom padding to showStudyPanel ? 280.0 : 20.0")
else:
    text, count = re.subn(
        r"bottom: showStudyPanel \? 280\.0 : \(_menusVisible \? 90\.0 : 20\.0\)",
        "bottom: showStudyPanel ? 280.0 : 20.0",
        text
    )
    print(f"Updated bottom padding via regex: {count} matches")

with open(mushaf_path, 'wb') as f:
    f.write(text.encode(enc))
print("Saved mushaf_screen.dart.\n")

# ─── 2. Fix ayah_detail_screen.dart ───────────────────────────────────────────
ayah_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(ayah_path, 'rb') as f:
    raw = f.read()
try:
    text2 = raw.decode('utf-8'); enc2 = 'utf-8'
except UnicodeDecodeError:
    text2 = raw.decode('latin-1'); enc2 = 'latin-1'

# --- 2a. Update _loadAllData tab jump to call setState ---
old_load_tab = """      // Jump to the requested tab NOW that the TabBar is rendered.
      // Use direct index assignment (no animation) so it's instant and reliable.
      if (mounted && (widget.initialTab != null || widget.initialTafsir != null)) {
        final targetTab = widget.initialTab ?? 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabController.index != targetTab) {
            _tabController.index = targetTab;
          }
        });
      }"""

new_load_tab = """      // Jump to the requested tab NOW that the TabBar is rendered.
      // Use direct index assignment within setState so TabBar/TabBarView are fully synchronized.
      if (mounted && (widget.initialTab != null || widget.initialTafsir != null)) {
        final targetTab = widget.initialTab ?? 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _tabController.index = targetTab;
            });
          }
        });
      }"""

if old_load_tab in text2:
    text2 = text2.replace(old_load_tab, new_load_tab, 1)
    print("Updated _loadAllData tab jump with setState")
else:
    text2, count = re.subn(
        r"// Jump to the requested tab NOW that the TabBar is rendered\..*?_tabController\.index = targetTab;\s*\}\s*\}\);\s*\}",
        new_load_tab,
        text2,
        flags=re.DOTALL
    )
    print(f"Updated _loadAllData tab jump via regex: {count} matches")

# --- 2b. Update didUpdateWidget tab jump to call setState ---
old_did_tab = """      // Immediately switch to the requested tab BEFORE data reload
      // Use direct assignment so there's no animation delay or missed frame
      if (widget.initialTab != null) {
        final targetTab = widget.initialTab!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabController.index != targetTab) {
            _tabController.index = targetTab;
          }
        });
      }"""

new_did_tab = """      // Immediately switch to the requested tab BEFORE data reload
      // Use direct assignment within setState so there's no synchronization delay
      if (widget.initialTab != null) {
        final targetTab = widget.initialTab!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _tabController.index = targetTab;
            });
          }
        });
      }"""

if old_did_tab in text2:
    text2 = text2.replace(old_did_tab, new_did_tab, 1)
    print("Updated didUpdateWidget tab jump with setState")
else:
    text2, count = re.subn(
        r"// Immediately switch to the requested tab BEFORE data reload.*?_tabController\.index = targetTab;\s*\}\s*\}\);\s*\}",
        new_did_tab,
        text2,
        flags=re.DOTALL
    )
    print(f"Updated didUpdateWidget tab jump via regex: {count} matches")

with open(ayah_path, 'wb') as f:
    f.write(text2.encode(enc2))
print("Saved ayah_detail_screen.dart.\n")
print("All patches completed successfully!")
