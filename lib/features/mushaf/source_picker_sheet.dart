import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/quran_sources.dart';

class SourcePickerSheet extends StatefulWidget {
  final String title;
  final Map<String, QuranSource> sources;
  final String currentSource;
  final ValueChanged<String> onSelected;

  const SourcePickerSheet({
    super.key,
    required this.title,
    required this.sources,
    required this.currentSource,
    required this.onSelected,
  });

  @override
  State<SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<SourcePickerSheet> {
  String _searchQuery = '';
  late List<QuranSource> _filteredList;

  @override
  void initState() {
    super.initState();
    _filteredList = widget.sources.values.toList();
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredList = widget.sources.values.where((src) {
        final nameMatch = src.name.toLowerCase().contains(query.toLowerCase());
        final idMatch = src.id.toLowerCase().contains(query.toLowerCase());
        final langMatch = src.language.toLowerCase().contains(query.toLowerCase());
        return nameMatch || idMatch || langMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isEn = widget.title.toLowerCase().contains('select');
    return Container(
      height: media.size.height * 0.7,
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: media.viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.outline),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search Field
          TextField(
            onChanged: _filter,
            style: const TextStyle(color: AppTheme.onSurface),
            decoration: InputDecoration(
              hintText: isEn ? 'Search source...' : 'Cari sumber...',
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
          const SizedBox(height: 16),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredList.length,
              itemBuilder: (context, index) {
                final src = _filteredList[index];
                final isSelected = src.id == widget.currentSource;
                return ListTile(
                  title: Text(
                    src.name,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${src.id} (${src.language})',
                    style: const TextStyle(color: AppTheme.outline, fontSize: 11),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    widget.onSelected(src.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
