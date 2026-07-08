import os

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(file_path, 'r', encoding='latin-1') as f:
    content = f.read()

# Replace the copy link and variables safely
old_block = """  void _copyActiveAyah() {
    if (_verse == null) return;
    final arabic = _verse!['text_ar'] as String;
    final verseKey = _verse!['verse_key'] as String;
    final link = 'https://tafseer.id/surahs/${widget.surahId}/ayahs/${widget.ayahNumber}';"""

new_block_dart = """  void _copyActiveAyah() {
    if (_verse == null) return;
    final arabic = (_verse!['text_ar'] as String?) ?? '';
    final verseKey = (_verse!['verse_key'] as String?) ?? '';
    final base = Uri.base;
    final origin = base.host.isNotEmpty
        ? "${base.scheme}://${base.host}${base.port != 80 && base.port != 443 && base.port != 0 ? ':${base.port}' : ''}"
        : 'https://tafseer.id';
    final link = '$origin/#/surahs/${widget.surahId}/ayahs/${widget.ayahNumber}';"""

replaced = content.replace(old_block.replace('\r\n', '\n'), new_block_dart.replace('\r\n', '\n'))
replaced = replaced.replace(old_block, new_block_dart)

with open(file_path, 'w', encoding='latin-1') as f:
    f.write(replaced)

print("Python replace completed successfully!")
