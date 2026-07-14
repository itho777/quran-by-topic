import json
import time
import urllib.request
import urllib.error
import os

def download_metadata():
    print("Starting download of verse metadata (page_number and juz_number) for all 114 surahs...")
    meta = {}
    
    for surah in range(1, 115):
        url = f"https://api.quran.com/api/v4/verses/by_chapter/{surah}?fields=page_number,juz_number&per_page=300"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
        
        success = False
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=15) as r:
                    res = json.loads(r.read().decode('utf-8'))
                    for verse in res.get("verses", []):
                        vk = verse["verse_key"]
                        meta[vk] = {
                            "page": verse["page_number"],
                            "juz": verse["juz_number"]
                        }
                    print(f"  Surah {surah}/114 fetched successfully ({len(res.get('verses', []))} verses).")
                    success = True
                    break
            except Exception as e:
                print(f"  Warning: attempt {attempt+1} failed for Surah {surah}: {e}")
                time.sleep(2)
        
        if not success:
            raise Exception(f"Failed to fetch metadata for Surah {surah} after 5 attempts.")
        
        # Small delay to be polite to the API
        time.sleep(0.1)
        
    out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "verse_meta.json")
    
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
        
    print(f"Success! Saved metadata for {len(meta)} verses to {out_path}")

if __name__ == "__main__":
    download_metadata()
