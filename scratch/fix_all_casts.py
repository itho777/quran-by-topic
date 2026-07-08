"""
Comprehensive null-safe cast fixer for ayah_detail_screen.dart
Handles every remaining 'as String' (non-nullable) cast from DB data.
"""
import re

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(file_path, 'rb') as f:
    raw = f.read()

# Use latin-1 so we never fail on any byte value
text = raw.decode('latin-1')

# Normalise to LF for easier processing, restore CRLF at end if needed
was_crlf = '\r\n' in text
text = text.replace('\r\n', '\n')

# ---- 1. Fix topics tab (still has old code) ----
old_topics = """\
          ...filteredTopics.map((t) {
            final tag = t['tags'] as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(tag['name'] as String, style: TextStyle(fontSize: 13, color: AppTheme.onSurface)),
                trailing: Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.outline),
                onTap: () => context.go('/topics/${t['tag_id']}'),
              ),
            );
          }),"""

new_topics = """\
          ...filteredTopics.map((t) {
            final tag = t['tags'] as Map<String, dynamic>?;
            if (tag == null) return const SizedBox.shrink();
            final tagName = (tag['name'] as String?) ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(tagName, style: TextStyle(fontSize: 13, color: AppTheme.onSurface)),
                trailing: Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.outline),
                onTap: () => context.go('/topics/${t['tag_id']}'),
              ),
            );
          }),"""

text = text.replace(old_topics, new_topics)

# ---- 2. Fix related verses casts ----
old_related = "            final rVerseKey = r['verse_key'] as String;\n            final rText = r['text'] as String;"
new_related = "            final rVerseKey = (r['verse_key'] as String?) ?? '';\n            final rText = (r['text'] as String?) ?? '';"
text = text.replace(old_related, new_related)

# ---- 3. Fix build-method arabic / verseKey casts (non-nullable) ----
text = text.replace(
    "    final String arabicText = _verse!['text_ar'] as String;",
    "    final String arabicText = (_verse!['text_ar'] as String?) ?? '';"
)
text = text.replace(
    "    final String verseKey = _verse!['verse_key'] as String;",
    "    final String verseKey = (_verse!['verse_key'] as String?) ?? '';"
)

# ---- 4. The _copyActiveAyah variants in ayah detail ----
text = text.replace(
    "    final arabic = _verse!['text_ar'] as String;",
    "    final arabic = (_verse!['text_ar'] as String?) ?? '';"
)
text = text.replace(
    "    final verseKey = _verse!['verse_key'] as String;",
    "    final verseKey = (_verse!['verse_key'] as String?) ?? '';"
)

# ---- 5. surahNameAr cast ----
text = text.replace(
    "    final String surahNameAr = _surah!['name_ar'] as String? ?? '';",
    "    final String surahNameAr = (_surah!['name_ar'] as String?) ?? '';"
)

# ---- Report any remaining non-nullable String casts from map accesses ----
remaining = [(i+1, l) for i, l in enumerate(text.split('\n'))
             if re.search(r"\['.+'\] as String[^?]", l)]
if remaining:
    print("WARNING - remaining non-nullable String casts:")
    for ln, line in remaining:
        print(f"  L{ln}: {line.strip()}")
else:
    print("No remaining non-nullable String casts from map accesses!")

# Restore CRLF
if was_crlf:
    text = text.replace('\n', '\r\n')

with open(file_path, 'wb') as f:
    f.write(text.encode('latin-1'))

print("Done.")
