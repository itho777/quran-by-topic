"""
Re-apply ALL mushaf_screen.dart fixes in one pass:
1. Two-step scroll (_scrollToActiveVerse) — works in both directions
2. Immediate _isPlaying flag in _playAudioForVerse
3. Info button: safe firstWhere + null guard on sura_id/ayah_number  
4. _copyActiveAyah: safe firstWhere + dynamic URL via Uri.base
5. verse_key casts: null-safe
"""
import os, re

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(file_path, 'rb') as f:
    raw = f.read()
was_crlf = b'\r\n' in raw
text = raw.decode('utf-8', errors='replace').replace('\r\n', '\n')

def replace_once(text, old, new, label):
    if old in text:
        text = text.replace(old, new, 1)
        print(f"  FIXED: {label}")
    else:
        print(f"  SKIP (not found): {label}")
    return text

# ── 1. Two-step scroll ──────────────────────────────────────────────────────
old_scroll = """\
  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {
    // Ensure the study panel is open so the verse card is rendered
    if (!_studyPanelOpen) {
      setState(() => _studyPanelOpen = true);
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

# Try alternative with 2-line open block
old_scroll2 = """\
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

    final idx = _pageVerses.indexWhere((v) => v['id'] == vId);
    if (idx < 0) return;

    // Two-step scroll — works in BOTH directions with ListView.builder.
    // Step 1: jumpTo(approx) forces the item into the render tree.
    // Step 2: ensureVisible animates to the exact pixel position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_studyPanelScrollController.hasClients) return;

      const double approxCardHeight = 140.0;
      const double listPadding = 12.0;
      final approxOffset = listPadding + idx * approxCardHeight;
      final maxScroll = _studyPanelScrollController.position.maxScrollExtent;
      _studyPanelScrollController.jumpTo(approxOffset.clamp(0.0, maxScroll));

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

if old_scroll in text:
    text = replace_once(text, old_scroll, new_scroll, "_scrollToActiveVerse two-step (v1)")
elif old_scroll2 in text:
    text = replace_once(text, old_scroll2, new_scroll, "_scrollToActiveVerse two-step (v2)")
else:
    # find and show actual body
    si = text.find('void _scrollToActiveVerse')
    if si >= 0:
        print("  WARNING: pattern mismatch. Actual body:")
        print(repr(text[si:si+600]))
    else:
        print("  ERROR: _scrollToActiveVerse not found at all")

# ── 2. Immediate _isPlaying in _playAudioForVerse ──────────────────────────
old_play_setState = """\
    if (mounted) {
      setState(() {
        _playingVerseId = vId;
        _selectedVerseId = vId;
        _selectedVerseKey = verse['verse_key'] as String;
      });
    }"""

new_play_setState = """\
    if (mounted) {
      setState(() {
        _playingVerseId = vId;
        _selectedVerseId = vId;
        _selectedVerseKey = (verse['verse_key'] as String?) ?? '';
        _isPlaying = true; // Highlight immediately while audio loads
      });
    }"""

text = replace_once(text, old_play_setState, new_play_setState,
                    "_playAudioForVerse immediate isPlaying + null-safe verse_key")

# ── 3. Info button: safe navigation ────────────────────────────────────────
old_info = """\
                        onPressed: () async {
                          if (_selectedVerseId != null) {
                            final current = _pageVerses.firstWhere((v) => v['id'] == _selectedVerseId);
                            ref.read(hideNavBarProvider.notifier).state = false;
                            await context.push('/surahs/${current['sura_id']}/ayahs/${current['ayah_number']}');
                            if (mounted) {
                              ref.read(hideNavBarProvider.notifier).state = true;
                            }
                          }
                        },"""

new_info = """\
                        onPressed: () async {
                          if (_selectedVerseId != null && _pageVerses.isNotEmpty) {
                            final current = _pageVerses.firstWhere(
                              (v) => v['id'] == _selectedVerseId,
                              orElse: () => _pageVerses.first,
                            );
                            final sId = current['sura_id'];
                            final aNum = current['ayah_number'];
                            if (sId == null || aNum == null) return;
                            ref.read(hideNavBarProvider.notifier).state = false;
                            await context.push('/surahs/$sId/ayahs/$aNum');
                            if (mounted) {
                              ref.read(hideNavBarProvider.notifier).state = true;
                            }
                          }
                        },"""

text = replace_once(text, old_info, new_info, "info button safe nav")

# ── 4. _copyActiveAyah: safe firstWhere + dynamic URL ──────────────────────
old_copy = """\
  void _copyActiveAyah() {
    if (_selectedVerseId == null) return;
    final current = _pageVerses.firstWhere((v) => v['id'] == _selectedVerseId);
    final surahId = current['sura_id'];
    final ayahNum = current['ayah_number'];
    final link = 'https://tafseer.id/surahs/$surahId/ayahs/$ayahNum';"""

new_copy = """\
  void _copyActiveAyah() {
    if (_selectedVerseId == null || _pageVerses.isEmpty) return;
    final current = _pageVerses.firstWhere(
      (v) => v['id'] == _selectedVerseId,
      orElse: () => _pageVerses.first,
    );
    final surahId = current['sura_id'];
    final ayahNum = current['ayah_number'];
    final base = Uri.base;
    final origin = base.host.isNotEmpty
        ? '${base.scheme}://${base.host}${base.port != 80 && base.port != 443 && base.port != 0 ? ':${base.port}' : ''}'
        : 'https://tafseer.id';
    final link = '$origin/#/surahs/$surahId/ayahs/$ayahNum';"""

text = replace_once(text, old_copy, new_copy, "_copyActiveAyah safe + dynamic URL")

# ── 5. Null-safe verse_key casts ───────────────────────────────────────────
text = replace_once(text,
    "    final vKey = verse['verse_key'] as String;",
    "    final vKey = (verse['verse_key'] as String?) ?? '';",
    "vKey cast null-safe (selectVerse)")

text = replace_once(text,
    "        _selectedVerseKey = verse['verse_key'] as String;",
    "        _selectedVerseKey = (verse['verse_key'] as String?) ?? '';",
    "verse_key cast null-safe (playAudioForVerse)")

if was_crlf:
    text = text.replace('\n', '\r\n')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(text)

print("\nAll done. File size:", os.path.getsize(file_path))
