import os
import json
import urllib.request
import urllib.error
import sys

# Color printing constants
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BLUE = "\033[94m"
END = "\033[0m"

def print_status(msg, color=GREEN):
    print(f"{color}{msg}{END}")

# 1. LOAD CONFIGURATION
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_key:
    print_status("Supabase credentials not found in environment variables.", RED)
    print("Please enter them manually:")
    supabase_url = input("Enter SUPABASE_URL (e.g. https://xxxx.supabase.co): ").strip()
    supabase_key = input("Enter SUPABASE_SERVICE_ROLE_KEY (Service Role Key, NOT Anon Key): ").strip()

if not supabase_url.endswith("/"):
    supabase_url += "/"

# 2. UTILITY FUNCTION FOR RAW POSTGREST BATCH INSERTS
def send_batch(table, records):
    url = f"{supabase_url}rest/v1/{table}"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }
    
    # Convert records to JSON string and then to bytes
    data = json.dumps(records).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    
    retries = 3
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req) as response:
                return response.read()
        except urllib.error.HTTPError as e:
            # Read detailed error message from response
            err_msg = e.read().decode("utf-8")
            if attempt == retries - 1:
                print_status(f"\n[Error] Failed to insert into {table} (HTTP {e.code}): {err_msg}", RED)
                raise e
            print_status(f"\n[Warning] Retrying batch insert into {table} (Attempt {attempt+1}/{retries})...", YELLOW)
        except Exception as e:
            if attempt == retries - 1:
                print_status(f"\n[Error] Connection error during batch insert into {table}: {e}", RED)
                raise e
            print_status(f"\n[Warning] Retrying batch insert into {table} (Attempt {attempt+1}/{retries})...", YELLOW)

def fetch_table(table, select_query="*"):
    url = f"{supabase_url}rest/v1/{table}?select={select_query}"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}"
    }
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception as e:
        print_status(f"Error fetching from table {table}: {e}", RED)
        return []

# 3. MIGRATION RUNNER
def run_migration():
    print_status("===================================================", BLUE)
    print_status("Starting Quran by Topic Supabase Migration", BLUE)
    print_status("===================================================", BLUE)

    # Path detection
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data_dir = os.path.join(base_dir, "data")
    
    if not os.path.exists(data_dir):
        print_status(f"Error: Data directory not found at {data_dir}", RED)
        sys.exit(1)

    # --- A. MIGRATE SURAHS ---
    print_status("\n--- 1. Migrating Surahs ---", YELLOW)
    suras_file = os.path.join(data_dir, "sura_list.json")
    with open(suras_file, "r", encoding="utf-8-sig") as f:
        suras = json.load(f)
    
    suras_records = []
    for s in suras:
        suras_records.append({
            "id": s["id"],
            "name_ar": s["name_ar"],
            "name_en": s["name_en"],
            "name_id": s["name_id"],
            "meaning": s["meaning"],
            "meaning_id": s["meaning_id"],
            "ayas": s["ayas"],
            "type": s["type"]
        })
    send_batch("surahs", suras_records)
    print_status(f"Successfully migrated {len(suras_records)} Surahs.")

    # --- B. MIGRATE VERSES ---
    print_status("\n--- 2. Migrating Verses ---", YELLOW)
    arabic_file = os.path.join(data_dir, "quran_arabic.json")
    with open(arabic_file, "r", encoding="utf-8-sig") as f:
        arabic_data = json.load(f)
    
    verses_records = []
    for key, text in arabic_data.items():
        sura_id, ayah_number = map(int, key.split(":"))
        verses_records.append({
            "sura_id": sura_id,
            "ayah_number": ayah_number,
            "verse_key": key,
            "text_ar": text
        })
    
    # Batch upload verses (1000 at a time)
    batch_size = 1000
    for i in range(0, len(verses_records), batch_size):
        chunk = verses_records[i:i+batch_size]
        send_batch("verses", chunk)
        print(f"Uploaded verses {i+1} to {min(i+batch_size, len(verses_records))}...", end="\r")
    print_status(f"\nSuccessfully migrated {len(verses_records)} Verses.")

    # Fetch mapping of verse_key -> id from DB to resolve foreign keys efficiently
    print_status("Fetching database verse IDs for mapping...", BLUE)
    db_verses = fetch_table("verses", "id,verse_key")
    verse_key_to_id = {v["verse_key"]: v["id"] for v in db_verses}
    
    if not verse_key_to_id:
        print_status("Error: Could not retrieve mapped verse IDs from database.", RED)
        sys.exit(1)

    # --- C. MIGRATE TRANSLATIONS ---
    print_status("\n--- 3. Migrating Translations ---", YELLOW)
    trans_dir = os.path.join(data_dir, "translations")
    trans_files = [f for f in os.listdir(trans_dir) if f.endswith(".json")]
    
    for filename in trans_files:
        source_id = filename[:-5] # remove ".json" extension
        filepath = os.path.join(trans_dir, filename)
        
        with open(filepath, "r", encoding="utf-8-sig") as f:
            trans_data = json.load(f)
            
        trans_records = []
        for key, text in trans_data.items():
            if key in verse_key_to_id:
                trans_records.append({
                    "verse_id": verse_key_to_id[key],
                    "verse_key": key,
                    "source_id": source_id,
                    "text": text
                })
        
        # Batch upload
        for i in range(0, len(trans_records), batch_size):
            send_batch("translations", trans_records[i:i+batch_size])
        print_status(f"Migrated translation: {source_id} ({len(trans_records)} entries)")

    # --- D. MIGRATE TAFSIRS ---
    print_status("\n--- 4. Migrating Tafsirs ---", YELLOW)
    tafsir_dir = os.path.join(data_dir, "tafsirs")
    tafsir_files = [f for f in os.listdir(tafsir_dir) if f.endswith(".json")]
    
    for filename in tafsir_files:
        source_id = filename[:-5]
        filepath = os.path.join(tafsir_dir, filename)
        
        with open(filepath, "r", encoding="utf-8-sig") as f:
            tafsir_data = json.load(f)
            
        tafsir_records = []
        for key, text in tafsir_data.items():
            if key in verse_key_to_id:
                tafsir_records.append({
                    "verse_id": verse_key_to_id[key],
                    "verse_key": key,
                    "source_id": source_id,
                    "text": text
                })
                
        # Batch upload
        for i in range(0, len(tafsir_records), batch_size):
            send_batch("tafsirs", tafsir_records[i:i+batch_size])
        print_status(f"Migrated tafsir: {source_id} ({len(tafsir_records)} entries)")

    # --- E. MIGRATE ASBABUN NUZUL ---
    print_status("\n--- 5. Migrating Asbabun Nuzul ---", YELLOW)
    nuzul_dir = os.path.join(data_dir, "asbabun_nuzul")
    nuzul_files = [f for f in os.listdir(nuzul_dir) if f.endswith(".json")]
    
    for filename in nuzul_files:
        source_id = filename[:-5]
        filepath = os.path.join(nuzul_dir, filename)
        
        with open(filepath, "r", encoding="utf-8-sig") as f:
            nuzul_data = json.load(f)
            
        nuzul_records = []
        for key, text in nuzul_data.items():
            if key in verse_key_to_id:
                nuzul_records.append({
                    "verse_id": verse_key_to_id[key],
                    "verse_key": key,
                    "source_id": source_id,
                    "text": text
                })
                
        # Batch upload
        for i in range(0, len(nuzul_records), batch_size):
            send_batch("asbabun_nuzul", nuzul_records[i:i+batch_size])
        print_status(f"Migrated Asbabun Nuzul: {source_id} ({len(nuzul_records)} entries)")

    # --- F. MIGRATE TAGS / TOPICS ---
    print_status("\n--- 6. Migrating Topic Tags ---", YELLOW)
    
    # Load Indonesian tags
    with open(os.path.join(data_dir, "tags_id.json"), "r", encoding="utf-8-sig") as f:
        tags_id = json.load(f)
    # Load English tags
    with open(os.path.join(data_dir, "tags_en.json"), "r", encoding="utf-8-sig") as f:
        tags_en = json.load(f)
    
    # Send each language as a SEPARATE batch to avoid duplicate ID conflicts
    # within a single upsert request (both lang files share the same ID numbers)
    tags_id_records = [{"id": t["id"], "name": t["name"], "lang": "id"} for t in tags_id]
    tags_en_records = [{"id": t["id"], "name": t["name"], "lang": "en"} for t in tags_en]
    
    send_batch("tags", tags_id_records)
    print_status(f"Migrated {len(tags_id_records)} Indonesian tag definitions.")
    send_batch("tags", tags_en_records)
    print_status(f"Migrated {len(tags_en_records)} English tag definitions.")

    # --- G. MIGRATE VERSE-TAG MAPPINGS ---
    print_status("\n--- 7. Migrating Verse-Tag Mappings ---", YELLOW)
    
    # Indonesian mapping
    with open(os.path.join(data_dir, "verse_tags_id.json"), "r", encoding="utf-8-sig") as f:
        vtags_id = json.load(f)
    # English mapping
    with open(os.path.join(data_dir, "verse_tags_en.json"), "r", encoding="utf-8-sig") as f:
        vtags_en = json.load(f)
        
    vtags_records = []
    
    # Parse Indonesian maps
    for key, tag_list in vtags_id.items():
        if key in verse_key_to_id:
            verse_id = verse_key_to_id[key]
            for tag_id in tag_list:
                vtags_records.append({
                    "verse_id": verse_id,
                    "verse_key": key,
                    "tag_id": tag_id,
                    "tag_lang": "id",
                    "lang": "id"
                })
                
    # Parse English maps
    for key, tag_list in vtags_en.items():
        if key in verse_key_to_id:
            verse_id = verse_key_to_id[key]
            for tag_id in tag_list:
                vtags_records.append({
                    "verse_id": verse_id,
                    "verse_key": key,
                    "tag_id": tag_id,
                    "tag_lang": "en",
                    "lang": "en"
                })
                
    # Batch upload mappings
    total_maps = len(vtags_records)
    for i in range(0, total_maps, batch_size):
        send_batch("verse_tags", vtags_records[i:i+batch_size])
        print(f"Uploaded mapping {i+1} to {min(i+batch_size, total_maps)}...", end="\r")
        
    print_status(f"\nSuccessfully migrated {total_maps} verse-topic mappings!")
    print_status("\n===================================================", GREEN)
    print_status("Supabase Migration Completed Successfully!", GREEN)
    print_status("===================================================", GREEN)

if __name__ == "__main__":
    run_migration()
