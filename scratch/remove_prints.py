import os

ayah_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(ayah_file, 'r', encoding='utf-8') as f:
    text = f.read()

# Remove the print statements we added
text = text.replace("    print('AYAH_DETAIL_SCREEN init: surahId=${widget.surahId}, ayahNum=${widget.ayahNumber}, initialTab=${widget.initialTab}, initialTafsir=${widget.initialTafsir}');\n", "")
text = text.replace("    print('AYAH_DETAIL_SCREEN didUpdateWidget: initialTab=${widget.initialTab}, initialTafsir=${widget.initialTafsir}');\n", "")
text = text.replace("    print('AYAH_DETAIL_SCREEN build: _loading=$_loading, initialTab=${widget.initialTab}, initialTafsir=${widget.initialTafsir}, controllerIndex=${_tabController.index}');\n", "")

with open(ayah_file, 'w', encoding='utf-8') as f:
    f.write(text)
print("Debug prints removed successfully.")
