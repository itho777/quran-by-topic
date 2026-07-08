import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/download_service.dart';
import '../../core/local_db.dart';
import '../../core/quran_sources.dart';
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State model for a single downloadable item card
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadItem {
  final String sourceType; // 'translation' | 'tafsir' | 'nuzul' | 'mushaf' | 'audio'
  final String sourceId;
  final String label;
  final String subtitle;
  final IconData icon;

  int downloaded = 0;
  int total = 0;
  String status = 'idle'; // idle | downloading | completed | error | paused
  String? error;

  _DownloadItem({
    required this.sourceType,
    required this.sourceId,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  double get progress => total > 0 ? downloaded / total : 0;
  bool get isDownloaded => status == 'completed';
  bool get isDownloading => status == 'downloading';
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Active download stream subscriptions keyed by sourceId
  final Map<String, StreamSubscription<DownloadProgress>> _subs = {};

  // All downloadable items by category
  final List<_DownloadItem> _translations = [];
  final List<_DownloadItem> _tafsirs = [];
  final List<_DownloadItem> _mushaf = [];
  final List<_DownloadItem> _audio = [];

  // Storage stats
  int _mushafBytes = 0;
  int _audioBytes = 0;
  int _textBytes = 0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _buildItems();
    _loadManifest();
    _loadStorageStats();
  }

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _tabController.dispose();
    super.dispose();
  }

  // ── Build static item lists ───────────────────────────────────────────────

  void _buildItems() {
    // Translations (key popular ones first)
    const priorityTranslations = ['id.kemenag', 'en.sahih', 'en.yusufali', 'en.pickthall'];
    for (final id in priorityTranslations) {
      final src = QuranSources.translations[id];
      if (src != null) {
        _translations.add(_DownloadItem(
          sourceType: 'translation',
          sourceId: id,
          label: src.name,
          subtitle: '6,236 ayahs · ${src.language}',
          icon: Icons.translate_rounded,
        ));
      }
    }

    // Tafsirs
    final tafsirEntries = [
      ('id.tafsir_jalalayn', 'Tafsir Jalalayn (ID)', 'Indonesian'),
      ('id.tafsir_ibnu_katsir', 'Tafsir Ibnu Katsir (ID)', 'Indonesian'),
      ('en.tafsir_ibn_kathir', 'Tafsir Ibn Kathir (EN)', 'English'),
    ];
    for (final (id, name, lang) in tafsirEntries) {
      _tafsirs.add(_DownloadItem(
        sourceType: 'tafsir',
        sourceId: id,
        label: name,
        subtitle: '6,236 ayahs · $lang',
        icon: Icons.menu_book_rounded,
      ));
    }
    // Asbabun Nuzul
    _tafsirs.add(_DownloadItem(
      sourceType: 'nuzul',
      sourceId: 'asbabun_nuzul',
      label: 'Asbabun Nuzul',
      subtitle: 'Causes of Revelation · Indonesian',
      icon: Icons.history_edu_rounded,
    ));

    // Mushaf Pages
    _mushaf.add(_DownloadItem(
      sourceType: 'mushaf',
      sourceId: 'hafs_kfqc',
      label: 'Mushaf KFQC · Quranpedia Vector',
      subtitle: '604 pages · ~9 MB · Interactive SVG',
      icon: Icons.auto_stories_rounded,
    ));

    // Audio — use reciters from QuranSources
    for (final entry in QuranSources.reciters.entries.take(10)) {
      _audio.add(_DownloadItem(
        sourceType: 'audio',
        sourceId: entry.key,
        label: entry.value, // reciters is Map<String, String>
        subtitle: '114 surahs · MP3',
        icon: Icons.headphones_rounded,
      ));
    }
  }

  // ── Load manifest from SQLite ─────────────────────────────────────────────

  Future<void> _loadManifest() async {
    final manifests = await LocalDatabase.instance.getAllManifests();
    final map = <String, Map<String, dynamic>>{};
    for (final m in manifests) {
      final key = '${m['source_type']}::${m['source_id']}';
      map[key] = m;
    }

    void applyManifest(_DownloadItem item) {
      final key = '${item.sourceType}::${item.sourceId}';
      final m = map[key];
      if (m != null) {
        item.status = m['status'] as String? ?? 'idle';
        item.downloaded = m['downloaded_items'] as int? ?? 0;
        item.total = m['total_items'] as int? ?? 0;
      }
    }

    for (final item in [..._translations, ..._tafsirs, ..._mushaf, ..._audio]) {
      applyManifest(item);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadStorageStats() async {
    try {
      final appDoc = await getApplicationDocumentsDirectory();
      final mushafDir = Directory('${appDoc.path}/mushaf');
      final audioDir = Directory('${appDoc.path}/audio');
      final dbFile = File('${appDoc.path}/tafseer_cache.db');

      int mushafBytes = 0;
      int audioBytes = 0;
      final textBytes = dbFile.existsSync() ? await dbFile.length() : 0;

      if (mushafDir.existsSync()) {
        await for (final f in mushafDir.list(recursive: true)) {
          if (f is File) mushafBytes += await f.length();
        }
      }
      if (audioDir.existsSync()) {
        await for (final f in audioDir.list(recursive: true)) {
          if (f is File) audioBytes += await f.length();
        }
      }

      if (mounted) {
        setState(() {
          _mushafBytes = mushafBytes;
          _audioBytes = audioBytes;
          _textBytes = textBytes;
        });
      }
    } catch (_) {}
  }

  // ── Download logic ────────────────────────────────────────────────────────

  void _startDownload(_DownloadItem item) {
    final svc = ref.read(downloadServiceProvider);
    final key = '${item.sourceType}::${item.sourceId}';

    // Cancel any existing subscription for this item
    _subs[key]?.cancel();

    Stream<DownloadProgress> stream;
    switch (item.sourceType) {
      case 'translation':
        stream = svc.downloadTextSource(
          sourceType: 'translation',
          table: 'translations',
          sourceId: item.sourceId,
          label: item.label,
        );
      case 'tafsir':
        stream = svc.downloadTextSource(
          sourceType: 'tafsir',
          table: 'tafsirs',
          sourceId: item.sourceId,
          label: item.label,
        );
      case 'nuzul':
        stream = svc.downloadTextSource(
          sourceType: 'nuzul',
          table: 'asbabun_nuzul',
          sourceId: item.sourceId,
          label: item.label,
        );
      case 'mushaf':
        stream = svc.downloadMushafPages();
      case 'audio':
        stream = svc.downloadAllAudioSurahs(
          reciterId: item.sourceId,
          reciterName: item.label,
        );
      default:
        return;
    }

    if (mounted) setState(() => item.status = 'downloading');

    _subs[key] = stream.listen(
      (progress) {
        if (mounted) {
          setState(() {
            item.downloaded = progress.downloaded;
            item.total = progress.total;
            item.status = progress.status;
            item.error = progress.error;
          });
        }
        if (progress.status == 'completed') {
          _loadStorageStats();
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            item.status = 'error';
            item.error = e.toString();
          });
        }
      },
    );
  }

  Future<void> _deleteItem(_DownloadItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        title: Text('Delete "${item.label}"?',
            style: TextStyle(color: AppTheme.onSurface)),
        content: Text(
          'This will remove the offline copy. You can re-download it anytime.',
          style: TextStyle(color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final svc = ref.read(downloadServiceProvider);
    switch (item.sourceType) {
      case 'translation':
        await svc.deleteTextSource('translations', 'translation', item.sourceId);
      case 'tafsir':
        await svc.deleteTextSource('tafsirs', 'tafsir', item.sourceId);
      case 'nuzul':
        await svc.deleteTextSource('asbabun_nuzul', 'nuzul', item.sourceId);
      case 'mushaf':
        await svc.deleteMushafPages();
      case 'audio':
        await svc.deleteAllAudioSurahs(item.sourceId);
    }

    if (mounted) {
      setState(() {
        item.status = 'idle';
        item.downloaded = 0;
        item.total = 0;
      });
    }
    _loadStorageStats();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.onSurfaceVariant,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.translate_rounded), text: 'Translations'),
                Tab(icon: Icon(Icons.menu_book_rounded), text: 'Tafsirs'),
                Tab(icon: Icon(Icons.auto_stories_rounded), text: 'Mushaf'),
                Tab(icon: Icon(Icons.headphones_rounded), text: 'Audio'),
              ],
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_translations),
                  _buildList(_tafsirs),
                  _buildList(_mushaf),
                  _buildList(_audio),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    String _fmtBytes(int bytes) {
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withOpacity(0.9),
            AppTheme.secondary.withOpacity(0.7),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Offline Library',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              _StoragePill(icon: Icons.auto_stories_rounded,
                  label: 'Mushaf ${_fmtBytes(_mushafBytes)}'),
              const SizedBox(width: 8),
              _StoragePill(icon: Icons.headphones_rounded,
                  label: 'Audio ${_fmtBytes(_audioBytes)}'),
              const SizedBox(width: 8),
              _StoragePill(icon: Icons.text_snippet_rounded,
                  label: 'Text ${_fmtBytes(_textBytes)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<_DownloadItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _DownloadCard(
        item: items[i],
        onDownload: () => _startDownload(items[i]),
        onDelete: () => _deleteItem(items[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Download Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadCard extends StatelessWidget {
  final _DownloadItem item;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _DownloadCard({
    required this.item,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = item.isDownloaded;
    final bool isActive = item.isDownloading;
    final bool hasError = item.status == 'error';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? AppTheme.primary.withOpacity(0.5)
              : hasError
                  ? AppTheme.error.withOpacity(0.4)
                  : AppTheme.outline.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDone
                      ? [AppTheme.primary, AppTheme.secondary]
                      : [
                          AppTheme.surfaceContainerHigh,
                          AppTheme.surfaceContainerHigh
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon,
                  color: isDone ? AppTheme.onPrimary : AppTheme.onSurfaceVariant,
                  size: 24),
            ),
            title: Text(item.label,
                style: TextStyle(
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.subtitle,
                    style: TextStyle(
                        color: AppTheme.onSurfaceVariant, fontSize: 12)),
                if (hasError && item.error != null)
                  Text('Error: ${item.error}',
                      style: TextStyle(color: AppTheme.error, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: _buildTrailing(isDone, isActive, hasError),
          ),
          if (isActive) _buildProgressBar(),
          if (isDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary, size: 16),
                  const SizedBox(width: 6),
                  Text('Available offline',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 14, color: AppTheme.error),
                    label: Text('Remove',
                        style: TextStyle(color: AppTheme.error, fontSize: 12)),
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailing(bool isDone, bool isActive, bool hasError) {
    if (isActive) {
      return SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          value: item.progress > 0 ? item.progress : null,
          color: AppTheme.primary,
          strokeWidth: 3,
        ),
      );
    }
    if (isDone) {
      return Icon(Icons.cloud_done_rounded, color: AppTheme.primary, size: 28);
    }
    if (hasError) {
      return IconButton(
        icon: Icon(Icons.refresh_rounded, color: AppTheme.error),
        onPressed: onDownload,
        tooltip: 'Retry',
      );
    }
    return FilledButton.icon(
      onPressed: onDownload,
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('Download'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildProgressBar() {
    final pct = item.total > 0
        ? '${item.downloaded} / ${item.total}'
        : 'Starting…';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress > 0 ? item.progress : null,
              color: AppTheme.primary,
              backgroundColor: AppTheme.outline.withOpacity(0.15),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(pct,
              style: TextStyle(
                  color: AppTheme.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Storage Pill (header stat chip)
// ─────────────────────────────────────────────────────────────────────────────

class _StoragePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StoragePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
