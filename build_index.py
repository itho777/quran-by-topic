#!/usr/bin/env python3
"""
build_index.py
==============
Generates a highly-compact search index file data/search_index.json:
{
  "word": "verse_1_src_src,verse_2_src,..."
}
Filters out words appearing in > 500 verses to optimize download size.
"""

import json, re, os, sys, time

sys.stdout.reconfigure(encoding='utf-8')

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
    # Arabic particles
    'من','إلى','عن','مع','في','على','بـ','لـ','كـ','وـ','فـ','ثم','أو',
    'لا','ما','هو','هي','هم','نحن','أنا','أنت',
}

def strip_html(text):
    return re.sub(r'<[^>]+>', ' ', text)

def tokenize(text):
    text = strip_html(text)
    words = re.findall(r'[a-zA-Z\u0600-\u06FF\u0750-\u077F\u00C0-\u024F]{3,}', text.lower())
    return [w for w in words if w not in STOP_WORDS and len(w) >= 3]

print("Reading registry.json...")
with open('data/registry.json', encoding='utf-8-sig') as f:
    registry = json.load(f)

sources = []
# Quran Arabic text
quran_file = registry.get('quran_arabic', 'data/quran_arabic.json')
if os.path.exists(quran_file):
    sources.append({'name': 'Qur\'an Arabic', 'file': quran_file, 'cat': 'q'})

# Translations (EN/ID/AR)
for s in registry.get('translations', []):
    if s.get('lang') in ('en', 'id', 'ar'):
        sources.append({'name': s.get('name', s.get('id')), 'file': s.get('file'), 'cat': 't'})

# Tafsirs (EN/ID/AR)
for s in registry.get('tafsirs', []):
    if s.get('lang') in ('en', 'id', 'ar'):
        sources.append({'name': s.get('name', s.get('id')), 'file': s.get('file'), 'cat': 'f'})

# Asbabun Nuzul (EN/ID/AR)
for s in registry.get('asbabun_nuzul', []):
    if s.get('lang') in ('en', 'id', 'ar'):
        sources.append({'name': s.get('name', s.get('id')), 'file': s.get('file'), 'cat': 'n'})

# Transliterations
for s in registry.get('transliterations', []):
    sources.append({'name': s.get('name', s.get('id')), 'file': s.get('file'), 'cat': 'r'})

total = len(sources)
print(f"Total sources to index (EN/ID/AR + Translit + Arabic): {total}\n")

temp_index = {}
t0 = time.time()

for idx, source in enumerate(sources):
    name = source.get('name', '?')
    file = source.get('file', '')
    cat  = source.get('cat', 't')
    print(f"  [{idx+1:3d}/{total}] [{cat}] {name}", flush=True)

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
            if word not in temp_index:
                temp_index[word] = {}
            if verse_key not in temp_index[word]:
                temp_index[word][verse_key] = set()
            temp_index[word][verse_key].add(cat)

elapsed = time.time() - t0
print(f"\n✓ Raw indexing finished in {elapsed:.1f}s")

# Compact serialization & filtering common words (> 500 verses)
print("Filtering common words and compacting with category tags...")
compact_index = {}
filtered_count = 0
for w, verses in temp_index.items():
    if len(verses) > 500:
        filtered_count += 1
        continue
    parts = []
    for vk, cats in verses.items():
        cat_str = ''.join(sorted(cats))
        parts.append(f'{vk}:{cat_str}')
    compact_index[w] = ','.join(parts)

out_path = 'data/search_index.json'
print(f"Writing compact index to {out_path}...")
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(compact_index, f, ensure_ascii=False, separators=(',', ':'))

size_mb = os.path.getsize(out_path) / 1e6
print(f"\n✅ Done! Wrote: {out_path}")
print(f"   Index size: {size_mb:.2f} MB")
print(f"   Unique words kept: {len(compact_index):,}")
print(f"   Common words filtered (>500 verses): {filtered_count}")
