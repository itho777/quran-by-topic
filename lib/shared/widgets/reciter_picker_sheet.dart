import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/quran_sources.dart';

class ReciterPickerSheet extends StatefulWidget {
  final String currentReciter;
  final String currentLang;
  final ValueChanged<String> onSelected;

  const ReciterPickerSheet({
    super.key,
    required this.currentReciter,
    required this.currentLang,
    required this.onSelected,
  });

  @override
  State<ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<ReciterPickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isEn = widget.currentLang == 'en';
    final query = _searchQuery.toLowerCase();

    // Filter reciters based on search query
    final filteredReciters = QuranSources.reciters.entries.where((entry) {
      if (query.isEmpty) return true;
      final folder = entry.key.toLowerCase();
      final displayName = entry.value.toLowerCase();
      return folder.contains(query) || displayName.contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
              const Icon(Icons.record_voice_over, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEn ? 'Select Reciter' : 'Pilih Qori',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.outline),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search box
          TextField(
            autofocus: false,
            style: const TextStyle(color: AppTheme.onSurface),
            onChanged: (v) {
              setState(() {
                _searchQuery = v;
              });
            },
            decoration: InputDecoration(
              hintText: isEn ? 'Search reciter by name…' : 'Cari qori…',
              hintStyle: const TextStyle(color: AppTheme.outline),
              prefixIcon: const Icon(Icons.search, color: AppTheme.outline),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Count indicator
          Text(
            isEn 
                ? 'Found ${filteredReciters.length} reciters' 
                : 'Menampilkan ${filteredReciters.length} qori',
            style: const TextStyle(color: AppTheme.outline, fontSize: 11),
          ),
          const SizedBox(height: 8),
          // Reciter list
          Expanded(
            child: ListView.builder(
              itemCount: filteredReciters.length,
              itemBuilder: (ctx, idx) {
                final entry = filteredReciters[idx];
                final isSelected = widget.currentReciter == entry.key;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      widget.onSelected(entry.key);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withOpacity(0.12)
                            : AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.outlineVariant.withOpacity(0.4),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? AppTheme.primary : AppTheme.outline,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check, color: AppTheme.primary, size: 16),
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
