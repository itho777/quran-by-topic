#!/usr/bin/env python3
"""
build_index.py
==============
One-time script to build a static inverted search index from all registered
translations, tafsirs, and asbabun nuzul JSON files.

Run this whenever you add a new data source to registry.json:
    python build_index.py

Output: data/search_index.json
    { "word": ["1:1", "2:5", ...], ... }
"""

import json, re, os, sys, time

sys.stdout.reconfigure(encoding='utf-8')

# ── Stop words (very common words that add no search value) ──────────────────
STOP_WORDS = {
    # English
    'the','and','of','to','in','a','that','is','was','for','on','are','with',
    'his','they','at','be','this','have','from','or','one','had','by','but',
    'not','what','all','were','we','when','your','can','said','there','use',
    'an','each','which','she','do','how','their','if','will','up','other',
    'about','out','many','then','them','these','so','some','her','would','make',
    'him','into','has','two','more','go','see','no','way','could','my','than',
    'been','who','its','now','did','get','come','made','may','part','over',
    'new','our','own','well','also','because','does','any','those','such',
    'off','you','unto','upon','thou','thee','thy','shall','thus','even','yet',
    'also','both','after','before','above','below','between','through','during',
    'these','those','have','had','has','its','our','their','your','her','him',
    'they','them','these','those','then','than','that','this','thus','such',
    # Indonesian
    'yang','dan','ini','itu','dia','ada','untuk','dari','dengan','tidak',
    'kamu','mereka','kami','kepada','bahwa','telah','akan','oleh','juga',
    'maka','orang','pun','satu','bagi','lain','pada','dalam','atau','adalah',
    'atas','bisa','jika','agar','saja','sudah','sedang','sebuah','namun',
    'selain','seperti','hal','apa','siapa','kapan','dimana','kenapa',
    # Arabic particles (short)
    'من','إلى','عن','مع','في','على','بـ','لـ','كـ','وـ','فـ','ثم','أو',
    'لا','ما','هو','هي','هم','نحن','أنا','أنت',
}

def strip_html(text):
    """Remove HTML tags."""
    return re.sub(r'<[^>]+>', ' ', text)

def tokenize(text):
    """Extract meaningful word tokens from text."""
    text = strip_html(text)
    # Match Latin + Arabic + Indonesian extended chars, min 3 chars
    words = re.findall(r'[a-zA-Z\u0600-\u06FF\u0750-\u077F\u00C0-\u024F]{3,}', text.lower())
    return [w for w in words if w not in STOP_WORDS and len(w) >= 3]

def verse_sort_key(key):
    """Sort key for verse strings like '2:255'."""
    try:
        s, a = key.split(':')
        return (int(s), int(a))
    except:
        return (0, 0)

# ── Load registry ─────────────────────────────────────────────────────────────
print("Reading registry.json...")
with open('data/registry.json', encoding='utf-8-sig') as f:
    registry = json.load(f)

all_sources = (
    registry.get('translations', []) +
    registry.get('tafsirs', []) +
    registry.get('asbabun_nuzul', [])
)
total = len(all_sources)
print(f"Found {total} sources to index.\n")

# ── Build index ───────────────────────────────────────────────────────────────
index = {}   # word (str) -> set of verse keys (str)
t0 = time.time()

for i, source in enumerate(all_sources):
    name = source.get('name', source.get('id', '?'))
    file = source.get('file', '')
    print(f"  [{i+1:3d}/{total}] {name}", flush=True)

    if not os.path.exists(file):
        print(f"           ⚠ File not found: {file}")
        continue

    try:
        with open(file, encoding='utf-8-sig') as f:
            data = json.load(f)
    except Exception as e:
        print(f"           ⚠ Error reading: {e}")
        continue

    for verse_key, text in data.items():
        if not isinstance(text, str):
            continue
        for word in tokenize(text):
            if word not in index:
                index[word] = set()
            index[word].add(verse_key)

elapsed = time.time() - t0
print(f"\n✓ Indexed {total} files in {elapsed:.1f}s")
print(f"  Unique word tokens: {len(index):,}")

# ── Sort and serialize ────────────────────────────────────────────────────────
print("\nSorting and serializing...")
final_index = {
    word: sorted(keys, key=verse_sort_key)
    for word, keys in index.items()
}

out_path = 'data/search_index.json'
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(final_index, f, ensure_ascii=False, separators=(',', ':'))

size_mb = os.path.getsize(out_path) / 1e6
print(f"\n✅ Done! Wrote: {out_path}")
print(f"   Index size: {size_mb:.1f} MB")
print(f"   Unique words: {len(final_index):,}")
print(f"\nNext: git add data/search_index.json && git push")
