import '../models/game_state.dart';
import '../models/monster.dart';

/// Contains all zone and monster definitions. Spawns monsters for adventure nodes.
class MonsterFactory {
  static const zones = <ZoneDefinition>[
    ZoneDefinition(
      name: 'Enchanted Forest',
      emoji: '\u{1F333}',
      description: 'A mysterious forest filled with creatures.',
      zoneIndex: 0,
      nodeCount: 6,
    ),
    ZoneDefinition(
      name: 'Crystal Cave',
      emoji: '\u{1F48E}',
      description: 'Deep caves glittering with crystals.',
      zoneIndex: 1,
      nodeCount: 6,
    ),
    ZoneDefinition(
      name: 'Haunted Castle',
      emoji: '\u{1F3F0}',
      description: 'A dark castle ruled by the undead.',
      zoneIndex: 2,
      nodeCount: 6,
    ),
    ZoneDefinition(
      name: 'Volcanic Wasteland',
      emoji: '\u{1F30B}',
      description: 'Scorching lands of fire and lava.',
      zoneIndex: 3,
      nodeCount: 6,
    ),
    ZoneDefinition(
      name: 'Shadow Realm',
      emoji: '\u{1F30C}',
      description: 'The final frontier of darkness.',
      zoneIndex: 4,
      nodeCount: 6,
    ),
  ];

  static final _monsters = <int, List<Monster>>{
    // Zone 0: Enchanted Forest
    0: const [
      Monster(name: 'Slime', emoji: '\u{1F7E2}', baseHp: 15, baseAtk: 3, element: ElementType.normal, xpReward: 10, goldReward: 5, lootTableId: 'common_weapon', zoneIndex: 0),
      Monster(name: 'Forest Bat', emoji: '\u{1F987}', baseHp: 20, baseAtk: 4, element: ElementType.dark, xpReward: 15, goldReward: 7, lootTableId: 'common_accessory', zoneIndex: 0),
      Monster(name: 'Goblin', emoji: '\u{1F47A}', baseHp: 25, baseAtk: 5, element: ElementType.normal, xpReward: 20, goldReward: 10, lootTableId: 'common_any', zoneIndex: 0),
      Monster(name: 'Wild Boar', emoji: '\u{1F417}', baseHp: 30, baseAtk: 6, element: ElementType.earth, xpReward: 25, goldReward: 12, lootTableId: 'uncommon_armor', zoneIndex: 0),
      Monster(name: 'Spider', emoji: '\u{1F577}\uFE0F', baseHp: 22, baseAtk: 7, element: ElementType.poison, xpReward: 20, goldReward: 8, lootTableId: 'common_weapon', zoneIndex: 0),
      Monster(name: 'Treant', emoji: '\u{1F333}', baseHp: 60, baseAtk: 8, element: ElementType.earth, xpReward: 80, goldReward: 40, lootTableId: 'rare_any', zoneIndex: 0, isBoss: true),
    ],
    // Zone 1: Crystal Cave
    1: const [
      Monster(name: 'Cave Bat', emoji: '\u{1F987}', baseHp: 30, baseAtk: 7, element: ElementType.dark, xpReward: 25, goldReward: 12, lootTableId: 'common_any', zoneIndex: 1),
      Monster(name: 'Rock Golem', emoji: '\u{1FAA8}', baseHp: 40, baseAtk: 6, element: ElementType.earth, xpReward: 30, goldReward: 15, lootTableId: 'uncommon_armor', zoneIndex: 1),
      Monster(name: 'Skeleton', emoji: '\u{1F480}', baseHp: 28, baseAtk: 9, element: ElementType.dark, xpReward: 28, goldReward: 14, lootTableId: 'uncommon_weapon', zoneIndex: 1),
      Monster(name: 'Mushroom', emoji: '\u{1F344}', baseHp: 25, baseAtk: 8, element: ElementType.poison, xpReward: 22, goldReward: 10, lootTableId: 'common_accessory', zoneIndex: 1),
      Monster(name: 'Crystal Lizard', emoji: '\u{1F98E}', baseHp: 35, baseAtk: 8, element: ElementType.ice, xpReward: 32, goldReward: 18, lootTableId: 'uncommon_any', zoneIndex: 1),
      Monster(name: 'Dragon Wyrmling', emoji: '\u{1F432}', baseHp: 80, baseAtk: 12, element: ElementType.fire, xpReward: 120, goldReward: 60, lootTableId: 'rare_weapon', zoneIndex: 1, isBoss: true),
    ],
    // Zone 2: Haunted Castle
    2: const [
      Monster(name: 'Ghost', emoji: '\u{1F47B}', baseHp: 35, baseAtk: 10, element: ElementType.dark, xpReward: 35, goldReward: 18, lootTableId: 'uncommon_accessory', zoneIndex: 2),
      Monster(name: 'Armored Knight', emoji: '\u{1F6E1}\uFE0F', baseHp: 50, baseAtk: 9, element: ElementType.normal, xpReward: 40, goldReward: 22, lootTableId: 'uncommon_armor', zoneIndex: 2),
      Monster(name: 'Fire Imp', emoji: '\u{1F525}', baseHp: 30, baseAtk: 12, element: ElementType.fire, xpReward: 35, goldReward: 20, lootTableId: 'uncommon_weapon', zoneIndex: 2),
      Monster(name: 'Gargoyle', emoji: '\u{1F5FF}', baseHp: 45, baseAtk: 11, element: ElementType.earth, xpReward: 42, goldReward: 24, lootTableId: 'rare_armor', zoneIndex: 2),
      Monster(name: 'Vampire Bat', emoji: '\u{1F987}', baseHp: 38, baseAtk: 13, element: ElementType.dark, xpReward: 38, goldReward: 22, lootTableId: 'rare_accessory', zoneIndex: 2),
      Monster(name: 'Lich King', emoji: '\u{1F451}', baseHp: 100, baseAtk: 15, element: ElementType.dark, xpReward: 200, goldReward: 100, lootTableId: 'epic_any', zoneIndex: 2, isBoss: true),
    ],
    // Zone 3: Volcanic Wasteland
    3: const [
      Monster(name: 'Fire Elemental', emoji: '\u{1F525}', baseHp: 45, baseAtk: 13, element: ElementType.fire, xpReward: 45, goldReward: 25, lootTableId: 'rare_weapon', zoneIndex: 3),
      Monster(name: 'Lava Slime', emoji: '\u{1F7E0}', baseHp: 40, baseAtk: 14, element: ElementType.fire, xpReward: 42, goldReward: 22, lootTableId: 'uncommon_any', zoneIndex: 3),
      Monster(name: 'Obsidian Golem', emoji: '\u{1FAA8}', baseHp: 55, baseAtk: 12, element: ElementType.earth, xpReward: 50, goldReward: 30, lootTableId: 'rare_armor', zoneIndex: 3),
      Monster(name: 'Phoenix Hatchling', emoji: '\u{1F426}', baseHp: 38, baseAtk: 16, element: ElementType.fire, xpReward: 48, goldReward: 28, lootTableId: 'rare_accessory', zoneIndex: 3),
      Monster(name: 'Magma Serpent', emoji: '\u{1F40D}', baseHp: 50, baseAtk: 15, element: ElementType.fire, xpReward: 52, goldReward: 32, lootTableId: 'rare_any', zoneIndex: 3),
      Monster(name: 'Ancient Dragon', emoji: '\u{1F409}', baseHp: 130, baseAtk: 18, element: ElementType.fire, xpReward: 300, goldReward: 150, lootTableId: 'epic_weapon', zoneIndex: 3, isBoss: true),
    ],
    // Zone 4: Shadow Realm
    4: const [
      Monster(name: 'Shadow Wraith', emoji: '\u{1F47B}', baseHp: 55, baseAtk: 16, element: ElementType.dark, xpReward: 55, goldReward: 35, lootTableId: 'rare_any', zoneIndex: 4),
      Monster(name: 'Demon', emoji: '\u{1F47F}', baseHp: 60, baseAtk: 17, element: ElementType.dark, xpReward: 60, goldReward: 38, lootTableId: 'rare_weapon', zoneIndex: 4),
      Monster(name: 'Nightmare', emoji: '\u{1F434}', baseHp: 50, baseAtk: 19, element: ElementType.dark, xpReward: 58, goldReward: 36, lootTableId: 'epic_accessory', zoneIndex: 4),
      Monster(name: 'Void Walker', emoji: '\u{1F30C}', baseHp: 65, baseAtk: 18, element: ElementType.dark, xpReward: 65, goldReward: 42, lootTableId: 'epic_armor', zoneIndex: 4),
      Monster(name: 'Dark Sorcerer', emoji: '\u{1F9D9}', baseHp: 58, baseAtk: 20, element: ElementType.dark, xpReward: 62, goldReward: 40, lootTableId: 'epic_any', zoneIndex: 4),
      Monster(name: 'Shadow Lord', emoji: '\u{1F608}', baseHp: 180, baseAtk: 22, element: ElementType.dark, xpReward: 500, goldReward: 250, lootTableId: 'epic_weapon', zoneIndex: 4, isBoss: true),
    ],
  };

  /// Get the monster for a given node. Last node of each zone is the boss.
  static Monster spawnForNode(int zoneIndex, int nodeIndex) {
    final zoneMonsters = _monsters[zoneIndex];
    if (zoneMonsters == null || nodeIndex >= zoneMonsters.length) {
      return _monsters[0]![0]; // fallback
    }
    return zoneMonsters[nodeIndex];
  }

  /// Build the full list of adventure nodes across all zones.
  static List<AdventureNode> buildAdventureNodes() {
    final nodes = <AdventureNode>[];
    var globalIndex = 0;
    for (final zone in zones) {
      for (var i = 0; i < zone.nodeCount; i++) {
        nodes.add(AdventureNode(
          zoneIndex: zone.zoneIndex,
          nodeIndex: i,
          globalIndex: globalIndex,
          isBoss: i == zone.nodeCount - 1,
        ));
        globalIndex++;
      }
    }
    return nodes;
  }

  /// Total number of nodes across all zones.
  static int get totalNodes =>
      zones.fold(0, (sum, z) => sum + z.nodeCount);
}
