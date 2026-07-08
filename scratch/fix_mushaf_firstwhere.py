"""
Fix mushaf_screen.dart:
1. Info button navigation - add orElse to firstWhere, add _pageVerses.isNotEmpty guard
2. _copyActiveAyah - add orElse to firstWhere
"""

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(file_path, 'rb') as f:
    raw = f.read()

was_crlf = b'\r\n' in raw
text = raw.decode('latin-1').replace('\r\n', '\n')

# ---- 1. Fix info button navigation ----
old_info = """\
                        onPressed: () async {
                          if (_selectedVerseId != null) {
                            final current = _pageVerses.firstWhere((v) => v['id'] == _selectedVerseId);
                            ref.read(hideNavBarProvider.notifier).state = false;
                            await context.push('/surahs/${current['sura_id']}/ayahs/${current['ayah_number']}');
                            if (mounted) {
                              ref.read(hideNavBarProvider.notifier).state = true;
                            }
                          }
                        },"""

new_info = """\
                        onPressed: () async {
                          if (_selectedVerseId != null && _pageVerses.isNotEmpty) {
                            final current = _pageVerses.firstWhere(
                              (v) => v['id'] == _selectedVerseId,
                              orElse: () => _pageVerses.first,
                            );
                            final surahId = current['sura_id'];
                            final ayahNum = current['ayah_number'];
                            if (surahId == null || ayahNum == null) return;
                            ref.read(hideNavBarProvider.notifier).state = false;
                            await context.push('/surahs/$surahId/ayahs/$ayahNum');
                            if (mounted) {
                              ref.read(hideNavBarProvider.notifier).state = true;
                            }
                          }
                        },"""

if old_info in text:
    text = text.replace(old_info, new_info)
    print("INFO BUTTON: fixed")
else:
    print("INFO BUTTON: pattern not found, trying partial match...")
    # Show surrounding context
    idx = text.find("firstWhere((v) => v['id'] == _selectedVerseId)")
    if idx >= 0:
        print(repr(text[idx-200:idx+300]))

# ---- 2. Fix _copyActiveAyah firstWhere ----
old_copy = """\
  void _copyActiveAyah() {
    if (_selectedVerseId == null) return;
    final current = _pageVerses.firstWhere((v) => v['id'] == _selectedVerseId);"""

new_copy = """\
  void _copyActiveAyah() {
    if (_selectedVerseId == null || _pageVerses.isEmpty) return;
    final current = _pageVerses.firstWhere(
      (v) => v['id'] == _selectedVerseId,
      orElse: () => _pageVerses.first,
    );"""

if old_copy in text:
    text = text.replace(old_copy, new_copy)
    print("COPY AYAH: fixed")
else:
    print("COPY AYAH: pattern not found")
    idx = text.find("_copyActiveAyah")
    if idx >= 0:
        print(repr(text[idx:idx+300]))

if was_crlf:
    text = text.replace('\n', '\r\n')

with open(file_path, 'wb') as f:
    f.write(text.encode('latin-1'))

print("Done.")
