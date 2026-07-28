import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/web_audio_player.dart';
import '../../core/theme.dart';
import '../../core/settings_manager.dart';
import '../../core/bookmarks_manager.dart';
import '../../shared/widgets/islamic_star.dart';
import '../../shared/widgets/tajweed_text.dart';
import '../../shared/widgets/reciter_picker_sheet.dart';
import '../../core/quran_sources.dart';
import '../mushaf/source_picker_sheet.dart';
import '../../core/local_db.dart';
import '../../core/cdn_translation_service.dart';
import '../../core/murajaah_service.dart';

class SurahDetailScreen extends ConsumerStatefulWidget {
  final int surahId;
  final bool autoplay;
  final int? initialAyah;

  const SurahDetailScreen({
    super.key,
    required this.surahId,
    this.autoplay = false,
    this.initialAyah,
  });

  @override
  ConsumerState<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends ConsumerState<SurahDetailScreen> {
  Map<String, dynamic>? _surah;
  List<Map<String, dynamic>> _verses = [];
  Map<int, String> _translations = {};
  Map<int, String> _transliterations = {};
  bool _loading = true;
  bool _loadingTrans = false;

  String _selectedSource = 'id.kemenag';
  bool _showTranslation = true;
  bool _showArabic = true;
  bool _showTranslit = true;
  bool _showTajweedColors = false;
  int? _firstPageNumber; 

  // Audio Playback
  final WebAudioPlayer _audioPlayer = WebAudioPlayer();
  bool _isPlaying = false;
  int? _playingAyahNum;
  late StreamSubscription _playerStateSubscription;
  late StreamSubscription _playerCompleteSubscription;

  // Scrolling reference
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  // Go to Ayah feature state
  int _selectedSurahId = 1;
  final _ayahController = TextEditingController(text: '1');
  List<Map<String, dynamic>> _dropdownSurahs = [];
  Set<String> _bookmarkedKeys = {};
  String? _lastLang;
  String? _lastSyncedMurajaahVerseKey;

  String get _currentLang => ref.watch(settingsProvider).appLanguage;

  @override
  void initState() {
    super.initState();
    _selectedSurahId = widget.surahId;
    _selectedSource = ref.read(settingsProvider).defaultTranslationSource;
    _load().then((_) {
      if (widget.autoplay && mounted) {
        _playAudioForVerse(1);
      } else if (widget.initialAyah != null && mounted) {
        _scrollToAyah(widget.initialAyah!);
      }
    });
    _loadSurahsList();

    // Bind audio listeners
    _playerStateSubscription = _audioPlayer.onStateChange.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    _playerCompleteSubscription = _audioPlayer.onComplete.listen((_) async {
      if (_playingAyahNum != null && _verses.isNotEmpty) {
        final currentIndex = _verses.indexWhere((v) => v['ayah_number'] == _playingAyahNum);
        if (currentIndex != -1 && currentIndex + 1 < _verses.length) {
          final nextVerse = _verses[currentIndex + 1];
          await _playAudioForVerse(nextVerse['ayah_number']);
        } else {
          if (widget.surahId < 114) {
            if (mounted) {
              context.go('/surahs/${widget.surahId + 1}?autoplay=1');
            }
          } else {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _playingAyahNum = null;
              });
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _playerStateSubscription.cancel();
    _playerCompleteSubscription.cancel();
    _audioPlayer.dispose();
    _ayahController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SurahDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahId != widget.surahId) {
      _isPlaying = false;
      _audioPlayer.stop();
      _playingAyahNum = null;
      _load().then((_) {
        if (widget.autoplay && mounted) {
          _playAudioForVerse(1);
        }
      });
    } else if (widget.initialAyah != null && widget.initialAyah != oldWidget.initialAyah) {
      _scrollToAyah(widget.initialAyah!);
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
      debugPrint('Error loading surahs dropdown: $e');
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = LocalDatabase.instance;
    Map<String, dynamic>? surahRes;
    List<Map<String, dynamic>> versesList = [];
    int? firstPage;

    try {
      final onlineSurah = await Supabase.instance.client
          .from('surahs').select().eq('id', widget.surahId).single();
      surahRes = onlineSurah;
      await db.saveSurahs([onlineSurah]);

      List<Map<String, dynamic>> onlineVerses;
      try {
        final versesRes = await Supabase.instance.client
            .from('verses')
            .select('id, ayah_number, verse_key, text_ar, transliteration')
            .eq('sura_id', widget.surahId);
        onlineVerses = List<Map<String, dynamic>>.from(versesRes);
      } catch (_) {
        final versesRes = await Supabase.instance.client
            .from('verses')
            .select('id, ayah_number, verse_key, text_ar')
            .eq('sura_id', widget.surahId);
        onlineVerses = List<Map<String, dynamic>>.from(versesRes);
      }
      versesList = onlineVerses;
      versesList.sort((a, b) =>
          (a['ayah_number'] as int).compareTo(b['ayah_number'] as int));

      await db.saveVerses(versesList, widget.surahId);

      if (versesList.isNotEmpty) {
        final firstVerseId = versesList.first['id'] as int;
        try {
          final pageRes = await Supabase.instance.client
              .from('verses')
              .select('page_number')
              .eq('id', firstVerseId)
              .single();
          firstPage = pageRes['page_number'] as int?;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('SurahDetail online load failed, trying local DB: $e');
      surahRes = await db.getSurah(widget.surahId);
      versesList = await db.getVerses(widget.surahId);
    }

    Set<String> bookmarkedKeys = {};
    try {
      final bookmarksList = await BookmarksManager.getBookmarks();
      bookmarkedKeys = bookmarksList.map((b) => b['verseKey'] as String).toSet();
    } catch (_) {}

    setState(() {
      _surah = surahRes;
      _verses = versesList;
      _firstPageNumber = firstPage;
      _bookmarkedKeys = bookmarkedKeys;
      _loading = false;
    });

    // Save Last Read to sync immediately with Home Widget
    final initialAyahNum = widget.initialAyah ?? 1;
    final sName = surahRes != null ? (surahRes['name_en'] as String? ?? 'Surah ${widget.surahId}') : 'Surah ${widget.surahId}';
    final totalAyahs = versesList.isNotEmpty ? versesList.length : 50;
    await BookmarksManager.saveLastRead(
      surahId: widget.surahId,
      ayahNumber: initialAyahNum,
      surahName: sName,
      maxAyahs: totalAyahs,
    );

    await _loadTranslations();

    final murajaah = ref.read(murajaahProvider);
    if (murajaah.sessionActive && murajaah.currentVerse != null && murajaah.currentVerse!.surahId == widget.surahId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyah(murajaah.currentVerse!.ayahNumber);
      });
    }
  }

  Future<void> _loadTranslations() async {
    if (_verses.isEmpty) return;
    setState(() => _loadingTrans = true);
    final db = LocalDatabase.instance;
    final verseIds = _verses.map((v) => v['id'] as int).toList();
    final verseKeys = _verses.map((v) => (v['verse_key'] as String?) ?? '').toList();

    final map = <int, String>{};
    
    const primarySources = {
      'en.sahih',
      'id.kemenag',
      'id.indonesian',
      'en.transliteration',
      'id.kemenag_translit',
    };
    
    final isPrimary = primarySources.contains(_selectedSource);
    bool loadedFromSupabase = false;

    if (isPrimary) {
      try {
        final res = await Supabase.instance.client
            .from('translations')
            .select('verse_id, text')
            .eq('source_id', _selectedSource)
            .inFilter('verse_id', verseIds);
        
        if (res.isNotEmpty) {
          loadedFromSupabase = true;
          for (final r in res) {
            if (r['verse_id'] != null) {
              final vId = r['verse_id'] as int;
              final txt = (r['text'] as String?) ?? '';
              map[vId] = txt;
              
              final vMap = _verses.firstWhere((v) => v['id'] == vId, orElse: () => {});
              final vKey = vMap['verse_key'] as String?;
              if (vKey != null) {
                unawaited(db.saveTextData('translations', vKey, _selectedSource, txt));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('SurahDetail translation online load failed: $e');
      }
    }

    if (!loadedFromSupabase) {
      // 1. Try local DB first
      final localTrans = await db.getBatchTextData('translations', _selectedSource, verseKeys);
      for (final v in _verses) {
        final vKey = v['verse_key'] as String?;
        final vId = v['id'] as int?;
        if (vKey != null && vId != null && localTrans.containsKey(vKey)) {
          map[vId] = localTrans[vKey]!;
        }
      }
      
      // 2. Fetch missing from CDN
      final missingVerses = _verses.where((v) {
        final vId = v['id'] as int?;
        return vId != null && !map.containsKey(vId);
      }).toList();
      
      if (missingVerses.isNotEmpty) {
        try {
          final cdn = CdnTranslationService.instance;
          for (final v in missingVerses) {
            final vKey = v['verse_key'] as String?;
            final vId = v['id'] as int?;
            if (vKey != null && vId != null) {
              final text = await cdn.getVerse(_selectedSource, vKey);
              if (text != null) {
                map[vId] = text;
                unawaited(db.saveTextData('translations', vKey, _selectedSource, text));
              }
            }
          }
        } catch (e) {
          debugPrint('SurahDetail translation CDN load failed: $e');
        }
      }
    }

    final translitMap = <int, String>{};
    final translitSource = ref.read(settingsProvider).appLanguage == 'en' ? 'en.transliteration' : 'id.kemenag_translit';
    try {
      final translitRes = await Supabase.instance.client
          .from('translations')
          .select('verse_id, text')
          .eq('source_id', translitSource)
          .inFilter('verse_id', verseIds);
      
      for (final r in translitRes) {
        if (r['verse_id'] != null) {
          final vId = r['verse_id'] as int;
          final txt = (r['text'] as String?) ?? '';
          translitMap[vId] = txt;

          final vMap = _verses.firstWhere((v) => v['id'] == vId, orElse: () => {});
          final vKey = vMap['verse_key'] as String?;
          if (vKey != null) {
            unawaited(db.saveTextData('translations', vKey, translitSource, txt));
          }
        }
      }
    } catch (e) {
      debugPrint('SurahDetail transliteration online load failed, trying local DB: $e');
      final localTranslit = await db.getBatchTextData('translations', translitSource, verseKeys);
      for (final v in _verses) {
        final vKey = v['verse_key'] as String?;
        final vId = v['id'] as int?;
        if (vKey != null && vId != null && localTranslit.containsKey(vKey)) {
          translitMap[vId] = localTranslit[vKey]!;
        }
      }
    }

    setState(() {
      _translations = map;
      _transliterations = translitMap;
      _loadingTrans = false;
    });
  }

  Future<void> _toggleBookmarkForVerse(Map<String, dynamic> verse) async {
    final verseKey = (verse['verse_key'] as String?) ?? '';
    final arabicText = (verse['text_ar'] as String?) ?? '';
    final surahNameEn = _surah != null ? (_surah!['name_en'] as String? ?? '') : 'Surah ${widget.surahId}';
    final translation = _translations[verse['id']] ?? '';

    final added = await BookmarksManager.toggleBookmark(
      surahId: widget.surahId,
      ayahNumber: verse['ayah_number'] as int? ?? 1,
      surahName: surahNameEn,
      verseKey: verseKey,
      textAr: arabicText,
      translation: translation,
    );

    setState(() {
      if (added) {
        _bookmarkedKeys.add(verseKey);
      } else {
        _bookmarkedKeys.remove(verseKey);
      }
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

  void _showBookmarkOptionsForVerse(BuildContext context, Map<String, dynamic> verse) {
    final isEn = _currentLang == 'en';
    final verseKey = (verse['verse_key'] as String?) ?? '';
    final isBookmarked = _bookmarkedKeys.contains(verseKey);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: AppTheme.primary,
                ),
                title: Text(
                  isBookmarked 
                      ? (isEn ? 'Remove from Bookmarks' : 'Hapus dari Bookmark')
                      : (isEn ? 'Add to Bookmarks' : 'Tambah ke Bookmark'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleBookmarkForVerse(verse);
                },
              ),
              ListTile(
                leading: Icon(Icons.bookmark_outline, color: AppTheme.secondary),
                title: Text(
                  isEn ? 'Go to Bookmarks Page' : 'Buka Halaman Bookmark',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/bookmarks');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  String _getAudioUrl(int ayahNum, {bool useMirror = true}) {
    final reciter = ref.read(settingsProvider).selectedReciter;
    return QuranSources.buildAudioUrl(reciter, widget.surahId, ayahNum, useMirror: useMirror);
  }

  Future<void> _playAudioForVerse(int ayahNum, {bool isFallback = false}) async {
    setState(() {
      _playingAyahNum = ayahNum;
    });

    // Auto scroll to active verse card
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _ayahKeys[ayahNum];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.2,
        );
      }
    });

    final sName = _surah != null ? (_surah!['name_en'] as String? ?? '') : '';
    await BookmarksManager.saveLastRead(
      surahId: widget.surahId,
      ayahNumber: ayahNum,
      surahName: sName,
    );

    try {
      // Check for a locally cached full-surah file first
      final reciter = ref.read(settingsProvider).selectedReciter;
      final localPath = await LocalDatabase.instance.getAudioFile(reciter, widget.surahId);

      if (localPath != null) {
        // On web, local files aren't accessible; stream from network instead
        final url = _getAudioUrl(ayahNum, useMirror: !isFallback);
        _audioPlayer.play(url);
      } else {
        // Stream from network
        final url = _getAudioUrl(ayahNum, useMirror: !isFallback);
        _audioPlayer.play(url);
      }
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      if (!isFallback) {
        await _playAudioForVerse(ayahNum, isFallback: true);
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      final targetAyah = _playingAyahNum ?? 1;
      await _playAudioForVerse(targetAyah);
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
                _playingAyahNum = null;
              });
            }
            if (wasPlaying) {
              await _playAudioForVerse(1);
            }
          },
        );
      },
    );
  }

  void _showTranslationSourcePicker() {
    final title = _currentLang == 'en' ? 'Select Translation' : 'Pilih Terjemahan';
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
          currentSource: _selectedSource,
          onSelected: (newSrc) {
            setState(() {
              _selectedSource = newSrc;
            });
            _loadTranslations();
          },
        );
      },
    );
  }

  void _copySurahLink() {
    if (_surah == null) return;
    final isEn = _currentLang == 'en';
    final surahName = isEn ? (_surah!['name_en'] ?? '') : (_surah!['name_id'] ?? _surah!['name_en'] ?? '');
    const webBase = 'https://tafseer.id';
    final link = '$webBase/#sura/${widget.surahId}';
    Clipboard.setData(ClipboardData(text: 'Surah $surahName (${widget.surahId})\n\n$link'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEn ? 'Surah link copied to clipboard' : 'Tautan surah berhasil disalin'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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

  void _swipeToSurah(int surahId) {
    if (surahId < 1 || surahId > 114) return;
    context.go('/surahs/$surahId');
  }

  // ── Scroll to ayah in list ─────────────────────────────────────────────
  void _scrollToAyah(int ayahNumber) {
    if (_verses.isEmpty) return;
    final idx = _verses.indexWhere((v) => (v['ayah_number'] as int) == ayahNumber);
    if (idx < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      const double headerHeight = 280.0;
      const double approxCardHeight = 180.0;
      final approxOffset = (headerHeight + idx * approxCardHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        approxOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        if (!mounted) return;
        final key = _ayahKeys[ayahNumber];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            alignment: 0.2,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (_lastLang != settings.appLanguage) {
      _lastLang = settings.appLanguage;
      _selectedSource = settings.defaultTranslationSource;
      Future.microtask(() => _loadTranslations());
    }

    // Auto-scroll to active verse or navigate to new surah when Murajaah audio plays
    final murajaahState = ref.watch(murajaahProvider);
    if (murajaahState.sessionActive && murajaahState.isPlaying && murajaahState.currentVerse != null) {
      final verse = murajaahState.currentVerse!;
      if (_lastSyncedMurajaahVerseKey != verse.verseKey) {
        _lastSyncedMurajaahVerseKey = verse.verseKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (verse.surahId != widget.surahId) {
            context.go('/surahs/${verse.surahId}?ayah=${verse.ayahNumber}');
          } else {
            _scrollToAyah(verse.ayahNumber);
          }
        });
      }
    } else if (!murajaahState.sessionActive) {
      _lastSyncedMurajaahVerseKey = null;
    }

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (_surah == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceContainer,
          title: Text('Surah ${widget.surahId}', style: TextStyle(color: AppTheme.onSurface)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, color: AppTheme.outline, size: 56),
              const SizedBox(height: 16),
              Text(
                _currentLang == 'id' ? 'Data tidak tersedia' : 'Data not available',
                style: TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _currentLang == 'id'
                    ? 'Periksa koneksi internet dan coba lagi'
                    : 'Check your internet connection and try again',
                style: TextStyle(color: AppTheme.outline, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(_currentLang == 'id' ? 'Coba Lagi' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final surah = _surah!;

    final isEn = _currentLang == 'en';
    final surahDisplayName = isEn
        ? (surah['name_en'] as String? ?? '')
        : (surah['name_id'] as String? ?? surah['name_en'] as String? ?? '');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          // Swipe left → next surah, swipe right → prev surah
          if (details.primaryVelocity! < -400) {
            _swipeToSurah(widget.surahId + 1);
          } else if (details.primaryVelocity! > 400) {
            _swipeToSurah(widget.surahId - 1);
          }
        },
        child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.surfaceContainer,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF0D3040), Color(0xFF0A1C28)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        Text(surah['name_ar'] ?? '',
                          style: AppTheme.arabicStyle(fontSize: 32, fontWeight: FontWeight.w700),
                          textDirection: TextDirection.rtl),
                        const SizedBox(height: 8),
                        Text(
                          '$surahDisplayName — ${isEn ? (surah['meaning'] ?? '') : (surah['meaning_id'] ?? surah['meaning'] ?? '')}',
                          style: TextStyle(color: AppTheme.onSurface,
                            fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _Badge(isEn ? '${surah['ayas']} verses' : '${surah['ayas']} ayat'),
                          const SizedBox(width: 8),
                          _Badge(isEn
                              ? (surah['type'] ?? '')
                              : (surah['type'] == 'Meccan' ? 'Makkiyah' : 'Madaniyah')),
                          const SizedBox(width: 8),
                          _Badge('Surah ${surah['id']}'),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              // Tajweed Pill button
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  onTap: () => setState(() => _showTajweedColors = !_showTajweedColors),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _showTajweedColors ? const Color(0xFF2DB56B).withValues(alpha: 0.15) : AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showTajweedColors ? const Color(0xFF2DB56B) : AppTheme.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ت',
                          style: AppTheme.arabicStyle(
                            fontSize: 14,
                            color: _showTajweedColors ? const Color(0xFF2DB56B) : AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isEn ? 'Tajweed' : 'Tajwid',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _showTajweedColors ? const Color(0xFF2DB56B) : AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Audio Play button
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, color: AppTheme.primary, size: 24),
                tooltip: isEn ? 'Play Audio' : 'Putar Audio',
                onPressed: _toggleAudio,
              ),
              // Translation source picker
              IconButton(
                icon: Icon(Icons.translate, color: AppTheme.primary),
                tooltip: isEn ? 'Translation' : 'Terjemahan',
                onPressed: _showTranslationSourcePicker,
              ),
              // Display options
              PopupMenuButton<String>(
                icon: Icon(Icons.tune, color: AppTheme.outline),
                color: AppTheme.surfaceContainer,
                tooltip: isEn ? 'Display' : 'Tampilan',
                onSelected: (v) => setState(() {
                  if (v == 'arabic') _showArabic = !_showArabic;
                  if (v == 'translit') _showTranslit = !_showTranslit;
                  if (v == 'translation') _showTranslation = !_showTranslation;
                }),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'arabic', child: Row(children: [
                    Icon(_showArabic ? Icons.check_box : Icons.check_box_outline_blank,
                      color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8), Text(isEn ? 'Show Arabic' : 'Tampilkan Arab'),
                  ])),
                  PopupMenuItem(value: 'translit', child: Row(children: [
                    Icon(_showTranslit ? Icons.check_box : Icons.check_box_outline_blank,
                      color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8), Text(isEn ? 'Show Transliteration' : 'Tampilkan Transliterasi'),
                  ])),
                  PopupMenuItem(value: 'translation', child: Row(children: [
                    Icon(_showTranslation ? Icons.check_box : Icons.check_box_outline_blank,
                      color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8), Text(isEn ? 'Show Translation' : 'Tampilkan Terjemahan'),
                  ])),
                ],
              ),
              // Overflow — secondary actions
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.primary),
                tooltip: isEn ? 'More' : 'Lainnya',
                color: AppTheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  switch (value) {
                    case 'lang_en':
                      ref.read(settingsProvider.notifier).setAppLanguage('en');
                      setState(() {});
                      break;
                    case 'lang_id':
                      ref.read(settingsProvider.notifier).setAppLanguage('id');
                      setState(() {});
                      break;
                    case 'reciter':
                      _showReciterSelection();
                      break;
                    case 'mushaf':
                      if (_firstPageNumber != null) {
                        context.go('/mushaf?page=$_firstPageNumber');
                      }
                      break;
                    case 'murajaah':
                      context.go('/murajaah');
                      break;
                    case 'share':
                      _copySurahLink();
                      break;
                    case 'settings':
                      context.push('/settings');
                      break;
                  }
                },
                itemBuilder: (ctx) {
                  return [
                    // Language header
                    PopupMenuItem<String>(
                      enabled: false,
                      height: 28,
                      child: Text(
                        isEn ? 'LANGUAGE' : 'BAHASA',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.outline,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'lang_en',
                      child: Row(children: [
                        Icon(Icons.language, size: 18,
                            color: _currentLang == 'en' ? AppTheme.primary : AppTheme.outline),
                        const SizedBox(width: 10),
                        Expanded(child: Text('English', style: TextStyle(
                          fontSize: 13,
                          color: _currentLang == 'en' ? AppTheme.primary : AppTheme.onSurface,
                          fontWeight: _currentLang == 'en' ? FontWeight.bold : FontWeight.normal,
                        ))),
                        if (_currentLang == 'en')
                          Icon(Icons.check, size: 14, color: AppTheme.primary),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'lang_id',
                      child: Row(children: [
                        Icon(Icons.language, size: 18,
                            color: _currentLang == 'id' ? AppTheme.primary : AppTheme.outline),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Indonesia', style: TextStyle(
                          fontSize: 13,
                          color: _currentLang == 'id' ? AppTheme.primary : AppTheme.onSurface,
                          fontWeight: _currentLang == 'id' ? FontWeight.bold : FontWeight.normal,
                        ))),
                        if (_currentLang == 'id')
                          Icon(Icons.check, size: 14, color: AppTheme.primary),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'reciter',
                      child: Row(children: [
                        Icon(Icons.record_voice_over, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        Text(isEn ? 'Select Reciter' : 'Pilih Qori',
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                    if (_firstPageNumber != null)
                      PopupMenuItem<String>(
                        value: 'mushaf',
                        child: Row(children: [
                          AppTheme.getMushafIcon(color: AppTheme.primary, size: 18),
                          const SizedBox(width: 10),
                          Text(isEn ? 'Read in Mushaf' : 'Buka Mushaf',
                              style: const TextStyle(fontSize: 13)),
                        ]),
                      ),
                    PopupMenuItem<String>(
                      value: 'murajaah',
                      child: Row(children: [
                        const Icon(Icons.headphones_rounded, size: 18, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 10),
                        Text(isEn ? 'Murajaah' : 'Murājaah',
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'share',
                      child: Row(children: [
                        Icon(Icons.share, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        Text(isEn ? 'Copy & Share' : 'Salin & Bagikan',
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'settings',
                      child: Row(children: [
                        Icon(Icons.settings_outlined, size: 18, color: AppTheme.outline),
                        const SizedBox(width: 10),
                        Text(isEn ? 'Settings' : 'Pengaturan',
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ];
                },
              ),
            ],

          ),

          // ── Go to Ayah Row (Exactly same style and logic as Home) ───────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            style: TextStyle(
                              color: AppTheme.outline,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _showSurahPicker,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
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
                                          ? '$_selectedSurahId'
                                          : isEn
                                              ? '${s['id']}. ${s['name_en'] ?? ''}'
                                              : '${s['id']}. ${s['name_id'] ?? s['name_en'] ?? ''}';
                                      return Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.onSurface,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }),
                                  ),
                                  Icon(Icons.arrow_drop_down, color: AppTheme.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'AYAH (1-$_maxAyas)' : 'AYAT (1-$_maxAyas)',
                            style: TextStyle(
                              color: AppTheme.outline,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 42,
                            child: TextField(
                              controller: _ayahController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                filled: true,
                                fillColor: AppTheme.surfaceContainerHigh,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () {
                          final aNum = int.tryParse(_ayahController.text.trim()) ?? 1;
                          final validAyah = aNum.clamp(1, _maxAyas);
                          if (_selectedSurahId == widget.surahId) {
                            final key = _ayahKeys[validAyah];
                            if (key?.currentContext != null) {
                              Scrollable.ensureVisible(
                                key!.currentContext!,
                                duration: const Duration(milliseconds: 300),
                                alignment: 0.2,
                              );
                            }
                          } else {
                            context.go('/surahs/$_selectedSurahId/ayahs/$validAyah');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          elevation: 0,
                        ),
                        child: Text(isEn ? 'GO' : 'GO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (surah['id'] != 9)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  textAlign: TextAlign.center, textDirection: TextDirection.rtl,
                  style: AppTheme.arabicStyle(fontSize: 22)),
              ),
            ),

          if (_loadingTrans)
            SliverToBoxAdapter(
              child: LinearProgressIndicator(
                color: AppTheme.primary, backgroundColor: AppTheme.surfaceContainerHigh),
            ),

          if (_showTajweedColors)
            SliverToBoxAdapter(
              child: TajweedLegend(isEn: isEn),
            ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final v = _verses[i];
                  final aNum = v['ayah_number'] as int;
                  final key = _ayahKeys.putIfAbsent(aNum, () => GlobalKey());
                  final murajaahState = ref.watch(murajaahProvider);
                  final isMurajaahPlaying = murajaahState.sessionActive &&
                      murajaahState.isPlaying &&
                      murajaahState.currentVerse?.surahId == widget.surahId &&
                      murajaahState.currentVerse?.ayahNumber == aNum;

                  return Container(
                    key: key,
                    child: _VerseCard(
                      surahId: widget.surahId,
                      verse: v,
                      translation: _translations[v['id'] as int],
                      transliteration: _transliterations[v['id'] as int],
                      showArabic: _showArabic,
                      showTranslit: _showTranslit,
                      showTranslation: _showTranslation,
                      showTajweedColors: _showTajweedColors,
                      isPlaying: (_playingAyahNum == aNum && _isPlaying) || isMurajaahPlaying,
                      isBookmarked: _bookmarkedKeys.contains(v['verse_key'] as String? ?? ''),
                      onPlayTapped: () {
                        if (_playingAyahNum == aNum && _isPlaying) {
                          _toggleAudio();
                        } else {
                          _playAudioForVerse(aNum);
                        }
                      },
                      onBookmarkTapped: () => _showBookmarkOptionsForVerse(context, v),
                    ),
                  );
                },
                childCount: _verses.length,
              ),
            ),
          ),
        ],
      ),
     ),
      bottomNavigationBar: Container(
        color: AppTheme.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavButton(
              label: isEn ? '← Prev Surah' : '← Surah Sebelum',
              enabled: widget.surahId > 1,
              onTap: () => _swipeToSurah(widget.surahId - 1),
            ),
            Text(
              'Surah ${widget.surahId} / 114',
              style: TextStyle(color: AppTheme.outline, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            _NavButton(
              label: isEn ? 'Next Surah →' : 'Surah Berikut →',
              enabled: widget.surahId < 114,
              onTap: () => _swipeToSurah(widget.surahId + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: AppTheme.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.outlineVariant)),
    child: Text(text, style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 11)),
  );
}

class _VerseCard extends ConsumerWidget {
  final int surahId;
  final Map<String, dynamic> verse;
  final String? translation;
  final String? transliteration;
  final bool showArabic;
  final bool showTranslit;
  final bool showTranslation;
  final bool showTajweedColors;
  final bool isPlaying;
  final bool isBookmarked;
  final VoidCallback onPlayTapped;
  final VoidCallback onBookmarkTapped;

  const _VerseCard({
    required this.surahId,
    required this.verse,
    required this.translation,
    required this.transliteration,
    required this.showArabic,
    required this.showTranslit,
    required this.showTranslation,
    this.showTajweedColors = false,
    required this.isPlaying,
    required this.isBookmarked,
    required this.onPlayTapped,
    required this.onBookmarkTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ayahNum = verse['ayah_number'] as int;
    final verseKey = (verse['verse_key'] as String?) ?? '';
    final arabic = (verse['text_ar'] as String?) ?? '';

    final Color bgColor = isPlaying
        ? AppTheme.secondary.withValues(alpha: 0.08)
        : AppTheme.surfaceContainer;
    final Color borderColor = isPlaying
        ? AppTheme.secondary
        : AppTheme.outlineVariant;
    final double borderWidth = isPlaying ? 1.5 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/surahs/$surahId/ayahs/$ayahNum'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isPlaying ? AppTheme.secondary.withValues(alpha: 0.12) : AppTheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                IslamicStar(
                  size: 32,
                  color: isPlaying ? AppTheme.secondary.withValues(alpha: 0.12) : AppTheme.primary.withValues(alpha: 0.12),
                  borderColor: isPlaying ? AppTheme.secondary.withValues(alpha: 0.4) : AppTheme.primary.withValues(alpha: 0.4),
                  child: Text('$ayahNum',
                    style: TextStyle(
                      color: isPlaying ? AppTheme.secondary : AppTheme.primary, 
                      fontSize: 10, 
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(verseKey, style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                if (isPlaying) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.volume_up, color: AppTheme.secondary, size: 16),
                  const SizedBox(width: 4),
                  Text('PLAYING', style: TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
                const Spacer(),
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_outline, 
                    size: 20, 
                    color: isPlaying ? AppTheme.secondary : AppTheme.primary),
                  tooltip: isPlaying ? 'Pause' : 'Play', 
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onPlayTapped,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, size: 16, color: isBookmarked ? Colors.amber : AppTheme.outline),
                  tooltip: 'Bookmark', padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onBookmarkTapped,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: AppTheme.getMushafIcon(size: 16, color: AppTheme.primary),
                  tooltip: 'Read in Mushaf', padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context.go('/mushaf?verse_key=$verseKey'),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (showArabic) ...[
                  TajweedText(
                    arabic: arabic,
                    fontSize: settings.arabicFontSize * 0.82,
                    fallbackColor: isPlaying ? AppTheme.secondary : AppTheme.primary,
                    enabled: showTajweedColors,
                    textAlign: TextAlign.right,
                  ),
                  if ((showTranslit && settings.showTransliteration) || showTranslation)
                    Padding(padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: AppTheme.outlineVariant)),
                ],
                if (showTranslit && settings.showTransliteration) ...[
                  AppTheme.buildFormattedText(
                    transliteration ?? '',
                    TextStyle(
                      color: AppTheme.outline,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                  ),
                  if (showTranslation)
                    Padding(padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: AppTheme.outlineVariant)),
                ],
                if (showTranslation)
                  translation != null
                    ? Text(translation!,
                        style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: settings.translationFontSize, height: 1.7))
                    : Text('Loading translation...',
                        style: TextStyle(color: AppTheme.outline, fontSize: 13,
                          fontStyle: FontStyle.italic)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

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
