import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final results = game.results;
    final totalStars = game.totalStars;
    final maxStars = game.maxStars;
    final modeLabel =
        game.mode == GameMode.countries ? 'Countries' : 'Capitals';

    final overallMessage = _overallMessage(totalStars, maxStars);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              color: const Color(0xFF1B5E20),
              child: Column(
                children: [
                  Text(
                    overallMessage.emoji,
                    style: const TextStyle(fontSize: 56),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    overallMessage.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$modeLabel  •  ${game.totalScore} pts',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'$totalStars'} / $maxStars stars',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // ── Round breakdown ──
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = results[i];
                  final stars = '\u{2B50}' * r.stars;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    leading: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black45,
                      ),
                    ),
                    title: Text(
                      '${r.quest.flag} ${r.quest.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${r.distanceKm.round()} km  $stars',
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: Text(
                      '+${r.points}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF43A047),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Action buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF1B5E20), width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => game.goHome(),
                        child: const Text('Home'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43A047),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => game.startGame(game.mode),
                        child: const Text('Play Again!'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static ({String emoji, String text}) _overallMessage(
      int stars, int maxStars) {
    final ratio = stars / maxStars;
    if (ratio >= 0.8) return (emoji: '\u{1F3C6}', text: 'Geography Genius!');
    if (ratio >= 0.6) return (emoji: '\u{1F31F}', text: 'Super Explorer!');
    if (ratio >= 0.4) return (emoji: '\u{1F44D}', text: 'Great Adventure!');
    return (emoji: '\u{1F30D}', text: 'Keep Exploring!');
  }
}
