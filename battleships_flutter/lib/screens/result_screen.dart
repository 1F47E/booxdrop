import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/battle_provider.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final battle = context.watch<BattleProvider>();
    final won = battle.iWon;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Battleships',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Big result text
              Text(
                won ? 'You Won!' : 'You Lost',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: won ? const Color(0xFF006600) : const Color(0xFFCC0000),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                won
                    ? 'You sank all of ${battle.peerName ?? "their"} ships!'
                    : '${battle.winnerName ?? "Opponent"} sank all your ships.',
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Stats panel
              _StatsPanel(battle: battle),

              const Spacer(),

              // Rematch button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => battle.requestRematch(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Rematch',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Leave button
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => battle.leave(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Leave Game',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats panel
// ---------------------------------------------------------------------------

class _StatsPanel extends StatelessWidget {
  final BattleProvider battle;
  const _StatsPanel({required this.battle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Your Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'Shots Fired', value: '${battle.shotsFired}'),
          const _Divider(),
          _StatRow(label: 'Hits', value: '${battle.hits}'),
          const _Divider(),
          _StatRow(label: 'Enemy Ships Sunk', value: '${battle.theirShipsSunk} / 4'),
          const _Divider(),
          _StatRow(label: 'Your Ships Lost', value: '${battle.myShipsSunk} / 4'),
          if (battle.shotsFired > 0) ...[
            const _Divider(),
            _StatRow(
              label: 'Accuracy',
              value: '${(battle.hits * 100 / battle.shotsFired).round()}%',
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF333333),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: Color(0xFFCCCCCC), thickness: 1, height: 2);
  }
}
