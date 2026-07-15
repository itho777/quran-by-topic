#!/usr/bin/env python3
"""
build_index_full.py
===================
Downloads all 111 Quran translations from AlQuran.cloud API
and builds a static JSON index hosted in assets/index/.

The index structure per file:
  assets/index/<source_id>.json
  {
    "source_id": "en.sahih",
    "name": "Saheeh International (English)",
    "language": "EN",
    "verses": {
      "1:1": "In the name of Allah...",
      "1:2": "...",
      ...
    }
  }

Additionally writes:
  assets/index/manifest.json
  {
    "generated_at": "...",
    "sources": ["en.sahih", "id.kemenag", ...]
  }

Usage:
  python scripts/build_index_full.py
  python scripts/build_index_full.py --source en.sahih   # single source only
  python scripts/build_index_full.py --upload            # also upload to Supabase Storage
"""

import os
import sys
import json
import time
import argparse
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

# ─── Configuration ──────────────────────────────────────────────────────────────

ALQURAN_API = "https://api.alquran.cloud/v1/quran/{identifier}"
OUTPUT_DIR  = Path(__file__).parent.parent / "assets" / "index"
MANIFEST    = OUTPUT_DIR / "manifest.json"

# All 111 sources from quran_sources.dart
ALL_SOURCES = [
    ("en.shakir",           "en",   "Shakir (English)"),
    ("id.kemenag",          "id",   "Kemenag (Indonesian)"),
    ("sq.nahi",             "sq",   "Efendi Nahi (Albanian)"),
    ("sq.mehdiu",           "sq",   "Feti Mehdiu (Albanian)"),
    ("sq.ahmeti",           "sq",   "Sherif Ahmeti (Albanian)"),
    ("ber.mensur",          "ber",  "At Mensur (Amazigh)"),
    ("am.sadiq",            "am",   "Sadiq & Sani Habib (Amharic)"),
    ("az.mammadaliyev",     "az",   "Mammadaliyev & Bunyadov (Azerbaijani)"),
    ("az.musayev",          "az",   "Musayev (Azerbaijani)"),
    ("bn.hoque",            "bn",   "Zohurul Hoque (Bengali)"),
    ("bn.bengali",          "bn",   "Muhiuddin Khan (Bengali)"),
    ("bs.korkut",           "bs",   "Besim Korkut (Bosnian)"),
    ("bs.mlivo",            "bs",   "Mustafa Mlivo (Bosnian)"),
    ("bg.theophanov",       "bg",   "Theophanov (Bulgarian)"),
    ("zh.jian",             "zh",   "Ma Jian (Chinese Simplified)"),
    ("zh.majian",           "zh",   "Ma Jian (Chinese Traditional)"),
    ("cs.hrbek",            "cs",   "Hrbek (Czech)"),
    ("cs.nykl",             "cs",   "Nykl (Czech)"),
    ("dv.divehi",           "dv",   "Divehi (Maldivian)"),
    ("nl.keyzer",           "nl",   "Keyzer (Dutch)"),
    ("nl.leemhuis",         "nl",   "Leemhuis (Dutch)"),
    ("nl.siregar",          "nl",   "Siregar (Dutch)"),
    ("en.ahmedali",         "en",   "Ahmed Ali (English)"),
    ("en.ahmedraza",        "en",   "Ahmed Raza Khan (English)"),
    ("en.arberry",          "en",   "Arberry (English)"),
    ("en.daryabadi",        "en",   "Daryabadi (English)"),
    ("en.hilali",           "en",   "Hilali & Khan (English)"),
    ("en.itani",            "en",   "Talal Itani (English)"),
    ("en.mubarakpuri",      "en",   "Mubarakpuri (English)"),
    ("en.pickthall",        "en",   "Pickthall (English)"),
    ("en.qarai",            "en",   "Ali Quli Qarai (English)"),
    ("en.qaribullah",       "en",   "Qaribullah & Darwish (English)"),
    ("en.sahih",            "en",   "Saheeh International (English)"),
    ("en.sarwar",           "en",   "Muhammad Sarwar (English)"),
    ("en.wahiduddin",       "en",   "Wahiduddin Khan (English)"),
    ("en.yusufali",         "en",   "Yusuf Ali (English)"),
    ("fr.hamidullah",       "fr",   "Hamidullah (French)"),
    ("de.aburida",          "de",   "Abu Rida (German)"),
    ("de.bubenheim",        "de",   "Bubenheim & Elyas (German)"),
    ("de.khoury",           "de",   "Khoury (German)"),
    ("de.zaidan",           "de",   "Zaidan (German)"),
    ("ha.gumi",             "ha",   "Gumi (Hausa)"),
    ("hi.farooq",           "hi",   "Farooq Khan & Ahmad (Hindi)"),
    ("hi.hindi",            "hi",   "Farooq Khan & Nadwi (Hindi)"),
    ("it.piccardo",         "it",   "Piccardo (Italian)"),
    ("ja.japanese",         "ja",   "Japanese Translation"),
    ("ko.korean",           "ko",   "Korean Translation"),
    ("ku.asan",             "ku",   "Burhan Muhammad-Amin (Kurdish)"),
    ("ms.basmeih",          "ms",   "Basmeih (Malay)"),
    ("ml.abdulhameed",      "ml",   "Abdul Hameed & Parappoor (Malayalam)"),
    ("ml.karakunnu",        "ml",   "Karakunnu & Elayavoor (Malayalam)"),
    ("no.berg",             "no",   "Einar Berg (Norwegian)"),
    ("ps.abdulwali",        "ps",   "Abdulwali Khan (Pashto)"),
    ("fa.ansarian",         "fa",   "Ansarian (Persian)"),
    ("fa.ayati",            "fa",   "Ayati (Persian)"),
    ("fa.bahrampour",       "fa",   "Bahrampour (Persian)"),
    ("fa.gharaati",         "fa",   "Gharaati (Persian)"),
    ("fa.ghomshei",         "fa",   "Elahi Ghomshei (Persian)"),
    ("fa.khorramdel",       "fa",   "Khorramdel (Persian)"),
    ("fa.khorramshahi",     "fa",   "Khorramshahi (Persian)"),
    ("fa.sadeqi",           "fa",   "Sadeqi Tehrani (Persian)"),
    ("fa.safavi",           "fa",   "Safavi (Persian)"),
    ("fa.fooladvand",       "fa",   "Fooladvand (Persian)"),
    ("fa.mojtabavi",        "fa",   "Mojtabavi (Persian)"),
    ("fa.moezzi",           "fa",   "Moezzi (Persian)"),
    ("fa.makarem",          "fa",   "Makarem Shirazi (Persian)"),
    ("pl.bielawskiego",     "pl",   "Bielawskiego (Polish)"),
    ("pt.elhayek",          "pt",   "El-Hayek (Portuguese)"),
    ("ro.grigore",          "ro",   "Grigore (Romanian)"),
    ("ru.abuadel",          "ru",   "Abu Adel (Russian)"),
    ("ru.muntahab",         "ru",   "Al-Muntahab (Russian)"),
    ("ru.kalam",            "ru",   "Kalam Sharif (Russian)"),
    ("ru.krachkovsky",      "ru",   "Krachkovsky (Russian)"),
    ("ru.kuliev",           "ru",   "Kuliev (Russian)"),
    ("ru.kuliev-alsaadi",   "ru",   "Kuliev + as-Saadi (Russian)"),
    ("ru.osmanov",          "ru",   "Osmanov (Russian)"),
    ("ru.porokhova",        "ru",   "Porokhova (Russian)"),
    ("ru.sablukov",         "ru",   "Sablukov (Russian)"),
    ("sd.amroti",           "sd",   "Amroti (Sindhi)"),
    ("so.abduh",            "so",   "Mahmud Abduh (Somali)"),
    ("es.bornez",           "es",   "Bornez (Spanish)"),
    ("es.cortes",           "es",   "Cortes (Spanish)"),
    ("es.garcia",           "es",   "Garcia (Spanish)"),
    ("sw.barwani",          "sw",   "Al-Barwani (Swahili)"),
    ("sv.bernstrom",        "sv",   "Bernstrom (Swedish)"),
    ("tg.ayati",            "tg",   "Ayati (Tajik)"),
    ("ta.tamil",            "ta",   "Jan Turst Foundation (Tamil)"),
    ("tt.nugman",           "tt",   "Yakub Ibn Nugman (Tatar)"),
    ("th.thai",             "th",   "King Fahad Complex (Thai)"),
    ("tr.golpinarli",       "tr",   "Golpinarli (Turkish)"),
    ("tr.bulac",            "tr",   "Ali Bulac (Turkish)"),
    ("tr.diyanet",          "tr",   "Diyanet Isleri (Turkish)"),
    ("tr.vakfi",            "tr",   "Diyanet Vakfi (Turkish)"),
    ("tr.yuksel",           "tr",   "Edip Yuksel (Turkish)"),
    ("tr.yazir",            "tr",   "Elmalili Hamdi Yazir (Turkish)"),
    ("tr.ozturk",           "tr",   "Yasar Nuri Ozturk (Turkish)"),
    ("tr.yildirim",         "tr",   "Suat Yildirim (Turkish)"),
    ("tr.ates",             "tr",   "Suleyman Ates (Turkish)"),
    ("ur.maududi",          "ur",   "Maududi (Urdu)"),
    ("ur.kanzuliman",       "ur",   "Ahmed Raza Khan (Urdu)"),
    ("ur.ahmedali",         "ur",   "Ahmed Ali (Urdu)"),
    ("ur.jalandhry",        "ur",   "Jalandhry (Urdu)"),
    ("ur.qadri",            "ur",   "Tahir ul Qadri (Urdu)"),
    ("ur.jawadi",           "ur",   "Syed Zeeshan Jawadi (Urdu)"),
    ("ur.junagarhi",        "ur",   "Muhammad Junagarhi (Urdu)"),
    ("ur.najafi",           "ur",   "Muhammad Hussain Najafi (Urdu)"),
    ("ug.saleh",            "ug",   "Muhammad Saleh (Uyghur)"),
    ("uz.sodik",            "uz",   "Muhammad Sodik (Uzbek)"),
]

# AlQuran.cloud uses different identifiers for some sources
# Map our source_id → alquran.cloud edition identifier
IDENTIFIER_MAP = {
    "en.shakir":        "en.shakir",
    "id.kemenag":       "id.kemenag",
    "sq.nahi":          "sq.nahi",
    "sq.mehdiu":        "sq.mehdiu",
    "sq.ahmeti":        "sq.ahmeti",
    "ber.mensur":       "ber.mensur",
    "am.sadiq":         "am.sadiq",
    "az.mammadaliyev":  "az.mammadaliyev",
    "az.musayev":       "az.musayev",
    "bn.hoque":         "bn.hoque",
    "bn.bengali":       "bn.bengali",
    "bs.korkut":        "bs.korkut",
    "bs.mlivo":         "bs.mlivo",
    "bg.theophanov":    "bg.theophanov",
    "zh.jian":          "zh.jian",
    "zh.majian":        "zh.majian",
    "cs.hrbek":         "cs.hrbek",
    "cs.nykl":          "cs.nykl",
    "dv.divehi":        "dv.divehi",
    "nl.keyzer":        "nl.keyzer",
    "nl.leemhuis":      "nl.leemhuis",
    "nl.siregar":       "nl.siregar",
    "en.ahmedali":      "en.ahmedali",
    "en.ahmedraza":     "en.ahmedraza",
    "en.arberry":       "en.arberry",
    "en.daryabadi":     "en.daryabadi",
    "en.hilali":        "en.hilali",
    "en.itani":         "en.itani",
    "en.mubarakpuri":   "en.mubarakpuri",
    "en.pickthall":     "en.pickthall",
    "en.qarai":         "en.qarai",
    "en.qaribullah":    "en.qaribullah",
    "en.sahih":         "en.sahih",
    "en.sarwar":        "en.sarwar",
    "en.wahiduddin":    "en.wahiduddin",
    "en.yusufali":      "en.yusufali",
    "fr.hamidullah":    "fr.hamidullah",
    "de.aburida":       "de.aburida",
    "de.bubenheim":     "de.bubenheim",
    "de.khoury":        "de.khoury",
    "de.zaidan":        "de.zaidan",
    "ha.gumi":          "ha.gumi",
    "hi.farooq":        "hi.farooq",
    "hi.hindi":         "hi.hindi",
    "it.piccardo":      "it.piccardo",
    "ja.japanese":      "ja.japanese",
    "ko.korean":        "ko.korean",
    "ku.asan":          "ku.asan",
    "ms.basmeih":       "ms.basmeih",
    "ml.abdulhameed":   "ml.abdulhameed",
    "ml.karakunnu":     "ml.karakunnu",
    "no.berg":          "no.berg",
    "ps.abdulwali":     "ps.abdulwali",
    "fa.ansarian":      "fa.ansarian",
    "fa.ayati":         "fa.ayati",
    "fa.bahrampour":    "fa.bahrampour",
    "fa.gharaati":      "fa.gharaati",
    "fa.ghomshei":      "fa.ghomshei",
    "fa.khorramdel":    "fa.khorramdel",
    "fa.khorramshahi":  "fa.khorramshahi",
    "fa.sadeqi":        "fa.sadeqi",
    "fa.safavi":        "fa.safavi",
    "fa.fooladvand":    "fa.fooladvand",
    "fa.mojtabavi":     "fa.mojtabavi",
    "fa.moezzi":        "fa.moezzi",
    "fa.makarem":       "fa.makarem",
    "pl.bielawskiego":  "pl.bielawskiego",
    "pt.elhayek":       "pt.elhayek",
    "ro.grigore":       "ro.grigore",
    "ru.abuadel":       "ru.abuadel",
    "ru.muntahab":      "ru.muntahab",
    "ru.kalam":         "ru.kalam",
    "ru.krachkovsky":   "ru.krachkovsky",
    "ru.kuliev":        "ru.kuliev",
    "ru.kuliev-alsaadi":"ru.kuliev-alsaadi",
    "ru.osmanov":       "ru.osmanov",
    "ru.porokhova":     "ru.porokhova",
    "ru.sablukov":      "ru.sablukov",
    "sd.amroti":        "sd.amroti",
    "so.abduh":         "so.abduh",
    "es.bornez":        "es.bornez",
    "es.cortes":        "es.cortes",
    "es.garcia":        "es.garcia",
    "sw.barwani":       "sw.barwani",
    "sv.bernstrom":     "sv.bernstrom",
    "tg.ayati":         "tg.ayati",
    "ta.tamil":         "ta.tamil",
    "tt.nugman":        "tt.nugman",
    "th.thai":          "th.thai",
    "tr.golpinarli":    "tr.golpinarli",
    "tr.bulac":         "tr.bulac",
    "tr.diyanet":       "tr.diyanet",
    "tr.vakfi":         "tr.vakfi",
    "tr.yuksel":        "tr.yuksel",
    "tr.yazir":         "tr.yazir",
    "tr.ozturk":        "tr.ozturk",
    "tr.yildirim":      "tr.yildirim",
    "tr.ates":          "tr.ates",
    "ur.maududi":       "ur.maududi",
    "ur.kanzuliman":    "ur.kanzuliman",
    "ur.ahmedali":      "ur.ahmedali",
    "ur.jalandhry":     "ur.jalandhry",
    "ur.qadri":         "ur.qadri",
    "ur.jawadi":        "ur.jawadi",
    "ur.junagarhi":     "ur.junagarhi",
    "ur.najafi":        "ur.najafi",
    "ug.saleh":         "ug.saleh",
    "uz.sodik":         "uz.sodik",
}

# ─── Helpers ────────────────────────────────────────────────────────────────────

def fetch_json(url: str, retries: int = 3, delay: float = 2.0) -> dict:
    """Fetch JSON from URL with retry logic."""
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "tafseer-id-indexer/1.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            print(f"    HTTPError {e.code} on attempt {attempt+1}/{retries}")
        except Exception as e:
            print(f"    Error on attempt {attempt+1}/{retries}: {e}")
        if attempt < retries - 1:
            time.sleep(delay * (attempt + 1))
    return None


def build_verses_dict_from_surahs(surahs: list) -> dict:
    """Convert list of surah objects (each with ayahs) to {verse_key: text} dict.
    API v1 returns: data.surahs[].ayahs[].{numberInSurah, text}
    """
    verses = {}
    for surah in surahs:
        surah_num = surah.get("number", 0)
        for ayah in surah.get("ayahs", []):
            ayah_num  = ayah.get("numberInSurah", 0)
            text      = ayah.get("text", "").strip()
            verse_key = f"{surah_num}:{ayah_num}"
            verses[verse_key] = text
    return verses


def download_source(source_id: str, name: str, lang: str) -> dict | None:
    """Download a single translation from AlQuran.cloud."""
    identifier = IDENTIFIER_MAP.get(source_id, source_id)
    url = ALQURAN_API.format(identifier=identifier)
    
    print(f"  -> Downloading {source_id} ({identifier}) ...", end=" ", flush=True)
    data = fetch_json(url)
    
    if not data or data.get("code") != 200:
        code = data.get("code") if data else "N/A"
        print(f"FAILED (code={code})")
        return None
    
    # API structure: data.surahs[114].ayahs[]
    surahs = data.get("data", {}).get("surahs", [])
    if not surahs:
        print("EMPTY")
        return None
    
    verses = build_verses_dict_from_surahs(surahs)
    print(f"OK ({len(verses)} verses)")
    
    return {
        "source_id": source_id,
        "name":      name,
        "language":  lang.upper(),
        "verses":    verses,
    }


def save_index(source_id: str, index_data: dict):
    """Save index JSON for a single source."""
    path = OUTPUT_DIR / f"{source_id}.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(index_data, f, ensure_ascii=False, separators=(",", ":"))
    size_kb = path.stat().st_size / 1024
    print(f"    Saved: {path.name} ({size_kb:.1f} KB)")


def update_manifest(built: list, failed: list):
    """Write/update manifest.json."""
    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total":        len(built),
        "sources":      sorted(built),
        "failed":       sorted(failed),
    }
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"\n✅ Manifest saved: {MANIFEST}")
    print(f"   Built:  {len(built)} sources")
    print(f"   Failed: {len(failed)} sources")
    if failed:
        print(f"   Failed list: {failed}")


# ─── Main ────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Build static Quran translation index")
    parser.add_argument("--source",  help="Build only this source (e.g. en.sahih)")
    parser.add_argument("--force",   action="store_true", help="Re-download even if file exists")
    parser.add_argument("--delay",   type=float, default=0.5, help="Delay between requests (seconds)")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Output directory: {OUTPUT_DIR}")
    print()

    sources_to_build = ALL_SOURCES
    if args.source:
        sources_to_build = [(s, l, n) for s, l, n in ALL_SOURCES if s == args.source]
        if not sources_to_build:
            print(f"ERROR: source '{args.source}' not found in ALL_SOURCES")
            sys.exit(1)

    built  = []
    failed = []

    for i, (source_id, lang, name) in enumerate(sources_to_build, 1):
        out_path = OUTPUT_DIR / f"{source_id}.json"
        print(f"[{i:3d}/{len(sources_to_build)}] {source_id}")

        # Skip if already built (unless --force)
        if out_path.exists() and not args.force:
            print(f"    Already exists, skipping (use --force to re-download)")
            built.append(source_id)
            continue

        index_data = download_source(source_id, name, lang)
        if index_data:
            save_index(source_id, index_data)
            built.append(source_id)
        else:
            failed.append(source_id)

        # Be polite to the API
        if i < len(sources_to_build):
            time.sleep(args.delay)

    update_manifest(built, failed)
    print("\nDone!")


if __name__ == "__main__":
    main()
