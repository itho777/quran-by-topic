import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Mobile/Desktop implementation of the audio player using audioplayers package.
/// Mirrors the WebAudioPlayer API so mushaf_screen.dart works identically on all platforms.
/// Plays from a local cached file if present; falls back to network streaming.
class WebAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  final _onCompleteController = StreamController<void>.broadcast();
  final _onStateController = StreamController<bool>.broadcast();

  bool _hasSource = false;
  bool _isPlaying = false;

  WebAudioPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _onStateController.add(_isPlaying);
    });

    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _hasSource = false;
      _onStateController.add(false);
      _onCompleteController.add(null);
    });
  }

  Stream<void> get onComplete => _onCompleteController.stream;
  Stream<bool> get onStateChange => _onStateController.stream;

  bool get isPlaying => _isPlaying;
  bool get hasSource => _hasSource;

  /// Check if a local audio file exists for this URL.
  /// URL form: https://…/quran/{reciterId}/{surah:3}.mp3
  Future<String?> _localPath(String url) async {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      // Expected: [..., 'quran', reciterId, 'NNN.mp3']
      if (segments.length >= 3) {
        final reciterId = segments[segments.length - 2];
        final fileName = segments.last;
        final appDocDir = await getApplicationDocumentsDirectory();
        final localFile = File('${appDocDir.path}/audio/$reciterId/$fileName');
        if (localFile.existsSync()) return localFile.path;
      }
    } catch (_) {}
    return null;
  }

  Future<void> play(String url) async {
    _hasSource = true;
    _isPlaying = false;
    await _player.stop();

    // Prefer local cached file
    final localPath = await _localPath(url);
    if (localPath != null) {
      await _player.play(DeviceFileSource(localPath));
    } else {
      await _player.play(UrlSource(url));
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    if (_hasSource) {
      await _player.resume();
    }
  }

  Future<void> stop() async {
    _hasSource = false;
    _isPlaying = false;
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
    _onCompleteController.close();
    _onStateController.close();
  }
}
