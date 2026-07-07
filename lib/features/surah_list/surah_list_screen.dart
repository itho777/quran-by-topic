import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/settings_manager.dart';
import '../../core/bookmarks_manager.dart';
import '../../shared/widgets/islamic_star.dart';

class SurahListScreen extends ConsumerStatefulWidget {
  const SurahListScreen({super.key});

  @override
  ConsumerState<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends ConsumerState<SurahListScreen> {
  List<Map<String, dynamic>> _surahs = [];
  bool _loading = true;

  // Go to Ayah states
  int _selectedSurahId = 1;
  final _ayahController = TextEditingController(text: '1');
  List<Map<String, dynamic>> _dropdownSurahs = [];

  Map<String, dynamic>? _lastRead;

  String get _currentLang => ref.watch(settingsProvider).appLanguage;

  @override
  void initState() {
    super.initState();
    _load();
    _loadLastRead();
  }

  @override
  void dispose() {
    _ayahController.dispose();
    super.dispose();
  }

  Future<void> _loadLastRead() async {
    final lr = await BookmarksManager.getLastRead();
    if (mounted) setState(() => _lastRead = lr);
  }

  Future<void> _load() async {
    final res = await Supabase.instance.client.from('surahs').select();
    final list = List<Map<String, dynamic>>.from(res);
    list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    if (mounted) {
      setState(() {
        _surahs = list;
        _dropdownSurahs = list;
        _loading = false;
      });
    }
  }

  int get _maxAyas {
    if (_dropdownSurahs.isEmpty) return 7;
    final s = _dropdownSurahs.firstWhere(
      (x) => x['id'] == _selectedSurahId,
      orElse: () => {'id': 1, 'ayas': 7},
    );
    return (s['ayas'] as num?)?.toInt() ?? 7;
  }

  void _goSpecificAyah() {
    final ayah = int.tryParse(_ayahController.text) ?? 1;
    final clamped = ayah.clamp(1, _maxAyas);
    context.go('/mushaf?verse_key=$_selectedSurahId:$clamped');
  }

  void _showSurahPicker() {
    final isEn = _currentLang == 'en';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerHigh,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(builder: (ctx2, setSheet) {
          final filtered = _dropdownSurahs.where((s) {
            if (query.isEmpty) return true;
            final nameEn = (s['name_en'] ?? '').toLowerCase();
            final nameId = (s['name_id'] ?? '').toLowerCase();
            final id = '${s['id']}';
            final q = query.toLowerCase();
            return nameEn.contains(q) || nameId.contains(q) || id.contains(q);
          }).toList();
          return Container(
            height: MediaQuery.of(ctx2).size.height * 0.7,
            padding: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEn ? 'Select Surah' : 'Pilih Surah',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.outline),
                      onPressed: () => Navigator.pop(ctx2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setSheet(() => query = v),
                  style: const TextStyle(color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: isEn ? 'Search surah by name or number…' : 'Cari surah…',
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
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      final name = isEn
                          ? (s['name_en'] ?? '')
                          : (s['name_id'] ?? s['name_en'] ?? '');
                      final isSelected = s['id'] == _selectedSurahId;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${s['id']}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.outline,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${s['ayas'] ?? ''} ${isEn ? 'verses' : 'ayat'}',
                          style: const TextStyle(color: AppTheme.outline, fontSize: 11),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppTheme.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedSurahId = s['id'] as int;
                            _ayahController.text = '1';
                          });
                          Navigator.pop(ctx2);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  String _getTimeAgo(int timestamp, bool isEn) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inMinutes < 60) {
      return isEn ? '${diff.inMinutes} mins ago' : '${diff.inMinutes} menit lalu';
    } else if (diff.inHours < 24) {
      return isEn ? '${diff.inHours} hours ago' : '${diff.inHours} jam lalu';
    } else {
      return isEn ? '${diff.inDays} days ago' : '${diff.inDays} hari lalu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _currentLang == 'en';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: Text(isEn ? 'Surahs' : 'Daftar Surah'),
        actions: [
          // Global Language Toggle Pill
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
                  final active = _currentLang == lang;
                  return GestureDetector(
                    onTap: () => ref.read(settingsProvider.notifier).setAppLanguage(lang),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : CustomScrollView(
              slivers: [
                // Last Read Card (live from BookmarksManager)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              final sId = _lastRead?['surahId'] as int? ?? 1;
                              final aNum = _lastRead?['ayahNumber'] as int? ?? 1;
                              context.go('/surahs/$sId/ayahs/$aNum');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryContainer.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.history, color: AppTheme.primaryContainer),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isEn ? 'LAST READ' : 'TERAKHIR DIBACA',
                                              style: const TextStyle(
                                                color: AppTheme.outline,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _lastRead != null
                                                  ? '${_lastRead!['surahName']}, ${isEn ? 'Ayah' : 'Ayat'} ${_lastRead!['ayahNumber']}'
                                                  : (isEn ? 'Al-Fatihah, Ayah 1' : 'Al-Fatihah, Ayat 1'),
                                              style: const TextStyle(
                                                color: AppTheme.onSurface,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _lastRead != null
                                            ? _getTimeAgo(_lastRead!['timestamp'] as int, isEn)
                                            : (isEn ? 'Not started' : 'Belum mulai'),
                                        style: const TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isEn ? 'Progress' : 'Kemajuan',
                                        style: const TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${_lastRead != null ? ((_lastRead!['surahId'] as int) / 114.0 * 100).toStringAsFixed(0) : '0'}%',
                                        style: const TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: _lastRead != null ? (_lastRead!['surahId'] as int) / 114.0 : 0.0,
                                      minHeight: 6,
                                      backgroundColor: AppTheme.surfaceContainerHigh,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Go to Ayah Widget — identical to home page (searchable picker + clamped input)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEn ? 'SELECT SURAH' : 'PILIH SURAH',
                                    style: const TextStyle(
                                      color: AppTheme.outline,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Searchable surah picker (tap to open sheet)
                                  GestureDetector(
                                    onTap: _showSurahPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Builder(builder: (_) {
                                              final s = _dropdownSurahs.isNotEmpty
                                                  ? _dropdownSurahs.firstWhere(
                                                      (x) => x['id'] == _selectedSurahId,
                                                      orElse: () => _dropdownSurahs.first,
                                                    )
                                                  : null;
                                              final name = s == null
                                                  ? ''
                                                  : isEn
                                                      ? '${s['id']}. ${s['name_en'] ?? ''}'
                                                      : '${s['id']}. ${s['name_id'] ?? s['name_en'] ?? ''}';
                                              return Text(
                                                name,
                                                style: const TextStyle(color: AppTheme.onSurface, fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            }),
                                          ),
                                          const Icon(Icons.search, color: AppTheme.outline, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEn ? 'AYAH (1-$_maxAyas)' : 'AYAT (1-$_maxAyas)',
                                    style: const TextStyle(
                                      color: AppTheme.outline,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _ayahController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: const TextStyle(color: AppTheme.onSurface),
                                    onSubmitted: (_) => _goSpecificAyah(),
                                    onChanged: (val) {
                                      if (val.isNotEmpty) {
                                        final numVal = int.tryParse(val);
                                        if (numVal != null) {
                                          if (numVal > _maxAyas) {
                                            _ayahController.text = _maxAyas.toString();
                                            _ayahController.selection = TextSelection.fromPosition(
                                              TextPosition(offset: _ayahController.text.length),
                                            );
                                          } else if (numVal < 1) {
                                            _ayahController.text = '1';
                                            _ayahController.selection = TextSelection.fromPosition(
                                              TextPosition(offset: _ayahController.text.length),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      hintText: '1',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _goSpecificAyah,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryContainer,
                                foregroundColor: AppTheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(isEn ? 'GO' : 'BUKA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward, size: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Header title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isEn ? 'All 114 Surahs' : 'Seluruh 114 Surah',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),

                // Surah list with swipe-to-navigate hint gesture
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final s = _surahs[i];
                        return Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.outlineVariant),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => context.go('/surahs/${s['id']}'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      IslamicStar(
                                        size: 40,
                                        color: AppTheme.primary.withValues(alpha: 0.12),
                                        borderColor: AppTheme.primary.withValues(alpha: 0.4),
                                        child: Text(
                                          '${s['id']}',
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  isEn
                                                      ? (s['name_en'] ?? '')
                                                      : (s['name_id'] ?? s['name_en'] ?? ''),
                                                  style: const TextStyle(
                                                    color: AppTheme.onSurface,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.surfaceContainerHigh,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isEn
                                                        ? (s['type'] ?? '')
                                                        : (s['type'] == 'Meccan' ? 'Makkiyah' : 'Madaniyah'),
                                                    style: const TextStyle(color: AppTheme.outline, fontSize: 10),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isEn
                                                  ? (s['meaning'] ?? '')
                                                  : (s['meaning_id'] ?? s['meaning'] ?? ''),
                                              style: const TextStyle(color: AppTheme.outline, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(s['name_ar'] ?? '', style: AppTheme.arabicStyle(fontSize: 16)),
                                          Text(
                                            isEn ? '${s['ayas']} verses' : '${s['ayas']} ayat',
                                            style: const TextStyle(color: AppTheme.outline, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _surahs.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }
}
