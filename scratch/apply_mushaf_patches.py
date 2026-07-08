import re

file_path = r'C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart'

with open(file_path, 'rb') as f:
    raw = f.read()

try:
    content = raw.decode('utf-8')
    enc = 'utf-8'
except UnicodeDecodeError:
    content = raw.decode('latin-1')
    enc = 'latin-1'

# Normalize to LF
content = content.replace('\r\n', '\n')

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
    
    if not pattern_clean:
        print(f"  [ERROR] Pattern for {label} is empty!")
        return text
        
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

# Match the scroll open block exactly as it is now
old_scroll = """
    if (!_studyPanelOpen) {
      setState(() {
        _studyPanelOpen = true;
      });
    }
"""
new_scroll = """
    if (!_studyPanelOpen || !_studyMenuBarVisible) {
      setState(() {
        _studyPanelOpen = true;
        _studyMenuBarVisible = true;
        _startStudyMenuCollapseTimer();
      });
    }
"""
content = patch_flexible(content, old_scroll, new_scroll, "_scrollToActiveVerse open study panel")

with open(file_path, 'wb') as f:
    f.write(content.encode(enc))

print("Completed scroll patch.")
