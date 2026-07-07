class Surah {
  final int id;
  final String nameAr;
  final String nameEn;
  final String nameId;
  final String meaning;
  final String meaningId;
  final int ayas;
  final String type;

  Surah({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.nameId,
    required this.meaning,
    required this.meaningId,
    required this.ayas,
    required this.type,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'] as int,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      nameId: json['name_id'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      meaningId: json['meaning_id'] as String? ?? '',
      ayas: json['ayas'] as int? ?? 0,
      type: json['type'] as String? ?? 'Meccan',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_en': nameEn,
      'name_id': nameId,
      'meaning': meaning,
      'meaning_id': meaningId,
      'ayas': ayas,
      'type': type,
    };
  }
}
