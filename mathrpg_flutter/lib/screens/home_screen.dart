import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/ota_controller.dart';
import '../providers/game_provider.dart';
import '../theme/eink_theme.dart';
import '../widgets/ota_menu_footer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final ota = context.read<OtaController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Math RPG'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              OtaMenuFooter(controller: ota),
            ],
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '\u2694\uFE0F',
                style: TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 16),
              const Text(
                'Adventure Math',
                style: TextStyle(
                  fontSize: EinkSizes.textTitle,
                  fontWeight: FontWeight.bold,
                  color: EinkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Solve. Fight. Level Up!',
                style: TextStyle(
                  fontSize: EinkSizes.textBody,
                  color: EinkColors.textMuted,
                ),
              ),
              const SizedBox(height: 48),
              if (game.hasSave) ...[
                SizedBox(
                  width: double.infinity,
                  height: EinkSizes.buttonHeight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EinkColors.white,
                      backgroundColor: EinkColors.primary,
                      side: const BorderSide(color: EinkColors.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: game.continueGame,
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: EinkSizes.textLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: EinkSizes.buttonHeight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EinkColors.white,
                    backgroundColor: EinkColors.accent,
                    side: const BorderSide(color: EinkColors.accent, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: game.startNewGame,
                  child: const Text(
                    'New Game',
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
