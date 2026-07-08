"""
Fix the isPlaying highlight logic in the study panel:
1. The card highlight uses `isPlaying = vId == _playingVerseId && _isPlaying`
   This causes the highlight to DROP during the ~200ms transition between verses
   because _isPlaying momentarily becomes false between onComplete → play().
2. Fix: highlight any verse whose id == _playingVerseId, 
   regardless of whether _isPlaying is momentarily false.
   Use a separate isPausedOnVerse check to distinguish "paused" styling.
"""
import os

file_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart"

with open(file_path, 'rb') as f:
    raw = f.read()

was_crlf = b'\r\n' in raw
text = raw.decode('latin-1').replace('\r\n', '\n')

# Old highlight check: drops during transition
old_check = "              final isPlaying = vId == _playingVerseId && _isPlaying;"

# New: highlight any verse that is the active playing/loading verse
new_check = """\
              // Highlight the playing/loading verse even during brief inter-verse pause
              final isPlaying = vId == _playingVerseId && (_isPlaying || _playingVerseId != null);"""

if old_check in text:
    text = text.replace(old_check, new_check)
    print("isPlaying check: FIXED")
else:
    print("Pattern not found for isPlaying check")
    idx = text.find("isPlaying = vId == _playingVerseId")
    if idx > 0:
        print(repr(text[idx-50:idx+100]))

# Also: ensure _isPlaying is set to true AT THE SAME TIME as _playingVerseId
# in _playAudioForVerse — not after await _audioPlayer.play()
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
        _isPlaying = true; // Mark as playing immediately so highlight shows
      });
    }"""

if old_setState in text:
    text = text.replace(old_setState, new_setState)
    print("_playAudioForVerse setState: FIXED (set _isPlaying=true immediately)")
else:
    print("Pattern not found for _playAudioForVerse setState")

if was_crlf:
    text = text.replace('\n', '\r\n')

with open(file_path, 'wb') as f:
    f.write(text.encode('latin-1'))

print("Done.")
