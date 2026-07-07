import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class TopicDetailScreen extends StatefulWidget {
  final String tagId;
  const TopicDetailScreen({super.key, required this.tagId});

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  Map<String, dynamic>? _tag;
  List<Map<String, dynamic>> _taggedVerses = [];
  bool _loading = true;
  String _currentLang = 'id'; // default to ID

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = Supabase.instance.client;

    try {
      // 1. Fetch Tag Info
      final tagRes = await db
          .from('tags')
          .select()
          .eq('id', widget.tagId)
          .limit(1);
      
      Map<String, dynamic>? tagData;
      if (tagRes.isNotEmpty) {
        tagData = tagRes.first;
        _currentLang = tagData['lang'] as String? ?? 'id';
      }

      // 2. Fetch all verses tagged with this topic
      final transSource = _currentLang == 'en' ? 'en.sahih' : 'id.kemenag';
      final versesRes = await db
          .from('verse_tags')
          .select('verse_id, verse_key, verses(text_ar, sura_id, ayah_number, translations(text, source_id))')
          .eq('tag_id', widget.tagId)
          .eq('verses.translations.source_id', transSource);

      final list = List<Map<String, dynamic>>.from(versesRes);
      
      // Sort sequentially by sura_id and ayah_number
      list.sort((a, b) {
        final aVerses = a['verses'] as Map<String, dynamic>?;
        final bVerses = b['verses'] as Map<String, dynamic>?;
        if (aVerses == null || bVerses == null) return 0;
        final aSura = aVerses['sura_id'] as int? ?? 0;
        final bSura = bVerses['sura_id'] as int? ?? 0;
        if (aSura != bSura) return aSura.compareTo(bSura);
        final aAyah = aVerses['ayah_number'] as int? ?? 0;
        final bAyah = bVerses['ayah_number'] as int? ?? 0;
        return aAyah.compareTo(bAyah);
      });

      setState(() {
        _tag = tagData;
        _taggedVerses = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading topic detail: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _currentLang == 'en';
    final tagName = _tag != null ? _tag!['name'] as String : widget.tagId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.outline),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.label_outline, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tagName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.outline),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary header
                Container(
                  width: double.infinity,
                  color: AppTheme.surfaceContainer,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${_taggedVerses.length} ${isEn ? 'verses' : 'ayat'}',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentLang.toUpperCase(),
                          style: const TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Verses list
                Expanded(
                  child: _taggedVerses.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_stories_outlined, size: 48, color: AppTheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  isEn ? 'No verses tagged under this topic.' : 'Belum ada ayat untuk topik ini.',
                                  style: const TextStyle(color: AppTheme.outline, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _taggedVerses.length,
                          itemBuilder: (context, i) {
                            final row = _taggedVerses[i];
                            final verseKey = row['verse_key'] as String? ?? '';
                            final verses = row['verses'] as Map<String, dynamic>?;
                            if (verses == null) return const SizedBox.shrink();

                            final arabic = verses['text_ar'] as String? ?? '';
                            final surahId = verses['sura_id'] as int? ?? 1;
                            final ayahNum = verses['ayah_number'] as int? ?? 1;
                            
                            // Extract translation text
                            final translations = verses['translations'] as List<dynamic>?;
                            String translationText = '';
                            if (translations != null && translations.isNotEmpty) {
                              translationText = (translations.first as Map<String, dynamic>)['text'] as String? ?? '';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.25)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => context.go('/surahs/$surahId/ayahs/$ayahNum'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Header row
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [AppTheme.primary, AppTheme.outlineVariant],
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                verseKey,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            const Icon(
                                              Icons.arrow_forward_ios,
                                              size: 12,
                                              color: AppTheme.outline,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Arabic
                                        if (arabic.isNotEmpty)
                                          Text(
                                            arabic,
                                            textDirection: TextDirection.rtl,
                                            textAlign: TextAlign.right,
                                            style: AppTheme.arabicStyle(fontSize: 20, color: AppTheme.primary),
                                          ),
                                        if (translationText.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          const Divider(color: AppTheme.outlineVariant),
                                          const SizedBox(height: 8),
                                          Text(
                                            translationText,
                                            style: const TextStyle(
                                              color: AppTheme.onSurfaceVariant,
                                              fontSize: 13,
                                              height: 1.6,
                                            ),
                                          ),
                                        ],
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
