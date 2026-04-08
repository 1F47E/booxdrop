import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/eink_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (game.character != null) {
              game.backToMap();
            } else {
              game.goHome();
            }
          },
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (game.hasSave) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: EinkColors.error, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danger Zone',
                    style: TextStyle(
                      fontSize: EinkSizes.textBody,
                      fontWeight: FontWeight.bold,
                      color: EinkColors.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: EinkSizes.tapTarget,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EinkColors.error,
                        side: const BorderSide(color: EinkColors.error, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _confirmDelete(context, game),
                      child: const Text(
                        'Delete Save',
                        style: TextStyle(
                          fontSize: EinkSizes.textBody,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, GameProvider game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Save?'),
        content: const Text(
            'This will permanently delete your character and all progress. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              game.deleteSave();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: EinkColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
