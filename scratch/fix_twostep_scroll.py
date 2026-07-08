"""
Fix _scrollToActiveVerse with two-step scroll + immediate isPlaying highlight.
Uses errors='replace' so any unrepresentable chars are preserved safely.
"""
import os

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(file_path, 'rb') as f:
    raw = f.read()

was_crlf = b'\r\n' in raw

# Decode with errors='replace' so we never fail, then normalise to LF
text = raw.decode('utf-8', errors='replace').replace('\r\n', '\n')

# ---- Replace the current animateTo _scrollToActiveVerse ----
old_fn = """\
  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {
    // Open study panel if needed
    if (!_studyPanelOpen) {
      setState(() {
        _studyPanelOpen = true;
        _studyMenuBarVisible = true;
        _startStudyMenuCollapseTimer();
      });
    }

    // Compute target index in the list
    final idx = _pageVerses.indexWhere((v) => v['id'] == vId);
    if (idx < 0) return;

    // Estimated card height (Arabic + translation + padding).
    // Slightly over-estimate so we always scroll far enough.
    const double estimatedCardHeight = 130.0;
    const double listTopPadding = 12.0;

    final targetOffset = listTopPadding + idx * estimatedCardHeight;

    // Give the panel one frame to open/layout, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_studyPanelScrollController.hasClients) return;
      final maxScroll = _studyPanelScrollController.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxScroll);
      _studyPanelScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }"""

new_fn = """\
  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {
    // Open study panel if needed
    if (!_studyPanelOpen) {
      setState(() {
        _studyPanelOpen = true;
        _studyMenuBarVisible = true;
        _startStudyMenuCollapseTimer();
      });
    }

    final idx = _pageVerses.indexWhere((v) => v['id'] == vId);
    if (idx < 0) return;

    // Two-step scroll — works in BOTH directions with ListView.builder:
    //
    // Step 1: jumpTo(approxOffset) moves the viewport immediately so the
    //   target card enters the rendered area (GlobalKey gets a context).
    //
    // Step 2: Scrollable.ensureVisible animates to the exact rendered position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_studyPanelScrollController.hasClients) return;

      const double approxCardHeight = 140.0;
      const double listPadding = 12.0;
      final approxOffset = listPadding + idx * approxCardHeight;
      final maxScroll = _studyPanelScrollController.position.maxScrollExtent;
      _studyPanelScrollController.jumpTo(approxOffset.clamp(0.0, maxScroll));

      // One more frame → item is now rendered → precise scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _verseKeys[vId];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.1,
          );
        }
      });
    });
  }"""

if old_fn in text:
    text = text.replace(old_fn, new_fn)
    print("_scrollToActiveVerse two-step: FIXED")
else:
    idx = text.find("void _scrollToActiveVerse")
    if idx >= 0:
        print("Current body:\n" + repr(text[idx:idx+1000]))
    else:
        print("ERROR: function not found")

# ---- Set _isPlaying immediately in _playAudioForVerse ----
old_setState = """\
    if (mounted) {
      setState(() {
        _playingVerseId = vId;
        _selectedVerseId = vId;
        _selectedVerseKey = (verse['verse_key'] as String?) ?? '';
      });
    }"""

new_setState = """\
    if (mounted) {
      setState(() {
        _playingVerseId = vId;
        _selectedVerseId = vId;
        _selectedVerseKey = (verse['verse_key'] as String?) ?? '';
        _isPlaying = true; // Highlight immediately while audio loads
      });
    }"""

if old_setState in text:
    text = text.replace(old_setState, new_setState)
    print("Immediate _isPlaying highlight: FIXED")
else:
    print("_playAudioForVerse setState not found")

if was_crlf:
    text = text.replace('\n', '\r\n')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(text)

print("Done.")
