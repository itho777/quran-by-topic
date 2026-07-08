import os

more_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\more\more_screen.dart"

with open(more_file, 'r', encoding='utf-8') as f:
    text = f.read()

old_import = "import 'package:flutter_riverpod/flutter_riverpod.dart';"
new_import = "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:go_router/go_router.dart';"

text_normalised = text.replace('\r\n', '\n')
if old_import in text_normalised:
    text_normalised = text_normalised.replace(old_import, new_import, 1)
    print("go_router import: ADDED")
else:
    print("WARNING: flutter_riverpod import not found!")

if '\r\n' in text:
    text_normalised = text_normalised.replace('\n', '\r\n')

with open(more_file, 'w', encoding='utf-8') as f:
    f.write(text_normalised)

print("Finished more_screen.dart import patching.")
