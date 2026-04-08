import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/eink_theme.dart';

class DefeatScreen extends StatelessWidget {
  const DefeatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '\u{1F480}',
                  style: TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Defeated!',
                  style: TextStyle(
                    fontSize: EinkSizes.textTitle,
                    fontWeight: FontWeight.bold,
                    color: EinkColors.hpRed,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The monster was too strong!',
                  style: TextStyle(
                    fontSize: EinkSizes.textBody,
                    color: EinkColors.textMuted,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: EinkSizes.buttonHeight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EinkColors.white,
                      backgroundColor: EinkColors.accent,
                      side: const BorderSide(
                          color: EinkColors.accent, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: game.retryBattle,
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: EinkSizes.textLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: EinkSizes.buttonHeight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EinkColors.textMuted,
                      side:
                          const BorderSide(color: EinkColors.disabled, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: game.retreatFromBattle,
                    child: const Text(
                      'Retreat',
                      style: TextStyle(
                        fontSize: EinkSizes.textLarge,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
