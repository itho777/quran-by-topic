import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/bookmarks_manager.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _loading = true);
    final list = await BookmarksManager.getBookmarks();
    // Sort by timestamp descending (newest first)
    list.sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
    setState(() {
      _bookmarks = list;
      _loading = false;
    });
  }

  Future<void> _deleteBookmark(String verseKey) async {
    final b = _bookmarks.firstWhere((element) => element['verseKey'] == verseKey);
    await BookmarksManager.toggleBookmark(
      surahId: b['surahId'] as int,
      ayahNumber: b['ayahNumber'] as int,
      surahName: b['surahName'] as String,
      verseKey: b['verseKey'] as String,
      textAr: b['textAr'] as String,
      translation: b['translation'] as String,
    );
    _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: const Text('Bookmarks', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_bookmarks.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh, color: AppTheme.primary),
              onPressed: _loadBookmarks,
            ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.outline),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark_outline, size: 64, color: AppTheme.secondary),
            ),
            const SizedBox(height: 20),
            Text(
              'No bookmarks yet',
              style: TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Bookmark your favorite verses on the ayah detail screen to view them here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.outline, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, i) {
        final b = _bookmarks[i];
        final verseKey = b['verseKey'] as String? ?? '';
        final surahName = b['surahName'] as String? ?? '';
        final ayahNumber = b['ayahNumber'] as int? ?? 1;
        final surahId = b['surahId'] as int? ?? 1;
        final textAr = b['textAr'] as String? ?? '';
        final translation = b['translation'] as String? ?? '';

        return Dismissible(
          key: Key(verseKey),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _deleteBookmark(verseKey),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go('/surahs/$surahId/ayahs/$ayahNumber'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$surahName : $ayahNumber',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            verseKey,
                            style: TextStyle(color: AppTheme.outline, fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.outline),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteBookmark(verseKey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        textAr,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: AppTheme.arabicStyle(fontSize: 22, color: AppTheme.onSurface),
                      ),
                      if (translation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Divider(color: AppTheme.outlineVariant),
                        const SizedBox(height: 6),
                        Text(
                          translation,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
