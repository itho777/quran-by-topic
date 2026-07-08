import os

ayah_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(ayah_file, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Update initState
old_init = """    final startTab = widget.initialTab ?? (widget.initialTafsir != null ? 1 : 0);
    _tabController = TabController(length: 5, vsync: this, initialIndex: startTab);"""

new_init = """    // Always start at index 0 initially so programmatically animating to targetTab triggers updates correctly
    _tabController = TabController(length: 5, vsync: this, initialIndex: 0);"""

if old_init in text:
    text = text.replace(old_init, new_init, 1)
    print("Init state updated successfully")
else:
    print("WARNING: init target not found!")

# 2. Update didUpdateWidget tab jump
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

if old_did_tab in text:
    text = text.replace(old_did_tab, new_did_tab, 1)
    print("didUpdateWidget tab jump updated successfully")
else:
    print("WARNING: didUpdateWidget tab jump target not found!")

# 3. Update _loadAllData tab jump
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

if old_load_tab in text:
    text = text.replace(old_load_tab, new_load_tab, 1)
    print("_loadAllData tab jump updated successfully")
else:
    print("WARNING: _loadAllData tab jump target not found!")

with open(ayah_file, 'w', encoding='utf-8') as f:
    f.write(text)
print("Done.")
