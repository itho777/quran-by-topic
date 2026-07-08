"""
Download all 604 quranpedia KFQC SVG pages into assets/mushaf/.
Uses parallel threads to finish fast.
"""
import os
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE_URL = "https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg"
OUT_DIR  = os.path.join(os.path.dirname(__file__), "assets", "mushaf")
TOTAL    = 604
WORKERS  = 20   # parallel connections

os.makedirs(OUT_DIR, exist_ok=True)

def download_page(n: int) -> tuple[int, bool, str]:
    padded = str(n).zfill(3)
    url    = f"{BASE_URL}/{padded}.svg"
    dest   = os.path.join(OUT_DIR, f"{padded}.svg")
    if os.path.exists(dest) and os.path.getsize(dest) > 100:
        return n, True, "cached"
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            data = r.read()
        with open(dest, "wb") as f:
            f.write(data)
        return n, True, f"{len(data):,} bytes"
    except Exception as e:
        return n, False, str(e)

pages   = list(range(1, TOTAL + 1))
done    = 0
errors  = []
t0      = time.time()

print(f"Downloading {TOTAL} pages -> {OUT_DIR}")
print(f"Using {WORKERS} parallel workers\n")

with ThreadPoolExecutor(max_workers=WORKERS) as ex:
    futures = {ex.submit(download_page, n): n for n in pages}
    for fut in as_completed(futures):
        n, ok, msg = fut.result()
        done += 1
        if not ok:
            errors.append((n, msg))
            print(f"  x page {n:03d}: {msg}")
        else:
            # Progress every 50 pages
            if done % 50 == 0 or done == TOTAL:
                elapsed = time.time() - t0
                print(f"  {done}/{TOTAL} pages done  ({elapsed:.1f}s)")

elapsed = time.time() - t0
total_size = sum(
    os.path.getsize(os.path.join(OUT_DIR, f))
    for f in os.listdir(OUT_DIR)
    if f.endswith(".svg")
)

print(f"\n{'='*50}")
print(f"Done in {elapsed:.1f}s")
print(f"Files: {TOTAL - len(errors)}/{TOTAL}")
print(f"Total size: {total_size / 1024 / 1024:.1f} MB")
if errors:
    print(f"Errors ({len(errors)}): {errors[:5]}")
    sys.exit(1)
else:
    print("All pages downloaded successfully!")
