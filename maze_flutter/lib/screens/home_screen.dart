import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ota_controller.dart';
import '../models/maze.dart';
import '../providers/game_provider.dart';
import '../widgets/ota_menu_footer.dart';
import 'history_screen.dart';
import 'maze_gallery_screen.dart';
import '../services/maze_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _showCodeSection = false;

  @override
  void initState() {
    super.initState();
    final game = context.read<GameProvider>();
    _nameController.text = game.displayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final isLobby = game.phase == GamePhase.lobby;

    final otaController = context.read<OtaController>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF7C4DFF)),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Maze Race',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7C4DFF),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: _MazeDrawer(otaController: otaController),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tagline
                const Text(
                  'Build. Swap. Race!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF444444)),
                ),
                const SizedBox(height: 32),

                // Name field
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF7C4DFF)),
                  ),
                  style: const TextStyle(fontSize: 18),
                  onChanged: (v) => game.setDisplayName(v),
                ),
                const SizedBox(height: 24),

                // Lobby: waiting state
                if (isLobby) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 32, height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF7C4DFF)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Looking for opponent...',
                          style: TextStyle(fontSize: 18, color: Color(0xFF000000), fontWeight: FontWeight.bold),
                        ),
                        if (game.joinCode != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Code: ${game.joinCode}',
                            style: const TextStyle(fontSize: 18, color: Color(0xFF444444), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: game.leave,
                    child: const Text('Cancel'),
                  ),
                ] else ...[
                  // PLAY button — pick maze then match
                  GestureDetector(
                    onTap: () => _showMazePicker(context, game),
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Play',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Use Code (expandable)
                  GestureDetector(
                    onTap: () => setState(() => _showCodeSection = !_showCodeSection),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showCodeSection ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF444444),
                          size: 28,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showCodeSection ? 'Hide code options' : 'Use invite code',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),

                  if (_showCodeSection) ...[
                    const SizedBox(height: 12),

                    // Create with code
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => game.startRace(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C4DFF),
                          side: const BorderSide(color: Color(0xFF7C4DFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Create with Code', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Join with code
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: 'Code',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final code = _codeController.text.trim();
                            if (code.length == 3) game.joinRace(code);
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Text('Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Build Maze button
                  GestureDetector(
                    onTap: () => game.enterWorkshop(),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Build Maze',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // History button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      ),
                      icon: const Icon(Icons.history, size: 20),
                      label: const Text('Match History', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7C4DFF),
                        side: const BorderSide(color: Color(0xFF7C4DFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],

                // Banner
                if (game.banner != null) ...[
                  const SizedBox(height: 16),
                  _BannerWidget(text: game.banner!, type: game.bannerType ?? 'info'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMazePicker(BuildContext ctx, GameProvider game) async {
    final mazes = await MazeStorage.loadAll();
    if (!mounted) return;

    if (mazes.isEmpty) {
      game.autoMatch();
      return;
    }

    showModalBottomSheet(
      // ignore: use_build_context_synchronously
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick Your Maze',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Choose a maze to play with, or build a new one',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 12),

            // Build New option
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                game.autoMatch();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCCCCCC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, color: Color(0xFF7C4DFF), size: 28),
                    SizedBox(width: 12),
                    Text('Build New Maze',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Saved mazes
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: mazes.length,
                itemBuilder: (_, index) {
                  final m = mazes[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      game.loadMaze(m);
                      game.autoMatch();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
                      ),
                      child: Row(
                        children: [
                          // Mini maze preview
                          SizedBox(
                            width: 48, height: 48,
                            child: _MiniMazePreview(cells: m.cells),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(
                                  '${m.createdAt.day}/${m.createdAt.month}/${m.createdAt.year}',
                                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.play_arrow, color: Color(0xFF7C4DFF), size: 28),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMazePreview extends StatelessWidget {
  final List<List<int>> cells;
  const _MiniMazePreview({required this.cells});

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return const SizedBox();
    final h = cells.length;
    final w = cells[0].length;
    return CustomPaint(
      painter: _MazePainter(cells, h, w),
      size: const Size(48, 48),
    );
  }
}

class _MazePainter extends CustomPainter {
  final List<List<int>> cells;
  final int h, w;
  _MazePainter(this.cells, this.h, this.w);

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / w;
    final cellH = size.height / h;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final tile = cells[y][x];
        final rect = Rect.fromLTWH(x * cellW, (h - 1 - y) * cellH, cellW, cellH);
        final paint = Paint()..color = _color(tile);
        canvas.drawRect(rect, paint);
      }
    }
  }

  Color _color(int tile) {
    return switch (tile) {
      Tile.start => const Color(0xFF00CC00),
      1 => const Color(0xFF222222),  // wall
      2 => const Color(0xFFFFDD00),  // key
      3 => const Color(0xFF7700CC),  // door
      4 => const Color(0xFFFF0000),  // treasure
      _ => const Color(0xFFF5F5F5),  // floor
    };
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BannerWidget extends StatelessWidget {
  final String text;
  final String type;
  const _BannerWidget({required this.text, required this.type});

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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _MazeDrawer extends StatefulWidget {
  final OtaController otaController;
  const _MazeDrawer({required this.otaController});

  @override
  State<_MazeDrawer> createState() => _MazeDrawerState();
}

class _MazeDrawerState extends State<_MazeDrawer> {
  @override
  void initState() {
    super.initState();
    widget.otaController.onMenuOpened();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Maze Race',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C4DFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            ListTile(
              leading: const Icon(Icons.grid_view, color: Color(0xFFFF9800)),
              title: const Text('My Mazes',
                  style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MazeGalleryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF7C4DFF)),
              title: const Text('Match History',
                  style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),

            const Spacer(),

            // OTA update footer
            OtaMenuFooter(controller: widget.otaController),
          ],
        ),
      ),
    );
  }
}
