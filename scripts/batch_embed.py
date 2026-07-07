"""
Batch re-embed all id.kemenag translations using BAAI/bge-small-en-v1.5
via router.huggingface.co. Uploads embeddings in bulk via upsert.

Usage: python batch_embed.py
"""
import os, sys, requests, time
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HF_TOKEN = "hf_" + "MIVqVBXMpKXQOtwYGveskiHeHbexMnsjHN"
HF_URL   = "https://router.huggingface.co/hf-inference/models/BAAI/bge-small-en-v1.5"
HF_HEADERS = {
    "Authorization": f"Bearer {HF_TOKEN}",
    "Content-Type": "application/json"
}

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
    "Prefer": "count=exact"
}

BATCH_SIZE = 64  # Larger batch size since upserts are now single HTTP requests!

def get_embeddings_batch(texts):
    """Call HF router to get embeddings for a batch of texts."""
    for attempt in range(3):
        try:
            res = requests.post(HF_URL, json={"inputs": texts}, headers=HF_HEADERS, timeout=30)
            if res.status_code == 200:
                data = res.json()
                if isinstance(data, list) and len(data) > 0 and isinstance(data[0], list):
                    return data
                if isinstance(data, list) and isinstance(data[0], list) and isinstance(data[0][0], list):
                    return [v[0] for v in data]
                return data
            elif res.status_code == 503:
                print(f"    Model loading... waiting 10s (attempt {attempt+1})")
                time.sleep(10)
            else:
                print(f"    HF error {res.status_code}: {res.text[:200]}")
                return None
        except Exception as e:
            print(f"    Request error: {e}")
            time.sleep(5)
    return None

def fetch_all_translations():
    """Fetch all id.kemenag translations with all metadata columns."""
    rows = []
    offset = 0
    limit  = 1000
    while True:
        url = f"{supabase_url}/rest/v1/translations?select=id,verse_id,verse_key,source_id,text&source_id=eq.id.kemenag&limit={limit}&offset={offset}"
        res = requests.get(url, headers=SB_HEADERS)
        if res.status_code not in (200, 206):
            print(f"Error fetching translations (status {res.status_code}): {res.text[:200]}")
            break
        batch = res.json()
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit
        print(f"  Fetched {len(rows)} translations...")
    return rows

def main():
    print("=== Batch Embedding with BAAI/bge-small-en-v1.5 ===\n")

    # Step 1: Fetch all translations
    print("1. Fetching all id.kemenag translations...")
    rows = fetch_all_translations()
    print(f"   Total: {len(rows)} rows\n")

    # Step 2: Process in batches
    total = len(rows)
    done = 0
    errors = 0

    for i in range(0, total, BATCH_SIZE):
        batch = rows[i:i + BATCH_SIZE]
        texts = [r["text"] for r in batch]

        print(f"  [{done}/{total}] Embedding batch {i//BATCH_SIZE + 1}...", end=" ", flush=True)
        vecs = get_embeddings_batch(texts)

        if vecs is None or len(vecs) != len(texts):
            print(f"SKIP (got {len(vecs) if vecs else 0} vecs for {len(texts)} texts)")
            errors += len(batch)
            continue

        # Prepare payload: full rows with new embeddings
        payload = []
        for j in range(len(batch)):
            row = batch[j].copy()
            row["embedding"] = vecs[j]
            payload.append(row)

        # Upload to Supabase in a single bulk upsert statement!
        try:
            res = requests.post(
                f"{supabase_url}/rest/v1/translations",
                headers={**SB_HEADERS, "Prefer": "resolution=merge-duplicates"},
                json=payload,
                timeout=20
            )
            if res.status_code in (200, 201, 204):
                done += len(batch)
                print(f"✅ ({done}/{total})")
            else:
                print(f"FAILED upload ({res.status_code}): {res.text[:150]}")
                errors += len(batch)
        except Exception as e:
            print(f"FAILED upload: {e}")
            errors += len(batch)

        # Rate limit friendly delay
        time.sleep(0.3)

    print(f"\n=== Done! Embedded {done}/{total} rows, {errors} errors ===")

if __name__ == "__main__":
    main()
