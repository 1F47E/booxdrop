import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/maze.dart';
import '../providers/game_provider.dart';
import '../services/maze_storage.dart';

class MazeGalleryScreen extends StatefulWidget {
  const MazeGalleryScreen({super.key});

  @override
  State<MazeGalleryScreen> createState() => _MazeGalleryScreenState();
}

class _MazeGalleryScreenState extends State<MazeGalleryScreen> {
  List<SavedMaze>? _mazes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final mazes = await MazeStorage.loadAll();
    if (!mounted) return;
    setState(() { _mazes = mazes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Mazes${_mazes != null ? ' (${_mazes!.length})' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mazes == null || _mazes!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No mazes saved yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context.read<GameProvider>().enterWorkshop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Build One!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _mazes!.length,
                  itemBuilder: (context, index) {
                    final maze = _mazes![index];
                    return _MazeCard(
                      maze: maze,
                      onTap: () => _showDetail(maze),
                    );
                  },
                ),
    );
  }

  void _showDetail(SavedMaze maze) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _MazeDetailScreen(maze: maze),
      ),
    );
    if (deleted == true) _load();
  }
}

class _MazeCard extends StatelessWidget {
  final SavedMaze maze;
  final VoidCallback onTap;
  const _MazeCard({required this.maze, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _MiniGrid(cells: maze.cells),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
              ),
              child: Text(
                maze.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MazeDetailScreen extends StatelessWidget {
  final SavedMaze maze;
  const _MazeDetailScreen({required this.maze});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(maze.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () {
              final game = context.read<GameProvider>();
              game.enterWorkshopWithMaze(maze);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${maze.createdAt.day}/${maze.createdAt.month}/${maze.createdAt.year}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _MiniGrid(cells: maze.cells),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete maze?'),
        content: Text('Delete "${maze.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await MazeStorage.delete(maze.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx); // dialog
              if (!context.mounted) return;
              Navigator.pop(context, true); // detail screen, signal refresh
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MiniGrid extends StatelessWidget {
  final List<List<int>> cells;
  const _MiniGrid({required this.cells});

  @override
  Widget build(BuildContext context) {
    final h = cells.length;
    final w = cells.isNotEmpty ? cells[0].length : 7;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: w,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: h * w,
      itemBuilder: (context, index) {
        final row = index ~/ w;
        final col = index % w;
        final y = h - 1 - row;
        final x = col;
        final tile = cells[y][x];
        final isStart = x == 0 && y == 0;

        return Container(
          decoration: BoxDecoration(
            color: _color(tile, isStart),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: _border(tile, isStart), width: 1),
          ),
          child: Center(
            child: Text(_emoji(tile, isStart), style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }

  Color _color(int tile, bool isStart) {
    if (isStart) return const Color(0xFFC8FFC8);
    return switch (tile) {
      Tile.wall => const Color(0xFF333333),
      Tile.key => const Color(0xFFFFF9C4),
      Tile.door => const Color(0xFFE1BEE7),
      Tile.treasure => const Color(0xFFFFCDD2),
      _ => const Color(0xFFE8E8F0),
    };
  }

  Color _border(int tile, bool isStart) {
    if (isStart) return const Color(0xFF4CAF50);
    return switch (tile) {
      Tile.wall => const Color(0xFF333333),
      Tile.key => const Color(0xFFFFD700),
      Tile.door => const Color(0xFF7C4DFF),
      Tile.treasure => const Color(0xFFFF1744),
      _ => const Color(0xFFDDDDDD),
    };
  }

  String _emoji(int tile, bool isStart) {
    if (isStart) return '\u{1F6A9}';
    return switch (tile) {
      Tile.key => '\u{1F511}',
      Tile.door => '\u{1F6AA}',
      Tile.treasure => '\u{1F48E}',
      _ => '',
    };
  }
}
