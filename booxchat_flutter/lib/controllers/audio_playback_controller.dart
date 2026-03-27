import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlaybackController extends ChangeNotifier
    with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;

  String? _currentPath;
  String? _currentLabel;
  String? _currentSessionId;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _commandChain = Future.value();
  int _opVersion = 0;

  String? get currentPath => _currentPath;
  String? get currentLabel => _currentLabel;
  String? get currentSessionId => _currentSessionId;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get hasActiveTrack => _currentPath != null;
  String? get error => _error;

  AudioPlaybackController() {
    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onPlayerState(PlayerState state) {
    final playing = state.playing &&
        state.processingState != ProcessingState.completed;

    if (_isPlaying != playing) {
      _isPlaying = playing;
      notifyListeners();
    }

    if (state.processingState == ProcessingState.completed) {
      _player.seek(Duration.zero);
      _isPlaying = false;
      notifyListeners();
    }
  }

  bool isCurrentTrack(String? path) => _currentPath != null && _currentPath == path;

  Future<void> togglePlay({
    required String path,
    required String label,
    String? sessionId,
  }) {
    return _enqueue(() async {
      _error = null;

      if (_currentPath == path && _isPlaying) {
        await _player.pause();
        return;
      }

      if (_currentPath == path) {
        try {
          await _player.play();
        } catch (e) {
          _error = 'Audio control failed';
          notifyListeners();
        }
        return;
      }

      // New track
      final version = ++_opVersion;
      _isLoading = true;
      notifyListeners();

      try {
        await _player.stop();
        await _player.setFilePath(path);
        if (version != _opVersion) return; // stale — superseding op owns notify
        await _player.play();
        if (version != _opVersion) return; // stale
        _currentPath = path;
        _currentLabel = label;
        _currentSessionId = sessionId;
        _isLoading = false;
        notifyListeners();
      } catch (e) {
        if (version == _opVersion) {
          _error = "Couldn't play audio";
          _isLoading = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> pause() {
    return _enqueue(() async {
      try {
        await _player.pause();
      } catch (_) {
        _error = 'Audio control failed';
        notifyListeners();
      }
    });
  }

  Future<void> resume() {
    return _enqueue(() async {
      _error = null;
      try {
        await _player.play();
      } catch (_) {
        _error = 'Audio control failed';
        notifyListeners();
      }
    });
  }

  Future<void> stopAndClear() {
    return _enqueue(() async {
      ++_opVersion;
      try {
        await _player.stop();
      } catch (_) {}
      _currentPath = null;
      _currentLabel = null;
      _currentSessionId = null;
      _isPlaying = false;
      _isLoading = false;
      _error = null;
      notifyListeners();
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final step = _commandChain.then((_) => action()).catchError((_) {});
    _commandChain = step;
    return step;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_isPlaying) {
        pause(); // enqueued — no race with in-flight commands
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerStateSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }
}
