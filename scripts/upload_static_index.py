"""
upload_static_index.py
======================
Uploads the pre-built translation index (assets/index/*.json + manifest.json)
to a PUBLIC Supabase Storage bucket named "quran-index".

Usage:
    python scripts/upload_static_index.py            # skip already-uploaded files
    python scripts/upload_static_index.py --force    # overwrite every file
    python scripts/upload_static_index.py --dry-run  # just list what would upload

The CDN URL for each file will be:
    {SUPABASE_URL}/storage/v1/object/public/quran-index/{source_id}.json
"""

import os
import sys
import json
import time
import argparse
from pathlib import Path
from dotenv import load_dotenv

try:
    import requests
except ImportError:
    print("ERROR: 'requests' not installed. Run: pip install requests")
    sys.exit(1)

# ── Config ──────────────────────────────────────────────────────────────────

load_dotenv()

SUPABASE_URL        = os.environ["SUPABASE_URL"].rstrip("/")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY") or os.environ["SUPABASE_SERVICE_ROLE_KEY"]
BUCKET_NAME         = "quran-index"
INDEX_DIR           = Path(__file__).parent.parent / "assets" / "index"

STORAGE_BASE = f"{SUPABASE_URL}/storage/v1"
HEADERS_AUTH = {
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "apikey":        SUPABASE_SERVICE_KEY,
}

# ── Helpers ──────────────────────────────────────────────────────────────────

def ensure_bucket_exists():
    """Create bucket if missing; make it public."""
    url = f"{STORAGE_BASE}/bucket"
    r = requests.get(url, headers=HEADERS_AUTH, timeout=15)
    r.raise_for_status()
    buckets = {b["name"] for b in r.json()}
    if BUCKET_NAME in buckets:
        print(f"  Bucket '{BUCKET_NAME}' already exists.")
        return

    print(f"  Creating public bucket '{BUCKET_NAME}' ...")
    payload = {"id": BUCKET_NAME, "name": BUCKET_NAME, "public": True}
    r = requests.post(url, headers=HEADERS_AUTH, json=payload, timeout=15)
    if r.status_code not in (200, 201):
        print(f"  ERROR creating bucket: {r.status_code} {r.text}")
        sys.exit(1)
    print(f"  Bucket '{BUCKET_NAME}' created.")


def list_existing_files():
    """Return set of filenames already in the bucket."""
    url     = f"{STORAGE_BASE}/object/list/{BUCKET_NAME}"
    payload = {"prefix": "", "limit": 1000, "offset": 0}
    r = requests.post(url, headers=HEADERS_AUTH, json=payload, timeout=15)
    if r.status_code == 200:
        return {item["name"] for item in r.json() if isinstance(item, dict)}
    return set()


def upload_file(local_path: Path, remote_name: str, overwrite: bool) -> bool:
    """
    Upload a single file.  Returns True on success, False on failure.
    Uses POST (create) or PUT (upsert) based on `overwrite`.
    """
    data = local_path.read_bytes()
    url  = f"{STORAGE_BASE}/object/{BUCKET_NAME}/{remote_name}"

    headers = {
        **HEADERS_AUTH,
        "Content-Type":  "application/json",
        "Cache-Control": "public, max-age=31536000, immutable",  # 1 year CDN cache
    }

    if overwrite:
        # PUT = upsert
        headers["x-upsert"] = "true"
        r = requests.put(url, headers=headers, data=data, timeout=120)
    else:
        r = requests.post(url, headers=headers, data=data, timeout=120)

    if r.status_code in (200, 201):
        return True

    # "already exists" when not overwriting
    if r.status_code == 409 and not overwrite:
        return None   # signal: skipped

    print(f"    WARN {r.status_code}: {r.text[:120]}")
    return False


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Upload static Quran index to Supabase Storage.")
    parser.add_argument("--force",   action="store_true", help="Overwrite already-uploaded files")
    parser.add_argument("--dry-run", action="store_true", help="List files without uploading")
    args = parser.parse_args()

    if not INDEX_DIR.exists():
        print(f"ERROR: Index directory not found: {INDEX_DIR}")
        print("       Run 'python scripts/build_index_full.py' first.")
        sys.exit(1)

    json_files = sorted(INDEX_DIR.glob("*.json"))
    if not json_files:
        print("ERROR: No .json files found in assets/index/.")
        sys.exit(1)

    print(f"\n{'='*60}")
    print(f"  Supabase Storage Upload — '{BUCKET_NAME}' bucket")
    print(f"  Files to process : {len(json_files)}")
    print(f"  Mode             : {'DRY RUN' if args.dry_run else ('force overwrite' if args.force else 'skip existing')}")
    print(f"{'='*60}\n")

    if args.dry_run:
        for f in json_files:
            size = f.stat().st_size / 1024
            print(f"  {f.name:40s}  {size:8.1f} KB")
        total = sum(f.stat().st_size for f in json_files)
        print(f"\n  Total: {total/1024/1024:.1f} MB across {len(json_files)} files.")
        return

    # ── Real upload ──────────────────────────────────────────────────────────
    print("Step 1: Checking / creating bucket ...")
    ensure_bucket_exists()

    print("\nStep 2: Listing already-uploaded files ...")
    existing = list_existing_files() if not args.force else set()
    print(f"  Found {len(existing)} existing file(s) in bucket.")

    uploaded = skipped = failed = 0
    total    = len(json_files)
    t0       = time.time()

    print(f"\nStep 3: Uploading {total} file(s) ...\n")

    for i, local_path in enumerate(json_files, 1):
        remote_name = local_path.name
        size_kb     = local_path.stat().st_size / 1024
        prefix      = f"[{i:3d}/{total}] {remote_name:40s}  ({size_kb:8.1f} KB)"

        if remote_name in existing and not args.force:
            print(f"{prefix}  -- SKIP")
            skipped += 1
            continue

        print(f"{prefix}  -> uploading ...", end="", flush=True)
        ok = upload_file(local_path, remote_name, overwrite=args.force)

        if ok is True:
            print("  OK")
            uploaded += 1
        elif ok is None:
            print("  SKIP (already exists)")
            skipped += 1
        else:
            print("  FAILED")
            failed += 1

    elapsed = time.time() - t0
    print(f"\n{'='*60}")
    print(f"  Done in {elapsed:.1f}s")
    print(f"  Uploaded : {uploaded}")
    print(f"  Skipped  : {skipped}")
    print(f"  Failed   : {failed}")
    print(f"\n  CDN base URL:")
    print(f"  {SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/")
    print(f"\n  Example:")
    print(f"  {SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/en.sahih.json")
    print(f"{'='*60}\n")

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
