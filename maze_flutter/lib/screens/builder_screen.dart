import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/maze.dart';
import '../providers/game_provider.dart';

class BuilderScreen extends StatelessWidget {
  const BuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final isCountdown = game.phase == GamePhase.countdown;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        title: const Text('Build Your Maze', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: game.leave,
        ),
        actions: [
          if (game.peerBuildState == 'done')
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${game.peerName ?? "Peer"} done',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Banner
              if (game.banner != null)
                _buildBanner(game.banner!, game.bannerType ?? 'info'),

              // Grid
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _MazeGrid(maze: game.maze, onTap: game.placeTile),
                    ),
                  ),
                ),
              ),

              // Tool palette
              _ToolPalette(
                selected: game.selectedTool,
                onSelect: game.selectTool,
              ),

              // Done button — flat
              Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: game.maze.isLocallyValid ? game.toggleDone : null,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: !game.maze.isLocallyValid
                          ? Colors.grey.shade300
                          : game.isDone
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      game.isDone ? 'Done \u2713' : 'Done',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Countdown overlay
          if (isCountdown)
            Container(
              color: Colors.black54,
              child: Center(
                child: Text(
                  '${game.countdownValue}',
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBanner(String text, String type) {
    final colors = {
      'info': (const Color(0xFFE3F2FD), const Color(0xFF1976D2)),
      'success': (const Color(0xFFE8F5E9), const Color(0xFF388E3C)),
      'warning': (const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
      'error': (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
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

class _MazeGrid extends StatelessWidget {
  final Maze maze;
  final void Function(int x, int y) onTap;
  const _MazeGrid({required this.maze, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 49,
      itemBuilder: (context, index) {
        // Top row is y=6, bottom row is y=0
        final row = index ~/ 7;
        final col = index % 7;
        final y = 6 - row;
        final x = col;

        final tile = maze.get(x, y);
        final isStart = x == 0 && y == 0;

        return GestureDetector(
          onTap: () => onTap(x, y),
          child: Container(
            decoration: BoxDecoration(
              color: _tileColor(tile, isStart),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _tileBorder(tile, isStart),
                width: isStart || tile != Tile.floor ? 2 : 0.5,
              ),
            ),
            child: Center(
              child: Text(
                _tileEmoji(tile, isStart),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _tileColor(int tile, bool isStart) {
    if (isStart) return const Color(0xFFC8FFC8);
    return switch (tile) {
      Tile.wall => const Color(0xFF2C2C3A),
      Tile.key => const Color(0xFFFFF8DC),
      Tile.door => const Color(0xFFE0D4FF),
      Tile.treasure => const Color(0xFFFFE0E0),
      _ => const Color(0xFFE8E8F0),
    };
  }

  Color _tileBorder(int tile, bool isStart) {
    if (isStart) return const Color(0xFF4CAF50);
    return switch (tile) {
      Tile.wall => const Color(0xFF555555),
      Tile.key => const Color(0xFFFFD700),
      Tile.door => const Color(0xFF7C4DFF),
      Tile.treasure => const Color(0xFFFF4444),
      _ => const Color(0xFFCCCCCC),
    };
  }

  String _tileEmoji(int tile, bool isStart) {
    if (isStart) return '\u{1F6A9}';
    return switch (tile) {
      Tile.key => '\u{1F511}',
      Tile.door => '\u{1F6AA}',
      Tile.treasure => '\u{1F48E}',
      _ => '',
    };
  }
}

class _ToolPalette extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  const _ToolPalette({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tools = [
      (Tile.wall, '\u2B1B', 'Wall', const Color(0xFF2C2C3A)),
      (Tile.floor, '\u2B1C', 'Erase', const Color(0xFFE8E8F0)),
      (Tile.key, '\u{1F511}', 'Key', const Color(0xFFFFD700)),
      (Tile.door, '\u{1F6AA}', 'Door', const Color(0xFF7C4DFF)),
      (Tile.treasure, '\u{1F48E}', 'Gem', const Color(0xFFFF4444)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tools.map((t) {
          final (tile, emoji, label, color) = t;
          final isSelected = selected == tile;
          return GestureDetector(
            onTap: () => onSelect(tile),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
