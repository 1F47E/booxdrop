import 'package:audioplayers/audioplayers.dart';

/// Plays game sound effects from bundled assets.
class SoundService {
  static final _player = AudioPlayer();

  static Future<void> playPlace() => _play('sounds/place.mp3');
  static Future<void> playSplash() => _play('sounds/splash.mp3');
  static Future<void> playHit() => _play('sounds/hit.mp3');
  static Future<void> playSunk() => _play('sounds/sunk.mp3');
  static Future<void> playWin() => _play('sounds/win.mp3');

  static Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Sound is non-critical — silently ignore errors
    }
  }
}
