import '../models/character.dart';

/// Pure static methods for XP, leveling, and stat formulas.
class ProgressionService {
  /// XP required to reach [level] from level-1.
  static int xpForLevel(int level) => (level * level * 10) + (level * 20);

  /// Total cumulative XP to reach [level].
  static int totalXpForLevel(int level) {
    var total = 0;
    for (var i = 2; i <= level; i++) {
      total += xpForLevel(i);
    }
    return total;
  }

  /// XP needed for the next level from current level.
  static int xpToNextLevel(int currentLevel) => xpForLevel(currentLevel + 1);

  /// Check if character should level up; returns new level.
  /// Mutates character in place: increments level, subtracts XP cost,
  /// increases max HP (and heals the HP difference).
  /// Returns number of levels gained.
  static int processLevelUp(Character character) {
    var levelsGained = 0;
    while (character.level < 50) {
      final needed = xpToNextLevel(character.level);
      if (character.xp < needed) break;
      final oldMaxHp = character.maxHp;
      character.xp -= needed;
      character.level++;
      levelsGained++;
      // Heal the HP gained from leveling
      final hpGain = character.maxHp - oldMaxHp;
      character.currentHp += hpGain;
    }
    return levelsGained;
  }

  /// Max HP at a given level for a class (without equipment).
  static int maxHpAt(int level, CharacterClass cls) {
    final growth = classInfo[cls]!.hpGrowth;
    return 30 + (level - 1) * growth;
  }

  /// ATK at a given level for a class (without equipment).
  static int atkAt(int level, CharacterClass cls) {
    final growth = classInfo[cls]!.atkGrowth;
    return 5 + (level - 1) * growth;
  }

  /// DEF at a given level for a class (without equipment).
  static int defAt(int level, CharacterClass cls) {
    final growth = classInfo[cls]!.defGrowth;
    return 3 + (level - 1) * growth;
  }
}
