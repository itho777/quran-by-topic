import os

file_path = r"C:\Users\waverider\AppData\Local\Temp\tafseer_id_mushaf_tmp" # we can write directly to the file
# Wait, let's write to target file directly:
target_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(target_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _scrollToActiveVerse with the clean version
old_scroll = """  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {

    // Open study panel if needed

    if (!_studyPanelOpen) {

      setState(() {

        _studyPanelOpen = true;

        _studyMenuBarVisible = true;

        _startStudyMenuCollapseTimer();

      });

    }



    final idx = _pageVerses.indexWhere((v) => v['id'] == vId);

    if (idx < 0) return;"""

new_scroll = """  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {
    // Open study panel if needed
    if (!_studyPanelOpen) {
      setState(() {
        _studyPanelOpen = true;
      });
    }

    final idx = _pageVerses.indexWhere((v) => v['id'] == vId);
    if (idx < 0) return;"""

# Do the replacement
if old_scroll in content:
    content = content.replace(old_scroll, new_scroll)
    print("Replaced with LF style")
else:
    # Try normalising line endings and replacing
    content_normalised = content.replace('\r\n', '\n')
    old_scroll_normalised = old_scroll.replace('\r\n', '\n')
    new_scroll_normalised = new_scroll.replace('\r\n', '\n')
    if old_scroll_normalised in content_normalised:
        content_normalised = content_normalised.replace(old_scroll_normalised, new_scroll_normalised)
        content = content_normalised
        print("Replaced with normalised style")
    else:
        # Let's find _scrollToActiveVerse and print context to see what is there
        idx = content.find("_scrollToActiveVerse")
        if idx != -1:
            print("Found _scrollToActiveVerse but exact match failed. Context:")
            print(repr(content[idx:idx+400]))
        else:
            print("_scrollToActiveVerse not found")

with open(target_file, 'w', encoding='utf-8') as f:
    f.write(content)

print("Finished writing file")
