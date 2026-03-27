import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ota_controller.dart';
import '../providers/game_provider.dart';
import '../widgets/ota_menu_footer.dart';
import 'history_screen.dart';

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
      backgroundColor: const Color(0xFFF0E6FF),
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
        backgroundColor: const Color(0xFFF0E6FF),
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
                  style: TextStyle(fontSize: 18, color: Color(0xFF9575CD)),
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
                          style: TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        if (game.joinCode != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Code: ${game.joinCode}',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                  // PLAY button (auto-match)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => game.autoMatch(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4DFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Play'),
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
                          color: const Color(0xFF9575CD),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showCodeSection ? 'Hide code options' : 'Use invite code',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF9575CD)),
                        ),
                      ],
                    ),
                  ),

                  if (_showCodeSection) ...[
                    const SizedBox(height: 12),

                    // Create with code
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => game.startRace(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C4DFF),
                          side: const BorderSide(color: Color(0xFF7C4DFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Create with Code', style: TextStyle(fontSize: 15)),
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
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              final code = _codeController.text.trim();
                              if (code.length == 3) game.joinRace(code);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9800),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // History button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      ),
                      icon: const Icon(Icons.history, size: 20),
                      label: const Text('Match History', style: TextStyle(fontSize: 15)),
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
}

class _BannerWidget extends StatelessWidget {
  final String text;
  final String type;
  const _BannerWidget({required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'info': (const Color(0xFFE3F2FD), const Color(0xFF1976D2)),
      'success': (const Color(0xFFE8F5E9), const Color(0xFF388E3C)),
      'warning': (const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
      'error': (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
    };
    final (bg, fg) = colors[type] ?? colors['info']!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 15),
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
