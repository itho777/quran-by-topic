import os

ayah_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(ayah_file, 'r', encoding='utf-8') as f:
    text = f.read()

# Add debug print inside initState
old_init = "    super.initState();"
new_init = "    super.initState();\n    debugPrint('AYAH_DETAIL_SCREEN init: surahId=${widget.surahId}, ayahNum=${widget.ayahNumber}, initialTab=${widget.initialTab}, initialTafsir=${widget.initialTafsir}');"

if old_init in text:
    text = text.replace(old_init, new_init, 1)
    print("Added debugPrint to initState")

# Add debug print inside build
old_build = "  Widget build(BuildContext context) {"
new_build = "  Widget build(BuildContext context) {\n    debugPrint('AYAH_DETAIL_SCREEN build: _loading=$_loading, initialTab=${widget.initialTab}, initialTafsir=${widget.initialTafsir}, controllerIndex=${_tabController.index}');"

if old_build in text:
    text = text.replace(old_build, new_build, 1)
    print("Added debugPrint to build")

with open(ayah_file, 'w', encoding='utf-8') as f:
    f.write(text)
print("Debug prints applied.")
