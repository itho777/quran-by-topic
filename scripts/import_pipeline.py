"""
=============================================================================
Tafseer.id — Full Content Import Pipeline
=============================================================================
Fetches and inserts ALL missing content into Supabase:
  1. Arabic text + transliteration (from api.alquran.cloud)
  2. Kemenag ID translation  (id.kemenag)
  3. Sahih International EN translation (en.sahih)
  4. Tafsir Jalalayn ID (id.jalalayn)
  5. Tafsir Ibn Kathir EN (en.katsir)  [mapped from alquran editions]
  6. Asbabun Nuzul EN — Al-Wahidi (en.wahidi)  [from static source]

Usage:
  1. pip install requests
  2. Set SUPABASE_URL and SUPABASE_SERVICE_KEY below (or env vars)
  3. python import_pipeline.py
=============================================================================
"""

import os
import json
import time
import requests
from typing import Optional

# Load from .env if exists
env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
if os.path.exists(env_path):
    with open(env_path, "r") as f:
        for line in f:
            if "=" in line and not line.strip().startswith("#"):
                key, val = line.strip().split("=", 1)
                os.environ[key.strip()] = val.strip()

# ─── CONFIG ──────────────────────────────────────────────────────────────────
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://zgeygoclduqotqveperx.supabase.co")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates",   # upsert behaviour
}

BATCH_SIZE = 500   # rows per POST to Supabase
API_DELAY  = 0.4   # seconds between alquran.cloud calls

# ─── alquran.cloud edition identifiers ───────────────────────────────────────
EDITIONS = {
    "transliteration": "en.transliteration",
    "id.kemenag":      "id.indonesian",       # Kemenag RI
    "en.sahih":        "en.sahih",            # Sahih International
    "id.jalalayn":     "id.jalalayn",         # Tafsir Jalalayn (ID)
    "en.katsir":       "en.jalalayn",         # closest EN tafsir available; swap if you have IBK
}

# ─────────────────────────────────────────────────────────────────────────────
def sb_get(table: str, params: dict) -> list:
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    all_rows = []
    limit = 1000
    offset = 0
    while True:
        headers = {
            **HEADERS,
            "Range-Unit": "items",
            "Range": f"{offset}-{offset + limit - 1}"
        }
        r = requests.get(url, headers=headers, params=params)
        if r.status_code != 200:
            print(f"  [ERROR] sb_get {table} {r.status_code}: {r.text}")
        r.raise_for_status()
        rows = r.json()
        if not rows:
            break
        all_rows.extend(rows)
        offset += len(rows)
        if len(rows) < limit:
            break
    return all_rows


def sb_upsert(table: str, rows: list) -> None:
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    for i in range(0, len(rows), BATCH_SIZE):
        batch = rows[i : i + BATCH_SIZE]
        r = requests.post(url, headers=HEADERS, json=batch)
        if r.status_code not in (200, 201):
            print(f"  [ERROR] Batch {i//BATCH_SIZE+1} error {r.status_code}: {r.text[:200]}")
        else:
            print(f"  [OK] Upserted batch {i//BATCH_SIZE+1} ({len(batch)} rows)")


# ─────────────────────────────────────────────────────────────────────────────
def fetch_alquran_edition(edition: str) -> list:
    """Fetch all 6236 verses for a given alquran.cloud edition."""
    url = f"https://api.alquran.cloud/v1/quran/{edition}"
    print(f"  [-] Fetching {edition} from alquran.cloud ...")
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    data = r.json()
    if data["status"] != "OK":
        raise RuntimeError(f"alquran.cloud returned non-OK: {data}")
    verses = []
    for surah in data["data"]["surahs"]:
        for ayah in surah["ayahs"]:
            verses.append({
                "surah": surah["number"],
                "ayah":  ayah["numberInSurah"],
                "key":   f"{surah['number']}:{ayah['numberInSurah']}",
                "text":  ayah["text"],
            })
    time.sleep(API_DELAY)
    return verses


# ─────────────────────────────────────────────────────────────────────────────
def load_verse_id_map() -> dict:
    """Build {verse_key -> verse_id} from Supabase verses table with pagination."""
    print("Loading verse ID map from Supabase ...")
    verse_map = {}
    limit = 1000
    offset = 0
    url = f"{SUPABASE_URL}/rest/v1/verses"
    while True:
        headers = {
            **HEADERS,
            "Range-Unit": "items",
            "Range": f"{offset}-{offset + limit - 1}"
        }
        r = requests.get(url, headers=headers, params={"select": "id,verse_key"})
        r.raise_for_status()
        rows = r.json()
        if not rows:
            break
        for r in rows:
            verse_map[r["verse_key"]] = r["id"]
        offset += len(rows)
        if len(rows) < limit:
            break
    return verse_map


# ─────────────────────────────────────────────────────────────────────────────
def import_translation(source_id: str, edition_key: str, verse_map: dict) -> None:
    print(f"\n====== Translation: {source_id} ======")
    raw = fetch_alquran_edition(EDITIONS[edition_key])

    existing = sb_get("translations", {"select": "verse_key", "source_id": f"eq.{source_id}"})
    existing_keys = {r["verse_key"] for r in existing}
    print(f"  Already in DB: {len(existing_keys)} verses")

    rows = []
    for v in raw:
        if v["key"] not in existing_keys:
            vid = verse_map.get(v["key"])
            if vid:
                rows.append({
                    "verse_id":  vid,
                    "verse_key": v["key"],
                    "source_id": source_id,
                    "text":      v["text"],
                })

    if not rows:
        print("  Nothing to insert - all entries already present.")
        return

    print(f"  Inserting {len(rows)} new translation rows ...")
    sb_upsert("translations", rows)


# ─────────────────────────────────────────────────────────────────────────────
def import_tafsir(source_id: str, edition_key: str, verse_map: dict) -> None:
    print(f"\n====== Tafsir: {source_id} ======")
    raw = fetch_alquran_edition(EDITIONS[edition_key])

    existing = sb_get("tafsirs", {"select": "verse_key", "source_id": f"eq.{source_id}"})
    existing_keys = {r["verse_key"] for r in existing}
    print(f"  Already in DB: {len(existing_keys)} verses")

    rows = []
    for v in raw:
        if v["key"] not in existing_keys:
            vid = verse_map.get(v["key"])
            if vid:
                rows.append({
                    "verse_id":  vid,
                    "verse_key": v["key"],
                    "source_id": source_id,
                    "text":      v["text"],
                })

    if not rows:
        print("  Nothing to insert - all entries already present.")
        return

    print(f"  Inserting {len(rows)} new tafsir rows ...")
    sb_upsert("tafsirs", rows)


# ─────────────────────────────────────────────────────────────────────────────
def import_wahidi_nuzul(verse_map: dict) -> None:
    """
    Al-Wahidi's Asbabun Nuzul is not on alquran.cloud.
    We use the JSON from: https://cdn.jsdelivr.net/gh/AhmedBaset/quran-json@main/...
    or the tanzil dataset. Here we try a community JSON endpoint.
    """
    print("\n====== 5/5  Asbabun Nuzul - Al-Wahidi (en.wahidi) ======")
    url = "https://raw.githubusercontent.com/azvyae/quran-database/main/asbabun_nuzul/wahidi_en.json"
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        print(f"  [WARN] Could not fetch Wahidi JSON: {e}")
        print("  -> Skipping. You can add en.wahidi entries manually via the Admin panel.")
        return

    existing = sb_get("asbabun_nuzul", {"select": "verse_key", "source_id": "eq.en.wahidi"})
    existing_keys = {r["verse_key"] for r in existing}

    rows = []
    for entry in data:
        key = f"{entry.get('surah')}:{entry.get('ayah')}"
        if key not in existing_keys:
            vid = verse_map.get(key)
            if vid:
                rows.append({
                    "verse_id":  vid,
                    "verse_key": key,
                    "source_id": "en.wahidi",
                    "text":      entry.get("text", ""),
                })

    if not rows:
        print("  Nothing to insert.")
        return

    print(f"  Inserting {len(rows)} Wahidi nuzul rows ...")
    sb_upsert("asbabun_nuzul", rows)


# ─────────────────────────────────────────────────────────────────────────────
def main():
    print("=" * 65)
    print("  Tafseer.id - Full Content Import Pipeline")
    print(f"  Target: {SUPABASE_URL}")
    print("=" * 65)

    if not SUPABASE_SERVICE_KEY:
        print("\n[ERROR] Please set your SUPABASE_SERVICE_KEY in .env.")
        return

    # Step 0: build verse_key -> verse_id map
    verse_map = load_verse_id_map()
    print(f"  Verse map loaded: {len(verse_map)} verses\n")

    if len(verse_map) == 0:
        print("[ERROR] No verses found in DB. Make sure your verses table is populated first.")
        return

    # Step 1: Transliterations (imported as translation source rows)
    import_translation("en.transliteration", "transliteration", verse_map)
    import_translation("id.transliteration", "transliteration", verse_map)

    # Step 2-3: Translations
    import_translation("id.kemenag", "id.kemenag", verse_map)
    import_translation("en.sahih",   "en.sahih",   verse_map)

    # Step 4-5: Tafsirs
    import_tafsir("id.jalalayn", "id.jalalayn", verse_map)
    import_tafsir("en.katsir",   "en.katsir",   verse_map)

    # Step 6: Asbabun Nuzul - Wahidi EN
    import_wahidi_nuzul(verse_map)

    print("\n" + "=" * 65)
    print("  [OK] Import pipeline completed!")
    print("=" * 65)


if __name__ == "__main__":
    main()
