/// Juz (Paras) data — 30 Juz, each with start surah:ayah and name
class JuzData {
  static const List<Map<String, dynamic>> juzList = [
    {'juz': 1, 'name_en': 'Juz 1', 'name_ar': 'الجزء الأول', 'start': '1:1'},
    {'juz': 2, 'name_en': 'Juz 2', 'name_ar': 'الجزء الثاني', 'start': '2:142'},
    {'juz': 3, 'name_en': 'Juz 3', 'name_ar': 'الجزء الثالث', 'start': '2:253'},
    {'juz': 4, 'name_en': 'Juz 4', 'name_ar': 'الجزء الرابع', 'start': '3:93'},
    {'juz': 5, 'name_en': 'Juz 5', 'name_ar': 'الجزء الخامس', 'start': '4:24'},
    {'juz': 6, 'name_en': 'Juz 6', 'name_ar': 'الجزء السادس', 'start': '4:148'},
    {'juz': 7, 'name_en': 'Juz 7', 'name_ar': 'الجزء السابع', 'start': '5:82'},
    {'juz': 8, 'name_en': 'Juz 8', 'name_ar': 'الجزء الثامن', 'start': '6:111'},
    {'juz': 9, 'name_en': 'Juz 9', 'name_ar': 'الجزء التاسع', 'start': '7:88'},
    {'juz': 10, 'name_en': 'Juz 10', 'name_ar': 'الجزء العاشر', 'start': '8:41'},
    {'juz': 11, 'name_en': 'Juz 11', 'name_ar': 'الجزء الحادي عشر', 'start': '9:93'},
    {'juz': 12, 'name_en': 'Juz 12', 'name_ar': 'الجزء الثاني عشر', 'start': '11:6'},
    {'juz': 13, 'name_en': 'Juz 13', 'name_ar': 'الجزء الثالث عشر', 'start': '12:53'},
    {'juz': 14, 'name_en': 'Juz 14', 'name_ar': 'الجزء الرابع عشر', 'start': '15:1'},
    {'juz': 15, 'name_en': 'Juz 15', 'name_ar': 'الجزء الخامس عشر', 'start': '17:1'},
    {'juz': 16, 'name_en': 'Juz 16', 'name_ar': 'الجزء السادس عشر', 'start': '18:75'},
    {'juz': 17, 'name_en': 'Juz 17', 'name_ar': 'الجزء السابع عشر', 'start': '20:135'},
    {'juz': 18, 'name_en': 'Juz 18', 'name_ar': 'الجزء الثامن عشر', 'start': '22:78'},
    {'juz': 19, 'name_en': 'Juz 19', 'name_ar': 'الجزء التاسع عشر', 'start': '25:21'},
    {'juz': 20, 'name_en': 'Juz 20', 'name_ar': 'الجزء العشرون', 'start': '27:56'},
    {'juz': 21, 'name_en': 'Juz 21', 'name_ar': 'الجزء الحادي والعشرون', 'start': '29:46'},
    {'juz': 22, 'name_en': 'Juz 22', 'name_ar': 'الجزء الثاني والعشرون', 'start': '33:31'},
    {'juz': 23, 'name_en': 'Juz 23', 'name_ar': 'الجزء الثالث والعشرون', 'start': '36:28'},
    {'juz': 24, 'name_en': 'Juz 24', 'name_ar': 'الجزء الرابع والعشرون', 'start': '39:32'},
    {'juz': 25, 'name_en': 'Juz 25', 'name_ar': 'الجزء الخامس والعشرون', 'start': '41:47'},
    {'juz': 26, 'name_en': 'Juz 26', 'name_ar': 'الجزء السادس والعشرون', 'start': '46:1'},
    {'juz': 27, 'name_en': 'Juz 27', 'name_ar': 'الجزء السابع والعشرون', 'start': '51:31'},
    {'juz': 28, 'name_en': 'Juz 28', 'name_ar': 'الجزء الثامن والعشرون', 'start': '58:1'},
    {'juz': 29, 'name_en': 'Juz 29', 'name_ar': 'الجزء التاسع والعشرون', 'start': '67:1'},
    {'juz': 30, 'name_en': 'Juz 30', 'name_ar': 'الجزء الثلاثون', 'start': '78:1'},
  ];

  /// Parse "sura:ayah" → (suraId, ayahNumber)
  static (int, int) parseStart(String s) {
    final parts = s.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Get Juz data by number (1-30)
  static Map<String, dynamic>? getJuz(int juz) {
    if (juz < 1 || juz > 30) return null;
    return juzList.firstWhere((j) => j['juz'] == juz);
  }

  /// Get all Juz for display
  static List<Map<String, dynamic>> getAll() => juzList;

  static const List<String> _arabicDigits = [
    '\u0660', '\u0661', '\u0662', '\u0663', '\u0664',
    '\u0665', '\u0666', '\u0667', '\u0668', '\u0669',
  ];

  /// Convert any digits in [value] to Arabic-Indic (١٢٣).
  /// Non-digits pass through, so '2:142' becomes '٢:١٤٢'.
  static String toArabic(Object value) {
    return value.toString().split('').map((ch) {
      final digit = int.tryParse(ch);
      return digit == null ? ch : _arabicDigits[digit];
    }).join();
  }
}