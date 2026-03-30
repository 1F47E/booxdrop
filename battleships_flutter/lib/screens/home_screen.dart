import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';
import '../controllers/ota_controller.dart';
import '../providers/battle_provider.dart';
import '../widgets/ota_menu_footer.dart';
import 'bt_connect_screen.dart';

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

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _selectOnline(BattleProvider battle) {
    battle.selectOnlineMode();
    setState(() => _showCodeSection = false);
  }

  void _selectBluetooth(BattleProvider battle) {
    battle.selectBluetoothMode();
    setState(() => _showCodeSection = false);
  }

  Future<void> _hostBtGame(BattleProvider battle) async {
    await battle.connectBtHost();
  }

  Future<void> _findBtGame(BattleProvider battle) async {
    final device = await Navigator.of(context).push<BluetoothDevice>(
      MaterialPageRoute(builder: (_) => const BtConnectScreen()),
    );
    if (device == null) return;
    if (!mounted) return;
    await battle.connectBtGuest(device);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final battle = context.watch<BattleProvider>();
    final isLobby = battle.phase == BattlePhase.lobby;
    final isBtMode = battle.connectionMode == ConnectionMode.btHost ||
        battle.connectionMode == ConnectionMode.btGuest;
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
                const SizedBox(height: 24),

                // --- Mode toggle ---
                _ModeToggle(
                  isBluetooth: isBtMode,
                  onOnline: () => _selectOnline(battle),
                  onBluetooth: () => _selectBluetooth(battle),
                ),
                const SizedBox(height: 24),

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

                // --- Mode-specific content ---
                if (isBtMode)
                  _BluetoothPanel(
                    battle: battle,
                    onHost: () => _hostBtGame(battle),
                    onFind: () => _findBtGame(battle),
                  )
                else ...[
                  // --- Online content ---
                  if (isLobby)
                    _OnlineLobbyWaiting(battle: battle)
                  else
                    _OnlineActions(
                      battle: battle,
                      showCodeSection: _showCodeSection,
                      codeController: _codeController,
                      onToggleCode: () =>
                          setState(() => _showCodeSection = !_showCodeSection),
                    ),
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

// ---------------------------------------------------------------------------
// Mode toggle widget
// ---------------------------------------------------------------------------

class _ModeToggle extends StatelessWidget {
  final bool isBluetooth;
  final VoidCallback onOnline;
  final VoidCallback onBluetooth;

  const _ModeToggle({
    required this.isBluetooth,
    required this.onOnline,
    required this.onBluetooth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1565C0), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'Online',
              icon: Icons.wifi,
              active: !isBluetooth,
              isLeft: true,
              onTap: onOnline,
            ),
          ),
          Container(width: 2, height: 52, color: const Color(0xFF1565C0)),
          Expanded(
            child: _ToggleButton(
              label: 'Bluetooth',
              icon: Icons.bluetooth,
              active: isBluetooth,
              isLeft: false,
              onTap: onBluetooth,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool isLeft;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.isLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = active ? const Color(0xFF1565C0) : Colors.white;
    final fgColor = active ? Colors.white : const Color(0xFF1565C0);

    return GestureDetector(
      onTap: active ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: isLeft ? const Radius.circular(10) : Radius.zero,
            bottomLeft: isLeft ? const Radius.circular(10) : Radius.zero,
            topRight: isLeft ? Radius.zero : const Radius.circular(10),
            bottomRight: isLeft ? Radius.zero : const Radius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bluetooth panel
// ---------------------------------------------------------------------------

class _BluetoothPanel extends StatelessWidget {
  final BattleProvider battle;
  final VoidCallback onHost;
  final VoidCallback onFind;

  const _BluetoothPanel({
    required this.battle,
    required this.onHost,
    required this.onFind,
  });

  @override
  Widget build(BuildContext context) {
    final isWaiting = battle.btWaiting;
    final isLobby = battle.phase == BattlePhase.lobby;

    // While waiting for a BT guest to connect.
    if (isWaiting) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1565C0), width: 2),
            ),
            child: const Column(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF1565C0),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Waiting for nearby player...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Make sure the other tablet has Bluetooth on and taps "Find Nearby Game".',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF444444)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: battle.leave,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                side: const BorderSide(color: Color(0xFF1565C0), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      );
    }

    // After BT host got a guest (lobby state) — also handled by home/lobby
    // phase logic in BattleRouter, so this branch is just a fallback.
    if (isLobby) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1565C0), width: 2),
        ),
        child: Column(
          children: [
            const Icon(Icons.bluetooth_connected,
                color: Color(0xFF1565C0), size: 40),
            const SizedBox(height: 10),
            Text(
              'Connected — waiting for ${battle.peerName ?? 'opponent'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // Default BT panel: two action buttons.
    return Column(
      children: [
        // Create Bluetooth Game
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            onPressed: onHost,
            icon: const Icon(Icons.bluetooth_searching, size: 28),
            label: const Text(
              'Create Bluetooth Game',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Find Nearby Game
        SizedBox(
          width: double.infinity,
          height: 64,
          child: OutlinedButton.icon(
            onPressed: onFind,
            icon: const Icon(Icons.search, size: 28),
            label: const Text(
              'Find Nearby Game',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              side: const BorderSide(color: Color(0xFF1565C0), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Online lobby waiting
// ---------------------------------------------------------------------------

class _OnlineLobbyWaiting extends StatelessWidget {
  final BattleProvider battle;
  const _OnlineLobbyWaiting({required this.battle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Online actions (Play / code section)
// ---------------------------------------------------------------------------

class _OnlineActions extends StatelessWidget {
  final BattleProvider battle;
  final bool showCodeSection;
  final TextEditingController codeController;
  final VoidCallback onToggleCode;

  const _OnlineActions({
    required this.battle,
    required this.showCodeSection,
    required this.codeController,
    required this.onToggleCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
          onTap: onToggleCode,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showCodeSection ? Icons.expand_less : Icons.expand_more,
                color: const Color(0xFF444444),
                size: 28,
              ),
              const SizedBox(width: 4),
              Text(
                showCodeSection ? 'Hide code options' : 'Use invite code',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),

        if (showCodeSection) ...[
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
                  controller: codeController,
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
                  final code = codeController.text.trim();
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
    );
  }
}

// ---------------------------------------------------------------------------
// Banner widget
// ---------------------------------------------------------------------------

class _BannerWidget extends StatelessWidget {
  final String text;
  final String type;
  const _BannerWidget({required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'info':    (Color(0xFF0066FF), Color(0xFF0044CC)),
      'success': (Color(0xFF00CC00), Color(0xFF006600)),
      'warning': (Color(0xFFFF8800), Color(0xFF884400)),
      'error':   (Color(0xFFFF0000), Color(0xFFCC0000)),
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

// ---------------------------------------------------------------------------
// Drawer
// ---------------------------------------------------------------------------

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
