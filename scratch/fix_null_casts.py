import re

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(file_path, 'rb') as f:
    raw = f.read()

# Detect line ending style
has_crlf = b'\r\n' in raw
text = raw.decode('latin-1')

def fix(content):
    # Fix translation cast block
    content = content.replace(
        "        _translationTexts[row['source_id'] as String] = row['text'] as String;",
        "        final srcId = row['source_id'] as String?;\n"
        "        if (srcId != null) {\n"
        "          _translationTexts[srcId] = (row['text'] as String?) ?? '';\n"
        "        }"
    )

    # Fix tafsir cast block
    content = content.replace(
        "        _tafsirTexts[row['source_id'] as String] = row['text'] as String;",
        "        final srcId = row['source_id'] as String?;\n"
        "        if (srcId != null) {\n"
        "          _tafsirTexts[srcId] = (row['text'] as String?) ?? '';\n"
        "        }"
    )

    # Fix nuzul cast block
    content = content.replace(
        "        _nuzulTexts[row['source_id'] as String] = row['text'] as String;",
        "        final srcId = row['source_id'] as String?;\n"
        "        if (srcId != null) {\n"
        "          _nuzulTexts[srcId] = (row['text'] as String?) ?? '';\n"
        "        }"
    )

    # Fix related verses casts
    content = content.replace(
        "            final rVerseKey = r['verse_key'] as String;\n            final rText = r['text'] as String;",
        "            final rVerseKey = (r['verse_key'] as String?) ?? '';\n            final rText = (r['text'] as String?) ?? '';"
    )
    content = content.replace(
        "            final rVerseKey = r['verse_key'] as String;\r\n            final rText = r['text'] as String;",
        "            final rVerseKey = (r['verse_key'] as String?) ?? '';\r\n            final rText = (r['text'] as String?) ?? '';"
    )

    # Fix build method verse casts (both variable names)
    content = content.replace(
        "    final String arabicText = _verse!['text_ar'] as String;",
        "    final String arabicText = (_verse!['text_ar'] as String?) ?? '';"
    )
    content = content.replace(
        "    final String verseKey = _verse!['verse_key'] as String;",
        "    final String verseKey = (_verse!['verse_key'] as String?) ?? '';"
    )

    # Fix the rpcVerseKey cast
    content = content.replace(
        "      final rpcVerseKey = verseRes['verse_key'] as String;",
        "      final rpcVerseKey = (verseRes['verse_key'] as String?) ?? '';"
    )

    return content

text = fix(text)

# Normalise line endings back to original
if has_crlf:
    # Ensure no double \r
    text = text.replace('\r\n', '\n').replace('\r', '\n').replace('\n', '\r\n')

with open(file_path, 'wb') as f:
    f.write(text.encode('latin-1'))

print("All unsafe casts replaced successfully!")
