import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/bookmarks_manager.dart';
import '../../core/settings_manager.dart';
import '../../core/auth_provider.dart';
import '../../core/widgets/home_widget_service.dart';
import '../admin/admin_cms_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Advanced search options state
  bool _showAdvanced = false;
  bool _searchQuran = true;
  bool _searchTranslation = true;
  bool _searchTafsir = true;
  bool _searchNuzul = true;
  bool _searchTag = true;
  bool _semanticSearch = false;
  final _searchController = TextEditingController();
  String get _currentLang => ref.watch(settingsProvider).appLanguage;
  Map<String, dynamic>? _lastRead;

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



  @override
  void initState() {
    super.initState();
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
            'featured_rotation_mode'
          ]);
      String verseKey = '2:255';
      String note = '';
      String heroTitle = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
      String heroSubtitle = 'In the name of Allah, the Most Gracious, the Most Merciful';
      String rotationMode = 'manual';

      for (final row in List<Map<String, dynamic>>.from(cfgRes)) {
        final k = row['key'] as String?;  // may be null
        if (k == null) continue;
        final v = (row['value'] as String?) ?? '';
        if (k == 'featured_ayah_key') verseKey = v;
        if (k == 'featured_ayah_note') note = v;
        if (k == 'home_hero_title') heroTitle = v;
        if (k == 'home_hero_subtitle') heroSubtitle = v;
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
          verseKey = (vRes['verse_key'] as String?) ?? '';
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
          verseKey = (item['verse_key'] as String?) ?? '';
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
          _loadingFeatured = false;
        });
      }

      // Sync with Home Screen Widget
      try {
        final suraRes = await db
            .from('suras')
            .select('name_en')
            .eq('id', suraId)
            .maybeSingle();
        final sName = (suraRes?['name_en'] as String?) ?? 'Surah $suraId';

        final currentLang = ref.read(settingsProvider).appLanguage;
        final translation = currentLang == 'en' ? translationEn : translationId;
        final surahRef = '$sName: $ayahNum';
        await HomeWidgetService.instance.updateAyahWidget(
          arabic: arabic,
          translation: translation,
          surahRef: surahRef,
          surahNo: suraId,
          ayahNo: ayahNum,
        );
      } catch (_) {}
    } catch (_) {
      if (mounted) setState(() => _loadingFeatured = false);
    }
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
      final params = <String, String>{
        'q': q,
      };
      if (_semanticSearch) {
        params['mode'] = 'semantic';
      } else {
        params['mode'] = 'keyword';
        final List<String> sources = [];
        if (_searchQuran) sources.add('quran');
        if (_searchTranslation) sources.add('translation');
        if (_searchTafsir) sources.add('tafsir');
        if (_searchNuzul) sources.add('nuzul');
        if (_searchTag) sources.add('tag');
        params['sources'] = sources.join(',');
      }
      final uri = Uri(
        path: '/search',
        queryParameters: params,
      );
      context.go(uri.toString());
    }
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
                      // tafseer.id brand logo + 2-line tagline
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            AppTheme.isDark
                                ? 'assets/images/logo_dark.png'
                                : 'assets/images/logo_light.png',
                            height: 38,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isEn ? 'Qurʾan by Topic' : 'Al-Qurʾan by Topik',
                            style: TextStyle(
                              color: AppTheme.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                          Text(
                            isEn ? 'Read, Comprehend, Apply' : 'Baca, Pahami, Amalkan',
                            style: TextStyle(
                              color: AppTheme.outline,
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
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
                                      ? AppTheme.primary
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
                                      ? AppTheme.primary
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
                        onPressed: () => context.push('/settings'),
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
                                      AppTheme.primary,
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
                      const SizedBox(height: 6),
                      Text(
                        // Fix #8: Show the right translation based on app language.
                        // Indonesian default; fall back to CMS subtitle or English.
                        _currentLang == 'id'
                            ? 'Dengan nama Allah Yang Maha Pengasih, Maha Penyayang'
                            : (_homeHeroSubtitle.isNotEmpty
                                ? _homeHeroSubtitle
                                : 'In the name of Allah, the Most Gracious, the Most Merciful'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.outline,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
                          Text(
                            isEn
                                ? 'Compare translations, read tafsir commentary, and explore by topic'
                                : 'Bandingkan terjemahan, baca tafsir, dan jelajahi berdasarkan topik',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.outline,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 6),
                          // Advanced Search toggle row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                icon: Icon(
                                  _showAdvanced ? Icons.tune : Icons.tune_outlined,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                                label: Text(
                                  isEn ? 'Advanced Search' : 'Pencarian Lanjutan',
                                  style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                ),
                                onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                              ),
                              if (_searchController.text.trim().isNotEmpty)
                                TextButton(
                                  onPressed: _doSearch,
                                  child: Text(
                                    isEn ? 'SEARCH' : 'CARI',
                                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          // Advanced Search panel (hidden by default)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _showAdvanced
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Semantic toggle
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(children: [
                                                Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isEn ? 'Semantic (AI)' : 'Semantik (AI)',
                                                  style: TextStyle(color: AppTheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                                                ),
                                              ]),
                                              Switch(
                                                value: _semanticSearch,
                                                activeColor: AppTheme.primary,
                                                onChanged: (v) => setState(() => _semanticSearch = v),
                                              ),
                                            ],
                                          ),
                                          if (!_semanticSearch) ...[
                                            const Divider(height: 20),
                                            Text(
                                              isEn ? 'SEARCH IN:' : 'CARI DI DALAM:',
                                              style: TextStyle(color: AppTheme.outline, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(spacing: 12, runSpacing: 8, children: [
                                              _buildAdvancedCheckbox(label: isEn ? 'Arabic Text' : 'Teks Arab', value: _searchQuran, onChanged: (v) => setState(() => _searchQuran = v ?? true)),
                                              _buildAdvancedCheckbox(label: isEn ? 'Translation' : 'Terjemahan', value: _searchTranslation, onChanged: (v) => setState(() => _searchTranslation = v ?? true)),
                                              _buildAdvancedCheckbox(label: 'Tafsir', value: _searchTafsir, onChanged: (v) => setState(() => _searchTafsir = v ?? true)),
                                              _buildAdvancedCheckbox(label: 'Asbabun Nuzul', value: _searchNuzul, onChanged: (v) => setState(() => _searchNuzul = v ?? true)),
                                              _buildAdvancedCheckbox(label: isEn ? 'Topics / Tags' : 'Topik / Tag', value: _searchTag, onChanged: (v) => setState(() => _searchTag = v ?? true)),
                                            ]),
                                          ],
                                        ],
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
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
                        // Balanced ratio: fits both EN and ID text fully inside card
                        childAspectRatio: 1.3,
                        children: [
                          _QuickCard(
                            icon: AppTheme.getMushafIcon(color: AppTheme.secondary, size: 20),
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
                            icon: Icon(Icons.list_alt, color: AppTheme.primary, size: 20),
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
  Widget _buildAdvancedCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22, height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: AppTheme.onSurface, fontSize: 12)),
        ],
      ),
    );
  }

}

class _QuickCard extends StatelessWidget {
  final Widget icon;
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: icon,
                    ),
                    Icon(Icons.arrow_forward, color: AppTheme.outline, size: 16),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 10,
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
