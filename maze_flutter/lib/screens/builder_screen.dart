import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/maze.dart';
import '../providers/game_provider.dart';
import '../services/maze_storage.dart';

class BuilderScreen extends StatelessWidget {
  const BuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final isCountdown = game.phase == GamePhase.countdown;
    final isWorkshop = game.phase == GamePhase.workshop;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isWorkshop ? 'Build a Maze' : 'Build Your Maze',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isWorkshop ? game.exitWorkshop : game.leave,
        ),
        actions: [
          // Peer status (multiplayer only)
          if (!isWorkshop && game.peerBuildState == 'done')
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${game.peerName ?? "Peer"} done',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          // Load saved maze (multiplayer build only)
          if (!isWorkshop && game.phase == GamePhase.build)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Load saved maze',
              onPressed: () => _showLoadDialog(context, game),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Server banner takes priority
              if (game.banner != null)
                _buildBanner(game.banner!, game.bannerType ?? 'info')
              // Warning if maze may not be solvable (non-blocking)
              else if (game.maze.hasRequiredTiles && !game.maze.isSolvable)
                _buildBanner('\u26A0 ${game.maze.validationError ?? 'Maze may not be solvable'}', 'warning'),

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

              // Action button
              Padding(
                padding: const EdgeInsets.all(12),
                child: isWorkshop
                    ? _SaveButton(game: game)
                    : _DoneButton(game: game),
              ),
            ],
          ),

          // Countdown overlay
          if (isCountdown)
            Container(
              color: Colors.black,
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

  void _showLoadDialog(BuildContext context, GameProvider game) async {
    final mazes = await MazeStorage.loadAll();
    if (!context.mounted) return;

    if (mazes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved mazes yet. Build one first!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Load Saved Maze',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...mazes.take(5).map((m) => ListTile(
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${m.createdAt.day}/${m.createdAt.month}/${m.createdAt.year}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                game.loadMaze(m);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(String text, String type) {
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
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }
}

class _DoneButton extends StatelessWidget {
  final GameProvider game;
  const _DoneButton({required this.game});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: game.maze.hasRequiredTiles ? game.toggleDone : null,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: !game.maze.hasRequiredTiles
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
    );
  }
}

class _SaveButton extends StatelessWidget {
  final GameProvider game;
  const _SaveButton({required this.game});

  @override
  Widget build(BuildContext context) {
    final canSave = game.maze.hasRequiredTiles;
    return GestureDetector(
      onTap: canSave ? () => _save(context) : null,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: canSave ? const Color(0xFF7700CC) : const Color(0xFFBBBBBB),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Save Maze',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
    );
  }

  void _save(BuildContext context) async {
    final ok = await game.saveMaze();
    if (ok) {
      game.exitWorkshop();
    }
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
        final isStart = tile == Tile.start;

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
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _tileColor(int tile, bool isStart) {
    return switch (tile) {
      Tile.start => const Color(0xFF00CC00),
      Tile.wall => const Color(0xFF222222),
      Tile.key => const Color(0xFFFFDD00),
      Tile.door => const Color(0xFF7700CC),
      Tile.treasure => const Color(0xFFFF0000),
      _ => const Color(0xFFF5F5F5),
    };
  }

  Color _tileBorder(int tile, bool isStart) {
    return switch (tile) {
      Tile.start => const Color(0xFF006600),
      Tile.wall => const Color(0xFF000000),
      Tile.key => const Color(0xFFCC9900),
      Tile.door => const Color(0xFF5500AA),
      Tile.treasure => const Color(0xFFCC0000),
      _ => const Color(0xFFBBBBBB),
    };
  }

  String _tileEmoji(int tile, bool isStart) {
    return switch (tile) {
      Tile.start => '\u{1F3C1}',
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
      (Tile.wall, '\u2B1B', 'Wall', const Color(0xFF222222)),
      (Tile.floor, '\u2B1C', 'Erase', const Color(0xFF666666)),
      (Tile.start, '\u{1F3C1}', 'Start', const Color(0xFF00CC00)),
      (Tile.key, '\u{1F511}', 'Key', const Color(0xFFCC9900)),
      (Tile.door, '\u{1F6AA}', 'Door', const Color(0xFF7700CC)),
      (Tile.treasure, '\u{1F48E}', 'Gem', const Color(0xFFFF0000)),
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
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEEEEEE) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : const Color(0xFFCCCCCC),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  Text(label, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
