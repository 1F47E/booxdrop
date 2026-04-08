enum ElementType { normal, fire, ice, poison, dark, earth }

class Monster {
  final String name;
  final String emoji;
  final int baseHp;
  final int baseAtk;
  final ElementType element;
  final int xpReward;
  final int goldReward;
  final String? lootTableId;
  final int zoneIndex;
  final bool isBoss;

  const Monster({
    required this.name,
    required this.emoji,
    required this.baseHp,
    required this.baseAtk,
    required this.element,
    required this.xpReward,
    required this.goldReward,
    this.lootTableId,
    required this.zoneIndex,
    this.isBoss = false,
  });

  String get elementLabel => switch (element) {
        ElementType.normal => 'Normal',
        ElementType.fire => 'Fire',
        ElementType.ice => 'Ice',
        ElementType.poison => 'Poison',
        ElementType.dark => 'Dark',
        ElementType.earth => 'Earth',
      };
}
