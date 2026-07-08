"""
Fix mushaf_screen.dart study panel scroll:
Replace Scrollable.ensureVisible (breaks on ListView.builder lazy rendering)
with index-based ScrollController.animateTo() which works even for off-screen items.
"""
import os

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(file_path, 'rb') as f:
    raw = f.read()

was_crlf = b'\r\n' in raw
text = raw.decode('latin-1').replace('\r\n', '\n')

# Old _scrollToActiveVerse that uses Scrollable.ensureVisible — broken for lazy list
old_scroll = """\
  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {
    // Ensure the study panel is open so the verse card is rendered
    if (!_studyPanelOpen) {
      setState(() {
        _studyPanelOpen = true;
        _studyMenuBarVisible = true;
        _startStudyMenuCollapseTimer();
      });
    }
    // Use two post-frame callbacks: first lets AnimatedPositioned finish,
    // second ensures the ListView item is laid out before scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _verseKeys[vId];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    });
  }"""

# New: use index-based scroll so it works even when the item isn't rendered yet
new_scroll = """\
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

if old_scroll in text:
    text = text.replace(old_scroll, new_scroll)
    print("_scrollToActiveVerse: FIXED")
else:
    print("ERROR: old pattern not found — printing context around 'Scrollable.ensureVisible'")
    idx = text.find("Scrollable.ensureVisible")
    if idx >= 0:
        print(repr(text[idx-300:idx+400]))
    else:
        print("Scrollable.ensureVisible not found at all")

if was_crlf:
    text = text.replace('\n', '\r\n')

with open(file_path, 'wb') as f:
    f.write(text.encode('latin-1'))

print("Done.")
