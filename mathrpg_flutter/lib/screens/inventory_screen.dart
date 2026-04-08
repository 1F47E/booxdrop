import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../providers/game_provider.dart';
import '../theme/eink_theme.dart';
import '../widgets/item_card.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final character = game.character;
    if (character == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: game.backToMap,
        ),
        title: const Text('Inventory'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Equipment section
          const Text(
            'Equipment',
            style: TextStyle(
              fontSize: EinkSizes.textLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...ItemSlot.values.map((slot) {
            final item = character.equipment[slot];
            final slotLabel = switch (slot) {
              ItemSlot.weapon => '\u2694\uFE0F Weapon',
              ItemSlot.armor => '\u{1F6E1}\uFE0F Armor',
              ItemSlot.accessory => '\u{1F48D} Accessory',
            };
            if (item != null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ItemCard(
                  item: item,
                  onUnequip: () => game.unequipItem(slot),
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: EinkColors.disabled, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$slotLabel — Empty',
                style: const TextStyle(
                  fontSize: EinkSizes.textBody,
                  color: EinkColors.textMuted,
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          // Inventory items
          Row(
            children: [
              const Text(
                'Items',
                style: TextStyle(
                  fontSize: EinkSizes.textLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${character.inventory.length})',
                style: const TextStyle(
                  fontSize: EinkSizes.textBody,
                  color: EinkColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (character.inventory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No items yet. Defeat monsters to find loot!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: EinkSizes.textBody,
                  color: EinkColors.textMuted,
                ),
              ),
            )
          else
            ...character.inventory.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ItemCard(
                    item: item,
                    onEquip: () => game.equipItem(item),
                    onSell: () => game.sellItem(item),
                  ),
                )),
        ],
      ),
    );
  }
}
