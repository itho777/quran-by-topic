import os

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ─── 1. Fix the top and bottom padding of the Quran page ───
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

# Normalize line endings to avoid match failures
content_normalised = content.replace('\r\n', '\n')
old_padding_normalised = old_padding.replace('\r\n', '\n')
new_padding_normalised = new_padding.replace('\r\n', '\n')

if old_padding_normalised in content_normalised:
    content_normalised = content_normalised.replace(old_padding_normalised, new_padding_normalised)
    print("Padding fixed successfully.")
else:
    print("Padding pattern not found!")

# ─── 2. Fix _scrollToActiveVerse for robust scroll behavior ───
old_scroll_fn = """  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {
    // Open study panel if needed
    if (!_studyPanelOpen) {
      setState(() {
        _studyPanelOpen = true;
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

new_scroll_fn = """  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {
    if (!_studyPanelOpen) {
      setState(() {
        _studyPanelOpen = true;
      });
    }

    final idx = _pageVerses.indexWhere((v) => v['id'] == vId);
    if (idx < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_studyPanelScrollController.hasClients) return;

      // Scroll immediately and smoothly to the estimated offset
      const double approxCardHeight = 150.0;
      const double listPadding = 12.0;
      final approxOffset = (listPadding + idx * approxCardHeight).clamp(
        0.0,
        _studyPanelScrollController.position.maxScrollExtent,
      );

      _studyPanelScrollController.animateTo(
        approxOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        // After reaching the estimated area, precisely align the card if rendered
        final key = _verseKeys[vId];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            alignment: 0.1,
          );
        }
      });
    });
  }"""

old_scroll_normalised = old_scroll_fn.replace('\r\n', '\n')
new_scroll_normalised = new_scroll_fn.replace('\r\n', '\n')

if old_scroll_normalised in content_normalised:
    content_normalised = content_normalised.replace(old_scroll_normalised, new_scroll_normalised)
    print("Scroll function fixed successfully.")
else:
    # Try finding old function with different comments/newlines
    idx = content_normalised.find("void _scrollToActiveVerse")
    if idx != -1:
        print("Found _scrollToActiveVerse but exact match failed. Index:", idx)
        # Let's replace the whole method dynamically
        end_idx = content_normalised.find("  String _getAudioUrl", idx)
        if end_idx != -1:
            method_body = content_normalised[idx:end_idx].strip()
            content_normalised = content_normalised.replace(method_body, new_scroll_normalised.strip())
            print("Scroll function replaced dynamically.")
        else:
            print("Could not find end of _scrollToActiveVerse")
    else:
        print("Scroll function not found at all!")

# Restore line endings
if '\r\n' in content:
    content_normalised = content_normalised.replace('\n', '\r\n')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content_normalised)

print("Finished processing file.")
