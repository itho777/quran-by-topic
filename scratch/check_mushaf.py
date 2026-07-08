f = open('lib/features/mushaf/mushaf_screen.dart', 'rb')
raw = f.read()
f.close()
text = raw.decode('utf-8', errors='replace')

# Check _scrollToActiveVerse
idx = text.find('_scrollToActiveVerse')
print('scrollToActiveVerse found at:', idx)
if idx > 0:
    print(text[idx:idx+600])

print('---')
print('Has Scrollable.ensureVisible:', 'Scrollable.ensureVisible' in text)
print('Has Uri.base:', 'Uri.base' in text)
print('Has tafseer.id hardcoded link:', 'tafseer.id/surahs' in text)

# Find _copyActiveAyah
ci = text.find('_copyActiveAyah')
if ci > 0:
    print('copyActiveAyah at:', ci)
    print(text[ci:ci+400])
