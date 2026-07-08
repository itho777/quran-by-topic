import os

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ─── 1. Fix the padding of the Quran page ───
# We use a broad replacement that matches the exact spacing in the file
old_padding = """                      return Center(

                        child: Padding(

                          padding: const EdgeInsets.only(

                            top: 90.0,

                            bottom: 90.0,

                          ),"""

new_padding = """                      return Center(

                        child: AnimatedPadding(

                          duration: const Duration(milliseconds: 300),

                          curve: Curves.easeInOut,

                          padding: EdgeInsets.only(

                            top: _menusVisible ? 90.0 : 0.0,

                            bottom: showStudyPanel ? 300.0 : (_menusVisible ? 90.0 : 20.0),

                          ),"""

# Normalize any CRLF to LF just in case, replace, and write back
content_normalised = content.replace('\r\n', '\n')
old_padding_normalised = old_padding.replace('\r\n', '\n')
new_padding_normalised = new_padding.replace('\r\n', '\n')

if old_padding_normalised in content_normalised:
    content_normalised = content_normalised.replace(old_padding_normalised, new_padding_normalised)
    print("Padding replaced successfully in v2.")
else:
    print("Padding pattern not found in v2! Attempting regex...")
    import re
    # Match child: Padding( ... padding: const EdgeInsets.only( ... top: 90.0, ... bottom: 90.0, ... )
    pattern = r"child:\s*Padding\(\s*padding:\s*const\s*EdgeInsets\.only\(\s*top:\s*90\.0,\s*bottom:\s*90\.0,\s*\),"
    match = re.search(pattern, content_normalised)
    if match:
        matched_str = match.group(0)
        print("Found regex match:", repr(matched_str))
        replacement = """child: AnimatedPadding(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: EdgeInsets.only(
                            top: _menusVisible ? 90.0 : 0.0,
                            bottom: showStudyPanel ? 300.0 : (_menusVisible ? 90.0 : 20.0),
                          ),"""
        content_normalised = content_normalised.replace(matched_str, replacement)
        print("Padding replaced via regex successfully.")
    else:
        print("Regex match failed too.")

# Restore CRLF
if '\r\n' in content:
    content_normalised = content_normalised.replace('\n', '\r\n')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content_normalised)

print("Finished processing file v2.")
