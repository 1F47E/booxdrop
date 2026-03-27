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
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text('Race!', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: game.leave,
        ),
        actions: [
          // Key badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: game.hasKey ? const Color(0xFFFFD700) : const Color(0xFF333333),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              game.hasKey ? '\u{1F511} Key' : 'No Key',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: game.hasKey ? Colors.black : const Color(0xFF666666),
              ),
            ),
          ),
          // Move counter
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Moves: ${game.moveCount}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner
          if (game.banner != null)
            _RaceBanner(text: game.banner!, type: game.bannerType ?? 'info'),

          // Opponent progress
          if (game.opponentEvent != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              color: const Color(0xFF1A2A3E),
              child: Text(
                game.opponentEvent!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4FC3F7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Fog grid
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
          _DPad(onMove: game.move),

          const SizedBox(height: 16),
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
      'info': (const Color(0xFF1A2A3E), const Color(0xFF4FC3F7)),
      'success': (const Color(0xFF1A3A1E), const Color(0xFF4CAF50)),
      'warning': (const Color(0xFF3A3A1E), const Color(0xFFFFD700)),
      'error': (const Color(0xFF3A1A1E), const Color(0xFFFF4444)),
    };
    final (bg, fg) = colors[type] ?? colors['info']!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: bg,
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 14)),
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
              color: _tileBorder(tile),
              width: tile == Tile.hidden ? 0.5 : 2,
            ),
            boxShadow: isPlayer
                ? [BoxShadow(color: const Color(0xFF4CAF50).withValues(alpha: 0.6), blurRadius: 8)]
                : null,
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
      Tile.hidden => const Color(0xFF1A1A2E),
      Tile.floor => const Color(0xFFE8E8F0),
      Tile.wall => const Color(0xFF2C2C3A),
      Tile.key => const Color(0xFFFFF8DC),
      Tile.door => const Color(0xFFE0D4FF),
      Tile.treasure => const Color(0xFFFFE0E0),
      Tile.openDoor => const Color(0xFFF0E6FF),
      _ => const Color(0xFFE8E8F0),
    };
  }

  Color _tileBorder(int tile) {
    return switch (tile) {
      Tile.hidden => const Color(0xFF222222),
      Tile.wall => const Color(0xFF555555),
      Tile.key => const Color(0xFFFFD700),
      Tile.door => const Color(0xFF7C4DFF),
      Tile.treasure => const Color(0xFFFF4444),
      Tile.openDoor => const Color(0xFF7C4DFF),
      _ => const Color(0xFFCCCCCC),
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
  const _DPad({required this.onMove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up
          _DPadButton(
            icon: Icons.arrow_upward,
            onTap: () => onMove('up'),
          ),
          const SizedBox(height: 4),
          // Left, Center, Right
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DPadButton(
                icon: Icons.arrow_back,
                onTap: () => onMove('left'),
              ),
              const SizedBox(width: 52, height: 52),
              _DPadButton(
                icon: Icons.arrow_forward,
                onTap: () => onMove('right'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Down
          _DPadButton(
            icon: Icons.arrow_downward,
            onTap: () => onMove('down'),
          ),
        ],
      ),
    );
  }
}

class _DPadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DPadButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A4A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4FC3F7), width: 2),
        ),
        child: Icon(icon, color: const Color(0xFF4FC3F7), size: 28),
      ),
    );
  }
}
