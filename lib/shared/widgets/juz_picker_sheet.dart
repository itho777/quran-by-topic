import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/juz_data.dart';
import 'juz_marker_icon.dart';
import 'islamic_star.dart';

class JuzPickerSheet extends StatefulWidget {
  final String currentLang;
  final int? currentJuz;

  const JuzPickerSheet({
    super.key,
    required this.currentLang,
    this.currentJuz,
  });

  @override
  State<JuzPickerSheet> createState() => _JuzPickerSheetState();
}

class _JuzPickerSheetState extends State<JuzPickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isEn = widget.currentLang == 'en';
    final query = _searchQuery.toLowerCase();

    final filteredJuz = JuzData.getAll().where((j) {
      if (query.isEmpty) return true;
      final hay = '${j['juz']} ${j['name_en']} ${j['name_ar']} ${j['start']}';
      return hay.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              JuzMarkerIcon(height: 46, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEn ? 'Select Juz' : 'Pilih Juz',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppTheme.outline),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search box
          TextField(
            autofocus: false,
            style: TextStyle(color: AppTheme.onSurface),
            onChanged: (v) {
              setState(() {
                _searchQuery = v;
              });
            },
            decoration: InputDecoration(
              hintText: isEn ? 'Search Juz by number or name…' : 'Cari Juz…',
              hintStyle: TextStyle(color: AppTheme.outline),
              prefixIcon: Icon(Icons.search, color: AppTheme.outline),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Count indicator
          Text(
            isEn
                ? 'Found ${filteredJuz.length} Juz'
                : 'Menampilkan ${filteredJuz.length} Juz',
            style: TextStyle(color: AppTheme.outline, fontSize: 11),
          ),
          const SizedBox(height: 8),
          // Juz list
          Expanded(
            child: ListView.builder(
              itemCount: filteredJuz.length,
              itemBuilder: (ctx, idx) {
                final j = filteredJuz[idx];
                final juzNum = j['juz'] as int;
                final isSelected = widget.currentJuz == juzNum;
                final name = 'Juz $juzNum';
                final arabicName = j['name_ar'] as String;
                final start = j['start'] as String;
                final (surah, ayah) = JuzData.parseStart(start);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/surahs/$surah/ayahs/$ayah');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.4),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: IslamicStar(
                              size: 40,
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.20)
                                  : AppTheme.primary.withValues(alpha: 0.10),
                              borderColor: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.primary.withValues(alpha: 0.35),
                              child: Text(
                                JuzData.toArabic(juzNum),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        arabicName,
                                        textDirection: TextDirection.rtl,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.outline,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Surah $surah : Ayah $ayah',
                                  style: TextStyle(
                                    color: AppTheme.outline,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check, color: AppTheme.primary, size: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}