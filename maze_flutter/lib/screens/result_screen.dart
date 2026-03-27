import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final won = game.iWon;

    return Scaffold(
      backgroundColor: won ? const Color(0xFF0A1A0A) : const Color(0xFF1A0A0A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy or sad face
                Text(
                  won ? '\u{1F3C6}' : '\u{1F614}',
                  style: const TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 16),

                // Result text
                Text(
                  won ? 'You Win!' : 'You Lose',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: won ? const Color(0xFF4CAF50) : const Color(0xFFFF4444),
                  ),
                ),
                const SizedBox(height: 8),

                // Winner name
                Text(
                  '${game.winnerName ?? "?"} found the treasure!',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
                const SizedBox(height: 8),

                // Move count
                Text(
                  '${game.moveCount} moves',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 40),

                // Rematch button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: game.rematch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Rematch',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Leave button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: game.leave,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF888888),
                      side: const BorderSide(color: Color(0xFF444444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Leave',
                      style: TextStyle(fontSize: 16),
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
