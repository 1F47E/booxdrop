import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match_record.dart';
import '../models/maze.dart';
import '../providers/game_provider.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MatchRecord>? _matches;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() { _loading = true; _error = null; });
    try {
      final game = context.read<GameProvider>();
      final matches = await HistoryService.fetchMatches(
        game.serverBaseUrl,
        limit: 50,
      );
      if (!mounted) return;
      setState(() { _matches = matches; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0E6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        title: const Text('Match History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _matches == null || _matches!.isEmpty
                  ? const Center(
                      child: Text(
                        'No matches yet!\nPlay a game first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMatches,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _matches!.length,
                        itemBuilder: (context, index) {
                          final m = _matches![index];
                          return _MatchCard(
                            match: m,
                            myDeviceId: game.deviceId,
                            onTap: () => _showDetail(m),
                          );
                        },
                      ),
                    ),
    );
  }

  void _showDetail(MatchRecord match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MatchDetailScreen(
          match: match,
          myDeviceId: context.read<GameProvider>().deviceId,
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchRecord match;
  final String? myDeviceId;
  final VoidCallback onTap;

  const _MatchCard({required this.match, required this.myDeviceId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iWon = match.didWin(myDeviceId);
    final iPlayed = match.winnerDeviceId == myDeviceId || match.loserDeviceId == myDeviceId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: iPlayed
              ? (iWon ? const Color(0xFF4CAF50) : const Color(0xFFFF4444))
              : Colors.grey.shade300,
          width: iPlayed ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: date + duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(match.playedAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    match.durationText,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Winner
              Row(
                children: [
                  const Text('\u{1F3C6} ', style: TextStyle(fontSize: 18)),
                  Text(
                    match.winnerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  Text(
                    ' (${match.winnerMoves} moves)',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  if (match.winnerDeviceId == myDeviceId)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('You', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Loser
              Row(
                children: [
                  const SizedBox(width: 26),
                  Text(
                    match.loserName,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
                  ),
                  Text(
                    ' (${match.loserMoves} moves)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (match.loserDeviceId == myDeviceId)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4444),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('You', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),

              const SizedBox(height: 6),
              Text(
                'Tap to view mazes \u{2192}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ========================================
// Match Detail — shows both mazes
// ========================================

class _MatchDetailScreen extends StatelessWidget {
  final MatchRecord match;
  final String? myDeviceId;

  const _MatchDetailScreen({required this.match, required this.myDeviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0E6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        title: const Text('Match Detail', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Result banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '\u{1F3C6} ${match.winnerName} wins!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${match.durationText} \u{2022} ${match.winnerMoves} vs ${match.loserMoves} moves',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    _formatDate(match.playedAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Host maze
            _MazeSection(
              label: '${match.hostName}\'s Maze',
              maze: match.hostMaze,
              isWinner: match.winnerDeviceId == match.hostDeviceId,
            ),
            const SizedBox(height: 16),

            // Guest maze
            _MazeSection(
              label: '${match.guestName}\'s Maze',
              maze: match.guestMaze,
              isWinner: match.winnerDeviceId == match.guestDeviceId,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MazeSection extends StatelessWidget {
  final String label;
  final List<List<int>> maze;
  final bool isWinner;

  const _MazeSection({required this.label, required this.maze, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner ? const Color(0xFF4CAF50) : Colors.grey.shade300,
          width: isWinner ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              if (isWinner) const Text('\u{1F3C6} ', style: TextStyle(fontSize: 16)),
              Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1,
            child: _MiniMazeGrid(maze: maze),
          ),
        ],
      ),
    );
  }
}

class _MiniMazeGrid extends StatelessWidget {
  final List<List<int>> maze;
  const _MiniMazeGrid({required this.maze});

  @override
  Widget build(BuildContext context) {
    if (maze.isEmpty) {
      return const Center(child: Text('No maze data', style: TextStyle(color: Colors.grey)));
    }

    final h = maze.length;
    final w = maze.isNotEmpty ? maze[0].length : 7;

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
        final tile = maze[y][x];
        final isStart = x == 0 && y == 0;

        return Container(
          decoration: BoxDecoration(
            color: _color(tile, isStart),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: _border(tile, isStart), width: 1),
          ),
          child: Center(
            child: Text(
              _emoji(tile, isStart),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );
      },
    );
  }

  Color _color(int tile, bool isStart) {
    if (isStart) return const Color(0xFFC8FFC8);
    return switch (tile) {
      Tile.wall => const Color(0xFF2C2C3A),
      Tile.key => const Color(0xFFFFF8DC),
      Tile.door => const Color(0xFFE0D4FF),
      Tile.treasure => const Color(0xFFFFE0E0),
      _ => const Color(0xFFE8E8F0),
    };
  }

  Color _border(int tile, bool isStart) {
    if (isStart) return const Color(0xFF4CAF50);
    return switch (tile) {
      Tile.wall => const Color(0xFF555555),
      Tile.key => const Color(0xFFFFD700),
      Tile.door => const Color(0xFF7C4DFF),
      Tile.treasure => const Color(0xFFFF4444),
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
