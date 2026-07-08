"""
Fix ALL non-nullable 'as String' map casts across the most critical user-facing screens.
Files: surah_detail_screen.dart, mushaf_screen.dart, home_screen.dart
"""
import os, re

BASE = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib"

def process(path, replacements):
    full = os.path.join(BASE, path)
    with open(full, 'rb') as f:
        raw = f.read()
    was_crlf = b'\r\n' in raw
    text = raw.decode('latin-1').replace('\r\n', '\n')
    for old, new in replacements:
        if old in text:
            text = text.replace(old, new)
            print(f"  FIXED: {old[:60]!r}")
        else:
            print(f"  SKIP (not found): {old[:60]!r}")
    if was_crlf:
        text = text.replace('\n', '\r\n')
    with open(full, 'wb') as f:
        f.write(text.encode('latin-1'))
    print(f"  => Saved {path}")


# ─── surah_detail_screen.dart ───────────────────────────────────────────────
print("\n[surah_detail_screen.dart]")
process("features/surah_detail/surah_detail_screen.dart", [
    # _AyahCard build() casts
    ("    final verseKey = verse['verse_key'] as String;",
     "    final verseKey = (verse['verse_key'] as String?) ?? '';"),
    ("    final arabic = verse['text_ar'] as String;",
     "    final arabic = (verse['text_ar'] as String?) ?? '';"),
    # _loadTranslations loop cast
    ("for (final r in res) { map[r['verse_id'] as int] = r['text'] as String; }",
     "for (final r in res) { if (r['verse_id'] != null) { map[r['verse_id'] as int] = (r['text'] as String?) ?? ''; } }"),
    # _loadTransliteration loop cast
    ("for (final r in translitRes) { translitMap[r['verse_id'] as int] = r['text'] as String; }",
     "for (final r in translitRes) { if (r['verse_id'] != null) { translitMap[r['verse_id'] as int] = (r['text'] as String?) ?? ''; } }"),
])

# ─── mushaf_screen.dart ──────────────────────────────────────────────────────
print("\n[mushaf_screen.dart]")
process("features/mushaf/mushaf_screen.dart", [
    ("    final vKey = verse['verse_key'] as String;",
     "    final vKey = (verse['verse_key'] as String?) ?? '';"),
    ("        _selectedVerseKey = verse['verse_key'] as String;",
     "        _selectedVerseKey = (verse['verse_key'] as String?) ?? '';"),
])

# ─── home_screen.dart ────────────────────────────────────────────────────────
print("\n[home_screen.dart]")
process("features/home/home_screen.dart", [
    ("          verseKey = vRes['verse_key'] as String;",
     "          verseKey = (vRes['verse_key'] as String?) ?? '';"),
    ("          verseKey = item['verse_key'] as String;",
     "          verseKey = (item['verse_key'] as String?) ?? '';"),
    ("        final k = row['key'] as String;",
     "        final k = row['key'] as String?;  // may be null"),
    ("        final v = row['value'] as String;",
     "        if (k == null) continue;\n        final v = (row['value'] as String?) ?? '';"),
])

print("\nAll done.")
