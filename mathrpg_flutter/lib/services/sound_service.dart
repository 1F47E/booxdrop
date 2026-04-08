import 'package:audioplayers/audioplayers.dart';

/// Plays game sound effects from bundled assets.
class SoundService {
  static final _player = AudioPlayer();

  static Future<void> playAttack() => _play('sounds/attack.mp3');
  static Future<void> playHit() => _play('sounds/hit.mp3');
  static Future<void> playVictory() => _play('sounds/victory.mp3');
  static Future<void> playLevelUp() => _play('sounds/levelup.mp3');
  static Future<void> playDefeat() => _play('sounds/defeat.mp3');
  static Future<void> playLoot() => _play('sounds/loot.mp3');

  static Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Sound is non-critical — silently ignore errors
    }
  }
}
