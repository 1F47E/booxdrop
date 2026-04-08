import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/eink_theme.dart';
import '../widgets/item_card.dart';
import '../widgets/xp_bar.dart';

class VictoryScreen extends StatelessWidget {
  const VictoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final character = game.character;
    if (character == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '\u{1F3C6}',
                style: TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 16),
              const Text(
                'Victory!',
                style: TextStyle(
                  fontSize: EinkSizes.textTitle,
                  fontWeight: FontWeight.bold,
                  color: EinkColors.success,
                ),
              ),
              const SizedBox(height: 24),

              // Rewards
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: EinkColors.success, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: EinkColors.offWhite,
                ),
                child: Column(
                  children: [
                    Text(
                      '+${game.lastXpGained} XP    +${game.lastGoldGained} Gold',
                      style: const TextStyle(
                        fontSize: EinkSizes.textLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    XpBar(
                      currentXp: character.xp,
                      level: character.level,
                    ),
                  ],
                ),
              ),

              // Level up
              if (game.lastLevelsGained > 0) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: EinkColors.goldYellow, width: 3),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFFFFDE0),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '\u{2B50} Level Up!',
                        style: TextStyle(
                          fontSize: EinkSizes.textTitle,
                          fontWeight: FontWeight.bold,
                          color: EinkColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Now Level ${character.level}!',
                        style: const TextStyle(
                          fontSize: EinkSizes.textBody,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'HP: ${character.baseMaxHp}  ATK: ${character.baseAtk}  DEF: ${character.baseDef}',
                        style: const TextStyle(
                          fontSize: EinkSizes.textSmall,
                          color: EinkColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Loot
              if (game.lastLoot != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Loot Found!',
                  style: TextStyle(
                    fontSize: EinkSizes.textBody,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ItemCard(
                  item: game.lastLoot!,
                  onEquip: () => game.equipLoot(game.lastLoot!),
                  onSell: null,
                  showActions: true,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EinkColors.textMuted,
                      side: const BorderSide(color: EinkColors.disabled),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => game.keepLoot(game.lastLoot!),
                    child: const Text('Keep in inventory',
                        style: TextStyle(fontSize: EinkSizes.textSmall)),
                  ),
                ),
              ],

              const Spacer(),

              // Continue
              SizedBox(
                width: double.infinity,
                height: EinkSizes.buttonHeight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EinkColors.white,
                    backgroundColor: EinkColors.success,
                    side:
                        const BorderSide(color: EinkColors.success, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: game.collectVictoryRewards,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: EinkSizes.textLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
