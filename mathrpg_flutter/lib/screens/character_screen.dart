import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/eink_theme.dart';
import '../widgets/emoji_avatar.dart';
import '../widgets/stat_row.dart';
import '../widgets/xp_bar.dart';

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

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
        title: const Text('Hero Stats'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            EmojiAvatar(
              emoji: character.info.emoji,
              size: EinkSizes.avatarLarge,
              borderColor: EinkColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              character.name,
              style: const TextStyle(
                fontSize: EinkSizes.textTitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Level ${character.level} ${character.info.name}',
              style: const TextStyle(
                fontSize: EinkSizes.textBody,
                color: EinkColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            XpBar(currentXp: character.xp, level: character.level),
            const SizedBox(height: 24),

            // Stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: EinkColors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: EinkColors.offWhite,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatRow(
                    label: 'HP',
                    value: '${character.maxHp}',
                    bonus: character.equipHpBonus > 0
                        ? character.equipHpBonus
                        : null,
                  ),
                  StatRow(
                    label: 'ATK',
                    value: '${character.atk}',
                    bonus: character.equipAtkBonus > 0
                        ? character.equipAtkBonus
                        : null,
                  ),
                  StatRow(
                    label: 'DEF',
                    value: '${character.def}',
                    bonus: character.equipDefBonus > 0
                        ? character.equipDefBonus
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: EinkColors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: EinkColors.offWhite,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatRow(
                    label: 'Gold',
                    value: '${character.gold}',
                  ),
                  StatRow(
                    label: 'Monsters Defeated',
                    value: '${character.monstersDefeated}',
                  ),
                  StatRow(
                    label: 'Problems Solved',
                    value: '${character.problemsSolved}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
