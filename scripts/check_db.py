"""
Quick credential test — run BEFORE import_pipeline.py
Checks: DB connection, verse count, existing content counts.

Usage:
  set SUPABASE_SERVICE_KEY=eyJh...your_key...
  python check_db.py
"""
import os
import requests

# Load from .env if exists
env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
if os.path.exists(env_path):
    with open(env_path, "r") as f:
        for line in f:
            if "=" in line and not line.strip().startswith("#"):
                key, val = line.strip().split("=", 1)
                os.environ[key.strip()] = val.strip()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://zgeygoclduqotqveperx.supabase.co")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}

TABLES = ["verses", "surahs", "translations", "tafsirs", "asbabun_nuzul", "tags", "verse_tags"]

def count_table(table: str) -> int:
    r = requests.head(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={**HEADERS, "Prefer": "count=exact"},
    )
    content_range = r.headers.get("Content-Range", "*/0")
    try:
        return int(content_range.split("/")[-1])
    except (ValueError, IndexError):
        return -1

print("=" * 55)
print("  Tafseer.id - Database Check")
print(f"  URL: {SUPABASE_URL}")
print("=" * 55)

if not SUPABASE_SERVICE_KEY:
    print("\n[ERROR] SUPABASE_SERVICE_KEY not set!")
    print("   Please populate the SUPABASE_SERVICE_KEY in .env")
    exit(1)

print("\nTable counts:")
for t in TABLES:
    count = count_table(t)
    status = "[OK]" if count > 0 else ("[WARN] empty" if count == 0 else "[ERR] error")
    print(f"  {t:<25} {count:>8}   {status}")

print("\nSource breakdown in translations:")
r = requests.get(
    f"{SUPABASE_URL}/rest/v1/translations",
    headers={**HEADERS, "Prefer": "count=exact"},
    params={"select": "source_id", "limit": "0"},
)
# Get unique sources
r2 = requests.get(
    f"{SUPABASE_URL}/rest/v1/translations",
    headers=HEADERS,
    params={"select": "source_id", "limit": "10000"},
)
if r2.status_code == 200:
    sources = {}
    for row in r2.json():
        sources[row["source_id"]] = sources.get(row["source_id"], 0) + 1
    for src, cnt in sorted(sources.items()):
        print(f"  {src:<30} {cnt:>6} rows")

print("\nSource breakdown in tafsirs:")
r3 = requests.get(
    f"{SUPABASE_URL}/rest/v1/tafsirs",
    headers=HEADERS,
    params={"select": "source_id", "limit": "10000"},
)
if r3.status_code == 200:
    sources = {}
    for row in r3.json():
        sources[row["source_id"]] = sources.get(row["source_id"], 0) + 1
    for src, cnt in sorted(sources.items()):
        print(f"  {src:<30} {cnt:>6} rows")

print("\n[INFO] Database check complete.\n")

