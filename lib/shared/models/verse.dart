class Verse {
  final int id;
  final int suraId;
  final int ayahNumber;
  final String verseKey;
  final String textAr;
  final int pageNumber;
  final int juzNumber;

  Verse({
    required this.id,
    required this.suraId,
    required this.ayahNumber,
    required this.verseKey,
    required this.textAr,
    required this.pageNumber,
    required this.juzNumber,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      id: json['id'] as int,
      suraId: json['sura_id'] as int,
      ayahNumber: json['ayah_number'] as int,
      verseKey: json['verse_key'] as String? ?? '',
      textAr: json['text_ar'] as String? ?? '',
      pageNumber: json['page_number'] as int? ?? 1,
      juzNumber: json['juz_number'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sura_id': suraId,
      'ayah_number': ayahNumber,
      'verse_key': verseKey,
      'text_ar': textAr,
      'page_number': pageNumber,
      'juz_number': juzNumber,
    };
  }
}
