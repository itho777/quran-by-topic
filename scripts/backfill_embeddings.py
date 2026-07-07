"""
backfill_embeddings.py
======================
Generates multilingual semantic embeddings locally using sentence-transformers
and uploads them directly to Supabase.

Requirements (run ONCE in your own PowerShell/Terminal, NOT Antigravity):
    pip install sentence-transformers requests

Then run:
    python scripts/backfill_embeddings.py
"""

import os, sys, time, json, math

# Fix Windows console encoding so progress bar renders correctly
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# ── Load credentials ─────────────────────────────────────────────────────────
def load_env(path=".env"):
    env = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env

env = load_env()
SUPABASE_URL = env.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = env.get("SUPABASE_SERVICE_KEY", "")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_KEY not found in .env")
    sys.exit(1)

HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
}

BATCH_SIZE = 100
MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"

# ── Import dependencies (with helpful error) ──────────────────────────────────
try:
    import requests
except ImportError:
    print("ERROR: 'requests' not installed.")
    print("  Run:  pip install requests sentence-transformers")
    sys.exit(1)

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    print("ERROR: 'sentence-transformers' not installed.")
    print("  Run:  pip install sentence-transformers")
    sys.exit(1)

# ── Load model ────────────────────────────────────────────────────────────────
print(f"Loading model '{MODEL_NAME}' (downloads ~120MB on first run)...")
model = SentenceTransformer(MODEL_NAME)
print("Model ready.\n")

# ── Count pending rows ────────────────────────────────────────────────────────
def count_pending():
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/translations",
        params={
            "select": "id",
            "embedding": "is.null",
            "or": "(source_id.eq.id.kemenag,source_id.eq.en.sahih)"
        },
        headers={**HEADERS, "Prefer": "count=exact", "Range": "0-0"},
    )
    cr = res.headers.get("Content-Range", "*/0")
    return int(cr.split("/")[-1])

# ── Fetch a batch of rows without embeddings ──────────────────────────────────
def fetch_batch(limit):
    res = requests.get(
        f"{SUPABASE_URL}/rest/v1/translations",
        params={
            "select": "id,verse_id,verse_key,source_id,text",
            "embedding": "is.null",
            "or": "(source_id.eq.id.kemenag,source_id.eq.en.sahih)",
            "limit": limit
        },
        headers=HEADERS,
    )
    res.raise_for_status()
    return res.json()

# ── Upload embeddings via upsert ──────────────────────────────────────────────
def upload_batch(rows, embeddings):
    updates = [
        {
            "id": row["id"],
            "verse_id": row["verse_id"],
            "verse_key": row["verse_key"],
            "source_id": row["source_id"],
            "text": row["text"],
            "embedding": emb.tolist()
        }
        for row, emb in zip(rows, embeddings)
    ]
    res = requests.post(
        f"{SUPABASE_URL}/rest/v1/translations",
        headers={**HEADERS, "Prefer": "resolution=merge-duplicates"},
        data=json.dumps(updates),
    )
    res.raise_for_status()

# ── Main loop ─────────────────────────────────────────────────────────────────
def main():
    total = count_pending()
    if total == 0:
        print("All embeddings already exist! Nothing to do.")
        return

    print(f"Found {total} translations needing embeddings.")
    print(f"Batch size: {BATCH_SIZE} | Estimated batches: {math.ceil(total / BATCH_SIZE)}\n")

    done = 0
    errors = 0

    while True:
        batch = fetch_batch(BATCH_SIZE)
        if not batch:
            break

        texts = [r["text"] or "" for r in batch]

        try:
            t0 = time.time()
            embeddings = model.encode(texts, show_progress_bar=False)
            elapsed = time.time() - t0
            upload_batch(batch, embeddings)
            done += len(batch)
        except Exception as e:
            print(f"  ERROR on batch: {e}")
            errors += len(batch)
            time.sleep(3)
            continue

        pct = (done / total) * 100
        bar = ("#" * int(pct // 4)).ljust(25)
        print(f"  [{bar}] {pct:5.1f}%  {done}/{total}  ({elapsed:.1f}s/batch)")

        time.sleep(0.1)  # gentle pacing

    print(f"\nDone! Processed={done}, Errors={errors}")

if __name__ == "__main__":
    main()
