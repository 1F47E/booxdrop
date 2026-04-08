import 'package:flutter_test/flutter_test.dart';
import 'package:math_rpg/models/character.dart';
import 'package:math_rpg/models/item.dart';
import 'package:math_rpg/services/progression_service.dart';

void main() {
  group('ProgressionService', () {
    test('xpForLevel increases with level', () {
      var prev = 0;
      for (var level = 2; level <= 50; level++) {
        final xp = ProgressionService.xpForLevel(level);
        expect(xp, greaterThan(prev), reason: 'Level $level XP should be > level ${level - 1}');
        prev = xp;
      }
    });

    test('xpForLevel formula matches expected values', () {
      // xpForLevel(n) = n² * 10 + n * 20
      expect(ProgressionService.xpForLevel(2), 80); // 4*10 + 2*20 = 80
      expect(ProgressionService.xpForLevel(5), 350); // 25*10 + 5*20 = 350
      expect(ProgressionService.xpForLevel(10), 1200); // 100*10 + 10*20 = 1200
    });

    test('stat growth by class', () {
      // Warrior: HP +3, ATK +2, DEF +1 per level
      expect(ProgressionService.maxHpAt(1, CharacterClass.warrior), 30);
      expect(ProgressionService.maxHpAt(10, CharacterClass.warrior), 30 + 9 * 3); // 57
      expect(ProgressionService.atkAt(10, CharacterClass.warrior), 5 + 9 * 2); // 23
      expect(ProgressionService.defAt(10, CharacterClass.warrior), 3 + 9 * 1); // 12

      // Mage: HP +2, ATK +1, DEF +3 per level
      expect(ProgressionService.maxHpAt(10, CharacterClass.mage), 30 + 9 * 2); // 48
      expect(ProgressionService.atkAt(10, CharacterClass.mage), 5 + 9 * 1); // 14
      expect(ProgressionService.defAt(10, CharacterClass.mage), 3 + 9 * 3); // 30

      // Archer: HP +2, ATK +3, DEF +1 per level
      expect(ProgressionService.maxHpAt(10, CharacterClass.archer), 30 + 9 * 2); // 48
      expect(ProgressionService.atkAt(10, CharacterClass.archer), 5 + 9 * 3); // 32
      expect(ProgressionService.defAt(10, CharacterClass.archer), 3 + 9 * 1); // 12
    });

    test('processLevelUp advances level correctly', () {
      final char = Character(
        name: 'Test',
        characterClass: CharacterClass.warrior,
        level: 1,
        xp: 80, // exactly enough for level 2 (xpForLevel(2) = 80)
      );
      char.currentHp = char.maxHp;

      final levelsGained = ProgressionService.processLevelUp(char);
      expect(levelsGained, 1);
      expect(char.level, 2);
      expect(char.xp, 0); // 80 - 80 = 0
    });

    test('processLevelUp handles multiple levels at once', () {
      final char = Character(
        name: 'Test',
        characterClass: CharacterClass.warrior,
        level: 1,
        xp: 10000, // enough for several levels
      );
      char.currentHp = char.maxHp;

      final levelsGained = ProgressionService.processLevelUp(char);
      expect(levelsGained, greaterThan(1));
      expect(char.level, greaterThan(2));
    });

    test('processLevelUp caps at level 50', () {
      final char = Character(
        name: 'Test',
        characterClass: CharacterClass.warrior,
        level: 49,
        xp: 999999,
      );
      char.currentHp = char.maxHp;

      ProgressionService.processLevelUp(char);
      expect(char.level, 50);
    });

    test('processLevelUp heals gained HP', () {
      final char = Character(
        name: 'Test',
        characterClass: CharacterClass.warrior,
        level: 1,
        xp: 80,
      );
      final initialMaxHp = char.maxHp;
      char.currentHp = initialMaxHp; // full health

      ProgressionService.processLevelUp(char);
      // After level up, HP should increase by warrior HP growth (3)
      expect(char.currentHp, initialMaxHp + 3);
    });
  });

  group('Character', () {
    test('equipment bonuses are calculated correctly', () {
      final char = Character(
        name: 'Test',
        characterClass: CharacterClass.warrior,
      );

      final baseAtk = char.atk;
      final baseDef = char.def;
      final baseMaxHp = char.maxHp;

      // Equip a weapon with ATK +5
      final sword = Item(
        id: 'sword1',
        name: 'Test Sword',
        emoji: '\u2694\uFE0F',
        slot: ItemSlot.weapon,
        rarity: ItemRarity.common,
        atkBonus: 5,
      );
      char.equipment[ItemSlot.weapon] = sword;

      expect(char.atk, baseAtk + 5);
      expect(char.def, baseDef);
      expect(char.maxHp, baseMaxHp);
      expect(char.equipAtkBonus, 5);
    });

    test('serialization round-trip preserves all fields', () {
      final char = Character(
        name: 'Hero',
        characterClass: CharacterClass.mage,
        level: 10,
        xp: 500,
        gold: 100,
        currentHp: 40,
        currentZone: 2,
        currentNode: 3,
        monstersDefeated: 15,
        problemsSolved: 50,
      );

      final json = char.toJson();
      final restored = Character.fromJson(json);

      expect(restored.name, 'Hero');
      expect(restored.characterClass, CharacterClass.mage);
      expect(restored.level, 10);
      expect(restored.xp, 500);
      expect(restored.gold, 100);
      expect(restored.currentHp, 40);
      expect(restored.currentZone, 2);
      expect(restored.currentNode, 3);
      expect(restored.monstersDefeated, 15);
      expect(restored.problemsSolved, 50);
    });
  });
}
