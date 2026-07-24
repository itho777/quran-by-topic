import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'web_audio_player.dart';
import 'quran_sources.dart';
import 'settings_manager.dart';
import 'quran_verse_utils.dart';

class MurajaahVerseEntry {
  final int surahId;
  final int ayahNumber;
  final int globalId; // Supabase DB primary key (may differ from sequential verse number)
  final String verseKey;
  final String textAr;

  const MurajaahVerseEntry({
    required this.surahId,
    required this.ayahNumber,
    required this.globalId,
    required this.verseKey,
    required this.textAr,
  });

  /// Sequential verse number (1–6236) used as the SVG element ID `verse-N`.
  /// This matches the quranCoordsData globalAyah field and the SVG `id="verse-N"`.
  int get svgVerseId => quranSvgVerseId(surahId, ayahNumber);
}

class MurajaahState {
  final List<MurajaahVerseEntry> playlist;
  final int currentPlaylistIndex;
  final int currentAyahRepeat;
  final int currentPlaylistRepeat;
  final int ayahRepeats;
  final int playlistRepeats;
  final bool isPlaying;
  final bool isPaused;
  final bool sessionActive;
  final bool loadingPlaylist;

  const MurajaahState({
    this.playlist = const [],
    this.currentPlaylistIndex = 0,
    this.currentAyahRepeat = 0,
    this.currentPlaylistRepeat = 0,
    this.ayahRepeats = 1,
    this.playlistRepeats = 1,
    this.isPlaying = false,
    this.isPaused = false,
    this.sessionActive = false,
    this.loadingPlaylist = false,
  });

  MurajaahVerseEntry? get currentVerse =>
      (sessionActive && currentPlaylistIndex < playlist.length)
          ? playlist[currentPlaylistIndex]
          : null;

  MurajaahState copyWith({
    List<MurajaahVerseEntry>? playlist,
    int? currentPlaylistIndex,
    int? currentAyahRepeat,
    int? currentPlaylistRepeat,
    int? ayahRepeats,
    int? playlistRepeats,
    bool? isPlaying,
    bool? isPaused,
    bool? sessionActive,
    bool? loadingPlaylist,
  }) {
    return MurajaahState(
      playlist: playlist ?? this.playlist,
      currentPlaylistIndex: currentPlaylistIndex ?? this.currentPlaylistIndex,
      currentAyahRepeat: currentAyahRepeat ?? this.currentAyahRepeat,
      currentPlaylistRepeat: currentPlaylistRepeat ?? this.currentPlaylistRepeat,
      ayahRepeats: ayahRepeats ?? this.ayahRepeats,
      playlistRepeats: playlistRepeats ?? this.playlistRepeats,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      sessionActive: sessionActive ?? this.sessionActive,
      loadingPlaylist: loadingPlaylist ?? this.loadingPlaylist,
    );
  }
}

class MurajaahNotifier extends StateNotifier<MurajaahState> {
  final Ref ref;
  final WebAudioPlayer _player = WebAudioPlayer();
  late StreamSubscription _completeSub;
  late StreamSubscription _stateSub;

  MurajaahNotifier(this.ref) : super(const MurajaahState()) {
    _completeSub = _player.onComplete.listen((_) => _onAyahComplete());
    _stateSub = _player.onStateChange.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
  }

  @override
  void dispose() {
    _completeSub.cancel();
    _stateSub.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  void setAyahRepeats(int count) {
    state = state.copyWith(ayahRepeats: count);
  }

  void setPlaylistRepeats(int count) {
    state = state.copyWith(playlistRepeats: count);
  }

  void setLoadingPlaylist(bool loading) {
    state = state.copyWith(loadingPlaylist: loading);
  }

  void setPlaylist(List<MurajaahVerseEntry> list) {
    _player.stop();
    state = state.copyWith(
      playlist: list,
      currentPlaylistIndex: 0,
      currentAyahRepeat: 0,
      currentPlaylistRepeat: 0,
      isPlaying: false,
      isPaused: false,
      sessionActive: false,
      loadingPlaylist: false,
    );
  }

  void deletePlaylistItem(int index) {
    final updated = List<MurajaahVerseEntry>.from(state.playlist);
    if (index < 0 || index >= updated.length) return;

    final isCurrent = index == state.currentPlaylistIndex;
    updated.removeAt(index);

    if (updated.isEmpty) {
      stop();
      state = state.copyWith(playlist: []);
      return;
    }

    int newIndex = state.currentPlaylistIndex;
    if (index < newIndex) {
      newIndex--;
    } else if (newIndex >= updated.length) {
      newIndex = updated.length - 1;
    }

    state = state.copyWith(
      playlist: updated,
      currentPlaylistIndex: newIndex,
    );

    if (isCurrent && state.sessionActive) {
      _playCurrentAyah();
    }
  }

  void clearPlaylist() {
    stop();
    state = state.copyWith(playlist: []);
  }

  void startPlayback({int index = 0}) {
    if (state.playlist.isEmpty) return;
    final targetIdx = index.clamp(0, state.playlist.length - 1);
    state = state.copyWith(
      currentPlaylistIndex: targetIdx,
      currentAyahRepeat: 0,
      currentPlaylistRepeat: 0,
      sessionActive: true,
      isPaused: false,
    );
    _playCurrentAyah();
  }

  void pause() {
    _player.pause();
    state = state.copyWith(isPlaying: false, isPaused: true);
  }

  void resume() {
    if (state.isPaused) {
      _player.resume();
      state = state.copyWith(isPlaying: true, isPaused: false);
    } else if (state.sessionActive) {
      _playCurrentAyah();
    }
  }

  void stop() {
    _player.stop();
    state = state.copyWith(
      isPlaying: false,
      isPaused: false,
      sessionActive: false,
      currentPlaylistIndex: 0,
      currentAyahRepeat: 0,
      currentPlaylistRepeat: 0,
    );
  }

  void skipNext() {
    if (state.playlist.isEmpty) return;
    if (state.currentPlaylistIndex + 1 < state.playlist.length) {
      state = state.copyWith(
        currentPlaylistIndex: state.currentPlaylistIndex + 1,
        currentAyahRepeat: 0,
        sessionActive: true,
        isPaused: false,
      );
      _playCurrentAyah();
    } else {
      stop();
    }
  }

  void skipPrev() {
    if (state.playlist.isEmpty) return;
    if (state.currentPlaylistIndex > 0) {
      state = state.copyWith(
        currentPlaylistIndex: state.currentPlaylistIndex - 1,
        currentAyahRepeat: 0,
        sessionActive: true,
        isPaused: false,
      );
      _playCurrentAyah();
    }
  }

  void playVerseAtIndex(int index) {
    startPlayback(index: index);
  }

  void _playCurrentAyah() {
    final verse = state.currentVerse;
    if (verse == null) return;
    final reciter = ref.read(settingsProvider).selectedReciter;
    final url = QuranSources.buildAudioUrl(reciter, verse.surahId, verse.ayahNumber);
    _player.play(url);
    state = state.copyWith(isPlaying: true, isPaused: false);
  }

  void _onAyahComplete() {
    if (!state.sessionActive) return;

    final nextAyahRepeat = state.currentAyahRepeat + 1;
    if (nextAyahRepeat < state.ayahRepeats) {
      state = state.copyWith(currentAyahRepeat: nextAyahRepeat);
      _playCurrentAyah();
      return;
    }

    final nextIndex = state.currentPlaylistIndex + 1;
    if (nextIndex >= state.playlist.length) {
      final nextPlaylistRepeat = state.currentPlaylistRepeat + 1;
      if (nextPlaylistRepeat < state.playlistRepeats) {
        state = state.copyWith(
          currentPlaylistIndex: 0,
          currentAyahRepeat: 0,
          currentPlaylistRepeat: nextPlaylistRepeat,
        );
        _playCurrentAyah();
      } else {
        stop();
      }
      return;
    }

    state = state.copyWith(
      currentPlaylistIndex: nextIndex,
      currentAyahRepeat: 0,
    );
    _playCurrentAyah();
  }
}

final murajaahProvider = StateNotifierProvider<MurajaahNotifier, MurajaahState>((ref) {
  return MurajaahNotifier(ref);
});
