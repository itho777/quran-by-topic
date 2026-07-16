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
  bool get isPartial => !isDownloaded && !isDownloading && downloaded > 0 && total > 0;
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

  // Fix #1: Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Build static item lists ───────────────────────────────────────────────

  void _buildItems() {
    // Fix #1: Load ALL translations from QuranSources, sorted by language then name.
    // Prioritise Indonesian and English entries at the top.
    const priority = ['id.kemenag', 'en.sahih', 'en.yusufali', 'en.pickthall'];
    final remaining = QuranSources.translations.keys
        .where((k) => !priority.contains(k))
        .toList()
      ..sort();
    for (final id in [...priority, ...remaining]) {
      final src = QuranSources.translations[id];
      if (src == null) continue;
      _translations.add(_DownloadItem(
        sourceType: 'translation',
        sourceId: id,
        label: src.name,
        subtitle: '6,236 ayahs · ${src.language}',
        icon: Icons.translate_rounded,
      ));
    }

    // Fix #1: Load ALL tafsirs from QuranSources.
    for (final entry in QuranSources.tafsirs.entries) {
      _tafsirs.add(_DownloadItem(
        sourceType: 'tafsir',
        sourceId: entry.key,
        label: entry.value.name,
        subtitle: '6,236 ayahs · ${entry.value.language}',
        icon: Icons.menu_book_rounded,
      ));
    }
    // Fix #1: Load ALL asbabun nuzul from QuranSources.
    for (final entry in QuranSources.asbabunNuzul.entries) {
      _tafsirs.add(_DownloadItem(
        sourceType: 'nuzul',
        sourceId: entry.key,
        label: entry.value.name,
        subtitle: '6,236 entries · ${entry.value.language}',
        icon: Icons.history_edu_rounded,
      ));
    }

    // Mushaf Pages
    _mushaf.add(_DownloadItem(
      sourceType: 'mushaf',
      sourceId: 'hafs_kfqc',
      label: 'Mushaf KFQC · Quranpedia Vector',
      subtitle: '604 pages · ~9 MB · Interactive SVG',
      icon: Icons.auto_stories_rounded,
    ));

    // Fix #1: Deduplicate reciters — for reciters with the same display-name base,
    // keep only the highest bitrate entry.
    // Strategy: parse kbps from the key (e.g., 'Alafasy_128kbps' → 128),
    // group by the normalised display name (strip bitrate from label),
    // and emit only the one with the highest kbps.
    final Map<String, MapEntry<String, int>> best = {}; // normKey → (id, kbps)
    final _kbpsRe = RegExp(r'(\d+)kbps', caseSensitive: false);
    for (final entry in QuranSources.reciters.entries) {
      final key = entry.key;
      final label = entry.value;
      // Parse kbps from key
      final kbpsMatch = _kbpsRe.firstMatch(key);
      final kbps = kbpsMatch != null ? int.tryParse(kbpsMatch.group(1)!) ?? 0 : 0;
      // Normalise display name: remove '(NNkbps)' and trailing source sites
      final normLabel = label
          .replaceAll(_kbpsRe, '')
          .replaceAll(RegExp(r'\(\s*\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(\w+\.\w+\)', caseSensitive: false), '')
          .replaceAll(RegExp(r',\s*'), ' ')
          .trim()
          .toLowerCase();
      final existing = best[normLabel];
      if (existing == null || kbps > existing.value) {
        best[normLabel] = MapEntry(key, kbps);
      }
    }
    // Sort deduped reciters alphabetically by label
    final dedupedIds = best.values.map((e) => e.key).toList()
      ..sort((a, b) {
        final la = QuranSources.reciters[a] ?? a;
        final lb = QuranSources.reciters[b] ?? b;
        return la.compareTo(lb);
      });
    for (final id in dedupedIds) {
      final label = QuranSources.reciters[id] ?? id;
      _audio.add(_DownloadItem(
        sourceType: 'audio',
        sourceId: id,
        label: label,
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

  void _startDownload(_DownloadItem item, {bool resume = false}) {
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
          resume: resume,
        );
      case 'tafsir':
        stream = svc.downloadTextSource(
          sourceType: 'tafsir',
          table: 'tafsirs',
          sourceId: item.sourceId,
          label: item.label,
          resume: resume,
        );
      case 'nuzul':
        stream = svc.downloadTextSource(
          sourceType: 'nuzul',
          table: 'asbabun_nuzul',
          sourceId: item.sourceId,
          label: item.label,
          resume: resume,
        );
      case 'mushaf':
        stream = svc.downloadMushafPages(resume: resume);
      case 'audio':
        stream = svc.downloadAllAudioSurahs(
          reciterId: item.sourceId,
          reciterName: item.label,
          resume: resume,
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

  void _pauseDownload(_DownloadItem item) async {
    final key = '${item.sourceType}::${item.sourceId}';
    await _subs[key]?.cancel();
    _subs.remove(key);

    if (mounted) {
      setState(() {
        item.status = 'paused';
      });
    }

    final db = LocalDatabase.instance;
    await db.upsertManifest(
      sourceType: item.sourceType,
      sourceId: item.sourceId,
      label: item.label,
      status: 'paused',
      totalItems: item.total,
      downloadedItems: item.downloaded,
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
    String fmtBytes(int bytes) {
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.surfaceContainer,
            title: const Text('Offline Library',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(136),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: AppTheme.surfaceContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(Icons.storage_rounded, size: 14, color: AppTheme.outline),
                        const SizedBox(width: 6),
                        Text(
                          'Mushaf: ${fmtBytes(_mushafBytes)}  •  Audio: ${fmtBytes(_audioBytes)}  •  Text: ${fmtBytes(_textBytes)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Fix #1: Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(color: AppTheme.onSurface, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search…',
                        hintStyle: TextStyle(color: AppTheme.outline, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.outline, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, size: 16, color: AppTheme.outline),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.surfaceContainerHigh,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.onSurfaceVariant,
                    indicatorColor: AppTheme.primary,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 11),
                    tabs: const [
                      Tab(icon: Icon(Icons.translate_rounded, size: 18), text: 'Trans.'),
                      Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Tafsir'),
                      Tab(icon: Icon(Icons.auto_stories_rounded, size: 18), text: 'Mushaf'),
                      Tab(icon: Icon(Icons.headphones_rounded, size: 18), text: 'Audio'),
                    ],
                  ),
                ],
              ),
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

  Widget _buildList(List<_DownloadItem> items) {
    final filtered = items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchesName = item.label.toLowerCase().contains(q);
      final matchesId = item.sourceId.toLowerCase().contains(q);
      final matchesSub = item.subtitle.toLowerCase().contains(q);
      return matchesName || matchesId || matchesSub;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: AppTheme.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text('No results for "$_searchQuery"',
                  style: TextStyle(color: AppTheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) => _DownloadCard(
        item: filtered[i],
        onDownload: () => _startDownload(filtered[i]),
        onResume: () => _startDownload(filtered[i], resume: true),
        onPause: () => _pauseDownload(filtered[i]),
        onDelete: () => _deleteItem(filtered[i]),
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
  final VoidCallback onResume;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  const _DownloadCard({
    required this.item,
    required this.onDownload,
    required this.onResume,
    required this.onPause,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = item.isDownloaded;
    final bool isActive = item.isDownloading;
    final bool hasError = item.status == 'error';
    final bool isPartial = item.isPartial;

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
                  : isPartial
                      ? AppTheme.secondary.withOpacity(0.45)
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
                      : isPartial
                          ? [AppTheme.secondary.withOpacity(0.7), AppTheme.secondary]
                          : [
                              AppTheme.surfaceContainerHigh,
                              AppTheme.surfaceContainerHigh
                            ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon,
                  color: isDone || isPartial ? AppTheme.onPrimary : AppTheme.onSurfaceVariant,
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
            trailing: _buildTrailing(isDone, isActive, hasError, isPartial),
          ),
          if (isActive) _buildProgressBar(),
          if (isPartial) _buildResumeBar(),
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

  Widget _buildTrailing(bool isDone, bool isActive, bool hasError, bool isPartial) {
    if (isActive) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: item.progress > 0 ? item.progress : null,
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
            IconButton(
              icon: Icon(Icons.pause, size: 16, color: AppTheme.primary),
              onPressed: onPause,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }
    if (isDone) {
      return Icon(Icons.cloud_done_rounded, color: AppTheme.primary, size: 28);
    }
    if (isPartial) {
      return Icon(Icons.cloud_sync_rounded, color: AppTheme.secondary, size: 28);
    }
    if (hasError) {
      return IconButton(
        icon: Icon(Icons.refresh_rounded, color: AppTheme.error),
        onPressed: onDownload,
        tooltip: 'Retry',
      );
    }
    return IconButton(
      onPressed: onDownload,
      icon: Icon(Icons.download_rounded, color: AppTheme.primary, size: 26),
      tooltip: 'Download',
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
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

  Widget _buildResumeBar() {
    final pct = '${item.downloaded} / ${item.total} downloaded';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress,
              color: AppTheme.secondary,
              backgroundColor: AppTheme.outline.withOpacity(0.15),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(pct,
                  style: TextStyle(
                      color: AppTheme.onSurfaceVariant, fontSize: 11)),
              const Spacer(),
              FilledButton.tonal(
                onPressed: onResume,
                style: FilledButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  backgroundColor: AppTheme.secondary.withOpacity(0.18),
                  foregroundColor: AppTheme.secondary,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline_rounded, size: 14),
                    SizedBox(width: 4),
                    Text('Resume'),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  foregroundColor: AppTheme.error,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

