// lib/features/murajaah/murajaah_screen.dart
//
// Murajaah — Quran Memorization Audio Tool
//
// Allows the user to define a range of verses (Start Surah/Ayah → End Surah/Ayah),
// configure repetitions (per-ayah and per-playlist), and play audio sequentially
// with a live highlighted verse display.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/settings_manager.dart';
import '../../core/quran_sources.dart';
import '../../core/web_audio_player.dart';

// ─── Data model ─────────────────────────────────────────────────────────────

class _VerseEntry {
  final int surahId;
  final int ayahNumber;
  final int globalId;
  final String verseKey;
  final String textAr;

  const _VerseEntry({
    required this.surahId,
    required this.ayahNumber,
    required this.globalId,
    required this.verseKey,
    required this.textAr,
  });
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class MurajaahScreen extends ConsumerStatefulWidget {
  const MurajaahScreen({super.key});

  @override
  ConsumerState<MurajaahScreen> createState() => _MurajaahScreenState();
}

class _MurajaahScreenState extends ConsumerState<MurajaahScreen> {
  // ── Surah metadata ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _surahs = [];
  bool _loadingSurahs = true;

  // ── Range picker state ──────────────────────────────────────────────────
  int _startSurahId = 1;
  int _startAyah = 1;
  int _endSurahId = 1;
  int _endAyah = 7;

  // ── Repeat config ───────────────────────────────────────────────────────
  int _ayahRepeats = 1;     // how many times each individual ayah plays
  int _playlistRepeats = 1; // how many times the full range plays

  // ── Playback state ──────────────────────────────────────────────────────
  final WebAudioPlayer _player = WebAudioPlayer();
  List<_VerseEntry> _playlist = [];
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _loadingPlaylist = false;
  bool _sessionActive = false; // true while a playback session is running

  int _currentPlaylistIndex = 0;  // index into _playlist
  int _currentAyahRepeat = 0;     // how many times current ayah has played so far
  int _currentPlaylistRepeat = 0; // current pass through the full playlist

  late StreamSubscription _completeSub;
  late StreamSubscription _stateSub;

  // ── Scroll controller ───────────────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};

  @override
  void initState() {
    super.initState();
    _loadSurahs();

    _completeSub = _player.onComplete.listen((_) => _onAyahComplete());
    _stateSub = _player.onStateChange.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    _completeSub.cancel();
    _stateSub.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Surah list loading ──────────────────────────────────────────────────

  Future<void> _loadSurahs() async {
    try {
      final res = await Supabase.instance.client
          .from('surahs')
          .select('id, name_en, name_id, ayas')
          .order('id');
      if (mounted) {
        setState(() {
          _surahs = List<Map<String, dynamic>>.from(res);
          _loadingSurahs = false;
          // Default end to last ayah of Al-Fatiha
          _updateEndAyahMax();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSurahs = false);
    }
  }

  int _ayasForSurah(int id) {
    final s = _surahs.firstWhere((x) => x['id'] == id, orElse: () => {'ayas': 7});
    return (s['ayas'] as num?)?.toInt() ?? 7;
  }

  void _updateEndAyahMax() {
    final maxEnd = _ayasForSurah(_endSurahId);
    if (_endAyah > maxEnd) setState(() => _endAyah = maxEnd);
    final maxStart = _ayasForSurah(_startSurahId);
    if (_startAyah > maxStart) setState(() => _startAyah = maxStart);
  }

  String _surahLabel(int id) {
    final isEn = ref.read(settingsProvider).appLanguage == 'en';
    final s = _surahs.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (s.isEmpty) return '$id';
    final name = isEn ? (s['name_en'] ?? '') : (s['name_id'] ?? '');
    return '$id. $name';
  }

  // ── Playlist builder ────────────────────────────────────────────────────

  Future<void> _buildPlaylist() async {
    setState(() => _loadingPlaylist = true);

    // Collect all (surahId, ayahNumber) pairs in the range
    final pairs = <Map<String, int>>[];
    for (int s = _startSurahId; s <= _endSurahId; s++) {
      final maxAyas = _ayasForSurah(s);
      final startA = (s == _startSurahId) ? _startAyah : 1;
      final endA   = (s == _endSurahId)   ? _endAyah   : maxAyas;
      for (int a = startA; a <= endA; a++) {
        pairs.add({'surah': s, 'ayah': a});
      }
    }

    if (pairs.isEmpty) {
      setState(() { _loadingPlaylist = false; _playlist = []; });
      return;
    }

    // Fetch verse IDs and Arabic text from Supabase
    final keys = pairs.map((p) => '${p['surah']}:${p['ayah']}').toList();
    try {
      final res = await Supabase.instance.client
          .from('verses')
          .select('id, sura_id, ayah_number, verse_key, text_ar')
          .inFilter('verse_key', keys);

      final map = <String, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(res)) {
        map[row['verse_key'] as String] = row;
      }

      final entries = <_VerseEntry>[];
      for (final p in pairs) {
        final vk = '${p['surah']}:${p['ayah']}';
        final row = map[vk];
        if (row != null) {
          entries.add(_VerseEntry(
            surahId: row['sura_id'] as int,
            ayahNumber: row['ayah_number'] as int,
            globalId: row['id'] as int,
            verseKey: vk,
            textAr: row['text_ar'] as String? ?? '',
          ));
        }
      }

      if (mounted) setState(() { _playlist = entries; _loadingPlaylist = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingPlaylist = false; });
      _showError('Failed to load verses: $e');
    }
  }

  // ── Playback controls ───────────────────────────────────────────────────

  Future<void> _startPlayback() async {
    if (_playlist.isEmpty) return;
    _currentPlaylistIndex = 0;
    _currentAyahRepeat = 0;
    _currentPlaylistRepeat = 0;
    _isPaused = false;
    _sessionActive = true;
    await _playCurrentAyah();
  }

  Future<void> _playCurrentAyah() async {
    if (_currentPlaylistIndex >= _playlist.length) return;
    final verse = _playlist[_currentPlaylistIndex];
    final reciter = ref.read(settingsProvider).selectedReciter;
    final url = QuranSources.buildAudioUrl(reciter, verse.surahId, verse.ayahNumber);
    if (mounted) setState(() {});
    _scrollToActiveRow(verse.globalId);
    await _player.play(url);
  }

  void _onAyahComplete() {
    // Guard: only advance if a session is actively running
    if (!_sessionActive) return;
    if (!mounted) return;

    _currentAyahRepeat++;

    if (_currentAyahRepeat < _ayahRepeats) {
      // Repeat current ayah
      _playCurrentAyah();
      return;
    }

    // Move to next ayah
    _currentAyahRepeat = 0;
    _currentPlaylistIndex++;

    if (_currentPlaylistIndex >= _playlist.length) {
      // End of playlist pass
      _currentPlaylistRepeat++;
      if (_currentPlaylistRepeat < _playlistRepeats) {
        // Repeat whole playlist
        _currentPlaylistIndex = 0;
        _playCurrentAyah();
      } else {
        // Done
        if (mounted) setState(() { _isPlaying = false; _isPaused = false; _sessionActive = false; });
      }
      return;
    }

    _playCurrentAyah();
  }

  Future<void> _pause() async {
    await _player.pause();
    if (mounted) setState(() { _isPlaying = false; _isPaused = true; });
  }

  Future<void> _resume() async {
    if (_isPaused) {
      await _player.resume();
      if (mounted) setState(() { _isPlaying = true; _isPaused = false; });
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _sessionActive = false;
        _currentPlaylistIndex = 0;
        _currentAyahRepeat = 0;
        _currentPlaylistRepeat = 0;
      });
    }
  }

  Future<void> _skipNext() async {
    if (_playlist.isEmpty) return;
    _currentAyahRepeat = 0;
    _currentPlaylistIndex = (_currentPlaylistIndex + 1).clamp(0, _playlist.length - 1);
    await _playCurrentAyah();
  }

  Future<void> _skipPrev() async {
    if (_playlist.isEmpty) return;
    _currentAyahRepeat = 0;
    _currentPlaylistIndex = (_currentPlaylistIndex - 1).clamp(0, _playlist.length - 1);
    await _playCurrentAyah();
  }

  void _scrollToActiveRow(int globalId) {
    final key = _rowKeys[globalId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        alignment: 0.4,
      );
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _isRangeValid {
    if (_startSurahId < 1 || _endSurahId < 1) return false;
    if (_startSurahId > _endSurahId) return false;
    if (_startSurahId == _endSurahId && _startAyah > _endAyah) return false;

    final maxStart = _ayasForSurah(_startSurahId);
    final maxEnd = _ayasForSurah(_endSurahId);
    if (_startAyah < 1 || _startAyah > maxStart) return false;
    if (_endAyah < 1 || _endAyah > maxEnd) return false;

    return true;
  }

  String? get _rangeError {
    final isEn = ref.read(settingsProvider).appLanguage == 'en';
    if (_startSurahId > _endSurahId) {
      return isEn
          ? 'Start surah cannot be after end surah'
          : 'Surah mulai tidak boleh setelah surah selesai';
    }
    if (_startSurahId == _endSurahId && _startAyah > _endAyah) {
      return isEn
          ? 'Start ayah cannot be after end ayah'
          : 'Ayat mulai tidak boleh setelah ayat selesai';
    }
    final maxStart = _ayasForSurah(_startSurahId);
    if (_startAyah < 1 || _startAyah > maxStart) {
      return isEn
          ? 'Start ayah must be between 1 and $maxStart'
          : 'Ayat mulai harus antara 1 dan $maxStart';
    }
    final maxEnd = _ayasForSurah(_endSurahId);
    if (_endAyah < 1 || _endAyah > maxEnd) {
      return isEn
          ? 'End ayah must be between 1 and $maxEnd'
          : 'Ayat selesai harus antara 1 dan $maxEnd';
    }
    return null;
  }

  void _deletePlaylistItem(int idx) {
    if (idx < 0 || idx >= _playlist.length) return;

    final wasActive = idx == _currentPlaylistIndex && (_isPlaying || _isPaused);

    if (wasActive) {
      _stop();
    }

    setState(() {
      if (!wasActive) {
        _playlist.removeAt(idx);
        if (idx < _currentPlaylistIndex) {
          _currentPlaylistIndex--;
        }
      } else {
        _playlist.removeAt(idx);
      }
    });
  }

  // ── UI helpers ──────────────────────────────────────────────────────────

  void _showSurahPicker({
    required int selectedId,
    required ValueChanged<int> onPick,
  }) {
    final isEn = ref.read(settingsProvider).appLanguage == 'en';
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
          final filtered = _surahs.where((s) {
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return (s['name_en'] as String? ?? '').toLowerCase().contains(q) ||
                (s['name_id'] as String? ?? '').toLowerCase().contains(q) ||
                '${s['id']}'.contains(q);
          }).toList();

          return SizedBox(
            height: MediaQuery.of(ctx2).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setSheet(() => query = v),
                    style: TextStyle(color: AppTheme.onSurface),
                    decoration: InputDecoration(
                      hintText: isEn ? 'Search surah…' : 'Cari surah…',
                      hintStyle: TextStyle(color: AppTheme.outline),
                      prefixIcon: Icon(Icons.search, color: AppTheme.outline),
                      filled: true,
                      fillColor: AppTheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      final id = s['id'] as int;
                      final name = isEn ? (s['name_en'] ?? '') : (s['name_id'] ?? '');
                      final selected = id == selectedId;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: selected
                              ? AppTheme.primary
                              : AppTheme.surfaceContainer,
                          child: Text(
                            '$id',
                            style: TextStyle(
                              fontSize: 11,
                              color: selected ? Colors.white : AppTheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(name,
                            style: TextStyle(
                                color: selected ? AppTheme.primary : AppTheme.onSurface,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text('${s['ayas']} ayahs',
                            style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                        onTap: () {
                          onPick(id);
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

  // ── Widgets ─────────────────────────────────────────────────────────────

  Widget _buildSurahAyahRow({
    required String label,
    required int surahId,
    required int ayah,
    required ValueChanged<int> onSurahChanged,
    required ValueChanged<int> onAyahChanged,
  }) {
    final maxAyas = _ayasForSurah(surahId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: GestureDetector(
                onTap: () => _showSurahPicker(
                  selectedId: surahId,
                  onPick: (id) {
                    onSurahChanged(id);
                    _updateEndAyahMax();
                  },
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.expand_more, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _surahLabel(surahId),
                          style: TextStyle(color: AppTheme.onSurface, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('Surah',
                          style: TextStyle(color: AppTheme.outline, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${surahId}_$ayah'),
                        initialValue: '$ayah',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                          hintText: '1',
                          hintStyle: TextStyle(color: AppTheme.outline),
                        ),
                        onChanged: (v) {
                          final parsed = int.tryParse(v) ?? 1;
                          onAyahChanged(parsed.clamp(1, maxAyas));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text('Aya',
                          style: TextStyle(color: AppTheme.outline, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRepeatRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    IconData? icon,
  }) {
    return Row(
      children: [
        Icon(icon ?? Icons.repeat, size: 18, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(color: AppTheme.onSurface, fontSize: 14)),
        ),
        _buildCounter(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildCounter({required int value, required ValueChanged<int> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.remove, size: 16, color: AppTheme.primary),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value×',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 16, color: AppTheme.primary),
            onPressed: value < 99 ? () => onChanged(value + 1) : null,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(int idx) {
    final verse = _playlist[idx];
    final isActive = idx == _currentPlaylistIndex && (_isPlaying || _isPaused);
    final key = _rowKeys.putIfAbsent(verse.globalId, () => GlobalKey());
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.15)
            : AppTheme.surfaceContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isActive
                ? AppTheme.primary
                : AppTheme.surfaceContainerHigh,
            child: isActive
                ? Icon(Icons.volume_up, size: 13, color: Colors.white)
                : Text(
                    '${idx + 1}',
                    style: TextStyle(fontSize: 10, color: AppTheme.outline),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verse.verseKey,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? AppTheme.primary : AppTheme.outline,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  verse.textAr,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                    fontFamily: 'Amiri',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isActive && _isPlaying) ...[
            const SizedBox(width: 8),
            _AnimatedEqualizer(),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade300),
            onPressed: () => _deletePlaylistItem(idx),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls() {
    final hasPlaylist = _playlist.isNotEmpty;
    final loading = _loadingPlaylist;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator
          if (_isPlaying || _isPaused) ...[
            Row(
              children: [
                Text(
                  '${_currentPlaylistIndex + 1} / ${_playlist.length}',
                  style: TextStyle(color: AppTheme.outline, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _playlist.isEmpty
                          ? 0
                          : (_currentPlaylistIndex + 1) / _playlist.length,
                      backgroundColor: AppTheme.outlineVariant.withValues(alpha: 0.3),
                      color: AppTheme.primary,
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pass ${_currentPlaylistRepeat + 1}/$_playlistRepeats',
                  style: TextStyle(color: AppTheme.outline, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Skip Previous
              _ControlButton(
                icon: Icons.skip_previous_rounded,
                size: 28,
                onTap: (_isPlaying || _isPaused) ? _skipPrev : null,
              ),
              const SizedBox(width: 8),
              // Play / Pause / Stop
              if (!_isPlaying && !_isPaused)
                _PlayButton(
                  loading: loading,
                  onTap: hasPlaylist
                      ? () => _startPlayback()
                      : null,
                )
              else if (_isPlaying)
                _PlayButton(
                  icon: Icons.pause_circle_filled_rounded,
                  onTap: _pause,
                )
              else
                _PlayButton(
                  icon: Icons.play_circle_filled_rounded,
                  onTap: _resume,
                ),
              const SizedBox(width: 8),
              // Skip Next
              _ControlButton(
                icon: Icons.skip_next_rounded,
                size: 28,
                onTap: (_isPlaying || _isPaused) ? _skipNext : null,
              ),
              const SizedBox(width: 16),
              // Stop
              if (_isPlaying || _isPaused)
                _ControlButton(
                  icon: Icons.stop_circle_rounded,
                  size: 28,
                  color: Colors.red.shade300,
                  onTap: _stop,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(settingsProvider).appLanguage == 'en';
    final hasPlaylist = _playlist.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerHigh,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.headphones_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              isEn ? 'Murajaah' : 'Murājaah',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: _loadingSurahs
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // ── Config panel ─────────────────────────────────────────
                Flexible(
                  fit: hasPlaylist ? FlexFit.loose : FlexFit.tight,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Start range
                        _buildSurahAyahRow(
                          label: isEn ? 'Start At' : 'Mulai dari',
                          surahId: _startSurahId,
                          ayah: _startAyah,
                          onSurahChanged: (id) => setState(() {
                            _startSurahId = id;
                            final maxA = _ayasForSurah(id);
                            if (_startAyah > maxA) _startAyah = maxA;
                            // Ensure start ≤ end
                            if (_startSurahId > _endSurahId) {
                              _endSurahId = id;
                              _endAyah = _startAyah;
                            }
                          }),
                          onAyahChanged: (a) => setState(() => _startAyah = a),
                        ),
                        const SizedBox(height: 20),
                        // End range
                        _buildSurahAyahRow(
                          label: isEn ? 'End At' : 'Sampai',
                          surahId: _endSurahId,
                          ayah: _endAyah,
                          onSurahChanged: (id) => setState(() {
                            _endSurahId = id;
                            _updateEndAyahMax();
                          }),
                          onAyahChanged: (a) => setState(() => _endAyah = a),
                        ),
                        if (!_isRangeValid) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _rangeError ?? '',
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Repeat config
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              _buildRepeatRow(
                                label: isEn
                                    ? 'Repeat each ayah'
                                    : 'Ulangi tiap ayat',
                                value: _ayahRepeats,
                                icon: Icons.repeat_one_rounded,
                                onChanged: (v) => setState(() => _ayahRepeats = v),
                              ),
                              Divider(
                                  height: 20,
                                  color:
                                      AppTheme.outlineVariant.withValues(alpha: 0.3)),
                              _buildRepeatRow(
                                label: isEn
                                    ? 'Repeat playlist'
                                    : 'Ulangi daftar putar',
                                value: _playlistRepeats,
                                icon: Icons.repeat_rounded,
                                onChanged: (v) =>
                                    setState(() => _playlistRepeats = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Build playlist button
                        ElevatedButton.icon(
                          onPressed: (_loadingPlaylist || !_isRangeValid) ? null : _buildPlaylist,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: _loadingPlaylist
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.playlist_add_rounded),
                          label: Text(
                            _loadingPlaylist
                                ? (isEn ? 'Building…' : 'Membangun…')
                                : (isEn ? 'Build Playlist' : 'Buat Daftar Putar'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Playlist ─────────────────────────────────────────────
                if (hasPlaylist) ...[
                  Divider(height: 1, color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        Icon(Icons.queue_music_rounded,
                            size: 16, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${_playlist.length} ${isEn ? 'verses' : 'ayat'}',
                          style: TextStyle(
                              color: AppTheme.outline, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: _playlist.length,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemBuilder: (_, idx) => _buildPlaylistItem(idx),
                    ),
                  ),
                ],

                // ── Player controls ───────────────────────────────────────
                if (hasPlaylist) _buildPlayerControls(),
              ],
            ),
    );
  }
}

// ─── Small helper widgets ────────────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _PlayButton({
    this.icon = Icons.play_circle_filled_rounded,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 56,
        color: onTap == null
            ? AppTheme.outline.withValues(alpha: 0.4)
            : AppTheme.primary,
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    this.size = 28,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: size,
        color: onTap == null
            ? AppTheme.outline.withValues(alpha: 0.3)
            : (color ?? AppTheme.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _AnimatedEqualizer extends StatefulWidget {
  @override
  State<_AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<_AnimatedEqualizer>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 120),
      )..repeat(reverse: true);
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, _) => Container(
            width: 3,
            height: 6 + _ctrls[i].value * 10,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
