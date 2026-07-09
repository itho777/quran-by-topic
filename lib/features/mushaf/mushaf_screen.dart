import 'dart:async';

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme.dart';

import '../../core/settings_manager.dart';

import '../../core/bookmarks_manager.dart';

import '../../core/quran_sources.dart';

import '../../core/quran_coords.dart';

import '../../shared/widgets/reciter_picker_sheet.dart';

import 'widgets/quran_page_image.dart';

import 'source_picker_sheet.dart';

class MushafScreen extends ConsumerStatefulWidget {

  final int? initialPage;

  final String? initialVerseKey;

  const MushafScreen({super.key, this.initialPage, this.initialVerseKey});

  @override

  ConsumerState<MushafScreen> createState() => _MushafScreenState();

}

class _MushafScreenState extends ConsumerState<MushafScreen> {

  // Page navigation state

  late final PageController _pageController;

  late int _currentPage;

  bool _loading = false;

  List<Map<String, dynamic>> _pageVerses = [];

  Map<int, String> _translations = {};

  Map<int, Map<String, String>> _surahNames = {};

  List<Map<String, dynamic>> _jumpSurahs = [];

  int _selectedJumpSurahId = 1;

  final _jumpAyahController = TextEditingController(text: '1');

  String _selectedSource = 'id.kemenag';

  String get _currentLang => ref.watch(settingsProvider).appLanguage;

  // Floating menus and panels visibility


  bool _menusVisible = true;
  bool _studyPanelOpen = true;
  Timer? _menuCollapseTimer;
  bool _studyMenuBarVisible = true;
  Timer? _studyMenuCollapseTimer;


  // Active Ayah details

  int? _selectedVerseId;

  String _selectedVerseKey = '';

  bool _isBookmarked = false;

  bool _loadingDetails = false;

  int? _playingVerseId;

  // Study Panel Settings & Navigation

  String _studyContentTab = 'transliteration'; // Defaults to transliteration

  double _fontSize = 15.0;

  // Audio Playback State

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;

  bool _playAfterPageLoad = false;

  final List<String> _debugLogs = [];

  void _addDebugLog(String msg) {
    debugPrint(msg);
    if (mounted) {
      setState(() {
        _debugLogs.insert(0, msg);
        if (_debugLogs.length > 20) _debugLogs.removeLast();
      });
    }
  }

  late StreamSubscription _playerStateSubscription;

  late StreamSubscription _playerCompleteSubscription;

  // Scrolling reference

  final Map<int, GlobalKey> _verseKeys = {};

  final ScrollController _studyPanelScrollController = ScrollController();

  // Pre-indexed: page â†’ list of (globalAyahId, x, y) tuples, built once from the static coords.

  // Each entry: [globalAyahId, x, y]

  late final Map<int, List<List<double>>> _coordsByPage;

  final Map<String, String> _transOptions = {

    'id.kemenag': 'Kemenag RI (ID)',

    'en.sahih': 'Sahih International (EN)',

    'en.yusufali': 'Yusuf Ali (EN)',

    'en.pickthall': 'Pickthall (EN)',

    'en.shakir': 'Shakir (EN)',

  };

  // Per-tab source selectors

  String _translitSource = 'id.kemenag_translit'; // Kemenag official romanization

  String _tafsirSource = 'en.katsir';              // Ibn Kathir EN (clean PDF)

  String _nuzulSource = 'en.wahidi';               // Al-Wahidi EN

  final Map<String, String> _translitOptions = {

    'id.kemenag_translit': 'Kemenag (ID)',

    'en.transliteration': 'International (EN)',

  };

  final Map<String, String> _tafsirOptions = {

    'en.katsir': 'Ibn Kathir (EN)',

    'id.jalalayn': 'Jalalayn (ID)',

    'en.jalalayn': 'Jalalayn (EN)',

    'ar.jalalayn': 'Jalalayn (AR)',

    'en.maududi': 'Maududi (EN)',

    'id.muntakhab': 'Muntakhab (ID)',

  };

  final Map<String, String> _nuzulOptions = {

    'en.wahidi': 'Al-Wahidi (EN)',

    'id.kemenag_nuzul': 'Kemenag RI (ID)',

  };

  @override

  void initState() {

    super.initState();

    WakelockPlus.enable().ignore();

    // Build a fast pageâ†’coords index from the static quranCoordsData list.

    final Map<int, List<List<double>>> byPage = {};

    for (int i = 0; i < quranCoordsData.length; i += 4) {

      final page = quranCoordsData[i].toInt();

      final ayah = quranCoordsData[i + 1];

      final x    = quranCoordsData[i + 2];

      final y    = quranCoordsData[i + 3];

      byPage.putIfAbsent(page, () => []).add([ayah, x, y]);

    }

    _coordsByPage = byPage;

    // Initialise page from optional deep-link param

    _currentPage = widget.initialPage ?? 293;

    _pageController = PageController(initialPage: _currentPage - 1);

    _selectedSource = ref.read(settingsProvider).defaultTranslationSource;

    _fontSize = ref.read(settingsProvider).translationFontSize;

    // Initialise study sources based on current language

    final initLang = ref.read(settingsProvider).appLanguage;

    if (initLang == 'en') {

      _selectedSource = 'en.sahih';

      _translitSource = 'en.transliteration';

      _tafsirSource = 'en.katsir';

      _nuzulSource = 'en.wahidi';

    } else {

      _selectedSource = 'id.kemenag';

      _translitSource = 'id.kemenag_translit';

      _tafsirSource = 'id.jalalayn';

      _nuzulSource = 'id.kemenag_nuzul';

    }

    _loadSurahNames();

    if (widget.initialVerseKey != null) {

      _loadFromVerseKey(widget.initialVerseKey!);

    } else {

      _loadPageData(_currentPage);

    }

    debugPrint('MushafScreen initState: _currentPage = $_currentPage');

    // Always collapse the root bottom nav bar immediately when entering the Mushaf screen.

    // Capture the notifier before the callback to avoid using ref after dispose.

    final hideNavNotifier = ref.read(hideNavBarProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (mounted) hideNavNotifier.state = true;

    });

    // Bind AudioPlayer Listeners

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {

      if (mounted) {

        setState(() {

          _isPlaying = state == PlayerState.playing;

        });

      }

    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) async {

      _addDebugLog('onPlayerComplete: fired! playing=$_playingVerseId, verses=${_pageVerses.length}');

      if (_playingVerseId != null && _pageVerses.isNotEmpty) {

        final currentIndex = _pageVerses.indexWhere((v) => v['id'] == _playingVerseId);

        if (currentIndex != -1 && currentIndex + 1 < _pageVerses.length) {

          // Play next verse on the page

          final nextVerse = _pageVerses[currentIndex + 1];

          await _playAudioForVerse(nextVerse);

        } else {

          // Advance to the next page

          if (_currentPage < 604) {

            _addDebugLog('onPlayerComplete: last verse, set playAfterPageLoad=true, next page');

            _playAfterPageLoad = true;

            _nextPage();

          } else {

            // End of Quran reached

            if (mounted) {

              setState(() {

                _isPlaying = false;

                _playingVerseId = null;

              });

            }

          }

        }

      }

    });

    // Start auto collapse timer for floating menus


    _startMenuCollapseTimer();
    _startStudyMenuCollapseTimer();
  }



  @override
  void dispose() {
    debugPrint('MushafScreen dispose');
    WakelockPlus.disable().ignore();
    _menuCollapseTimer?.cancel();
    _studyMenuCollapseTimer?.cancel();


    _playerStateSubscription.cancel();

    _playerCompleteSubscription.cancel();

    _audioPlayer.dispose();

    _pageController.dispose();

    _studyPanelScrollController.dispose();

    _jumpAyahController.dispose();

    // Restore the root bottom nav bar when leaving the Mushaf screen.

    Future.microtask(() {

      try {

        ref.read(hideNavBarProvider.notifier).state = false;

      } catch (_) {}

    });

    super.dispose();

  }

  Future<void> _loadSurahNames() async {

    try {

      final res = await Supabase.instance.client

          .from('surahs')

          .select('id, name_en, name_id, ayas')

          .order('id', ascending: true);

      final list = List<Map<String, dynamic>>.from(res);

      final namesMap = <int, Map<String, String>>{};

      for (final s in list) {

        namesMap[s['id'] as int] = {

          'name_en': s['name_en'] as String? ?? '',

          'name_id': s['name_id'] as String? ?? s['name_en'] as String? ?? '',

        };

      }

      if (mounted) {

        setState(() {

          _surahNames = namesMap;

          _jumpSurahs = list;

          // Pre-select based on current page

          if (_pageVerses.isNotEmpty) {

            _selectedJumpSurahId = _pageVerses.first['sura_id'] as int? ?? 1;

          }

        });

      }

    } catch (e) {

      debugPrint('Error loading surah names: $e');

    }

  }

  Future<void> _loadPageData(int pageNum) async {

    _addDebugLog('loadPageData: page=$pageNum, playAfter=$_playAfterPageLoad');

    if (mounted) setState(() => _loading = true);

    try {

      final versesRes = await Supabase.instance.client

          .from('verses')

          .select('id, ayah_number, verse_key, text_ar, sura_id, page_number, juz_number')

          .eq('page_number', pageNum);

      final versesList = List<Map<String, dynamic>>.from(versesRes);

      versesList.sort((a, b) {

        int suraComp = (a['sura_id'] as int).compareTo(b['sura_id'] as int);

        if (suraComp != 0) return suraComp;

        return (a['ayah_number'] as int).compareTo(b['ayah_number'] as int);

      });

      if (versesList.isNotEmpty) {

        final verseIds = versesList.map((v) => v['id'] as int).toList();

        final transRes = await Supabase.instance.client

            .from('translations')

            .select('verse_id, text')

            .eq('source_id', _selectedSource)

            .inFilter('verse_id', verseIds);

        final transMap = <int, String>{};

        for (final r in transRes) {

          transMap[r['verse_id'] as int] = r['text'] as String;

        }

        if (mounted) {

          setState(() {

            _pageVerses = versesList;

          });

        }

        await _loadPageTexts();

        // Auto-select first verse on new page if none is selected

        if (_selectedVerseId == null || !versesList.any((v) => v['id'] == _selectedVerseId)) {

          await _selectVerse(versesList.first, fetchDetails: !_playAfterPageLoad);

        } else {

          // Resync selected verse reference

          final current = versesList.firstWhere((v) => v['id'] == _selectedVerseId, orElse: () => versesList.first);

          await _selectVerse(current, fetchDetails: !_playAfterPageLoad);

        }

        _addDebugLog('loadPageData done: check playAfter=$_playAfterPageLoad');

        if (_playAfterPageLoad) {

          _playAfterPageLoad = false;

          final firstVerse = versesList.first;

          _addDebugLog('loadPageData done: auto-play first verse ID=${firstVerse['id']}');

          await _playAudioForVerse(firstVerse);

        }

      } else {

        if (mounted) {

          setState(() {

            _pageVerses = [];

            _translations = {};

            _selectedVerseId = null;

          });

        }

      }

    } catch (e) {

      debugPrint('Error loading page data: $e');

    } finally {

      if (mounted) setState(() => _loading = false);

    }

  }

  Future<void> _loadFromVerseKey(String key) async {

    if (mounted) setState(() => _loading = true);

    try {

      final res = await Supabase.instance.client

          .from('verses')

          .select('page_number, id')

          .eq('verse_key', key)

          .maybeSingle();

      if (res != null && res['page_number'] != null) {

        final pageNum = (res['page_number'] as num).toInt();

        final vId = (res['id'] as num).toInt();

        setState(() {

          _currentPage = pageNum;

          _selectedVerseId = vId;

          _selectedVerseKey = key;

        });

        _pageController.jumpToPage(pageNum - 1);

        await _loadPageData(pageNum);

      } else {

        await _loadPageData(_currentPage);

      }

    } catch (e) {

      debugPrint('Error loading from verse key: $e');

      await _loadPageData(_currentPage);

    }

  }

  Future<void> _loadPageTexts() async {

    if (_pageVerses.isEmpty) return;

    if (mounted) setState(() => _loadingDetails = true);

    try {

      final verseIds = _pageVerses.map((v) => v['id'] as int).toList();

      final Map<int, String> textsMap = {};

      if (_studyContentTab == 'transliteration') {

        final res = await Supabase.instance.client

            .from('translations')

            .select('verse_id, text')

            .eq('source_id', _translitSource)

            .inFilter('verse_id', verseIds);

        for (final r in res) {

          textsMap[r['verse_id'] as int] = r['text'] as String;

        }

      } else if (_studyContentTab == 'translation') {

        final res = await Supabase.instance.client

            .from('translations')

            .select('verse_id, text')

            .eq('source_id', _selectedSource)

            .inFilter('verse_id', verseIds);

        for (final r in res) {

          textsMap[r['verse_id'] as int] = r['text'] as String;

        }

      } else if (_studyContentTab == 'tafsir') {

        final res = await Supabase.instance.client

            .from('tafsirs')

            .select('verse_id, text')

            .eq('source_id', _tafsirSource)

            .inFilter('verse_id', verseIds);

        for (final r in res) {

          textsMap[r['verse_id'] as int] = r['text'] as String;

        }

      } else if (_studyContentTab == 'nuzul') {

        final res = await Supabase.instance.client

            .from('asbabun_nuzul')

            .select('verse_id, text')

            .eq('source_id', _nuzulSource)

            .inFilter('verse_id', verseIds);

        for (final r in res) {

          textsMap[r['verse_id'] as int] = r['text'] as String;

        }

      }

      if (mounted) {

        setState(() {

          _translations = textsMap;

        });

      }

    } catch (e) {

      debugPrint('Error loading page texts: $e');

    } finally {

      if (mounted) setState(() => _loadingDetails = false);

    }

  }

  Future<void> _selectVerse(Map<String, dynamic> verse, {bool fetchDetails = true}) async {

    _onUserInteraction();

    final vId = verse['id'] as int;

    final vKey = (verse['verse_key'] as String?) ?? '';

    if (vId != _selectedVerseId) {

      if (!_isPlaying) {

        _audioPlayer.stop().ignore();

      }

    }

    if (mounted) {

      setState(() {

        _selectedVerseId = vId;

        _selectedVerseKey = vKey;

        if (!_isPlaying) {

          _playingVerseId = vId;

        }

      });

    }

    _scrollToActiveVerse(vId, alignment: 0.0);

    final surahId = verse['sura_id'] as int? ?? 1;

    final ayahNum = verse['ayah_number'] as int? ?? 1;

    final s = _surahNames[surahId];

    final surahName = s != null ? (s['name_en'] ?? '') : 'Surah $surahId';

    BookmarksManager.saveLastRead(

      surahId: surahId,

      ayahNumber: ayahNum,

      surahName: surahName,

    );

    _checkBookmarkStatus();

  }

  void _scrollToActiveVerse(int vId, {double alignment = 0.0}) {

    // Note: study panel open/close is controlled manually by user only.
    // Do NOT auto-open the panel when audio plays.


    final idx = _pageVerses.indexWhere((v) => v['id'] == vId);
    if (idx < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_studyPanelScrollController.hasClients) return;

      // Scroll immediately and smoothly to the estimated offset
      const double approxCardHeight = 150.0;
      const double listPadding = 12.0;
      final approxOffset = (listPadding + idx * approxCardHeight).clamp(
        0.0,
        _studyPanelScrollController.position.maxScrollExtent,
      );

      _studyPanelScrollController.animateTo(
        approxOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        // After reaching the estimated area, precisely align the card if rendered
        final key = _verseKeys[vId];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            alignment: 0.1,
          );
        }
      });
    });
  }

  String _getAudioUrl(int surahId, int ayahNum, {bool useMirror = true}) {

    final sStr = surahId.toString().padLeft(3, '0');

    final aStr = ayahNum.toString().padLeft(3, '0');

    final reciter = ref.read(settingsProvider).selectedReciter;

    final host = useMirror

        ? 'https://mirrors.quranicaudio.com/everyayah'

        : 'https://everyayah.com/data';

    return '$host/$reciter/$sStr$aStr.mp3';

  }

  Future<void> _playAudioForVerse(Map<String, dynamic> verse, {bool isFallback = false}) async {

    final surahId = verse['sura_id'] as int;

    final ayahNum = verse['ayah_number'] as int;

    final vId = verse['id'] as int;

    _addDebugLog('playAudioForVerse: $surahId:$ayahNum ID=$vId (fallback=$isFallback)');

    if (mounted) {

      setState(() {

        _playingVerseId = vId;

        _selectedVerseId = vId;

        _selectedVerseKey = (verse['verse_key'] as String?) ?? '';

        _isPlaying = true;

      });

    }

    _checkBookmarkStatus();

    _scrollToActiveVerse(vId, alignment: 0.0);

    final s = _surahNames[surahId];

    final surahName = s != null ? (s['name_en'] ?? '') : 'Surah $surahId';

    BookmarksManager.saveLastRead(

      surahId: surahId,

      ayahNumber: ayahNum,

      surahName: surahName,

    );

    try {

      final url = _getAudioUrl(surahId, ayahNum, useMirror: !isFallback);

      await _audioPlayer.play(UrlSource(url));

      if (mounted) {

        setState(() {

          _isPlaying = true;

        });

      }

    } catch (e) {

      debugPrint('Error playing audio on $surahId:$ayahNum: $e');

      if (!isFallback) {

        debugPrint('Attempting fallback to primary everyayah.com server...');

        await _playAudioForVerse(verse, isFallback: true);

      }

    }

  }

  Future<void> _toggleAudio() async {

    if (_isPlaying) {

      await _audioPlayer.pause();

      if (mounted) {

        setState(() {

          _isPlaying = false;

        });

      }

    } else {

      if (_playingVerseId != null && _playingVerseId == _selectedVerseId && _audioPlayer.state == PlayerState.paused) {

        await _audioPlayer.resume();

        if (mounted) {

          setState(() {

            _isPlaying = true;

          });

        }

      } else if (_selectedVerseId != null) {

        final currentVerse = _pageVerses.firstWhere((v) => v['id'] == _selectedVerseId, orElse: () => {});

        if (currentVerse.isNotEmpty) {

          await _playAudioForVerse(currentVerse);

        }

      } else if (_playingVerseId != null) {

        final currentVerse = _pageVerses.firstWhere((v) => v['id'] == _playingVerseId, orElse: () => {});

        if (currentVerse.isNotEmpty) {

          await _playAudioForVerse(currentVerse);

        }

      }

    }

  }

  void _onPageChanged(int index) {
    int pageNum = index + 1;
    _addDebugLog('onPageChanged: index=$index, pageNum=$pageNum, playAfter=$_playAfterPageLoad');

    setState(() {
      _currentPage = pageNum;
    });

    _onUserInteraction();
    _loadPageData(pageNum);
  }

  void _nextPage() {

    if (_currentPage < 604) {

      _pageController.nextPage(

          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

    }

  }

  void _prevPage() {

    if (_currentPage > 1) {

      _pageController.previousPage(

          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

    }

  }

  void _toggleMenus() {

    final nowVisible = !_menusVisible;

    setState(() {

      _menusVisible = nowVisible;

    });

    ref.read(hideNavBarProvider.notifier).state = !nowVisible;

    if (nowVisible) {

      _startMenuCollapseTimer();

    } else {

      _menuCollapseTimer?.cancel();

    }

  }

  void _startMenuCollapseTimer() {

    _menuCollapseTimer?.cancel();

    _menuCollapseTimer = Timer(const Duration(seconds: 5), () {

      if (mounted && _menusVisible) {

        setState(() {

          _menusVisible = false;

        });

        ref.read(hideNavBarProvider.notifier).state = true;

      }

    });

  }


  void _onUserInteraction() {
    _startMenuCollapseTimer();
    _startStudyMenuCollapseTimer();
    if (!_menusVisible) {
      setState(() {
        _menusVisible = true;
      });
      ref.read(hideNavBarProvider.notifier).state = false;
    }
    if (!_studyMenuBarVisible) {
      setState(() {
        _studyMenuBarVisible = true;
      });
    }
  }

  void _startStudyMenuCollapseTimer() {
    _studyMenuCollapseTimer?.cancel();
    _studyMenuCollapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _studyPanelOpen && _studyMenuBarVisible) {
        setState(() {
          _studyMenuBarVisible = false;
        });
      }
    });
  }

  void _onStudyPanelInteraction() {
    _startStudyMenuCollapseTimer();
    if (!_studyMenuBarVisible) {
      setState(() {
        _studyMenuBarVisible = true;
      });
    }
  }


  void _onImageTapped(double relX, double relY) {

    if (_pageVerses.isEmpty) return;

    // Map relative click position to SVG coordinate space (viewBox 0 0 345 550).

    // relX / relY are already anchored to the actual image content area (letterbox-corrected).

    final clickX = relX * 345.0;

    final clickY = relY * 550.0;

    final pageCoords = _coordsByPage[_currentPage];

    if (pageCoords == null || pageCoords.isEmpty) return;

    double minDistanceSq = double.infinity;

    int closestAyahId = -1;

    for (final entry in pageCoords) {

      final x = entry[1];

      final y = entry[2];

      final dx = x - clickX;

      final dy = y - clickY;

      final distSq = dx * dx + dy * dy;

      if (distSq < minDistanceSq) {

        minDistanceSq = distSq;

        closestAyahId = entry[0].toInt();

      }

    }

    if (closestAyahId != -1) {

      final match = _pageVerses.firstWhere(

        (v) => v['id'] == closestAyahId,

        orElse: () => {},

      );

      if (match.isNotEmpty) {

        // Study panel is only manually toggled â€” do NOT open on verse tap
        setState(() {
          _menusVisible = true;
        });
        ref.read(hideNavBarProvider.notifier).state = false;
        _selectVerse(match);

      }

    }

  }

  void _onVerseSelectedBySurahAyah(int surah, int ayah) {

    if (_pageVerses.isEmpty) return;

    final match = _pageVerses.firstWhere(

      (v) => (v['sura_id'] as int) == surah && (v['ayah_number'] as int) == ayah,

      orElse: () => {},

    );

    if (match.isNotEmpty) {

      // Study panel is only manually toggled â€” do NOT open on verse select
      setState(() {
        _menusVisible = true;
      });
      ref.read(hideNavBarProvider.notifier).state = false;
      _selectVerse(match);

    }

  }

  void _copyActiveAyah() {

    if (_selectedVerseId == null || _pageVerses.isEmpty) return;

    final current = _pageVerses.firstWhere(

      (v) => v['id'] == _selectedVerseId,

      orElse: () => _pageVerses.first,

    );

    final surahId = current['sura_id'];

    final ayahNum = current['ayah_number'];

    final base = Uri.base;

    final origin = base.host.isNotEmpty

        ? '${base.scheme}://${base.host}${base.port != 80 && base.port != 443 && base.port != 0 ? ':${base.port}' : ''}'

        : 'https://tafseer.id';

    final link = '$origin/#/surahs/$surahId/ayahs/$ayahNum';

    final text = "${current['text_ar']}\n\n${_translations[_selectedVerseId] ?? ''}\n(${current['verse_key']})\n\n$link";

    Clipboard.setData(ClipboardData(text: text));

    final lang = ref.read(settingsProvider).appLanguage;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(lang == 'en' ? 'Ayah + link copied!' : 'Ayat & tautan berhasil disalin!'),

        behavior: SnackBarBehavior.floating,

        showCloseIcon: true,

        duration: const Duration(seconds: 5),

      ),

    );

  }

  Future<void> _checkBookmarkStatus() async {
    if (_selectedVerseKey.isEmpty) {
      if (mounted) {
        setState(() {
          _isBookmarked = false;
        });
      }
      return;
    }
    final bookmarked = await BookmarksManager.isBookmarked(_selectedVerseKey);
    if (mounted) {
      setState(() {
        _isBookmarked = bookmarked;
      });
    }
  }

  Future<void> _toggleBookmarkActive() async {
    if (_selectedVerseId == null || _pageVerses.isEmpty) return;
    final current = _pageVerses.firstWhere(
      (v) => v['id'] == _selectedVerseId,
      orElse: () => _pageVerses.first,
    );
    final surahId = current['sura_id'] as int? ?? 1;
    final ayahNum = current['ayah_number'] as int? ?? 1;
    final s = _surahNames[surahId];
    final surahName = s != null ? (s['name_en'] ?? '') : 'Surah $surahId';
    final verseKey = current['verse_key'] as String? ?? '';
    final textAr = current['text_ar'] as String? ?? '';
    final translation = _translations[_selectedVerseId] ?? '';

    final added = await BookmarksManager.toggleBookmark(
      surahId: surahId,
      ayahNumber: ayahNum,
      surahName: surahName,
      verseKey: verseKey,
      textAr: textAr,
      translation: translation,
    );

    setState(() {
      _isBookmarked = added;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added
                ? (_currentLang == 'en' ? 'Added to Bookmarks' : 'Ditambahkan ke Bookmark')
                : (_currentLang == 'en' ? 'Removed from Bookmarks' : 'Dihapus dari Bookmark'),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // Computed max ayahs for the currently selected jump-surah

  int get _jumpMaxAyas {

    if (_jumpSurahs.isEmpty) return 7;

    final s = _jumpSurahs.firstWhere(

      (x) => x['id'] == _selectedJumpSurahId,

      orElse: () => {'ayas': 7},

    );

    return (s['ayas'] as num?)?.toInt() ?? 7;

  }

  // Navigate to Mushaf page for the selected surah:ayah

  void _doJumpToAyah() async {

    final ayah = int.tryParse(_jumpAyahController.text) ?? 1;

    final clamped = ayah.clamp(1, _jumpMaxAyas);

    // Fetch the page number for the target verse

    final res = await Supabase.instance.client

        .from('verses')

        .select('page_number')

        .eq('sura_id', _selectedJumpSurahId)

        .eq('ayah_number', clamped)

        .maybeSingle();

    if (!mounted) return;

    if (res != null && res['page_number'] != null) {

      final targetPage = (res['page_number'] as num).toInt();

      _pageController.jumpToPage(targetPage - 1);

      await _loadPageData(targetPage);

      final verse = _pageVerses.firstWhere(

        (v) => v['sura_id'] == _selectedJumpSurahId && v['ayah_number'] == clamped,

        orElse: () => _pageVerses.first,

      );

      await _selectVerse(verse);

    }

  }

  // Searchable surah picker bottom sheet â€” same UX as Home & Surah pages

  void _showJumpSurahPicker() {

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

          final filtered = _jumpSurahs.where((s) {

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

                    hintText: isEn ? 'Search by name or numberâ€¦' : 'Cari surahâ€¦',

                    hintStyle: TextStyle(color: AppTheme.outline),

                    prefixIcon: Icon(Icons.search, color: AppTheme.outline),

                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

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

                      final isSelected = s['id'] == _selectedJumpSurahId;

                      return ListTile(

                        leading: Container(

                          width: 36,

                          height: 36,

                          alignment: Alignment.center,

                          decoration: BoxDecoration(

                            color: isSelected ? AppTheme.primary : AppTheme.surfaceContainer,

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

                        trailing: isSelected ? Icon(Icons.check, color: AppTheme.primary) : null,

                        onTap: () {

                          setState(() {

                            _selectedJumpSurahId = s['id'] as int;

                            _jumpAyahController.text = '1';

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

  // Jump to Ayah â€” bottom sheet with same UX as Home & Surah screens

  void _showJumpDialog() {

    final isEn = _currentLang == 'en';

    // Pre-select the surah of the first verse on the current page

    if (_pageVerses.isNotEmpty) {

      _selectedJumpSurahId = _pageVerses.first['sura_id'] as int? ?? _selectedJumpSurahId;

    }

    showModalBottomSheet(

      context: context,

      backgroundColor: AppTheme.surfaceContainerHigh,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

      ),

      builder: (ctx) {

        return StatefulBuilder(builder: (ctx2, setSheet) {

          return Padding(

            padding: EdgeInsets.only(

              top: 20,

              left: 20,

              right: 20,

              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,

            ),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                // Header

                Row(

                  children: [

                    Expanded(

                      child: Text(

                        isEn ? 'Jump to Ayah' : 'Lompat ke Ayat',

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

                const SizedBox(height: 16),

                // Surah selector + Ayah input + Go button (same layout as Home)

                Row(

                  crossAxisAlignment: CrossAxisAlignment.end,

                  children: [

                    // Surah selector

                    Expanded(

                      flex: 3,

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            isEn ? 'SURAH' : 'SURAH',

                            style: TextStyle(

                              color: AppTheme.outline,

                              fontSize: 9,

                              fontWeight: FontWeight.bold,

                              letterSpacing: 1.0,

                            ),

                          ),

                          const SizedBox(height: 6),

                          InkWell(

                            onTap: _showJumpSurahPicker,

                            borderRadius: BorderRadius.circular(14),

                            child: Container(

                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

                              decoration: BoxDecoration(

                                color: AppTheme.surfaceContainer,

                                borderRadius: BorderRadius.circular(14),

                                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),

                              ),

                              child: Row(

                                children: [

                                  Expanded(

                                    child: Builder(builder: (_) {

                                      final s = _jumpSurahs.isNotEmpty

                                          ? _jumpSurahs.firstWhere(

                                              (x) => x['id'] == _selectedJumpSurahId,

                                              orElse: () => _jumpSurahs.first,

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

                    // Ayah number input

                    Expanded(

                      flex: 2,

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            isEn ? 'AYAH (1-$_jumpMaxAyas)' : 'AYAT (1-$_jumpMaxAyas)',

                            style: TextStyle(

                              color: AppTheme.outline,

                              fontSize: 9,

                              fontWeight: FontWeight.bold,

                              letterSpacing: 1.0,

                            ),

                          ),

                          const SizedBox(height: 6),

                          TextField(

                            controller: _jumpAyahController,

                            keyboardType: TextInputType.number,

                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],

                            style: TextStyle(color: AppTheme.onSurface),

                            onSubmitted: (_) {

                              Navigator.pop(ctx2);

                              _doJumpToAyah();

                            },

                            onChanged: (val) {

                              if (val.isNotEmpty) {

                                final num = int.tryParse(val);

                                if (num != null) {

                                  if (num > _jumpMaxAyas) {

                                    _jumpAyahController.text = _jumpMaxAyas.toString();

                                    _jumpAyahController.selection = TextSelection.fromPosition(

                                      TextPosition(offset: _jumpAyahController.text.length),

                                    );

                                  } else if (num < 1) {

                                    _jumpAyahController.text = '1';

                                    _jumpAyahController.selection = TextSelection.fromPosition(

                                      TextPosition(offset: _jumpAyahController.text.length),

                                    );

                                  }

                                }

                              }

                              setSheet(() {});

                            },

                            decoration: const InputDecoration(

                              hintText: '1',

                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),

                            ),

                          ),

                        ],

                      ),

                    ),

                    const SizedBox(width: 12),

                    // Go button

                    ElevatedButton(

                      onPressed: () {

                        Navigator.pop(ctx2);

                        _doJumpToAyah();

                      },

                      style: ElevatedButton.styleFrom(

                        backgroundColor: AppTheme.primaryContainer,

                        foregroundColor: AppTheme.onPrimary,

                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(14),

                        ),

                      ),

                      child: Row(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          Text(isEn ? 'GO' : 'BUKA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),

                          const SizedBox(width: 4),

                          Icon(Icons.arrow_forward, size: 14),

                        ],

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 8),

              ],

            ),

          );

        });

      },

    );

  }

  String _getSurahName() {

    if (_pageVerses.isEmpty || _surahNames.isEmpty) return '';

    final first = _pageVerses.first;

    final surahId = first['sura_id'] as int? ?? 1;

    final s = _surahNames[surahId];

    if (s == null) return 'Surah $surahId';

    return _currentLang == 'en'

        ? (s['name_en'] ?? '')

        : (s['name_id'] ?? s['name_en'] ?? '');

  }

  @override

  Widget build(BuildContext context) {


    final mediaQuery = MediaQuery.of(context);
    final isMobileLandscape = mediaQuery.orientation == Orientation.landscape && mediaQuery.size.shortestSide < 600;
    // Study panel is independent of top menus â€” it only follows _studyPanelOpen
    final showStudyPanel = _studyPanelOpen && !isMobileLandscape;


    final activeTabTitle = {

      'translation': _currentLang == 'en' ? 'Translation' : 'Terjemahan',

      'transliteration': _currentLang == 'en' ? 'Transliteration' : 'Transliterasi',

      'tafsir': 'Tafsir',

      'nuzul': 'Asbabun Nuzul',

    }[_studyContentTab]!;

    return Scaffold(

      backgroundColor: AppTheme.background,

      body: Stack(

        children: [

          // â”€â”€ Background / Swipe View â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

          GestureDetector(

            onTap: _toggleMenus,

            behavior: HitTestBehavior.translucent,

            child: Stack(

              children: [

                ScrollConfiguration(

                  behavior: MouseDragScrollBehavior(),

                  // RTL: Arabic reads right-to-left; page 1 is rightmost

                  child: PageView.builder(

                    controller: _pageController,

                    reverse: true,

                    itemCount: 604,

                    onPageChanged: _onPageChanged,

                    itemBuilder: (context, index) {

                      int pageNum = index + 1;

                      return Center(

                        child: AnimatedPadding(

                          duration: const Duration(milliseconds: 300),

                          curve: Curves.easeInOut,


                          padding: EdgeInsets.only(
                            top: _menusVisible ? 90.0 : 0.0,
                            // Fixed padding when study panel is open â€” avoids blank space on menu-bar auto-hide
                            bottom: showStudyPanel
                                ? (_studyMenuBarVisible ? 280.0 : 230.0)
                                : 20.0,
                          ),


                        child: Container(

                          decoration: BoxDecoration(

                            color: const Color(0xFFFBF9F1), // Cream background for premium paper look

                            boxShadow: [

                              BoxShadow(

                                color: Colors.black.withValues(alpha: 0.08),

                                blurRadius: 16,

                                offset: const Offset(0, 4),

                              )

                            ],

                          ),

                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final fullWidth = ref.watch(settingsProvider).mushafFullWidth;
                              return InteractiveViewer(
                                maxScale: 3.0,
                                boundaryMargin: const EdgeInsets.symmetric(vertical: 240.0, horizontal: 80.0),
                                constrained: !fullWidth,
                                child: buildQuranPageImage(
                                  context,
                                  pageNum,
                                  onTap: _onUserInteraction,
                                  onTapWithPosition: _onImageTapped,
                                  onVerseTapped: _onVerseSelectedBySurahAyah,
                                  selectedVerseId: _selectedVerseId,
                                  playingVerseId: _playingVerseId,
                                  fullWidth: fullWidth,
                                  viewportWidth: width,
                                ),
                              );
                            },
                          ),

                        ),

                      ),

                    );

                  },

                ),

              ),

                // Swipe Arrow Indicators (for Desktop/Web preview)

                // RTL: left arrow = forward (next page), right arrow = back (prev page)

                PositionChangedArrowButton(

                  alignment: Alignment.centerLeft,

                  icon: Icons.chevron_left,

                  onTap: _nextPage,

                  visible: _currentPage < 604 && _menusVisible,

                ),

                PositionChangedArrowButton(

                  alignment: Alignment.centerRight,

                  icon: Icons.chevron_right,

                  onTap: _prevPage,

                  visible: _currentPage > 1 && _menusVisible,

                ),

              ],

            ),

          ),

          // â”€â”€ Slide-Down Top Menu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

          AnimatedPositioned(

            duration: const Duration(milliseconds: 300),

            curve: Curves.easeInOut,

            top: _menusVisible ? 0 : -100,

            left: 0,

            right: 0,

            child: ClipRRect(

              child: BackdropFilter(

                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),

                child: Container(

                  height: 90,

                  padding: const EdgeInsets.only(top: 36, left: 16, right: 16),

                  decoration: BoxDecoration(

                    color: AppTheme.background.withValues(alpha: 0.85),

                    border: Border(

                      bottom: BorderSide(color: AppTheme.outlineVariant, width: 0.5),

                    ),

                  ),

                  child: Row(

                    children: [

                      // Active Ayah Name Label

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [

                            Text(

                              _selectedVerseKey,

                              style: TextStyle(

                                color: AppTheme.primary,

                                fontSize: 16,

                                fontWeight: FontWeight.bold,

                              ),

                            ),

                            const SizedBox(height: 2),

                            Text(

                              '${_getSurahName()} â€¢ ${(_currentLang == 'en' ? 'Page $_currentPage' : 'Halaman $_currentPage')}',

                              style: TextStyle(

                                color: AppTheme.outline,

                                fontSize: 11,

                              ),

                            ),

                          ],

                        ),

                      ),

                      // Controls
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // â”€â”€ Language Toggle Pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.all(2),
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
                                      onTap: () {
                                        ref.read(settingsProvider.notifier).setAppLanguage(lang);
                                        setState(() {
                                          if (lang == 'en') {
                                            _selectedSource = 'en.sahih';
                                            _translitSource = 'en.transliteration';
                                            _tafsirSource = 'en.katsir';
                                            _nuzulSource = 'en.wahidi';
                                          } else {
                                            _selectedSource = 'id.kemenag';
                                            _translitSource = 'id.kemenag_translit';
                                            _tafsirSource = 'id.jalalayn';
                                            _nuzulSource = 'id.kemenag_nuzul';
                                          }
                                        });
                                        _loadPageTexts();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

                              IconButton(
                                icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, color: AppTheme.primary, size: 28),
                                onPressed: _toggleAudio,
                              ),

                              // Reciter selector
                              IconButton(
                                icon: Icon(Icons.record_voice_over, color: AppTheme.primary, size: 20),
                                tooltip: _currentLang == 'en' ? 'Select Reciter' : 'Pilih Qori',
                                onPressed: _showReciterPicker,
                              ),

                              IconButton(
                                icon: Icon(Icons.info_outline, color: AppTheme.primary),
                                onPressed: () async {
                                  if (_selectedVerseId != null && _pageVerses.isNotEmpty) {
                                    final current = _pageVerses.firstWhere(
                                      (v) => v['id'] == _selectedVerseId,
                                      orElse: () => _pageVerses.first,
                                    );
                                    final sId = current['sura_id'];
                                    final aNum = current['ayah_number'];
                                    if (sId == null || aNum == null) return;
                                    // Cancel timers so they don't re-hide nav bar
                                    _menuCollapseTimer?.cancel();
                                    _studyMenuCollapseTimer?.cancel();
                                    ref.read(hideNavBarProvider.notifier).state = false;
                                    await context.push('/surahs/$sId/ayahs/$aNum');
                                    if (mounted) {
                                      ref.read(hideNavBarProvider.notifier).state = true;
                                    }
                                  }
                                },
                              ),

                              IconButton(
                                icon: Icon(Icons.explore_outlined, color: AppTheme.primary),
                                onPressed: _showJumpDialog,
                              ),

                              // Bookmark button
                              IconButton(
                                icon: Icon(
                                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                  color: _isBookmarked ? Colors.amber : AppTheme.primary,
                                ),
                                tooltip: _currentLang == 'en' ? 'Bookmark' : 'Bookmark',
                                onPressed: _toggleBookmarkActive,
                              ),

                              IconButton(
                                icon: Icon(Icons.share, color: AppTheme.primary),
                                tooltip: _currentLang == 'en' ? 'Copy & Share' : 'Salin & Bagikan',
                                onPressed: _copyActiveAyah,
                              ),

                              // Panel toggle icon â€” small, compact
                              IconButton(
                                icon: Icon(
                                  _studyPanelOpen ? Icons.expand_more : Icons.chrome_reader_mode_outlined,
                                  color: _studyPanelOpen ? AppTheme.outline : AppTheme.primary,
                                ),
                                tooltip: _studyPanelOpen ? 'Close panel' : 'Open study panel',
                                onPressed: () => setState(() => _studyPanelOpen = !_studyPanelOpen),
                              ),

                              IconButton(
                                icon: Icon(Icons.settings_outlined, color: AppTheme.outline, size: 20),
                                tooltip: _currentLang == 'en' ? 'Settings' : 'Pengaturan',
                                onPressed: () => context.push('/settings'),
                              ),
                            ],
                          ),
                        ),
                      ),

                    ],

                  ),

                ),

              ),

            ),

          ),

          // â”€â”€ Slide-Up Study Panel (Bottom) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: showStudyPanel ? 0 : -320,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: _studyMenuBarVisible ? 270.0 : 220.0,


              decoration: BoxDecoration(

                color: AppTheme.surfaceContainer.withValues(alpha: 0.95),

                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),

                boxShadow: [

                  BoxShadow(

                    color: Colors.black.withValues(alpha: 0.12),

                    blurRadius: 10,

                  )

                ],

              ),

              child: Column(

                children: [


                  // Tab Navigation & Action Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _studyMenuBarVisible ? 50.0 : 0.0,
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: _studyMenuBarVisible ? AppTheme.outlineVariant : Colors.transparent,
                        width: 0.5,
                      )),
                    ),


                    child: Row(

                      children: [

                        // Tab selector â€” compact dropdown
                        _buildStudyTabDropdown(),

                        const Spacer(),

                        // Source selector button for active tab


                        IconButton(
                          icon: Icon(Icons.swap_horiz, size: 18, color: AppTheme.primary),
                          tooltip: _currentLang == 'en' ? 'Switch source' : 'Ganti sumber',
                          onPressed: () {
                            _onStudyPanelInteraction();
                            _showSourcePicker();
                          },
                        ),


                        // Adjust font size button


                        IconButton(
                          icon: Icon(Icons.format_size, size: 18, color: AppTheme.primary),
                          onPressed: () {
                            _onStudyPanelInteraction();
                            showModalBottomSheet(


                              context: context,

                              backgroundColor: AppTheme.surfaceContainerHigh,

                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),

                              builder: (context) {

                                return StatefulBuilder(

                                  builder: (context, setSheetState) {

                                    return Container(

                                      padding: const EdgeInsets.all(20),

                                      child: Column(

                                        mainAxisSize: MainAxisSize.min,

                                        children: [

                                          Text(

                                            _currentLang == 'en' ? 'Font Size' : 'Ukuran Font',

                                            style: TextStyle(fontWeight: FontWeight.bold),

                                          ),

                                          Slider(

                                            value: _fontSize,

                                            min: 12,

                                            max: 28,

                                            activeColor: AppTheme.primary,

                                            onChanged: (val) {

                                              setSheetState(() => _fontSize = val);

                                              setState(() => _fontSize = val);

                                            },

                                          ),

                                        ],

                                      ),

                                    );

                                  },

                                );

                              },

                            );

                          },

                        ),

                        // Close panel button

                        IconButton(

                          icon: Icon(Icons.close, size: 18, color: AppTheme.outline),

                          onPressed: () => setState(() => _studyPanelOpen = false),

                        ),

                      ],

                    ),

                  ),

                  // List of page verses showing translation details dynamically


                  Expanded(
                    child: _loading
                        ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                        : Listener(
                            onPointerDown: (_) {
                              _onUserInteraction();
                              _onStudyPanelInteraction();
                            },
                            child: ListView.builder(


                              controller: _studyPanelScrollController,

                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                            itemCount: _pageVerses.length,

                            itemBuilder: (context, index) {

                              final v = _pageVerses[index];

                              final vId = v['id'] as int;

                              final isSelected = vId == _selectedVerseId;

                              final isPlaying = vId == _playingVerseId && _isPlaying;

                              final key = _verseKeys.putIfAbsent(vId, () => GlobalKey());

                              final content = _translations[vId] ?? '';

                              final arabicText = v['text_ar'] as String? ?? '';

                              // Color priority: playing > selected > neutral

                              final Color bgColor = isPlaying

                                  ? AppTheme.secondary.withValues(alpha: 0.10)

                                  : isSelected

                                      ? AppTheme.primary.withValues(alpha: 0.08)

                                      : AppTheme.surfaceContainerLow;

                              final Color borderColor = isPlaying

                                  ? AppTheme.secondary

                                  : isSelected

                                      ? AppTheme.primary

                                      : AppTheme.outlineVariant.withValues(alpha: 0.3);

                              final double borderWidth = (isSelected || isPlaying) ? 1.5 : 1.0;

                              return Container(

                                key: key,

                                margin: const EdgeInsets.only(bottom: 8),

                                decoration: BoxDecoration(

                                  color: bgColor,

                                  borderRadius: BorderRadius.circular(12),

                                  border: Border.all(color: borderColor, width: borderWidth),

                                ),

                                child: InkWell(

                                  borderRadius: BorderRadius.circular(12),

                                  onTap: () => _selectVerse(v),

                                  child: Padding(

                                    padding: const EdgeInsets.all(12),

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.stretch,

                                      children: [

                                        // Header row: verse key badge + status label + detail link

                                        Row(

                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                          children: [

                                            // Left: verse key + detail link

                                            Row(

                                              mainAxisSize: MainAxisSize.min,

                                              children: [

                                                Container(

                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                                                  decoration: BoxDecoration(

                                                    color: AppTheme.surfaceContainerHigh,

                                                    borderRadius: BorderRadius.circular(6),

                                                  ),

                                                  child: Text(

                                                    v['verse_key'] ?? '',

                                                    style: TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold),

                                                  ),

                                                ),

                                                const SizedBox(width: 8),

                                                // â”€â”€ Detail page link â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

                                                InkWell(

                                                  onTap: () async {

                                                    final sId = v['sura_id'] as int;

                                                    final aNum = v['ayah_number'] as int;

                                                    // Cancel timers so they can't re-hide nav bar
                                                    _menuCollapseTimer?.cancel();
                                                    _studyMenuCollapseTimer?.cancel();
                                                    ref.read(hideNavBarProvider.notifier).state = false;

                                                    await context.push('/surahs/$sId/ayahs/$aNum');

                                                    if (mounted) {

                                                      ref.read(hideNavBarProvider.notifier).state = true;

                                                    }

                                                  },

                                                  borderRadius: BorderRadius.circular(4),

                                                  child: Padding(

                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),

                                                    child: Row(

                                                      mainAxisSize: MainAxisSize.min,

                                                      children: [

                                                        Text(

                                                          _currentLang == 'en' ? 'Details' : 'Detail',

                                                          style: TextStyle(

                                                            color: AppTheme.primary,

                                                            fontSize: 10,

                                                            fontWeight: FontWeight.w600,

                                                          ),

                                                        ),

                                                        const SizedBox(width: 2),

                                                        Icon(Icons.open_in_new, color: AppTheme.primary, size: 10),

                                                      ],

                                                    ),

                                                  ),

                                                ),

                                              ],

                                            ),

                                            // Right: playback / tab status

                                            Row(

                                              mainAxisSize: MainAxisSize.min,

                                              children: [

                                                if (isPlaying)

                                                  Padding(

                                                    padding: EdgeInsets.only(right: 4),

                                                    child: Icon(Icons.volume_up, color: AppTheme.secondary, size: 14),

                                                  ),

                                                if (isPlaying)

                                                  Text(

                                                    'PLAYING',

                                                    style: TextStyle(

                                                      color: AppTheme.secondary,

                                                      fontSize: 9,

                                                      fontWeight: FontWeight.bold,

                                                    ),

                                                  )

                                                else if (isSelected)

                                                  Text(

                                                    activeTabTitle.toUpperCase(),

                                                    style: TextStyle(

                                                      color: AppTheme.primary,

                                                      fontSize: 9,

                                                      fontWeight: FontWeight.bold,

                                                    ),

                                                  ),

                                              ],

                                            ),

                                          ],

                                        ),

                                        // Arabic text of the ayah (always visible)

                                        const SizedBox(height: 8),

                                        // Translation / Transliteration / Tafsir / Nuzul content

                                        _loadingDetails && isSelected

                                            ? Align(

                                                alignment: Alignment.centerLeft,

                                                child: SizedBox(

                                                  width: 16,

                                                  height: 16,

                                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),

                                                ),

                                              )

                                            : content.isNotEmpty

                                                ? AppTheme.buildFormattedText(

                                                    content,

                                                    TextStyle(

                                                      color: AppTheme.onSurface,

                                                      fontSize: _fontSize,

                                                      height: 1.6,

                                                    ),

                                                  )

                                                : const SizedBox.shrink(),

                                      ],

                                    ),

                                  ),

                                ),

                              );

                            },

                          ),

                        ),

                  ),

                ],

              ),

            ),

          ),

          // (Panel toggle now lives in the top bar â€” no big FAB needed)

          Positioned(
            left: 10,
            top: 100,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                ),
                constraints: const BoxConstraints(maxWidth: 300, maxHeight: 250),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'DEBUG LOGS',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const Divider(color: Colors.greenAccent, height: 8),
                      ..._debugLogs.map((log) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              log,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 9,
                                fontFamily: 'monospace',
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

      ),

    );

  }

  // â”€â”€ Study-panel tab: compact pop-up menu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStudyTabDropdown() {
    final tabLabels = {
      'transliteration': _currentLang == 'en' ? 'Transliteration' : 'Transliterasi',
      'translation'    : _currentLang == 'en' ? 'Translation'     : 'Terjemahan',
      'tafsir'         : 'Tafsir',
      'nuzul'          : 'Asbabun Nuzul',
    };
    final activeLabel = tabLabels[_studyContentTab] ?? _studyContentTab;

    return PopupMenuButton<String>(
      tooltip: _currentLang == 'en' ? 'Study mode' : 'Mode kajian',
      color: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (tab) async {
        _onStudyPanelInteraction();
        setState(() => _studyContentTab = tab);
        await _loadPageTexts();
      },
      itemBuilder: (_) => tabLabels.entries.map((e) {
        final isActive = e.key == _studyContentTab;
        return PopupMenuItem<String>(
          value: e.key,
          child: Row(
            children: [
              Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
                color: isActive ? AppTheme.primary : AppTheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                e.value,
                style: TextStyle(
                  color: isActive ? AppTheme.primary : AppTheme.onSurface,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              activeLabel,
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  void _showSourcePicker() {

    Map<String, QuranSource> allOpts = {};

    String currentSrc = '';

    String title = '';

    if (_studyContentTab == 'transliteration') {

      allOpts = {

        'id.kemenag_translit': const QuranSource(id: 'id.kemenag_translit', name: 'Kemenag RI (ID)', language: 'ID'),

        'en.transliteration': const QuranSource(id: 'en.transliteration', name: 'International (EN)', language: 'EN'),

      };

      currentSrc = _translitSource;

      title = _currentLang == 'en' ? 'Select Transliteration' : 'Pilih Transliterasi';

    } else if (_studyContentTab == 'translation') {

      allOpts = QuranSources.translations;

      currentSrc = _selectedSource;

      title = _currentLang == 'en' ? 'Select Translation' : 'Pilih Terjemahan';

    } else if (_studyContentTab == 'tafsir') {

      allOpts = QuranSources.tafsirs;

      currentSrc = _tafsirSource;

      title = _currentLang == 'en' ? 'Select Tafsir' : 'Pilih Tafsir';

    } else if (_studyContentTab == 'nuzul') {

      allOpts = QuranSources.asbabunNuzul;

      currentSrc = _nuzulSource;

      title = _currentLang == 'en' ? 'Select Asbabun Nuzul' : 'Pilih Asbabun Nuzul';

    }

    if (allOpts.isEmpty) return;

    showModalBottomSheet(

      context: context,

      backgroundColor: AppTheme.surfaceContainerHigh,

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

      ),

      isScrollControlled: true,

      builder: (context) {

        return SourcePickerSheet(

          title: title,

          sources: allOpts,

          currentSource: currentSrc,

          onSelected: (newSrc) async {

            setState(() {

              if (_studyContentTab == 'transliteration') {

                _translitSource = newSrc;

              } else if (_studyContentTab == 'translation') {

                _selectedSource = newSrc;

              } else if (_studyContentTab == 'tafsir') {

                _tafsirSource = newSrc;

              } else if (_studyContentTab == 'nuzul') {

                _nuzulSource = newSrc;

              }

            });

            await _loadPageTexts();

          },

        );

      },

    );

  }

  void _showReciterPicker() {

    final settings = ref.read(settingsProvider);

    showModalBottomSheet(

      context: context,

      backgroundColor: AppTheme.surfaceContainerHigh,

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

      ),

      isScrollControlled: true,

      builder: (ctx) {

        return ReciterPickerSheet(

          currentReciter: settings.selectedReciter,

          currentLang: settings.appLanguage,

          onSelected: (newReciter) async {

            final wasPlaying = _isPlaying;

            if (wasPlaying) await _audioPlayer.stop();

            await ref.read(settingsProvider.notifier).setSelectedReciter(newReciter);

            if (mounted) {

              setState(() {

                if (wasPlaying) _isPlaying = false;

                _playingVerseId = null;

              });

            }

            if (wasPlaying && _selectedVerseId != null) {

              final verse = _pageVerses.firstWhere(

                (v) => v['id'] == _selectedVerseId,

                orElse: () => {},

              );

              if (verse.isNotEmpty) await _playAudioForVerse(verse);

            }

          },

        );

      },

    );

  }

}

class PositionChangedArrowButton extends StatelessWidget {

  final Alignment alignment;

  final IconData icon;

  final VoidCallback onTap;

  final bool visible;

  const PositionChangedArrowButton({

    super.key,

    required this.alignment,

    required this.icon,

    required this.onTap,

    required this.visible,

  });

  @override

  Widget build(BuildContext context) {

    if (!visible) return const SizedBox.shrink();

    return Align(

      alignment: alignment,

      child: Padding(

        padding: const EdgeInsets.symmetric(horizontal: 8),

        child: CircleAvatar(

          radius: 22,

          backgroundColor: AppTheme.surfaceContainer.withValues(alpha: 0.8),

          child: IconButton(

            icon: Icon(icon, color: AppTheme.primary, size: 24),

            onPressed: onTap,

          ),

        ),

      ),

    );

  }

}

class MouseDragScrollBehavior extends MaterialScrollBehavior {

  @override

  Set<PointerDeviceKind> get dragDevices => {

        PointerDeviceKind.touch,

        PointerDeviceKind.mouse,

        PointerDeviceKind.trackpad,

      };

}


