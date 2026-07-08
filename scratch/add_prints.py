import os

ayah_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(ayah_file, 'rb') as f:
    raw = f.read()

try:
    text = raw.decode('utf-8')
    enc = 'utf-8'
except UnicodeDecodeError:
    text = raw.decode('latin-1')
    enc = 'latin-1'

# Print inside initState
old_init = "    super.initState();"
new_init = "    super.initState();\n    print('AYAH_DETAIL_SCREEN init: surahId=${widget.surahId}, ayahNum=${widget.ayahNumber}, initialTab=${widget.initialTab}, initialTafsir=${widget.initialTafsir}');"

if old_init in text:
    text = text.replace(old_init, new_init, 1)
    print("Added print to initState")

# Print inside didUpdateWidget
old_did_update = "  void didUpdateWidget(covariant AyahDetailScreen oldWidget) {\n    super.didUpdateWidget(oldWidget);"
new_did_update = "  void didUpdateWidget(covariant AyahDetailScreen oldWidget) {\n    super.didUpdateWidget(oldWidget);\n    print('AYAH_DETAIL_SCREEN didUpdateWidget: initialTab=${widget.initialTab}, initialTafsir=${widget.initialTafsir}');"

if old_did_update in text:
    text = text.replace(old_did_update, new_did_update, 1)
    print("Added print to didUpdateWidget")

# Print inside build
old_build = "  Widget build(BuildContext context) {"
new_build = "  Widget build(BuildContext context) {\n    print('AYAH_DETAIL_SCREEN build: _loading=$_loading, initialTab=${widget.initialTab}, initialTafsir=${widget.initialTafsir}, controllerIndex=${_tabController.index}');"

if old_build in text:
    text = text.replace(old_build, new_build, 1)
    print("Added print to build")

with open(ayah_file, 'wb') as f:
    f.write(text.encode(enc))
print("Patched debug prints successfully.")
