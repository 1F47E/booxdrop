import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/battle_provider.dart';
import '../widgets/grid_widget.dart';

class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final battle = context.watch<BattleProvider>();

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => battle.leave(),
        ),
        actions: [
          _TurnIndicator(myTurn: battle.myTurn),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner
              if (battle.banner != null && battle.banner!.isNotEmpty)
                _BannerBar(battle: battle),

              // Opponent name
              _SectionLabel(
                label: 'vs ${battle.peerName ?? "Opponent"}',
                sublabel: battle.myTurn ? 'Tap to fire!' : 'Their turn...',
                myTurn: battle.myTurn,
              ),

              // Opponent grid — large, tappable
              Expanded(
                flex: 5,
                child: GridWidget(
                  grid: battle.opponentGrid,
                  onCellTap: battle.myTurn ? (x, y) => battle.fireShot(x, y) : null,
                  showShips: false,
                ),
              ),

              const SizedBox(height: 8),

              // Stats bar
              _StatsBar(battle: battle),

              const SizedBox(height: 8),

              // My grid label
              _SectionLabel(
                label: 'Your Fleet',
                sublabel: null,
                myTurn: false,
              ),

              // My grid — smaller, read-only
              Expanded(
                flex: 3,
                child: GridWidget(
                  grid: battle.myGrid,
                  onCellTap: null,
                  showShips: true,
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Turn indicator — shown in AppBar actions
// ---------------------------------------------------------------------------

class _TurnIndicator extends StatelessWidget {
  final bool myTurn;
  const _TurnIndicator({required this.myTurn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: myTurn ? const Color(0xFF009900) : const Color(0xFF888888),
            width: 4,
          ),
        ),
      ),
      child: Text(
        myTurn ? 'Your turn!' : 'Waiting...',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: myTurn ? const Color(0xFF006600) : const Color(0xFF555555),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label above each grid
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool myTurn;

  const _SectionLabel({
    required this.label,
    required this.sublabel,
    required this.myTurn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(width: 8),
            Text(
              sublabel!,
              style: TextStyle(
                fontSize: 15,
                color: myTurn ? const Color(0xFF006600) : const Color(0xFF555555),
                fontWeight: myTurn ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats bar between the two grids
// ---------------------------------------------------------------------------

class _StatsBar extends StatelessWidget {
  final BattleProvider battle;
  const _StatsBar({required this.battle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Shots', value: '${battle.shotsFired}'),
          _StatDivider(),
          _StatItem(label: 'Hits', value: '${battle.hits}'),
          _StatDivider(),
          _StatItem(label: 'Sunk', value: '${battle.theirShipsSunk}/4'),
          _StatDivider(),
          _StatItem(label: 'Lost', value: '${battle.myShipsSunk}/4'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF444444),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 32,
      color: const Color(0xFFBBBBBB),
    );
  }
}

// ---------------------------------------------------------------------------
// Banner bar
// ---------------------------------------------------------------------------

class _BannerBar extends StatelessWidget {
  final BattleProvider battle;
  const _BannerBar({required this.battle});

  @override
  Widget build(BuildContext context) {
    final isError = battle.bannerType == 'error';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFDDDD) : const Color(0xFFDDFFDD),
        border: Border.all(
          color: isError ? const Color(0xFFCC0000) : const Color(0xFF009900),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        battle.banner!,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: isError ? const Color(0xFFCC0000) : const Color(0xFF006600),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

