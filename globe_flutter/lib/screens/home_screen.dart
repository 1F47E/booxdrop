import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ota_controller.dart';
import '../providers/game_provider.dart';
import '../widgets/ota_menu_footer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final otaController = context.read<OtaController>();

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'GlobeQuest',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
              const Spacer(),
              OtaMenuFooter(controller: otaController),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '\u{1F30D}',
                  style: TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 12),
                const Text(
                  'GlobeQuest',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find countries on the globe!',
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 48),

                // Countries button
                SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => game.startGame(GameMode.countries),
                    child: const Text('\u{1F3F3}\u{FE0F}  Countries'),
                  ),
                ),
                const SizedBox(height: 20),

                // Capitals button
                SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => game.startGame(GameMode.capitals),
                    child: const Text('\u{1F3DB}\u{FE0F}  Capitals'),
                  ),
                ),

                const SizedBox(height: 48),

                // High scores
                if (game.highScoreCountries > 0 || game.highScoreCapitals > 0)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Best Scores',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (game.highScoreCountries > 0)
                          Text(
                            'Countries: ${game.highScoreCountries} pts',
                            style: const TextStyle(
                                fontSize: 18, color: Color(0xFF43A047)),
                          ),
                        if (game.highScoreCapitals > 0)
                          Text(
                            'Capitals: ${game.highScoreCapitals} pts',
                            style: const TextStyle(
                                fontSize: 18, color: Color(0xFF1565C0)),
                          ),
                      ],
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
