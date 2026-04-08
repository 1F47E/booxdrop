import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/battle_state.dart';
import '../providers/battle_provider.dart';
import '../providers/game_provider.dart';
import '../theme/eink_theme.dart';
import '../widgets/damage_text.dart';
import '../widgets/emoji_avatar.dart';
import '../widgets/hp_bar.dart';
import '../widgets/math_choice_button.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  @override
  void initState() {
    super.initState();
    final game = context.read<GameProvider>();
    final battle = context.read<BattleProvider>();
    if (game.currentMonster != null && game.character != null) {
      battle.startBattle(game.currentMonster!, game.character!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();
    final battle = context.watch<BattleProvider>();
    final state = battle.state;
    final problem = battle.currentProblem;

    if (state == null || problem == null) return const SizedBox.shrink();

    // Auto-transition on victory/defeat
    if (state.phase == BattlePhase.victory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        game.onBattleVictory(
          xpGained: battle.xpGained,
          goldGained: battle.goldGained,
          loot: battle.lootDrop,
          levelsGained: battle.levelsGained,
        );
      });
    } else if (state.phase == BattlePhase.defeat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        game.onBattleDefeat();
      });
    }

    final isShowingResult = state.phase == BattlePhase.playerAttacking ||
        state.phase == BattlePhase.monsterAttacking;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app),
          onPressed: () => game.retreatFromBattle(),
        ),
        title: const Text('Battle!'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Turn ${state.turnCount}',
                style: const TextStyle(fontSize: EinkSizes.textBody),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Monster section
            EmojiAvatar(
              emoji: state.monster.emoji,
              size: EinkSizes.avatarLarge,
              borderColor: EinkColors.hpRed,
            ),
            const SizedBox(height: 4),
            Text(
              state.monster.name,
              style: const TextStyle(
                fontSize: EinkSizes.textBody,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: HpBar(
                current: state.monsterCurrentHp,
                max: state.monster.baseHp,
                color: EinkColors.hpRed,
              ),
            ),
            const SizedBox(height: 12),

            // Action text
            if (state.lastActionText != null)
              DamageText(
                text: state.lastActionText!,
                color: state.phase == BattlePhase.playerAttacking
                    ? EinkColors.success
                    : EinkColors.hpRed,
              ),
            if (state.lastActionText == null)
              const SizedBox(height: 44),

            const SizedBox(height: 12),

            // Math problem card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: EinkColors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: EinkColors.offWhite,
              ),
              child: Text(
                problem.questionText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: EinkSizes.textTitle,
                  fontWeight: FontWeight.bold,
                  color: EinkColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2x2 answer grid
            if (!isShowingResult)
              _AnswerGrid(
                choices: problem.choices,
                onTap: battle.submitAnswer,
                selectedAnswer: battle.selectedAnswer,
                answerCorrect: battle.answerCorrect,
                correctAnswer: problem.correctAnswer,
                enabled: true,
              )
            else
              _AnswerGrid(
                choices: problem.choices,
                onTap: (_) {},
                selectedAnswer: battle.selectedAnswer,
                answerCorrect: battle.answerCorrect,
                correctAnswer: problem.correctAnswer,
                enabled: false,
              ),

            // Continue button after showing result
            if (isShowingResult) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: EinkSizes.tapTarget,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EinkColors.black,
                    side: const BorderSide(color: EinkColors.black, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: battle.nextTurn,
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontSize: EinkSizes.textBody,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Player section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmojiAvatar(
                  emoji: game.character?.info.emoji ?? '\u2694\uFE0F',
                  size: EinkSizes.avatarSmall,
                  borderColor: EinkColors.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${game.character?.name ?? "Hero"} Lv.${game.character?.level ?? 1}',
                        style: const TextStyle(
                          fontSize: EinkSizes.textBody,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      HpBar(
                        current: state.playerCurrentHp,
                        max: state.playerMaxHp,
                        color: EinkColors.hpGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AnswerGrid extends StatelessWidget {
  const _AnswerGrid({
    required this.choices,
    required this.onTap,
    this.selectedAnswer,
    this.answerCorrect,
    required this.correctAnswer,
    required this.enabled,
  });

  final List<int> choices;
  final void Function(int) onTap;
  final int? selectedAnswer;
  final bool? answerCorrect;
  final int correctAnswer;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MathChoiceButton(
                value: choices[0],
                onTap: () => onTap(choices[0]),
                isSelected: selectedAnswer == choices[0],
                isCorrect: selectedAnswer != null
                    ? choices[0] == correctAnswer
                    : null,
                enabled: enabled,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MathChoiceButton(
                value: choices[1],
                onTap: () => onTap(choices[1]),
                isSelected: selectedAnswer == choices[1],
                isCorrect: selectedAnswer != null
                    ? choices[1] == correctAnswer
                    : null,
                enabled: enabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MathChoiceButton(
                value: choices[2],
                onTap: () => onTap(choices[2]),
                isSelected: selectedAnswer == choices[2],
                isCorrect: selectedAnswer != null
                    ? choices[2] == correctAnswer
                    : null,
                enabled: enabled,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MathChoiceButton(
                value: choices[3],
                onTap: () => onTap(choices[3]),
                isSelected: selectedAnswer == choices[3],
                isCorrect: selectedAnswer != null
                    ? choices[3] == correctAnswer
                    : null,
                enabled: enabled,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
