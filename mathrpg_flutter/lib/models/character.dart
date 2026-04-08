import 'item.dart';

enum CharacterClass { warrior, mage, archer }

class CharacterClassInfo {
  final String name;
  final String emoji;
  final String description;
  final int hpGrowth;
  final int atkGrowth;
  final int defGrowth;

  const CharacterClassInfo({
    required this.name,
    required this.emoji,
    required this.description,
    required this.hpGrowth,
    required this.atkGrowth,
    required this.defGrowth,
  });
}

const classInfo = {
  CharacterClass.warrior: CharacterClassInfo(
    name: 'Warrior',
    emoji: '\u2694\uFE0F',
    description: 'Strong and tough. Bonus HP and ATK.',
    hpGrowth: 3,
    atkGrowth: 2,
    defGrowth: 1,
  ),
  CharacterClass.mage: CharacterClassInfo(
    name: 'Mage',
    emoji: '\u{1F9D9}',
    description: 'Wise and resilient. Bonus DEF.',
    hpGrowth: 2,
    atkGrowth: 1,
    defGrowth: 3,
  ),
  CharacterClass.archer: CharacterClassInfo(
    name: 'Archer',
    emoji: '\u{1F3F9}',
    description: 'Fast and deadly. Bonus ATK.',
    hpGrowth: 2,
    atkGrowth: 3,
    defGrowth: 1,
  ),
};

class Character {
  String name;
  CharacterClass characterClass;
  int level;
  int xp;
  int gold;
  int currentHp;
  Map<ItemSlot, Item?> equipment;
  List<Item> inventory;
  int currentZone;
  int currentNode;
  int monstersDefeated;
  int problemsSolved;

  Character({
    required this.name,
    required this.characterClass,
    this.level = 1,
    this.xp = 0,
    this.gold = 0,
    int? currentHp,
    Map<ItemSlot, Item?>? equipment,
    List<Item>? inventory,
    this.currentZone = 0,
    this.currentNode = 0,
    this.monstersDefeated = 0,
    this.problemsSolved = 0,
  })  : equipment = equipment ??
            {
              ItemSlot.weapon: null,
              ItemSlot.armor: null,
              ItemSlot.accessory: null,
            },
        inventory = inventory ?? [],
        currentHp = currentHp ?? _baseHp;

  static const _baseHp = 30;
  static const _baseAtk = 5;
  static const _baseDef = 3;

  CharacterClassInfo get info => classInfo[characterClass]!;

  int get maxHp {
    final growth = info.hpGrowth;
    final base = _baseHp + (level - 1) * growth;
    return base + _equipmentBonus((i) => i.hpBonus);
  }

  int get atk {
    final growth = info.atkGrowth;
    final base = _baseAtk + (level - 1) * growth;
    return base + _equipmentBonus((i) => i.atkBonus);
  }

  int get def {
    final growth = info.defGrowth;
    final base = _baseDef + (level - 1) * growth;
    return base + _equipmentBonus((i) => i.defBonus);
  }

  int get baseMaxHp => _baseHp + (level - 1) * info.hpGrowth;
  int get baseAtk => _baseAtk + (level - 1) * info.atkGrowth;
  int get baseDef => _baseDef + (level - 1) * info.defGrowth;

  int get equipHpBonus => _equipmentBonus((i) => i.hpBonus);
  int get equipAtkBonus => _equipmentBonus((i) => i.atkBonus);
  int get equipDefBonus => _equipmentBonus((i) => i.defBonus);

  int _equipmentBonus(int Function(Item) getter) {
    var total = 0;
    for (final item in equipment.values) {
      if (item != null) total += getter(item);
    }
    return total;
  }

  void fullHeal() => currentHp = maxHp;

  Map<String, dynamic> toJson() => {
        'name': name,
        'characterClass': characterClass.index,
        'level': level,
        'xp': xp,
        'gold': gold,
        'currentHp': currentHp,
        'equipment': {
          for (final e in equipment.entries)
            e.key.index.toString(): e.value?.toJson(),
        },
        'inventory': inventory.map((i) => i.toJson()).toList(),
        'currentZone': currentZone,
        'currentNode': currentNode,
        'monstersDefeated': monstersDefeated,
        'problemsSolved': problemsSolved,
      };

  factory Character.fromJson(Map<String, dynamic> j) {
    final equipMap = j['equipment'] as Map<String, dynamic>? ?? {};
    final equipment = <ItemSlot, Item?>{};
    for (final slot in ItemSlot.values) {
      final raw = equipMap[slot.index.toString()];
      equipment[slot] =
          raw != null ? Item.fromJson(raw as Map<String, dynamic>) : null;
    }

    return Character(
      name: j['name'] as String,
      characterClass: CharacterClass.values[j['characterClass'] as int],
      level: j['level'] as int? ?? 1,
      xp: j['xp'] as int? ?? 0,
      gold: j['gold'] as int? ?? 0,
      currentHp: j['currentHp'] as int?,
      equipment: equipment,
      inventory: (j['inventory'] as List<dynamic>?)
              ?.map((e) => Item.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      currentZone: j['currentZone'] as int? ?? 0,
      currentNode: j['currentNode'] as int? ?? 0,
      monstersDefeated: j['monstersDefeated'] as int? ?? 0,
      problemsSolved: j['problemsSolved'] as int? ?? 0,
    );
  }
}
