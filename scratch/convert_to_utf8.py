import os

def convert_file(path):
    with open(path, 'rb') as f:
        raw = f.read()
    
    # Try decoding as UTF-8
    try:
        raw.decode('utf-8')
        print(f"{os.path.basename(path)} is already valid UTF-8.")
        return
    except UnicodeDecodeError:
        pass
    
    # Decode as latin-1
    text = raw.decode('latin-1')
    
    # Write back as UTF-8
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    print(f"Converted {os.path.basename(path)} to valid UTF-8.")

ayah_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"
mushaf_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"
surah_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\surah_detail\surah_detail_screen.dart"

convert_file(ayah_path)
convert_file(mushaf_path)
convert_file(surah_path)
