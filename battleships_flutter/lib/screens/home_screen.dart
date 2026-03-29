import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ota_controller.dart';
import '../providers/battle_provider.dart';
import '../widgets/ota_menu_footer.dart';

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
    final battle = context.read<BattleProvider>();
    _nameController.text = battle.displayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battle = context.watch<BattleProvider>();
    final isLobby = battle.phase == BattlePhase.lobby;
    final otaController = context.read<OtaController>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1565C0)),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Battleships',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF1565C0),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: _BattleDrawer(otaController: otaController),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tagline
                const Text(
                  'Place. Fire. Sink!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF444444),
                  ),
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
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF1565C0)),
                  ),
                  style: const TextStyle(fontSize: 18),
                  onChanged: (v) => battle.setDisplayName(v),
                ),
                const SizedBox(height: 24),

                // Lobby waiting state
                if (isLobby) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1565C0), width: 2),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Looking for opponent...',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF000000),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (battle.joinCode != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Code: ${battle.joinCode}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF444444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: battle.leave,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ] else ...[
                  // PLAY button — auto match
                  GestureDetector(
                    onTap: () => battle.autoMatch(),
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
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

                  // Join Code section (expandable)
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_showCodeSection) ...[
                    const SizedBox(height: 12),

                    // Create with code
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => battle.createSession(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Create with Code',
                          style: TextStyle(fontSize: 16),
                        ),
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
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
                            if (code.length >= 3) battle.joinSession(code);
                          },
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0097A7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Join',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                // Banner
                if (battle.banner != null) ...[
                  const SizedBox(height: 16),
                  _BannerWidget(
                    text: battle.banner!,
                    type: battle.bannerType ?? 'info',
                  ),
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
      'info':    (const Color(0xFF0066FF), const Color(0xFF0044CC)),
      'success': (const Color(0xFF00CC00), const Color(0xFF006600)),
      'warning': (const Color(0xFFFF8800), const Color(0xFF884400)),
      'error':   (const Color(0xFFFF0000), const Color(0xFFCC0000)),
    };
    final (borderColor, textColor) =
        colors[type] ?? colors['info']!;

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
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _BattleDrawer extends StatefulWidget {
  final OtaController otaController;
  const _BattleDrawer({required this.otaController});

  @override
  State<_BattleDrawer> createState() => _BattleDrawerState();
}

class _BattleDrawerState extends State<_BattleDrawer> {
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
                      'Battleships',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ],
              ),
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
