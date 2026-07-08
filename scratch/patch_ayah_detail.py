import re

path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(path, 'rb') as f:
    raw = f.read()

try:
    text = raw.decode('utf-8')
    enc = 'utf-8'
except UnicodeDecodeError:
    text = raw.decode('latin-1')
    enc = 'latin-1'

old = """  @override
  void didUpdateWidget(covariant AyahDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahId != widget.surahId ||
        oldWidget.ayahNumber != widget.ayahNumber ||
        oldWidget.initialTafsir != widget.initialTafsir ||
        oldWidget.initialTab != widget.initialTab) {
      _selectedSurahId = widget.surahId;
      _ayahController.text = widget.ayahNumber.toString();
      _isPlaying = false;
      _audioPlayer.stop();
      // Reset so _buildSlots re-applies the new initialTafsir
      _initialSourceApplied = false;
      _loadAllData();
    }
  }"""

new = """  @override
  void didUpdateWidget(covariant AyahDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahId != widget.surahId ||
        oldWidget.ayahNumber != widget.ayahNumber ||
        oldWidget.initialTafsir != widget.initialTafsir ||
        oldWidget.initialTab != widget.initialTab) {
      _selectedSurahId = widget.surahId;
      _ayahController.text = widget.ayahNumber.toString();
      _isPlaying = false;
      _audioPlayer.stop();
      // Reset so _buildSlots re-applies the new initialTafsir
      _initialSourceApplied = false;
      // Immediately switch to the requested tab before data reload
      if (widget.initialTab != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tabController.animateTo(widget.initialTab!);
        });
      }
      _loadAllData();
    }
  }"""

if old in text:
    text = text.replace(old, new, 1)
    print("didUpdateWidget patch applied")
else:
    print("ERROR: Target text not found!")
    # Try to find close match
    idx = text.find("void didUpdateWidget")
    if idx >= 0:
        print("Found didUpdateWidget at char:", idx)
        print("Context:", repr(text[idx:idx+500]))

with open(path, 'wb') as f:
    f.write(text.encode(enc))
print("Done.")
