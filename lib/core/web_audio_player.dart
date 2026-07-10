// Web-specific audio player using raw HTML5 Audio API.
// This bypasses audioplayers' Dart-to-JS async bridge that breaks
// the browser's user-gesture chain for autoplay policy.
//
// Mirrors the static web version's approach:
//   currentAudio = new Audio(url);
//   currentAudio.onended = () => playNextAyah();
//   currentAudio.play();

import 'dart:html' as html;
import 'dart:async';

/// A lightweight web audio player that uses the HTML5 Audio API directly.
/// This preserves the user-gesture chain from onended → play(), which
/// is required by Chrome's autoplay policy.
class WebAudioPlayer {
  html.AudioElement? _audio;
  final _onCompleteController = StreamController<void>.broadcast();
  final _onStateController = StreamController<bool>.broadcast();

  /// Stream that fires when the current audio finishes playing.
  Stream<void> get onComplete => _onCompleteController.stream;

  /// Stream that emits true when playing, false when paused/stopped.
  Stream<bool> get onStateChange => _onStateController.stream;

  bool get isPlaying => _audio != null && !_audio!.paused && !_audio!.ended;

  /// Play a URL. Creates a new Audio element each time (like the static web version).
  /// This MUST be called synchronously from an onended callback or user gesture
  /// to satisfy browser autoplay policy.
  void play(String url) {
    // Stop any previous audio
    if (_audio != null) {
      _audio!.pause();
      _audio!.src = '';
      _audio = null;
    }

    _audio = html.AudioElement(url);

    _audio!.onEnded.listen((_) {
      _onStateController.add(false);
      _onCompleteController.add(null);
    });

    _audio!.onPlay.listen((_) {
      _onStateController.add(true);
    });

    _audio!.onPause.listen((_) {
      if (!(_audio?.ended ?? true)) {
        _onStateController.add(false);
      }
    });

    _audio!.onError.listen((e) {
      print('WebAudioPlayer error: $e');
      _onStateController.add(false);
    });

    // Direct synchronous .play() call — preserves gesture chain
    _audio!.play().catchError((e) {
      print('WebAudioPlayer play() rejected: $e');
      _onStateController.add(false);
    });
  }

  void pause() {
    _audio?.pause();
  }

  void resume() {
    _audio?.play();
  }

  void stop() {
    if (_audio != null) {
      _audio!.pause();
      _audio!.src = '';
      _audio = null;
    }
    _onStateController.add(false);
  }

  void dispose() {
    stop();
    _onCompleteController.close();
    _onStateController.close();
  }
}
