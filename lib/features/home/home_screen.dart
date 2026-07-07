import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/bookmarks_manager.dart';
import '../../core/settings_manager.dart';
import '../../core/auth_provider.dart';
import '../admin/admin_cms_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String get _currentLang => ref.watch(settingsProvider).appLanguage;
  int _selectedSurahId = 1;
  final _ayahController = TextEditingController(text: '1');
  Map<String, dynamic>? _lastRead;
  bool _loadingSurahs = true;
  final String _surahSearchQuery = '';

  // Featured Ayah of the Day
  String _featuredVerseKey = '2:255';  // default: Ayat Kursi
  String _featuredNote = '';
  String _featuredArabic = '';
  String _featuredTranslationEn = '';
  String _featuredTranslationId = '';
  bool _loadingFeatured = true;

  // Site Config CMS Branding
  String _homeHeroTitle = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
  String _homeHeroSubtitle = 'In the name of Allah, the Most Gracious, the Most Merciful';
  String _homeTagline = 'Quran by Topic — Read, Study, and Reflect';

  // Initial fallback list of surahs for the dropdown
  List<Map<String, dynamic>> _dropdownSurahs = [
    {'id': 1, 'name': '1. Al-Fatihah'},
    {'id': 2, 'name': '2. Al-Baqarah'},
    {'id': 3, 'name': '3. Ali \'Imran'},
    {'id': 4, 'name': '4. An-Nisa\''},
    {'id': 5, 'name': '5. Al-Ma\'idah'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSurahs();
    _loadLastRead();
    _loadFeaturedAyah();
  }

  Future<void> _loadLastRead() async {
    final lr = await BookmarksManager.getLastRead();
    if (mounted) {
      setState(() {
        _lastRead = lr;
      });
    }
  }

  Future<void> _loadFeaturedAyah() async {
    try {
      final db = Supabase.instance.client;
      // Load site_config for the featured verse and branding
      final cfgRes = await db
          .from('site_config')
          .select('key, value')
          .inFilter('key', [
            'featured_ayah_key',
            'featured_ayah_note',
            'home_hero_title',
            'home_hero_subtitle',
            'home_tagline',
            'featured_rotation_mode'
          ]);
      String verseKey = '2:255';
      String note = '';
      String heroTitle = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
      String heroSubtitle = 'In the name of Allah, the Most Gracious, the Most Merciful';
      String tagline = 'Quran by Topic — Read, Study, and Reflect';
      String rotationMode = 'manual';

      for (final row in List<Map<String, dynamic>>.from(cfgRes)) {
        final k = row['key'] as String;
        final v = row['value'] as String;
        if (k == 'featured_ayah_key') verseKey = v;
        if (k == 'featured_ayah_note') note = v;
        if (k == 'home_hero_title') heroTitle = v;
        if (k == 'home_hero_subtitle') heroSubtitle = v;
        if (k == 'home_tagline') tagline = v;
        if (k == 'featured_rotation_mode') rotationMode = v;
      }

      int suraId = 2;
      int ayahNum = 255;

      if (rotationMode == 'daily_random') {
        // Synchronized Daily Random logic based on current date
        final now = DateTime.now();
        final seed = now.year * 365 + now.month * 31 + now.day;
        final verseDbId = (seed % 6236) + 1; // 6236 total verses

        final vRes = await db
            .from('verses')
            .select('sura_id, ayah_number, verse_key')
            .eq('id', verseDbId)
            .maybeSingle();
        if (vRes != null) {
          suraId = vRes['sura_id'] as int;
          ayahNum = vRes['ayah_number'] as int;
          verseKey = vRes['verse_key'] as String;
          note = 'Daily Reflection';
        }
      } else if (rotationMode == 'daily_playlist') {
        // Daily Playlist rotation mode
        final playlistRes = await db
            .from('featured_playlist')
            .select('verse_key, note')
            .order('id');
        final playlist = List<Map<String, dynamic>>.from(playlistRes);
        if (playlist.isNotEmpty) {
          final now = DateTime.now();
          final daysSinceEpoch = now.difference(DateTime(1970, 1, 1)).inDays;
          final item = playlist[daysSinceEpoch % playlist.length];
          verseKey = item['verse_key'] as String;
          note = item['note'] as String? ?? 'Daily Selection';
          
          final parts = verseKey.split(':');
          suraId = int.tryParse(parts[0]) ?? 2;
          ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '255') ?? 255;
        } else {
          // fallback if playlist is empty
          final parts = verseKey.split(':');
          suraId = int.tryParse(parts[0]) ?? 2;
          ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '255') ?? 255;
        }
      } else {
        // manual mode
        final parts = verseKey.split(':');
        suraId = int.tryParse(parts[0]) ?? 2;
        ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '255') ?? 255;
      }

      // Fetch verse details
      final verseRes = await db
          .from('verses')
          .select('text_ar')
          .eq('sura_id', suraId)
          .eq('ayah_number', ayahNum)
          .maybeSingle();
      final arabic = (verseRes?['text_ar'] as String?) ?? '';

      // Fetch default translation
      final verseIdRes = await db
          .from('verses')
          .select('id')
          .eq('sura_id', suraId)
          .eq('ayah_number', ayahNum)
          .maybeSingle();
      String translationEn = '';
      String translationId = '';
      if (verseIdRes != null) {
        final tid = verseIdRes['id'] as int;
        // Fetch both languages in parallel
        final results = await Future.wait([
          db.from('translations').select('text').eq('verse_id', tid).eq('source_id', 'en.sahih').maybeSingle(),
          db.from('translations').select('text').eq('verse_id', tid).eq('source_id', 'id.kemenag').maybeSingle(),
        ]);
        translationEn = (results[0]?['text'] as String?) ?? '';
        translationId = (results[1]?['text'] as String?) ?? '';
      }

      if (mounted) {
        setState(() {
          _featuredVerseKey = verseKey;
          _featuredNote = note;
          _featuredArabic = arabic;
          _featuredTranslationEn = translationEn;
          _featuredTranslationId = translationId;
          _homeHeroTitle = heroTitle;
          _homeHeroSubtitle = heroSubtitle;
          _homeTagline = tagline;
          _loadingFeatured = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFeatured = false);
    }
  }

  Future<void> _loadSurahs() async {
    try {
      final res = await Supabase.instance.client
          .from('surahs')
          .select('id, name_en, name_id, ayas')
          .order('id', ascending: true);
      
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _dropdownSurahs = list;
          _loadingSurahs = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading surahs: $e');
      if (mounted) {
        setState(() => _loadingSurahs = false);
      }
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

  void _doSearch() {
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      context.go('/search?q=${Uri.encodeComponent(q)}');
    }
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
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.outline),
                      onPressed: () => Navigator.pop(ctx2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setSheet(() => query = v),
                  style: TextStyle(color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: isEn ? 'Search surah by name or number…' : 'Cari surah…',
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
                          style: TextStyle(color: AppTheme.outline, fontSize: 11),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, color: AppTheme.primary)
                            : null,
                        onTap: () {
                          setState(() => _selectedSurahId = s['id'] as int);
                          Navigator.pop(ctx2);
                          // Reset ayah field
                          _ayahController.text = '1';
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

  @override
  Widget build(BuildContext context) {
    final isEn = _currentLang == 'en';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -1.0),
              radius: 1.2,
              colors: [
                Color(0x15E9C176), // 5% gold glow
                Color(0x00000000),
              ],
            ),
          ),
          child: CustomScrollView(
            slivers: [
              // Custom Top App Bar to match design
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: AppTheme.primary),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Al-Qur\'an',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: AppTheme.primaryContainer,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              fontSize: 22,
                            ),
                      ),
                      if (_homeTagline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _homeTagline,
                          style: TextStyle(
                            color: AppTheme.outline,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Language Selector Toggle
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => ref.read(settingsProvider.notifier).setAppLanguage('en'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isEn
                                      ? AppTheme.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'EN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isEn
                                        ? AppTheme.onPrimary
                                        : AppTheme.outline,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => ref.read(settingsProvider.notifier).setAppLanguage('id'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !isEn
                                      ? AppTheme.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'ID',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: !isEn
                                        ? AppTheme.onPrimary
                                        : AppTheme.outline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.settings_outlined, color: AppTheme.outline),
                        onPressed: () => context.go('/settings'),
                      ),
                    ],
                  ),
                ),
              ),

              // Last Read Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
                        ),
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
                                      child: Icon(
                                        Icons.history,
                                        color: AppTheme.primaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isEn ? 'LAST READ' : 'TERAKHIR DIBACA',
                                            style: TextStyle(
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
                                            style: TextStyle(
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
                                      style: TextStyle(
                                        color: AppTheme.outline,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isEn ? 'Progress' : 'Kemajuan',
                                      style: TextStyle(
                                        color: AppTheme.outline,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${_lastRead != null ? ((_lastRead!['surahId'] as int) / 114.0 * 100).toStringAsFixed(0) : '0'}%',
                                      style: TextStyle(
                                        color: AppTheme.outline,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryContainer,
                                    ),
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


              // Arabic Header Calligraphy Bismillah
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Text(
                        _homeHeroTitle,
                        textAlign: TextAlign.center,
                        style: AppTheme.arabicStyle(
                          fontSize: 30,
                          color: AppTheme.primaryContainer,
                        ),
                      ),
                      if (_homeHeroSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _homeHeroSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.outline,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Large Search Bar Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search field
                          TextField(
                            controller: _searchController,
                            style: TextStyle(color: AppTheme.onSurface),
                            decoration: InputDecoration(
                              hintText: isEn ? 'Search within Qur\'an' : 'Cari dalam Al-Qur\'an',
                              prefixIcon: Icon(Icons.search, color: AppTheme.outline),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: AppTheme.outline),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _doSearch(),
                            textInputAction: TextInputAction.search,
                          ),
                          const SizedBox(height: 16),
                          // Surah + Ayah select row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEn ? 'SELECT SURAH' : 'PILIH SURAH',
                                      style: TextStyle(
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
                                                  style: TextStyle(color: AppTheme.onSurface, fontSize: 14),
                                                  overflow: TextOverflow.ellipsis,
                                                );
                                              }),
                                            ),
                                            Icon(Icons.search, color: AppTheme.outline, size: 18),
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
                                      style: TextStyle(
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
                                      style: TextStyle(color: AppTheme.onSurface),
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
                                      decoration: InputDecoration(
                                        hintText: '1',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Go Button
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
                                    Text(isEn ? 'GO' : 'BUKA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward, size: 14),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Quick Access Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.25,
                        children: [
                          _QuickCard(
                            icon: Icons.menu_book,
                            title: isEn ? 'Mushaf Page' : 'Halaman Mushaf',
                            subtitle: isEn
                                ? 'Experience the traditional manuscript layout.'
                                : 'Baca Al-Qur\'an dengan tampilan mushaf standar.',
                            color: AppTheme.secondary,
                            iconBg: AppTheme.secondaryContainer.withValues(alpha: 0.2),
                            onTap: () async {
                              final lr = await BookmarksManager.getLastRead();
                              if (lr != null) {
                                context.go('/mushaf?verse_key=${lr['surahId']}:${lr['ayahNumber']}');
                              } else {
                                context.go('/mushaf');
                              }
                            },
                          ),
                          _QuickCard(
                            icon: Icons.list_alt,
                            title: isEn ? 'Surah List' : 'Daftar Surah',
                            subtitle: isEn
                                ? 'Browse the 114 Surahs of the Holy Quran.'
                                : 'Telusuri seluruh 114 surah dalam Al-Qur\'an.',
                            color: AppTheme.primary,
                            iconBg: AppTheme.primaryContainer.withValues(alpha: 0.1),
                            onTap: () => context.go('/surahs'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Featured Ayah of the Day ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: AppTheme.outlineVariant)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 10, color: AppTheme.outline),
                                const SizedBox(width: 5),
                                Text(
                                  isEn ? 'FEATURED AYAH' : 'AYAT HARI INI',
                                  style: TextStyle(
                                    color: AppTheme.outline,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: Divider(color: AppTheme.outlineVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D3040), Color(0xFF0A1C28)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            final parts = _featuredVerseKey.split(':');
                            if (parts.length == 2) {
                              context.go('/mushaf?verse_key=$_featuredVerseKey');
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: _loadingFeatured
                              ? Center(child: SizedBox(height: 60, child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        // Admin edit button
                                        if (ref.watch(isAdminProvider))
                                          AdminEditButton(
                                            tooltip: 'Edit Featured Ayah',
                                            onTap: () => context.go('/admin/cms'),
                                          ),
                                        const Spacer(),
                                        Text(_featuredVerseKey,
                                          style: TextStyle(color: AppTheme.outline, fontSize: 10)),
                                      ],
                                    ),
                                    if (_featuredArabic.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Text(
                                        _featuredArabic,
                                        textDirection: TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                        style: AppTheme.arabicStyle(fontSize: 22, color: Colors.white),
                                      ),
                                    ],
                                    if ((_currentLang == 'en' ? _featuredTranslationEn : _featuredTranslationId).isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Divider(color: AppTheme.outlineVariant),
                                      const SizedBox(height: 8),
                                      Text(
                                        _currentLang == 'en' ? _featuredTranslationEn : _featuredTranslationId,
                                        style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13, height: 1.6),
                                      ),
                                    ],
                                    if (_featuredNote.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '— $_featuredNote',
                                        style: TextStyle(color: AppTheme.outline, fontSize: 11, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconBg;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    Icon(Icons.arrow_forward, color: AppTheme.outline, size: 18),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
