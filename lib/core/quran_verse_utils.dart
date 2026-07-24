// Utility functions for Quran verse numbering.
// The Quran SVG files use sequential verse IDs (1–6236) as element IDs,
// e.g. id="verse-6208". This differs from the Supabase DB primary key.

/// Verse counts for each of the 114 surahs (index 0 = Surah 1).
const List<int> kSurahVerseCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, // 1–10
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135,  // 11–20
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60,     // 21–30
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85,       // 31–40
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45,        // 41–50
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13,        // 51–60
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44,        // 61–70
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42,        // 71–80
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20,        // 81–90
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11,             // 91–100
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3,                 // 101–110
  5, 4, 5, 6,                                     // 111–114
];

/// Returns the sequential verse number (1–6236) for a given surah + ayah.
/// This matches the SVG element `id="verse-N"` used in the Quran page images.
int quranSvgVerseId(int surahId, int ayahNumber) {
  int total = 0;
  for (int i = 0; i < surahId - 1; i++) {
    total += kSurahVerseCounts[i];
  }
  return total + ayahNumber;
}
