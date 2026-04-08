import 'package:flutter/material.dart';
import '../models/item.dart';
import '../theme/eink_theme.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    this.onEquip,
    this.onSell,
    this.onUnequip,
    this.showActions = true,
  });

  final Item item;
  final VoidCallback? onEquip;
  final VoidCallback? onSell;
  final VoidCallback? onUnequip;
  final bool showActions;

  Color get _rarityColor => switch (item.rarity) {
        ItemRarity.common => EinkColors.rarityCommon,
        ItemRarity.uncommon => EinkColors.rarityUncommon,
        ItemRarity.rare => EinkColors.rarityRare,
        ItemRarity.epic => EinkColors.rarityEpic,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _rarityColor, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: EinkColors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: EinkSizes.textBody,
                        fontWeight: FontWeight.bold,
                        color: _rarityColor,
                      ),
                    ),
                    Text(
                      '${item.rarityLabel} ${item.slotLabel}',
                      style: const TextStyle(
                        fontSize: EinkSizes.textSmall,
                        color: EinkColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildStats(),
          if (showActions) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onEquip != null)
                  Expanded(
                    child: _ActionButton(
                      label: 'Equip',
                      onTap: onEquip!,
                      color: EinkColors.primary,
                    ),
                  ),
                if (onUnequip != null)
                  Expanded(
                    child: _ActionButton(
                      label: 'Unequip',
                      onTap: onUnequip!,
                      color: EinkColors.textMuted,
                    ),
                  ),
                if (onSell != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Sell ${item.goldValue}g',
                      onTap: onSell!,
                      color: EinkColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = <String>[];
    if (item.atkBonus > 0) stats.add('ATK +${item.atkBonus}');
    if (item.defBonus > 0) stats.add('DEF +${item.defBonus}');
    if (item.hpBonus > 0) stats.add('HP +${item.hpBonus}');
    if (stats.isEmpty) return const SizedBox.shrink();
    return Text(
      stats.join('  '),
      style: const TextStyle(
        fontSize: EinkSizes.textSmall,
        fontWeight: FontWeight.bold,
        color: EinkColors.textSecondary,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: EinkSizes.textSmall,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
