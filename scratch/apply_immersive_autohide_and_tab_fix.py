import re

mushaf_file = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart'
ayah_file = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart'

# ─────────────────────────────────────────────────────────────────────────────
# 1. mushaf_screen.dart - Immersive Auto-hide & Padding adjustments
# ─────────────────────────────────────────────────────────────────────────────
with open(mushaf_file, 'rb') as f:
    raw = f.read()
try:
    mushaf = raw.decode('utf-8')
    enc_m = 'utf-8'
except UnicodeDecodeError:
    mushaf = raw.decode('latin-1')
    enc_m = 'latin-1'

mushaf = mushaf.replace('\r\n', '\n')

def patch_flexible(text, old_pattern, new_replacement, label):
    lines = text.split('\n')
    def get_clean_indices(lines_list):
        cleaned = []
        indices = []
        for i, l in enumerate(lines_list):
            s = l.strip()
            if s:
                cleaned.append(s)
                indices.append(i)
        return cleaned, indices
    text_clean, text_indices = get_clean_indices(lines)
    pattern_clean, _ = get_clean_indices(old_pattern.split('\n'))
    
    match_idx = -1
    for i in range(len(text_clean) - len(pattern_clean) + 1):
        if text_clean[i:i+len(pattern_clean)] == pattern_clean:
            match_idx = i
            break
    if match_idx != -1:
        start_line_idx = text_indices[match_idx]
        end_line_idx = text_indices[match_idx + len(pattern_clean) - 1]
        print(f"  [OK] {label} matched lines {start_line_idx+1} to {end_line_idx+1}")
        before = '\n'.join(lines[:start_line_idx])
        after = '\n'.join(lines[end_line_idx + 1:])
        return before + '\n' + new_replacement + '\n' + after
    else:
        print(f"  [!!] NOT FOUND: {label}")
        return text

# 1a. Update showStudyPanel definition to include _menusVisible
old_show_panel = """
    final mediaQuery = MediaQuery.of(context);
    final isMobileLandscape = mediaQuery.orientation == Orientation.landscape && mediaQuery.size.shortestSide < 600;
    final showStudyPanel = _studyPanelOpen && !isMobileLandscape;
"""
new_show_panel = """
    final mediaQuery = MediaQuery.of(context);
    final isMobileLandscape = mediaQuery.orientation == Orientation.landscape && mediaQuery.size.shortestSide < 600;
    final showStudyPanel = _studyPanelOpen && !isMobileLandscape && _menusVisible;
"""
mushaf = patch_flexible(mushaf, old_show_panel, new_show_panel, "showStudyPanel definition update")

# 1b. Update AnimatedPadding bottom value
old_padding = """
                          padding: EdgeInsets.only(
                            top: _menusVisible ? 90.0 : 0.0,
                            bottom: showStudyPanel ? 300.0 : (_menusVisible ? 90.0 : 20.0),
                          ),
"""
new_padding = """
                          padding: EdgeInsets.only(
                            top: _menusVisible ? 90.0 : 0.0,
                            bottom: showStudyPanel
                                ? (_studyMenuBarVisible ? 280.0 : 230.0)
                                : (_menusVisible ? 90.0 : 20.0),
                          ),
"""
mushaf = patch_flexible(mushaf, old_padding, new_padding, "AnimatedPadding bottom adjustment")

with open(mushaf_file, 'wb') as f:
    f.write(mushaf.encode(enc_m))
print(f"Saved {mushaf_file}")


# ─────────────────────────────────────────────────────────────────────────────
# 2. ayah_detail_screen.dart - TabController initialIndex fix
# ─────────────────────────────────────────────────────────────────────────────
with open(ayah_file, 'rb') as f:
    raw = f.read()
try:
    ayah = raw.decode('utf-8')
    enc_a = 'utf-8'
except UnicodeDecodeError:
    ayah = raw.decode('latin-1')
    enc_a = 'latin-1'

ayah = ayah.replace('\r\n', '\n')

old_tab_init = """
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
"""
new_tab_init = """
  @override
  void initState() {
    super.initState();
    final startTab = widget.initialTab ?? (widget.initialTafsir != null ? 1 : 0);
    _tabController = TabController(length: 5, vsync: this, initialIndex: startTab);
"""
ayah = patch_flexible(ayah, old_tab_init, new_tab_init, "TabController initialIndex initialization")

with open(ayah_file, 'wb') as f:
    f.write(ayah.encode(enc_a))
print(f"Saved {ayah_file}")

print("Completed all patches.")
