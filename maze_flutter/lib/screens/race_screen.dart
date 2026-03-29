import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/maze.dart';
import '../providers/game_provider.dart';

class RaceScreen extends StatelessWidget {
  const RaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Race!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: game.leave,
        ),
        actions: [
          // Key badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: game.hasKey ? const Color(0xFFFFDD00) : const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              game.hasKey ? '\u{1F511} Key' : 'No Key',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: game.hasKey ? Colors.black : Colors.white,
              ),
            ),
          ),
          // Move counter
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${game.moveCount}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Turn indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(
                  color: game.myTurn ? const Color(0xFF00CC00) : const Color(0xFF888888),
                  width: 4,
                ),
              ),
            ),
            child: Text(
              game.myTurn ? 'Your turn!' : 'Waiting...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: game.myTurn ? const Color(0xFF2E7D32) : const Color(0xFF666666),
              ),
            ),
          ),

          // Banner
          if (game.banner != null)
            _RaceBanner(text: game.banner!, type: game.bannerType ?? 'info'),

          // Opponent progress
          if (game.opponentEvent != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Color(0xFF0066FF), width: 4)),
              ),
              child: Text(
                game.opponentEvent!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF000000),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Fog grid
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _RaceGrid(
                    grid: game.raceGrid,
                    playerPos: game.playerPos,
                  ),
                ),
              ),
            ),
          ),

          // D-pad controls
          _DPad(onMove: game.move, enabled: game.myTurn),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RaceBanner extends StatelessWidget {
  final String text;
  final String type;
  const _RaceBanner({required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'info':    (const Color(0xFF0066FF), const Color(0xFF0066FF)),
      'success': (const Color(0xFF00CC00), const Color(0xFF006600)),
      'warning': (const Color(0xFFFF8800), const Color(0xFF884400)),
      'error':   (const Color(0xFFFF0000), const Color(0xFFCC0000)),
    };
    final (borderColor, textColor) = colors[type] ?? colors['info']!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

class _RaceGrid extends StatelessWidget {
  final List<List<int>> grid;
  final Point playerPos;
  const _RaceGrid({required this.grid, required this.playerPos});

  @override
  Widget build(BuildContext context) {
    if (grid.isEmpty) return const SizedBox();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 49,
      itemBuilder: (context, index) {
        final row = index ~/ 7;
        final col = index % 7;
        final y = 6 - row;
        final x = col;

        final tile = (y < grid.length && x < grid[0].length) ? grid[y][x] : Tile.hidden;
        final isPlayer = playerPos.x == x && playerPos.y == y;

        return Container(
          decoration: BoxDecoration(
            color: _tileColor(tile),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isPlayer ? const Color(0xFF4CAF50) : _tileBorder(tile),
              width: isPlayer ? 3 : (tile == Tile.hidden ? 1 : 2),
            ),
          ),
          child: Center(
            child: Text(
              isPlayer ? '\u{1F3C3}' : _tileEmoji(tile),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        );
      },
    );
  }

  Color _tileColor(int tile) {
    return switch (tile) {
      Tile.hidden => const Color(0xFFCCCCCC),
      Tile.floor => const Color(0xFFF5F5F5),
      Tile.wall => const Color(0xFF222222),
      Tile.key => const Color(0xFFFFDD00),
      Tile.door => const Color(0xFF7700CC),
      Tile.treasure => const Color(0xFFFF0000),
      Tile.openDoor => const Color(0xFFCC99FF),
      _ => const Color(0xFFF5F5F5),
    };
  }

  Color _tileBorder(int tile) {
    return switch (tile) {
      Tile.hidden => const Color(0xFFAAAAAA),
      Tile.wall => const Color(0xFF000000),
      Tile.key => const Color(0xFFCC9900),
      Tile.door => const Color(0xFF5500AA),
      Tile.treasure => const Color(0xFFCC0000),
      Tile.openDoor => const Color(0xFF5500AA),
      _ => const Color(0xFFBBBBBB),
    };
  }

  String _tileEmoji(int tile) {
    return switch (tile) {
      Tile.key => '\u{1F511}',
      Tile.door => '\u{1F6AA}',
      Tile.treasure => '\u{1F48E}',
      Tile.openDoor => '\u{1F6AA}',
      _ => '',
    };
  }
}

class _DPad extends StatelessWidget {
  final void Function(String direction) onMove;
  final bool enabled;
  const _DPad({required this.onMove, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DPadButton(icon: Icons.arrow_upward, onTap: () => onMove('up'), enabled: enabled),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DPadButton(icon: Icons.arrow_back, onTap: () => onMove('left'), enabled: enabled),
              const SizedBox(width: 64, height: 64),
              _DPadButton(icon: Icons.arrow_forward, onTap: () => onMove('right'), enabled: enabled),
            ],
          ),
          const SizedBox(height: 4),
          _DPadButton(icon: Icons.arrow_downward, onTap: () => onMove('down'), enabled: enabled),
        ],
      ),
    );
  }
}

class _DPadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _DPadButton({required this.icon, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF7700CC) : const Color(0xFF999999),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: enabled ? Colors.white : const Color(0xFF666666), size: 36),
      ),
    );
  }
}
