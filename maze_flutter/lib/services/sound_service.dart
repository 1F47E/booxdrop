import 'package:audioplayers/audioplayers.dart';

/// Plays game sound effects from bundled assets.
class SoundService {
  static final _player = AudioPlayer();

  static Future<void> playMove() => _play('sounds/move.mp3');
  static Future<void> playWall() => _play('sounds/wall.mp3');
  static Future<void> playKey() => _play('sounds/key.mp3');
  static Future<void> playDoor() => _play('sounds/door.mp3');
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
