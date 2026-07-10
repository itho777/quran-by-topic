import 'dart:async';

/// Stub for non-web platforms. Mobile apps use audioplayers.
class WebAudioPlayer {
  final _onCompleteController = StreamController<void>.broadcast();
  final _onStateController = StreamController<bool>.broadcast();

  Stream<void> get onComplete => _onCompleteController.stream;
  Stream<bool> get onStateChange => _onStateController.stream;

  bool get isPlaying => false;
  bool get hasSource => false;

  void play(String url) {}
  void pause() {}
  void resume() {}
  void stop() {}
  void dispose() {
    _onCompleteController.close();
    _onStateController.close();
  }
}
