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
  bool _nameReady = false;
  bool _showJoinCode = false;

  @override
  void initState() {
    super.initState();
    final battle = context.read<BattleProvider>();
    _nameController.text = battle.displayName;
    // If name was previously saved, skip name entry
    if (battle.displayName.isNotEmpty && battle.displayName != 'Player') {
      _nameReady = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _confirmName(BattleProvider battle) {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    battle.setDisplayName(name);
    setState(() => _nameReady = true);
  }

  void _editName() {
    setState(() => _nameReady = false);
  }

  @override
  Widget build(BuildContext context) {
    final battle = context.watch<BattleProvider>();
    final otaController = context.read<OtaController>();
    final isLobby = battle.phase == BattlePhase.lobby;
    final hasError = battle.bannerType == 'error' && battle.banner != null;

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
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1565C0)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_nameReady)
            GestureDetector(
              onTap: _editName,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      battle.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 18, color: Color(0xFF666666)),
                  ],
                ),
              ),
            ),
        ],
      ),
      drawer: _BattleDrawer(otaController: otaController),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildContent(battle, isLobby, hasError),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BattleProvider battle, bool isLobby, bool hasError) {
    // ERROR STATE — big, clear, one action
    if (hasError) {
      return _ErrorView(
        message: battle.banner!,
        onRetry: () {
          battle.leave();
          _codeController.clear();
          setState(() => _showJoinCode = false);
        },
      );
    }

    // WAITING STATE — spinner, message, cancel
    if (isLobby || battle.btWaiting) {
      return _WaitingView(
        message: battle.btWaiting
            ? 'Waiting for nearby player...'
            : 'Looking for opponent...',
        subtitle: battle.btWaiting
            ? 'Make sure the other tablet has\nBluetooth on'
            : battle.joinCode != null
                ? 'Code: ${battle.joinCode}'
                : null,
        onCancel: battle.leave,
      );
    }

    // NAME ENTRY STATE
    if (!_nameReady) {
      return _NameEntryView(
        controller: _nameController,
        onConfirm: () => _confirmName(battle),
      );
    }

    // ACTION STATE — choose what to do
    return _ActionView(
      battle: battle,
      showJoinCode: _showJoinCode,
      codeController: _codeController,
      onToggleJoinCode: () => setState(() => _showJoinCode = !_showJoinCode),
      onPlay: () => battle.autoMatch(),
      onCreateCode: () => battle.createSession(),
      onJoinCode: (code) => battle.joinSession(code),
      onBtHost: () => battle.connectBtHost(),
      onBtFind: () async {
        final device = await Navigator.of(context).push<BluetoothDevice>(
          MaterialPageRoute(builder: (_) => const BtConnectScreen()),
        );
        if (device != null && mounted) {
          await battle.connectBtGuest(device);
        }
      },
      onSelectOnline: () => battle.selectOnlineMode(),
      onSelectBt: () => battle.selectBluetoothMode(),
    );
  }
}

// =============================================================================
// ERROR VIEW — big warning, friendly message, one button
// =============================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 64, color: Color(0xFFCC0000)),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFCC0000),
          ),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Try Again',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WAITING VIEW — spinner + message + cancel
// =============================================================================

class _WaitingView extends StatelessWidget {
  final String message;
  final String? subtitle;
  final VoidCallback onCancel;
  const _WaitingView({required this.message, this.subtitle, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 48, height: 48,
          child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF1565C0)),
        ),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Color(0xFF444444)),
          ),
        ],
        const SizedBox(height: 32),
        GestureDetector(
          onTap: onCancel,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1565C0), width: 2),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// NAME ENTRY VIEW — one field, one button
// =============================================================================

class _NameEntryView extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;
  const _NameEntryView({required this.controller, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'What\'s your name?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          onSubmitted: (_) => onConfirm(),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onConfirm,
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Start',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ACTION VIEW — mode toggle + buttons
// =============================================================================

class _ActionView extends StatelessWidget {
  final BattleProvider battle;
  final bool showJoinCode;
  final TextEditingController codeController;
  final VoidCallback onToggleJoinCode;
  final VoidCallback onPlay;
  final VoidCallback onCreateCode;
  final void Function(String) onJoinCode;
  final VoidCallback onBtHost;
  final VoidCallback onBtFind;
  final VoidCallback onSelectOnline;
  final VoidCallback onSelectBt;

  const _ActionView({
    required this.battle,
    required this.showJoinCode,
    required this.codeController,
    required this.onToggleJoinCode,
    required this.onPlay,
    required this.onCreateCode,
    required this.onJoinCode,
    required this.onBtHost,
    required this.onBtFind,
    required this.onSelectOnline,
    required this.onSelectBt,
  });

  bool get _isBt =>
      battle.connectionMode == ConnectionMode.btHost ||
      battle.connectionMode == ConnectionMode.btGuest;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Place. Fire. Sink!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF444444)),
        ),
        const SizedBox(height: 24),

        // Mode toggle
        _ModeToggle(isBluetooth: _isBt, onOnline: onSelectOnline, onBluetooth: onSelectBt),
        const SizedBox(height: 24),

        if (_isBt) ...[
          // Bluetooth buttons
          _BigButton(label: 'Create Bluetooth Game', icon: Icons.bluetooth_searching, onTap: onBtHost),
          const SizedBox(height: 16),
          _BigButton(label: 'Find Nearby Game', icon: Icons.search, onTap: onBtFind, outlined: true),
        ] else ...[
          // Online Play button
          _BigButton(label: 'Play', onTap: onPlay),
          const SizedBox(height: 16),

          // Join code toggle
          GestureDetector(
            onTap: onToggleJoinCode,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(showJoinCode ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF444444), size: 28),
                const SizedBox(width: 4),
                Text(
                  showJoinCode ? 'Hide code options' : 'Use invite code',
                  style: const TextStyle(fontSize: 18, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),

          if (showJoinCode) ...[
            const SizedBox(height: 16),
            _BigButton(label: 'Create with Code', onTap: onCreateCode, outlined: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: codeController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Code',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    final code = codeController.text.trim();
                    if (code.length >= 3) onJoinCode(code);
                  },
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Join',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ],

        // Info banner (non-error only)
        if (battle.banner != null && battle.bannerType != 'error') ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(
                color: battle.bannerType == 'success' ? const Color(0xFF00CC00) : const Color(0xFF0066FF),
                width: 4,
              )),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              battle.banner!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: battle.bannerType == 'success' ? const Color(0xFF006600) : const Color(0xFF0044CC),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

class _BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool outlined;

  const _BigButton({required this.label, this.icon, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: outlined ? Colors.white : const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(16),
          border: outlined ? Border.all(color: const Color(0xFF1565C0), width: 2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: outlined ? const Color(0xFF1565C0) : Colors.white, size: 28),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: outlined ? const Color(0xFF1565C0) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool isBluetooth;
  final VoidCallback onOnline;
  final VoidCallback onBluetooth;
  const _ModeToggle({required this.isBluetooth, required this.onOnline, required this.onBluetooth});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1565C0), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _seg('Online', Icons.wifi, !isBluetooth, true, onOnline),
          Container(width: 2, height: 60, color: const Color(0xFF1565C0)),
          _seg('Bluetooth', Icons.bluetooth, isBluetooth, false, onBluetooth),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, bool active, bool isLeft, VoidCallback onTap) {
    final bg = active ? const Color(0xFF1565C0) : Colors.white;
    final fg = active ? Colors.white : const Color(0xFF1565C0);
    return Expanded(
      child: GestureDetector(
        onTap: active ? null : onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: bg,
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
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Drawer
// =============================================================================

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
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text('Battleships',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                  ),
                ],
              ),
            ),
            const Spacer(),
            OtaMenuFooter(controller: widget.otaController),
          ],
        ),
      ),
    );
  }
}
