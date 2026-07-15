import json
import re
from pathlib import Path

STOP_WORDS = {
    'the','and','of','to','in','a','that','is','was','for','on','are','with',
    'his','they','at','be','this','have','from','or','one','had','by','but',
    'not','what','all','were','we','when','your','can','said','there','use',
    'an','each','which','she','do','how','their','if','will','up','other',
    'about','out','many','then','them','these','so','some','her','would',
    'him','into','has','two','more','see','way','could','than','been','who',
    'its','now','did','get','come','made','may','our','own','well','also',
    'does','any','those','such','you','unto','upon','thou','thee','thy',
    # Indonesian
    'yang','dan','ini','itu','dia','ada','untuk','dari','dengan','tidak',
    'kamu','mereka','kami','kepada','bahwa','telah','akan','oleh','juga',
    'maka','orang','pun','bagi','lain','pada','dalam','atau','adalah',
    # Arabic particles
    'من','إلى','عن','مع','في','على','لا','ما','هو','هي','هم','نحن',
}

TOKEN_PATTERN = re.compile(
    r'[\u0600-\u06FF\u0750-\u077F]{3,}'
    r'|[a-z\u00c0-\u024f]{3,}'
    r'|[\u0400-\u04FF]{3,}'
    r'|[\u0900-\u097F]{3,}',
    re.IGNORECASE
)

def tokenize(text):
    text_lower = text.lower().strip()
    matches = TOKEN_PATTERN.findall(text_lower)
    tokens = []
    for m in matches:
        if len(m) >= 3 and m not in STOP_WORDS:
            tokens.append(m)
    return tokens

def main():
    index_dir = Path(__file__).parent.parent / "assets" / "index"
    print(f"Reading from {index_dir}")
    
    json_files = sorted(index_dir.glob("*.json"))
    
    total_raw_size = 0
    total_idx_size = 0
    
    for path in json_files:
        if path.name == "manifest.json":
            continue
            
        raw_size = path.stat().st_size
        total_raw_size += raw_size
        
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        # Check if it's already converted or in the old format
        if "verses" not in data:
            print(f"Skipping {path.name} (no 'verses' key, maybe already inverted?)")
            continue
            
        verses = data["verses"]
        
        inverted = {}
        for vk, text in verses.items():
            tokens = tokenize(text)
            # Remove duplicates in the same verse
            seen = set()
            for token in tokens:
                if token not in seen:
                    seen.add(token)
                    if token in inverted:
                        inverted[token].append(vk)
                    else:
                        inverted[token] = [vk]
                        
        # Convert lists to comma-separated strings
        output_data = {}
        for token, vks in inverted.items():
            output_data[token] = ",".join(vks)
            
        # Write back to the same file
        with open(path, "w", encoding="utf-8") as f:
            json.dump(output_data, f, ensure_ascii=False, separators=(",", ":"))
            
        idx_size = path.stat().st_size
        total_idx_size += idx_size
        print(f"Converted {path.name}: {raw_size/1024:.1f} KB -> {idx_size/1024:.1f} KB")
        
    print(f"\nDone! Total size: {total_raw_size/1024/1024:.2f} MB -> {total_idx_size/1024/1024:.2f} MB")

if __name__ == "__main__":
    main()
