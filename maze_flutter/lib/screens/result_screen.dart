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
      backgroundColor: Colors.white,
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
                    color: won ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 8),

                // Winner name
                Text(
                  '${game.winnerName ?? "?"} found the treasure!',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                ),
                const SizedBox(height: 8),

                // Move count
                Text(
                  '${game.moveCount} moves',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF444444)),
                ),
                const SizedBox(height: 40),

                // Rematch button — flat
                GestureDetector(
                  onTap: game.rematch,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Rematch',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Leave button
                GestureDetector(
                  onTap: game.leave,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF000000), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Leave',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
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
