import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  List<Map<String, dynamic>> _tags = [];
  Map<String, int> _verseCounts = {}; // tag_id -> verse count
  bool _loading = true;
  String _lang = 'id';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = Supabase.instance.client;

      // 1. Fetch all tags for selected language
      final res = await db.from('tags').select().eq('lang', _lang);
      final list = List<Map<String, dynamic>>.from(res);
      list.sort((a, b) =>
          (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

      // 2. Fetch verse counts per tag from verse_tags
      final countRes = await db
          .from('verse_tags')
          .select('tag_id')
          .eq('lang', _lang);
      final counts = <String, int>{};
      for (final row in countRes) {
        final id = row['tag_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }

      setState(() {
        _tags = list;
        _verseCounts = counts;
        _loading = false;
      });
    } catch (e) {
      debugPrint('TopicScreen load error: $e');
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _tags;
    return _tags
        .where((t) => (t['name'] as String? ?? '')
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isId = _lang == 'id';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: const Text('Topics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Language Toggle Pill
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: ['en', 'id'].map((lang) {
                  final active = _lang == lang;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _lang = lang;
                        _searchQuery = '';
                      });
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: active ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5)) : null,
                      ),
                      child: Text(
                        lang.toUpperCase(),
                        style: TextStyle(
                          color: active ? AppTheme.primary : AppTheme.outline,
                          fontSize: 11,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.outline),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              style: TextStyle(color: AppTheme.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: isId ? 'Cari topik...' : 'Search topics...',
                prefixIcon: Icon(Icons.search, color: AppTheme.outline, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppTheme.outline, size: 16),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Summary strip
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_filtered.length} ${isId ? 'topik' : 'topics'}',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_verseCounts.values.fold(0, (a, b) => a + b)} ${isId ? 'pemetaan' : 'mappings'}',
                      style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // List
          if (_loading)
            Expanded(
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            )
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_off_outlined, size: 48, color: AppTheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      isId ? 'Tidak ada topik.' : 'No topics found.',
                      style: TextStyle(color: AppTheme.outline, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final tag = _filtered[i];
                  final tagId = tag['id'] as String;
                  final tagName = tag['name'] as String? ?? tagId;
                  final count = _verseCounts[tagId] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.go('/topics/$tagId'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.label_outline, color: AppTheme.secondary, size: 17),
                              ),
                              const SizedBox(width: 12),
                              // Name
                              Expanded(
                                child: Text(
                                  tagName,
                                  style: TextStyle(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Verse count badge
                              if (count > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right, color: AppTheme.outline, size: 16),
                            ],
                          ),
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
