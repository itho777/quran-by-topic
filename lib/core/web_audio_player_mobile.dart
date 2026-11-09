import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Dual-player gapless audio for mobile.
/// Player A plays current ayah; Player B pre-sets (setSource) the next one
/// while A is still running. On complete, roles swap — B starts instantly,
/// A becomes the standby for the ayah after that.
/// This eliminates the stop→reinit gap that caused ~300–600ms delay between ayahs.
class WebAudioPlayer {
  // Two players alternating roles
  final AudioPlayer _playerA = AudioPlayer();
  final AudioPlayer _playerB = AudioPlayer();

  final _onCompleteController = StreamController<void>.broadcast();
  final _onStateController    = StreamController<bool>.broadcast();

  bool _hasSource = false;
  bool _isPlaying = false;

  // Which player is currently active
  bool _aIsActive = true;
  AudioPlayer get _active  => _aIsActive ? _playerA : _playerB;
  AudioPlayer get _standby => _aIsActive ? _playerB : _playerA;

  // Prefetch tracking
  String? _prefetchUrl;

  WebAudioPlayer() {
    _wire(_playerA);
    _wire(_playerB);
  }

  void _wire(AudioPlayer p) {
    p.onPlayerStateChanged.listen((state) {
      if (p == _active) {
        _isPlaying = state == PlayerState.playing;
        _onStateController.add(_isPlaying);
      }
    });

    p.onPlayerComplete.listen((_) {
      if (p != _active) return; // standby fired spuriously — ignore
      _isPlaying = false;
      _hasSource = false;
      _onStateController.add(false);
      _onCompleteController.add(null);
    });
  }

  Stream<void> get onComplete  => _onCompleteController.stream;
  Stream<bool> get onStateChange => _onStateController.stream;

  bool get isPlaying => _isPlaying;
  bool get hasSource => _hasSource;

  Future<String?> _localPath(String url) async {
    try {
      final uri = Uri.parse(url);
      final segs = uri.pathSegments;
      if (segs.length >= 3) {
        final reciterId = segs[segs.length - 2];
        final fileName  = segs.last;
        final dir = await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/audio/$reciterId/$fileName');
        if (f.existsSync()) return f.path;
      }
    } catch (_) {}
    return null;
  }

  Source _sourceFor(String localPath) => DeviceFileSource(localPath);
  Source _urlSourceFor(String url)    => UrlSource(url);

  Future<void> play(String url) async {
    _hasSource = true;
    _isPlaying = false;

    // Stop standby cleanly (don't await — fire and forget)
    _standby.stop();

    final localPath = await _localPath(url);
    final src = localPath != null ? _sourceFor(localPath) : _urlSourceFor(url);

    // If standby already has this URL pre-set, swap and play it instantly
    if (_prefetchUrl == url) {
      _aIsActive = !_aIsActive; // swap roles
      await _active.resume();   // standby (now active) was set+paused — resume
      _prefetchUrl = null;
    } else {
      // Cold play on active player
      await _active.play(src);
    }
  }

  /// Pre-set the next ayah on the standby player while current plays.
  /// Call right after play() starts. Standby loads+buffers but stays paused at t=0.
  Future<void> prefetch(String url) async {
    if (url == _prefetchUrl) return;
    _prefetchUrl = url;
    try {
      await _standby.stop();
      final localPath = await _localPath(url);
      final src = localPath != null ? _sourceFor(localPath) : _urlSourceFor(url);
      // setSource buffers the file; seek to 0 so resume() starts from beginning
      await _standby.setSource(src);
      await _standby.seek(Duration.zero);
    } catch (_) {
      _prefetchUrl = null; // prefetch failed — cold play will handle it
    }
  }

  Future<void> pause() async {
    await _active.pause();
  }

  Future<void> resume() async {
    if (_hasSource) await _active.resume();
  }

  Future<void> stop() async {
    _hasSource   = false;
    _isPlaying   = false;
    _prefetchUrl = null;
    await _active.stop();
    await _standby.stop();
  }

  void dispose() {
    _playerA.dispose();
    _playerB.dispose();
    _onCompleteController.close();
    _onStateController.close();
  }
}
