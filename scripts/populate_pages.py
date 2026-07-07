"""
Populate page_number and juz_number columns in the verses table by fetching
metadata from the Quran.com API.
"""
import os, sys, requests, time
from concurrent.futures import ThreadPoolExecutor

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

env_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\.env"
supabase_url = supabase_key = ""
with open(env_path) as f:
    for line in f:
        if "=" in line and not line.strip().startswith("#"):
            k, v = line.strip().split("=", 1)
            if k.strip() == "SUPABASE_URL": supabase_url = v.strip()
            elif k.strip() == "SUPABASE_SERVICE_KEY": supabase_key = v.strip()

SB_HEADERS = {
    "apikey": supabase_key,
    "Authorization": f"Bearer {supabase_key}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

def fetch_page_metadata(page_num):
    url = f"https://api.quran.com/api/v4/verses/by_page/{page_num}?words=false"
    for attempt in range(3):
        try:
            res = requests.get(url, timeout=10)
            if res.status_code == 200:
                data = res.json()
                results = []
                for v in data.get("verses", []):
                    results.append({
                        "verse_key": v["verse_key"],
                        "page_number": page_num,
                        "juz_number": v["juz_number"]
                    })
                return results
            else:
                time.sleep(2)
        except Exception as e:
            time.sleep(2)
    print(f"Failed to fetch page {page_num}")
    return []

def main():
    print("=== Fetching Quran Page Metadata (Pages 1 to 604) ===")
    
    # Fetch all pages in parallel (up to 20 threads)
    page_mappings = {}
    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = {executor.submit(fetch_page_metadata, p): p for p in range(1, 605)}
        for fut in futures:
            results = fut.result()
            for r in results:
                page_mappings[r["verse_key"]] = r

    print(f"Fetched mappings for {len(page_mappings)} verses.")

    # Fetch existing verses from Supabase to preserve all NOT NULL columns (id, sura_id, ayah_number, verse_key, text_ar)
    print("Fetching existing verses from Supabase...")
    existing_verses = []
    offset = 0
    limit = 1000
    while True:
        url = f"{supabase_url}/rest/v1/verses?select=id,sura_id,ayah_number,verse_key,text_ar&limit={limit}&offset={offset}"
        res = requests.get(url, headers={"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"})
        if res.status_code not in (200, 206):
            print("Error fetching verses:", res.text)
            return
        data = res.json()
        existing_verses.extend(data)
        if len(data) < limit:
            break
        offset += limit
    
    print(f"Fetched {len(existing_verses)} existing verses.")

    # Merge page_number and juz_number
    updated_verses = []
    missing_count = 0
    for v in existing_verses:
        key = v["verse_key"]
        m = page_mappings.get(key)
        if m:
            v["page_number"] = m["page_number"]
            v["juz_number"] = m["juz_number"]
            updated_verses.append(v)
        else:
            missing_count += 1

    print(f"Merged metadata. {len(updated_verses)} rows ready. {missing_count} missing.")

    # Upload in batches
    BATCH_SIZE = 100
    for i in range(0, len(updated_verses), BATCH_SIZE):
        batch = updated_verses[i:i + BATCH_SIZE]
        print(f"Uploading batch {i//BATCH_SIZE + 1}...", end=" ", flush=True)
        res = requests.post(
            f"{supabase_url}/rest/v1/verses",
            headers=SB_HEADERS,
            json=batch,
            timeout=30
        )
        if res.status_code in (200, 201, 204):
            print("✅")
        else:
            print("FAILED:", res.status_code, res.text[:200])
            break

    print("\n=== Done! ===")

if __name__ == "__main__":
    main()
