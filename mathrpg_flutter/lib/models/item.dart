enum ItemSlot { weapon, armor, accessory }

enum ItemRarity { common, uncommon, rare, epic }

class Item {
  final String id;
  final String name;
  final String emoji;
  final ItemSlot slot;
  final ItemRarity rarity;
  final int atkBonus;
  final int defBonus;
  final int hpBonus;
  final int goldValue;

  const Item({
    required this.id,
    required this.name,
    required this.emoji,
    required this.slot,
    required this.rarity,
    this.atkBonus = 0,
    this.defBonus = 0,
    this.hpBonus = 0,
    this.goldValue = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'slot': slot.index,
        'rarity': rarity.index,
        'atkBonus': atkBonus,
        'defBonus': defBonus,
        'hpBonus': hpBonus,
        'goldValue': goldValue,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        slot: ItemSlot.values[j['slot'] as int],
        rarity: ItemRarity.values[j['rarity'] as int],
        atkBonus: j['atkBonus'] as int? ?? 0,
        defBonus: j['defBonus'] as int? ?? 0,
        hpBonus: j['hpBonus'] as int? ?? 0,
        goldValue: j['goldValue'] as int? ?? 1,
      );

  String get rarityLabel => switch (rarity) {
        ItemRarity.common => 'Common',
        ItemRarity.uncommon => 'Uncommon',
        ItemRarity.rare => 'Rare',
        ItemRarity.epic => 'Epic',
      };

  String get slotLabel => switch (slot) {
        ItemSlot.weapon => 'Weapon',
        ItemSlot.armor => 'Armor',
        ItemSlot.accessory => 'Accessory',
      };
}
