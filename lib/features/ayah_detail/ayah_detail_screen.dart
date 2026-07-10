import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/web_audio_player.dart';
import '../../core/theme.dart';
import '../../core/bookmarks_manager.dart';
import '../../core/settings_manager.dart';
import '../../core/auth_provider.dart';
import '../../core/local_db.dart';
import '../admin/admin_cms_widgets.dart';
import '../../shared/widgets/reciter_picker_sheet.dart';
import '../mushaf/source_picker_sheet.dart';
import '../../core/quran_sources.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Data model for each "slot" the user can toggle between two sources
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ToggleSlot {
  final String label;        
  final String sourceId;     
  _ToggleSlot(this.label, this.sourceId);
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// AyahDetailScreen
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AyahDetailScreen extends ConsumerStatefulWidget {
  final int surahId;
  final int ayahNumber;
  /// Source ID to pre-select in the Tafsir tab (e.g. 'id.jalalayn').
  final String? initialTafsir;
  /// Tab index: 0=Translation 1=Tafsir 2=Nuzul 3=Topics 4=Related
  final int? initialTab;

  const AyahDetailScreen({
    super.key,
    required this.surahId,
    required this.ayahNumber,
    this.initialTafsir,
    this.initialTab,
  });

  @override
  ConsumerState<AyahDetailScreen> createState() => _AyahDetailScreenState();
}

class _AyahDetailScreenState extends ConsumerState<AyahDetailScreen>
    with SingleTickerProviderStateMixin {
  // â”€â”€ UI state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late TabController _tabController;
  bool _loading = true;
  bool _isBookmarked = false;

  // â”€â”€ DB data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Map<String, dynamic>? _verse;
  Map<String, dynamic>? _surah;
  final Map<String, String> _translationTexts = {};
  final Map<String, String> _transliterationTexts = {};
  final Map<String, String> _tafsirTexts = {};
  final Map<String, String> _nuzulTexts = {};
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _relatedVerses = [];

  // â”€â”€ Slot toggle indices (0 or 1) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  int _transIdx = 0;       
  int _tafsirIdx = 0;      
  int _nuzulIdx = 0;       
  int _tagsLangIdx = 0;    

  // â”€â”€ Slot definitions (updated on lang switch) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<_ToggleSlot> _transSlots = [];
  List<_ToggleSlot> _tafsirSlots = [];
  List<_ToggleSlot> _nuzulSlots = [];
  List<_ToggleSlot> _tagsSlots = [];
  String? _lastBuiltLang;
  bool _initialSourceApplied = false;

  // CMS: the database verse ID for admin inline editing
  int? _verseId;

  // Audio Playback
  final WebAudioPlayer _audioPlayer = WebAudioPlayer();
  bool _isPlaying = false;
  bool _playAfterPageLoad = false;
  late StreamSubscription _playerStateSubscription;
  late StreamSubscription _playerCompleteSubscription;

  // Go to Ayah feature state
  int _selectedSurahId = 1;
  final _ayahController = TextEditingController(text: '1');
  List<Map<String, dynamic>> _dropdownSurahs = [];

  String get _currentLang => ref.watch(settingsProvider).appLanguage;

  String get _translitSource => _currentLang == 'en' ? 'en.transliteration' : 'id.kemenag_translit';

  static const Map<String, String> _srcLabel = {
    'id.kemenag':           'Kemenag RI (ID)',
    'en.sahih':             'Sahih Int\'l (EN)',
    'id.transliteration':   'Transliteration (ID)',
    'en.transliteration':   'Transliteration (EN)',
    'id.kemenag_translit':  'Transliterasi Kemenag (ID)',
    'id.jalalayn':          'Jalalayn (ID)',
    'en.katsir_pdf':        'Ibn Kathir (EN)',
    'en.wahidi':            'Al-Wahidi (EN)',
    'id.kemenag_nuzul':     'Kemenag RI (ID)',
    'id':                   'Topik (ID)',
    'en':                   'Topics (EN)',
  };


  @override
  void initState() {
    super.initState();
    final initTab = widget.initialTab ?? (widget.initialTafsir != null ? 1 : 0);
    _tabController = TabController(length: 5, vsync: this, initialIndex: initTab);

    _selectedSurahId = widget.surahId;
    _loadAllData();
    _loadSurahsList();
    // Tab jump is scheduled in _loadAllData once data is ready

    // Bind audio listeners
    _playerStateSubscription = _audioPlayer.onStateChange.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    _playerCompleteSubscription = _audioPlayer.onComplete.listen((_) async {
      // Auto-advance to the next ayah in the surah
      if (_surah != null) {
        final totalAyahs = (_surah!['ayas'] as int?) ?? 0;
        if (widget.ayahNumber < totalAyahs) {
          _playAfterPageLoad = true;
          if (mounted) context.go('/surahs/${widget.surahId}/ayahs/${widget.ayahNumber + 1}');
        } else {
          if (widget.surahId < 114) {
            _playAfterPageLoad = true;
            if (mounted) context.go('/surahs/${widget.surahId + 1}/ayahs/1');
          } else {
            if (mounted) setState(() => _isPlaying = false);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _playerStateSubscription.cancel();
    _playerCompleteSubscription.cancel();
    _audioPlayer.dispose();
    _ayahController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AyahDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahId != widget.surahId ||
        oldWidget.ayahNumber != widget.ayahNumber ||
        oldWidget.initialTafsir != widget.initialTafsir ||
        oldWidget.initialTab != widget.initialTab) {
      _selectedSurahId = widget.surahId;
      _ayahController.text = widget.ayahNumber.toString();
      _isPlaying = false;
      _audioPlayer.stop();
      // Reset so _buildSlots re-applies the new initialTafsir
      _initialSourceApplied = false;
      
      final targetTab = widget.initialTab ?? (widget.initialTafsir != null ? 1 : _tabController.index);
      if (targetTab != _tabController.index) {
        _tabController.index = targetTab;
      }
      
      _loadAllData();
    }
  }

  Future<void> _loadSurahsList() async {
    try {
      final res = await Supabase.instance.client
          .from('surahs')
          .select('id, name_en, name_id, ayas')
          .order('id', ascending: true);
      
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _dropdownSurahs = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading surahs list: $e');
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

  void _buildSlots() {
    if (_lastBuiltLang == _currentLang &&
        _transSlots.isNotEmpty &&
        _tafsirSlots.isNotEmpty &&
        _nuzulSlots.isNotEmpty &&
        _tagsSlots.isNotEmpty) {
      return;
    }
    _lastBuiltLang = _currentLang;
    if (_currentLang == 'en') {
      _transSlots = [
        _ToggleSlot(_srcLabel['en.sahih']!, 'en.sahih'),
        _ToggleSlot(_srcLabel['id.kemenag']!, 'id.kemenag'),
      ];
      _tafsirSlots = [
        _ToggleSlot(_srcLabel['en.katsir_pdf']!, 'en.katsir_pdf'),
        _ToggleSlot(_srcLabel['id.jalalayn']!, 'id.jalalayn'),
      ];
      _nuzulSlots = [
        _ToggleSlot(_srcLabel['en.wahidi']!, 'en.wahidi'),
        _ToggleSlot(_srcLabel['id.kemenag_nuzul']!, 'id.kemenag_nuzul'),
      ];
      _tagsSlots = [
        _ToggleSlot(_srcLabel['en']!, 'en'),
        _ToggleSlot(_srcLabel['id']!, 'id'),
      ];
    } else {
      _transSlots = [
        _ToggleSlot(_srcLabel['id.kemenag']!, 'id.kemenag'),
        _ToggleSlot(_srcLabel['en.sahih']!, 'en.sahih'),
      ];
      _tafsirSlots = [
        _ToggleSlot(_srcLabel['id.jalalayn']!, 'id.jalalayn'),
        _ToggleSlot(_srcLabel['en.katsir_pdf']!, 'en.katsir_pdf'),
      ];
      _nuzulSlots = [
        _ToggleSlot(_srcLabel['id.kemenag_nuzul']!, 'id.kemenag_nuzul'),
        _ToggleSlot(_srcLabel['en.wahidi']!, 'en.wahidi'),
      ];
      _tagsSlots = [
        _ToggleSlot(_srcLabel['id']!, 'id'),
        _ToggleSlot(_srcLabel['en']!, 'en'),
      ];
    }
    // Apply initialTafsir from search deep-link (only once)
    if (!_initialSourceApplied && widget.initialTafsir != null) {
      _initialSourceApplied = true;
      final targetId = widget.initialTafsir!;
      final existingIdx = _tafsirSlots.indexWhere((s) => s.sourceId == targetId);
      if (existingIdx != -1) {
        _tafsirIdx = existingIdx;
      } else {
        final label = QuranSources.tafsirs[targetId]?.name ??
            _srcLabel[targetId] ?? targetId;
        _tafsirSlots[0] = _ToggleSlot(label, targetId);
        _tafsirIdx = 0;
      }
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    final localDb = LocalDatabase.instance;
    try {
      final db = Supabase.instance.client;

      final surahRes = await db.from('surahs').select().eq('id', widget.surahId).single();
      final verseRes = await db.from('verses').select().eq('sura_id', widget.surahId).eq('ayah_number', widget.ayahNumber).single();

      final int verseId = verseRes['id'] as int;
      _verseId = verseId;
      final String verseKey = (verseRes['verse_key'] as String?) ?? '';

      // Cache surah and verse details
      await localDb.saveSurahs([surahRes]);
      await localDb.saveVerses([verseRes], widget.surahId);

      final transRes = await db.from('translations').select().eq('verse_id', verseId);
      for (final row in List<Map<String, dynamic>>.from(transRes)) {
        final srcId = row['source_id'] as String?;
        if (srcId != null) {
          final txt = (row['text'] as String?) ?? '';
          _translationTexts[srcId] = txt;
          unawaited(localDb.saveTextData('translations', verseKey, srcId, txt));
        }
      }

      // Populate transliteration from verse field or from translations table
      final translit = verseRes['transliteration'] as String?;
      if (translit != null && translit.isNotEmpty) {
        _transliterationTexts['id.transliteration'] = translit;
        _transliterationTexts['en.transliteration'] = translit;
        _transliterationTexts['id.kemenag_translit'] = translit;
      }
      for (final key in ['id.transliteration', 'en.transliteration', 'id.kemenag_translit']) {
        if (_translationTexts.containsKey(key)) {
          _transliterationTexts[key] = _translationTexts[key]!;
        }
      }

      final tafsirRes = await db.from('tafsirs').select().eq('verse_id', verseId);
      for (final row in List<Map<String, dynamic>>.from(tafsirRes)) {
        final srcId = row['source_id'] as String?;
        if (srcId != null) {
          final txt = (row['text'] as String?) ?? '';
          _tafsirTexts[srcId] = txt;
          unawaited(localDb.saveTextData('tafsirs', verseKey, srcId, txt));
        }
      }

      final nuzulRes = await db.from('asbabun_nuzul').select().eq('verse_id', verseId);
      for (final row in List<Map<String, dynamic>>.from(nuzulRes)) {
        final srcId = row['source_id'] as String?;
        if (srcId != null) {
          final txt = (row['text'] as String?) ?? '';
          _nuzulTexts[srcId] = txt;
          unawaited(localDb.saveTextData('asbabun_nuzul', verseKey, srcId, txt));
        }
      }

      final tagRes = await db.from('verse_tags').select('tag_id, lang, tags(name, lang)').eq('verse_id', verseId);
      final isBookmarked = await BookmarksManager.isBookmarked(verseKey);

      final String sName = surahRes['name_en'] as String? ?? '';
      await BookmarksManager.saveLastRead(
        surahId: widget.surahId,
        ayahNumber: widget.ayahNumber,
        surahName: sName,
      );
      
      setState(() {
        _surah = surahRes;
        _verse = verseRes;
        _topics = List<Map<String, dynamic>>.from(tagRes);
        _isBookmarked = isBookmarked;
        _loading = false;
      });

      final rpcVerseKey = (verseRes['verse_key'] as String?) ?? '';
      final transSource = _currentLang == 'en' ? 'en.sahih' : 'id.kemenag';
      try {
        final related = await db.rpc('get_related_verses', params: {
          'input_verse_key': rpcVerseKey,
          'trans_source': transSource,
          'result_limit': 6,
        });
        if (mounted) {
          setState(() {
            _relatedVerses = List<Map<String, dynamic>>.from(related as List);
          });
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('AyahDetailScreen online load failed, trying local cache: $e');
      final cachedSurah = await localDb.getSurah(widget.surahId);
      final cachedVerse = await localDb.getVerse('${widget.surahId}:${widget.ayahNumber}');
      
      if (cachedVerse != null) {
        final String verseKey = (cachedVerse['verse_key'] as String?) ?? '';
        final localTrans = await localDb.getAllTextDataForVerse('translations', verseKey);
        final localTafsirs = await localDb.getAllTextDataForVerse('tafsirs', verseKey);
        final localNuzul = await localDb.getAllTextDataForVerse('asbabun_nuzul', verseKey);
        
        final isBookmarked = await BookmarksManager.isBookmarked(verseKey);

        setState(() {
          _surah = cachedSurah;
          _verse = cachedVerse;
          _translationTexts.clear();
          _translationTexts.addAll(localTrans);
          _tafsirTexts.clear();
          _tafsirTexts.addAll(localTafsirs);
          _nuzulTexts.clear();
          _nuzulTexts.addAll(localNuzul);
          _topics = [];
          _isBookmarked = isBookmarked;
          _loading = false;
        });

        // Populate transliteration
        final translit = cachedVerse['transliteration'] as String?;
        if (translit != null && translit.isNotEmpty) {
          _transliterationTexts['id.transliteration'] = translit;
          _transliterationTexts['en.transliteration'] = translit;
          _transliterationTexts['id.kemenag_translit'] = translit;
        }
        for (final key in ['id.transliteration', 'en.transliteration', 'id.kemenag_translit']) {
          if (_translationTexts.containsKey(key)) {
            _transliterationTexts[key] = _translationTexts[key]!;
          }
        }
      } else {
        setState(() {
          _loading = false;
        });
      }
    } finally {
      if (_playAfterPageLoad) {
        _playAfterPageLoad = false;
        _playAudio();
      }
    }
  }

  String _getText(Map<String, String> map, String source, String fallback) {
    return map[source] ?? fallback;
  }

  String _getAudioUrl({bool useMirror = true}) {
    final reciter = ref.read(settingsProvider).selectedReciter;
    return QuranSources.buildAudioUrl(reciter, widget.surahId, widget.ayahNumber, useMirror: useMirror);
  }

  Future<void> _playAudio({bool isFallback = false}) async {
    try {
      final url = _getAudioUrl(useMirror: !isFallback);
      _audioPlayer.play(url);
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      if (!isFallback) {
        await _playAudio(isFallback: true);
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      await _playAudio();
    }
  }

  void _showReciterSelection() {
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
             if (wasPlaying) _audioPlayer.stop();
            await ref.read(settingsProvider.notifier).setSelectedReciter(newReciter);
            if (mounted) {
              setState(() {
                if (wasPlaying) _isPlaying = false;
              });
            }
            if (wasPlaying) {
              await _playAudio();
            }
          },
        );
      },
    );
  }

  void _swipeToAyah(int ayahNum) {
    if (_surah == null) return;
    final totalAyahs = (_surah!['ayas'] as int?) ?? 0;
    if (ayahNum >= 1 && ayahNum <= totalAyahs) {
      context.go('/surahs/${widget.surahId}/ayahs/$ayahNum');
    }
  }

  void _showJumpDialog() {
    final isEn = _currentLang == 'en';
    // Pre-select the current surah
    setState(() => _selectedSurahId = widget.surahId);
    _ayahController.text = widget.ayahNumber.toString();

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
                            onTap: () => _showSurahSearchSheet(ctx2, setSheet),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
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
                                        style: TextStyle(color: AppTheme.onSurface, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }),
                                  ),
                                  Icon(Icons.search, color: AppTheme.outline, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Ayah number input
                    Expanded(
                      flex: 2,
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
                            style: TextStyle(color: AppTheme.onSurface, fontSize: 13),
                            onSubmitted: (_) {
                              final ayah = int.tryParse(_ayahController.text) ?? 1;
                              final clamped = ayah.clamp(1, _maxAyas);
                              Navigator.pop(ctx2);
                              if (mounted) {
                                context.go('/surahs/$_selectedSurahId/ayahs/$clamped');
                              }
                            },
                            onChanged: (val) {
                              if (val.isNotEmpty) {
                                final num = int.tryParse(val);
                                if (num != null) {
                                  if (num > _maxAyas) {
                                    _ayahController.text = _maxAyas.toString();
                                    _ayahController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: _ayahController.text.length),
                                    );
                                  } else if (num < 1) {
                                    _ayahController.text = '1';
                                    _ayahController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: _ayahController.text.length),
                                    );
                                  }
                                }
                              }
                              setSheet(() {});
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
                    // Go button
                    ElevatedButton(
                      onPressed: () {
                        final ayah = int.tryParse(_ayahController.text) ?? 1;
                        final clamped = ayah.clamp(1, _maxAyas);
                        Navigator.pop(ctx2);
                        if (mounted) {
                          context.go('/surahs/$_selectedSurahId/ayahs/$clamped');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isEn ? 'GO' : 'BUKA',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showSurahSearchSheet(BuildContext parentCtx, StateSetter setParent) {
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
                    hintText: isEn ? 'Search surah by name or numberâ€¦' : 'Cari surahâ€¦',
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
                      final isSelected = s['id'] == _selectedSurahId;
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
                        onTap: () {
                          setState(() {
                            _selectedSurahId = s['id'] as int;
                            _ayahController.text = '1';
                          });
                          setParent(() {});
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

  void _copyActiveAyah() {
    if (_verse == null) return;
    final arabic = (_verse!['text_ar'] as String?) ?? '';
    final verseKey = (_verse!['verse_key'] as String?) ?? '';
    final base = Uri.base;
    final origin = base.host.isNotEmpty
        ? "${base.scheme}://${base.host}${base.port != 80 && base.port != 443 && base.port != 0 ? ':${base.port}' : ''}"
        : 'https://tafseer.id';
    final link = '$origin/#/surahs/${widget.surahId}/ayahs/${widget.ayahNumber}';
    Clipboard.setData(ClipboardData(text: '$arabic\n\nÃ¢Â€Â” Quran $verseKey\n\n$link'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_currentLang == 'en' ? 'Ayah + link copied!' : 'Ayat & tautan berhasil disalin!'),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_verse == null || _surah == null) return;
    
    final String arabicText = (_verse!['text_ar'] as String?) ?? '';
    final String verseKey = (_verse!['verse_key'] as String?) ?? '';
    final String surahNameEn = _surah!['name_en'] as String? ?? '';
    
    final transSource = _currentLang == 'en' ? 'en.sahih' : 'id.kemenag';
    final translation = _translationTexts[transSource] ?? '';

    final added = await BookmarksManager.toggleBookmark(
      surahId: widget.surahId,
      ayahNumber: widget.ayahNumber,
      surahName: surahNameEn,
      verseKey: verseKey,
      textAr: arabicText,
      translation: translation,
    );

    setState(() {
      _isBookmarked = added;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added ? 'Added to Bookmarks' : 'Removed from Bookmarks'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 2),
          showCloseIcon: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('AyahDetailScreen build: _loading=$_loading, widget.initialTab=${widget.initialTab}, _tabController.index=${_tabController.index}');
    _buildSlots(); // Rebuild slots based on appLanguage
    final isEn = _currentLang == 'en';

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_verse == null || _surah == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('Ayah not found.', style: TextStyle(color: AppTheme.error)),
        ),
      );
    }

    final String arabicText = (_verse!['text_ar'] as String?) ?? '';
    final String verseKey = (_verse!['verse_key'] as String?) ?? '';
    final String surahNameDisplay = isEn
        ? (_surah!['name_en'] as String? ?? '')
        : (_surah!['name_id'] as String? ?? _surah!['name_en'] as String? ?? '');
    final String surahNameAr = (_surah!['name_ar'] as String?) ?? '';
    final int totalAyahs = (_surah!['ayas'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go('/surahs/${widget.surahId}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(surahNameDisplay, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 14, color: AppTheme.primary),
                ],
              ),
              Text(
                '${isEn ? 'Ayah' : 'Ayat'} ${widget.ayahNumber} Â· ${isEn ? 'Tap to go to Surah' : 'Ke Halaman Surah'}',
                style: TextStyle(color: AppTheme.primary, fontSize: 10),
              ),
            ],
          ),
        ),
        actions: [
          // Language Toggle Pill
          Padding(
            padding: const EdgeInsets.only(right: 6),
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
          // Play button
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, color: AppTheme.primary, size: 28),
            tooltip: isEn ? 'Play Audio' : 'Putar Audio',
            onPressed: _toggleAudio,
          ),
          // Reciter Selector
          IconButton(
            icon: Icon(Icons.record_voice_over, color: AppTheme.primary, size: 20),
            tooltip: isEn ? 'Select Reciter' : 'Pilih Qori',
            onPressed: _showReciterSelection,
          ),
          // Bookmark
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: AppTheme.primary),
            onPressed: _toggleBookmark,
          ),
          // Read in Mushaf
          if (_verse != null && _verse!['page_number'] != null)
            IconButton(
              icon: Icon(Icons.menu_book_outlined, color: AppTheme.primary),
              tooltip: isEn ? 'Read in Mushaf' : 'Buka Mushaf',
              onPressed: () {
                final pageNum = (_verse!['page_number'] as num).toInt();
                context.go('/mushaf?page=$pageNum');
              },
            ),
          // Jump to Ayah (explore_outlined)
          IconButton(
            icon: Icon(Icons.explore_outlined, color: AppTheme.primary, size: 22),
            tooltip: isEn ? 'Go to Ayah' : 'Lompat ke Ayat',
            onPressed: _showJumpDialog,
          ),
          // Share
          IconButton(
            icon: Icon(Icons.share, color: AppTheme.primary),
            tooltip: isEn ? 'Copy & Share' : 'Salin & Bagikan',
            onPressed: _copyActiveAyah,
          ),
          // Settings
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.outline, size: 20),
            tooltip: isEn ? 'Settings' : 'Pengaturan',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // â”€â”€ Arabic + Transliteration Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < -400) {
                  _swipeToAyah(widget.ayahNumber + 1);
                } else if (details.primaryVelocity! > 400) {
                  _swipeToAyah(widget.ayahNumber - 1);
                }
              },
              child: Container(
                color: AppTheme.surfaceContainer,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    Text(
                      arabicText,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: AppTheme.arabicStyle(
                        fontSize: ref.watch(settingsProvider).arabicFontSize * 0.82,
                        color: _isPlaying ? AppTheme.secondary : AppTheme.primary,
                      ),
                    ),
                    if (ref.watch(settingsProvider).showTransliteration) ...[
                      const SizedBox(height: 12),
                      AppTheme.buildFormattedText(
                        _getText(_transliterationTexts, _translitSource, isEn ? 'No transliteration available.' : 'Transliterasi tidak tersedia.'),
                        TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: ref.watch(settingsProvider).translationFontSize - 1,
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _isPlaying ? AppTheme.secondary.withValues(alpha: 0.12) : AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            verseKey,
                            style: TextStyle(
                              color: _isPlaying ? AppTheme.secondary : AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(surahNameAr, style: AppTheme.arabicStyle(fontSize: 14, color: AppTheme.outline)),
                        IconButton(
                          icon: Icon(Icons.copy_outlined, color: AppTheme.outline, size: 18),
                          onPressed: _copyActiveAyah,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // â”€â”€ Prev / Next Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(child: _buildNavigation(totalAyahs, isEn)),
          // â”€â”€ Pinned TabBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(_buildTabBar(isEn)),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTranslationTab(isEn),
            _buildTafsirTab(isEn),
            _buildNuzulTab(isEn),
            _buildTopicsTab(isEn),
            _buildRelatedTab(isEn),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(int totalAyahs, bool isEn) {
    final hasPrev = widget.ayahNumber > 1;
    final hasNext = widget.ayahNumber < totalAyahs;

    return Container(
      color: AppTheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(
            label: isEn ? '\u2190 Prev' : '\u2190 Sebelum',
            enabled: hasPrev,
            onTap: () => context.go('/surahs/${widget.surahId}/ayahs/${widget.ayahNumber - 1}'),
          ),
          Text(
            '${widget.ayahNumber} / $totalAyahs',
            style: TextStyle(color: AppTheme.outline, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          _NavButton(
            label: isEn ? 'Next \u2192' : 'Berikut \u2192',
            enabled: hasNext,
            onTap: () => context.go('/surahs/${widget.surahId}/ayahs/${widget.ayahNumber + 1}'),
          ),
        ],
      ),
    );
  }
  Widget _buildTabBar(bool isEn) {
    return Container(
      color: AppTheme.surfaceContainer,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppTheme.primary,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.outline,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [
          Tab(text: isEn ? 'Transl.' : 'Terjemahan'),
          Tab(text: 'Tafsir'),
          Tab(text: isEn ? 'Context' : 'Nuzul'),
          Tab(text: isEn ? 'Topics' : 'Topik'),
          Tab(text: isEn ? 'Related' : 'Terkait'),
        ],
      ),
    );
  }

  Widget _buildTranslationTab(bool isEn) {
    final currentSource = _transSlots[_transIdx].sourceId;
    final text = _getText(_translationTexts, currentSource, isEn ? 'Translation not available.' : 'Terjemahan tidak tersedia.');
    return _buildToggleTab(
      title: isEn ? 'Translation' : 'Terjemahan',
      icon: Icons.translate,
      slots: _transSlots,
      selectedIdx: _transIdx,
      onToggle: (i) => setState(() => _transIdx = i),
      content: text,
      isEn: isEn,
      onEdit: _verseId == null ? null : (newText) async {
        await adminUpdateTranslation(
          verseId: _verseId!,
          sourceId: currentSource,
          newText: newText,
        );
        setState(() => _translationTexts[currentSource] = newText);
      },
      onSwitchSource: () {
        final title = isEn ? 'Select Translation' : 'Pilih Terjemahan';
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
              sources: QuranSources.translations,
              currentSource: currentSource,
              onSelected: (newSrc) {
                setState(() {
                  _transSlots[_transIdx] = _ToggleSlot(
                    _srcLabel[newSrc] ?? newSrc,
                    newSrc,
                  );
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTafsirTab(bool isEn) {
    final currentSource = _tafsirSlots[_tafsirIdx].sourceId;
    final text = _getText(_tafsirTexts, currentSource, isEn ? 'Tafsir not available for this verse.' : 'Tafsir tidak tersedia untuk ayat ini.');
    return _buildToggleTab(
      title: 'Tafsir',
      icon: Icons.menu_book,
      slots: _tafsirSlots,
      selectedIdx: _tafsirIdx,
      onToggle: (i) => setState(() => _tafsirIdx = i),
      content: text,
      isEn: isEn,
      onEdit: _verseId == null ? null : (newText) async {
        await adminUpdateTafsir(
          verseId: _verseId!,
          tafsirId: currentSource,
          newText: newText,
        );
        setState(() => _tafsirTexts[currentSource] = newText);
      },
      onSwitchSource: () {
        final title = isEn ? 'Select Tafsir' : 'Pilih Tafsir';
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
              sources: QuranSources.tafsirs,
              currentSource: currentSource,
              onSelected: (newSrc) {
                setState(() {
                  _tafsirSlots[_tafsirIdx] = _ToggleSlot(
                    _srcLabel[newSrc] ?? newSrc,
                    newSrc,
                  );
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNuzulTab(bool isEn) {
    final currentSource = _nuzulSlots[_nuzulIdx].sourceId;
    final text = _getText(_nuzulTexts, currentSource, isEn ? 'Asbabun Nuzul context not recorded.' : 'Riwayat Asbabun Nuzul tidak tercatat.');
    return _buildToggleTab(
      title: isEn ? 'Asbabun Nuzul' : 'Asbabun Nuzul',
      icon: Icons.history,
      slots: _nuzulSlots,
      selectedIdx: _nuzulIdx,
      onToggle: (i) => setState(() => _nuzulIdx = i),
      content: text,
      isEn: isEn,
      onEdit: _verseId == null ? null : (newText) async {
        await adminUpdateNuzul(
          verseId: _verseId!,
          source: currentSource,
          newText: newText,
        );
        setState(() => _nuzulTexts[currentSource] = newText);
      },
      onSwitchSource: () {
        final title = isEn ? 'Select Asbabun Nuzul' : 'Pilih Asbabun Nuzul';
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
              sources: QuranSources.asbabunNuzul,
              currentSource: currentSource,
              onSelected: (newSrc) {
                setState(() {
                  _nuzulSlots[_nuzulIdx] = _ToggleSlot(
                    _srcLabel[newSrc] ?? newSrc,
                    newSrc,
                  );
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTopicsTab(bool isEn) {
    final currentLangKey = _tagsSlots[_tagsLangIdx].sourceId;
    final filteredTopics = _topics.where((t) {
      final tag = t['tags'] as Map<String, dynamic>?;
      return tag != null && tag['lang'] == currentLangKey;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? 'Topics & Themes' : 'Topik & Tema',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_tagsSlots.length, (idx) {
                final active = _tagsLangIdx == idx;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text(_tagsSlots[idx].label, style: TextStyle(fontSize: 10)),
                    selected: active,
                    onSelected: (sel) { if (sel) setState(() => _tagsLangIdx = idx); },
                    selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                    backgroundColor: Colors.transparent,
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredTopics.isEmpty)
          _buildEmptyState(isEn ? 'No topics categorized for this verse.' : 'Belum ada pengelompokan topik untuk ayat ini.')
        else
          ...filteredTopics.map((t) {
            final tag = t['tags'] as Map<String, dynamic>?;
            if (tag == null) return const SizedBox.shrink();
            final tagName = (tag['name'] as String?) ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(tagName, style: TextStyle(fontSize: 13, color: AppTheme.onSurface)),
                trailing: Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.outline),
                onTap: () => context.go('/topics/${t['tag_id']}'),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRelatedTab(bool isEn) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          isEn ? 'Related Verses' : 'Ayat Terkait',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_relatedVerses.isEmpty)
          _buildEmptyState(isEn ? 'No related verses discovered.' : 'Tidak ditemukan ayat terkait.')
        else
          ..._relatedVerses.map((r) {
            final rVerseKey = (r['verse_key'] as String?) ?? '';
            final rText = (r['text'] as String?) ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(rVerseKey, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                subtitle: Text(rText, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                trailing: Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.outline),
                onTap: () => context.go('/mushaf?verse_key=$rVerseKey'),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildToggleTab({
    required String title,
    required IconData icon,
    required List<_ToggleSlot> slots,
    required int selectedIdx,
    required ValueChanged<int> onToggle,
    required String content,
    required bool isEn,
    Future<void> Function(String newText)? onEdit,
    VoidCallback? onSwitchSource,
  }) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // â”€â”€ Sticky-style header bar (sources + action icons) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            border: Border(
              bottom: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
            ),
          ),
          child: Row(
            children: [
              // Section icon only (title removed to save space)
              Icon(icon, size: 15, color: AppTheme.primary),
              // Admin edit button
              if (ref.watch(isAdminProvider) && onEdit != null) ...[
                const SizedBox(width: 6),
                AdminEditButton(
                  tooltip: 'Edit $title',
                  onTap: () async {
                    await AdminEditDialog.show(
                      context,
                      title: 'Edit $title',
                      initialText: content,
                      onSave: onEdit,
                    );
                    setState(() {});
                  },
                ),
              ],
              const SizedBox(width: 8),
              // Scrollable source chips (Expanded to fill available space up to action buttons)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(slots.length, (idx) {
                      final active = selectedIdx == idx;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text(slots[idx].label,
                            style: TextStyle(
                              fontSize: 10,
                              color: active ? AppTheme.primary : AppTheme.outline,
                              fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            )),
                          selected: active,
                          onSelected: (sel) { if (sel) onToggle(idx); },
                          selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: active ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // Swap source button
              if (onSwitchSource != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.swap_horiz, size: 18, color: AppTheme.primary),
                  tooltip: isEn ? 'Switch source' : 'Ganti sumber',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: onSwitchSource,
                ),
              ],
              const SizedBox(width: 4),
              // Font size button
              IconButton(
                icon: Icon(Icons.format_size, size: 17, color: AppTheme.primary),
                tooltip: isEn ? 'Font size' : 'Ukuran font',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppTheme.surfaceContainerHigh,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    builder: (ctx) {
                      return StatefulBuilder(builder: (ctx2, setSS) {
                        double curSize = ref.read(settingsProvider).translationFontSize;
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(isEn ? 'Translation Font Size' : 'Ukuran Font Terjemahan',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                              Slider(
                                value: curSize,
                                min: 11,
                                max: 26,
                                divisions: 15,
                                label: curSize.round().toString(),
                                activeColor: AppTheme.primary,
                                onChanged: (val) {
                                  setSS(() => curSize = val);
                                  ref.read(settingsProvider.notifier).setTranslationFontSize(val);
                                },
                              ),
                            ],
                          ),
                        );
                      });
                    },
                  );             // showModalBottomSheet
                },               // onPressed
              ),                 // IconButton (font size)

            ],
          ),           // Row
        ),             // Container (header bar)
        // â”€â”€ Content text â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Text(
            content,
            style: TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: ref.watch(settingsProvider).translationFontSize,
              height: 1.75,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 36, color: AppTheme.outline),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.outline, fontSize: 12)),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Delegate that lets SliverPersistentHeader host the TabBar with a fixed height
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48.0;
  @override
  double get maxExtent => 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return tabBar;
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _NavButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _NavButton({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? AppTheme.primary : AppTheme.outline,
              fontSize: 12,
              fontWeight: enabled ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

