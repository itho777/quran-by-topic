import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Mobile/Desktop implementation of the audio player using audioplayers package.
/// The interface matches WebAudioPlayer so mushaf_screen.dart can use it seamlessly.
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
      _onStateController.add(false);
      _onCompleteController.add(null);
    });
  }

  Stream<void> get onComplete => _onCompleteController.stream;
  Stream<bool> get onStateChange => _onStateController.stream;

  bool get isPlaying => _isPlaying;
  bool get hasSource => _hasSource;

  void play(String url) async {
    _hasSource = true;
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  void pause() async {
    await _player.pause();
  }

  void resume() async {
    if (_hasSource) {
      await _player.resume();
    }
  }

  void stop() async {
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
