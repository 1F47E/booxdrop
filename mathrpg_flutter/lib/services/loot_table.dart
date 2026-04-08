import 'dart:math';
import '../models/item.dart';

/// Item drop tables. Returns loot based on monster's lootTableId.
class LootTable {
  static final _rng = Random();

  /// Roll for a drop. Returns null if no drop.
  static Item? rollDrop(String? lootTableId, int playerLevel) {
    if (lootTableId == null) return null;

    // Parse table ID: "rarity_slot" or "rarity_any"
    final parts = lootTableId.split('_');
    if (parts.length != 2) return null;

    final minRarity = switch (parts[0]) {
      'common' => ItemRarity.common,
      'uncommon' => ItemRarity.uncommon,
      'rare' => ItemRarity.rare,
      'epic' => ItemRarity.epic,
      _ => ItemRarity.common,
    };

    final slotFilter = switch (parts[1]) {
      'weapon' => ItemSlot.weapon,
      'armor' => ItemSlot.armor,
      'accessory' => ItemSlot.accessory,
      _ => null, // 'any'
    };

    // Drop chance: common 40%, uncommon 55%, rare 70%, epic 85%
    final dropChance = switch (minRarity) {
      ItemRarity.common => 0.40,
      ItemRarity.uncommon => 0.55,
      ItemRarity.rare => 0.70,
      ItemRarity.epic => 0.85,
    };

    if (_rng.nextDouble() > dropChance) return null;

    // Roll rarity upgrade
    var rarity = minRarity;
    if (_rng.nextDouble() < 0.15 && rarity.index < ItemRarity.epic.index) {
      rarity = ItemRarity.values[rarity.index + 1];
    }

    // Pick slot
    final slot = slotFilter ?? ItemSlot.values[_rng.nextInt(3)];

    return _generateItem(slot, rarity, playerLevel);
  }

  static Item _generateItem(ItemSlot slot, ItemRarity rarity, int playerLevel) {
    final tier = (playerLevel / 10).ceil().clamp(1, 5);
    final rarityMult = switch (rarity) {
      ItemRarity.common => 1.0,
      ItemRarity.uncommon => 1.5,
      ItemRarity.rare => 2.0,
      ItemRarity.epic => 3.0,
    };

    final templates = _templates[slot]!;
    final template = templates[_rng.nextInt(templates.length)];

    final baseStat = (tier * rarityMult).round();
    final id = '${template.id}_t${tier}_${rarity.name}_${_rng.nextInt(9999)}';

    return Item(
      id: id,
      name: '${rarity == ItemRarity.epic ? "Legendary " : rarity == ItemRarity.rare ? "Fine " : ""}${template.name}',
      emoji: template.emoji,
      slot: slot,
      rarity: rarity,
      atkBonus: slot == ItemSlot.weapon ? baseStat + _rng.nextInt(tier + 1) : 0,
      defBonus: slot == ItemSlot.armor ? baseStat + _rng.nextInt(tier + 1) : 0,
      hpBonus: slot == ItemSlot.accessory ? baseStat * 3 + _rng.nextInt(tier * 2 + 1) : 0,
      goldValue: (baseStat * 5 * rarityMult).round(),
    );
  }

  static final _templates = <ItemSlot, List<_ItemTemplate>>{
    ItemSlot.weapon: const [
      _ItemTemplate('sword', 'Sword', '\u2694\uFE0F'),
      _ItemTemplate('dagger', 'Dagger', '\u{1F5E1}\uFE0F'),
      _ItemTemplate('bow', 'Bow', '\u{1F3F9}'),
      _ItemTemplate('staff', 'Staff', '\u{1FA84}'),
      _ItemTemplate('axe', 'Axe', '\u{1FA93}'),
    ],
    ItemSlot.armor: const [
      _ItemTemplate('shield', 'Shield', '\u{1F6E1}\uFE0F'),
      _ItemTemplate('helmet', 'Helmet', '\u{1FA96}'),
      _ItemTemplate('vest', 'Vest', '\u{1F9E5}'),
      _ItemTemplate('robe', 'Robe', '\u{1F9E5}'),
      _ItemTemplate('plate', 'Plate Armor', '\u{1F6E1}\uFE0F'),
    ],
    ItemSlot.accessory: const [
      _ItemTemplate('ring', 'Ring', '\u{1F48D}'),
      _ItemTemplate('amulet', 'Amulet', '\u{1F4FF}'),
      _ItemTemplate('gem', 'Gem', '\u{1F48E}'),
      _ItemTemplate('charm', 'Charm', '\u{1F31F}'),
      _ItemTemplate('potion', 'Life Crystal', '\u{1F9EA}'),
    ],
  };
}

class _ItemTemplate {
  final String id;
  final String name;
  final String emoji;
  const _ItemTemplate(this.id, this.name, this.emoji);
}
