import re

# ─── 1. Update mushaf_screen.dart ─────────────────────────────────────────────
mushaf_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(mushaf_path, 'rb') as f:
    raw = f.read()
try:
    text = raw.decode('utf-8'); enc = 'utf-8'
except UnicodeDecodeError:
    text = raw.decode('latin-1'); enc = 'latin-1'

# Restore the start study menu collapse timer to its auto-hiding behavior
old_timer = """  void _startStudyMenuCollapseTimer() {
    // Disable auto-hide of study panel menu entirely to keep it visible
    _studyMenuCollapseTimer?.cancel();
  }"""

new_timer = """  void _startStudyMenuCollapseTimer() {
    _studyMenuCollapseTimer?.cancel();
    _studyMenuCollapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _studyPanelOpen && _studyMenuBarVisible) {
        setState(() {
          _studyMenuBarVisible = false;
        });
      }
    });
  }"""

if old_timer in text:
    text = text.replace(old_timer, new_timer, 1)
    print("Restored study menu collapse timer")
else:
    print("WARNING: Target timer block not found!")

# Update bottom padding of mushaf image to dynamically resize when menu hides
old_padding = """                            // Fixed padding when study panel is open — avoids blank space on menu-bar auto-hide
                            bottom: showStudyPanel ? 280.0 : 20.0,"""

new_padding = """                            // Fixed padding when study panel is open — avoids blank space on menu-bar auto-hide
                            bottom: showStudyPanel
                                ? (_studyMenuBarVisible ? 280.0 : 230.0)
                                : 20.0,"""

if old_padding in text:
    text = text.replace(old_padding, new_padding, 1)
    print("Updated bottom padding to showStudyPanel ? (_studyMenuBarVisible ? 280.0 : 230.0) : 20.0")
else:
    print("WARNING: Bottom padding target block not found!")

with open(mushaf_path, 'wb') as f:
    f.write(text.encode(enc))
print("Saved mushaf_screen.dart.\n")

# ─── 2. Update ayah_detail_screen.dart ────────────────────────────────────────
ayah_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(ayah_path, 'rb') as f:
    raw2 = f.read()
try:
    text2 = raw2.decode('utf-8'); enc2 = 'utf-8'
except UnicodeDecodeError:
    text2 = raw2.decode('latin-1'); enc2 = 'latin-1'

# --- 2a. Initialize TabController with initialIndex: 0 in initState ---
old_init = """    final startTab = widget.initialTab ?? (widget.initialTafsir != null ? 1 : 0);
    _tabController = TabController(length: 5, vsync: this, initialIndex: startTab);"""

new_init = """    // Always start at index 0 initially so programmatically animating to targetTab triggers updates correctly
    _tabController = TabController(length: 5, vsync: this, initialIndex: 0);"""

if old_init in text2:
    text2 = text2.replace(old_init, new_init, 1)
    print("Updated initState to initialize TabController at index 0")
else:
    print("WARNING: initState TabController initialization target not found!")

# --- 2b. Update _loadAllData tab jump to animateTo targetTab ---
old_load_tab = """      // Jump to the requested tab NOW that the TabBar is rendered.
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

new_load_tab = """      // Jump to the requested tab NOW that the TabBar is rendered.
      // Use animateTo to cleanly transition and synchronize both TabBar and TabBarView.
      if (mounted && (widget.initialTab != null || widget.initialTafsir != null)) {
        final targetTab = widget.initialTab ?? 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tabController.animateTo(targetTab);
          }
        });
      }"""

if old_load_tab in text2:
    text2 = text2.replace(old_load_tab, new_load_tab, 1)
    print("Updated _loadAllData tab jump to use animateTo")
else:
    print("WARNING: _loadAllData tab jump target not found!")

# --- 2c. Update didUpdateWidget tab jump to animateTo targetTab ---
old_did_tab = """      // Immediately switch to the requested tab BEFORE data reload
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

new_did_tab = """      // Immediately switch to the requested tab BEFORE data reload
      // Use animateTo to transition and synchronize both TabBar and TabBarView.
      if (widget.initialTab != null) {
        final targetTab = widget.initialTab!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tabController.animateTo(targetTab);
          }
        });
      }"""

if old_did_tab in text2:
    text2 = text2.replace(old_did_tab, new_did_tab, 1)
    print("Updated didUpdateWidget tab jump to use animateTo")
else:
    print("WARNING: didUpdateWidget tab jump target not found!")

with open(ayah_path, 'wb') as f:
    f.write(text2.encode(enc2))
print("Saved ayah_detail_screen.dart.\n")
print("All updates applied successfully!")
