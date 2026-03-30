import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grid.dart';
import '../models/ship.dart';
import '../services/battle_service.dart';
import '../services/bt_permissions.dart';
import '../services/bt_transport.dart';
import '../services/game_transport.dart';
import '../services/sound_service.dart';

enum BattlePhase { home, lobby, place, battle, gameOver }

/// Which network mode the player has chosen.
enum ConnectionMode { online, btHost, btGuest }

class BattleProvider extends ChangeNotifier {
  // Active transport — either WS or BT depending on mode.
  late GameTransport _transport;

  // Kept so we can recreate the WS transport on demand.
  WsGameTransport? _wsTransport;

  // Current connection mode.
  ConnectionMode _connectionMode = ConnectionMode.online;
  ConnectionMode get connectionMode => _connectionMode;

  BattleProvider({WsGameTransport? wsTransport}) {
    _wsTransport = wsTransport ?? WsGameTransport();
    _transport = _wsTransport!;
    _attachTransportCallbacks(_transport);
    _loadSettings();
  }

  // ---------------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------------

  bool _connected = false;
  bool get connected => _connected;

  // Status shown while BT host is waiting for a guest.
  bool _btWaiting = false;
  bool get btWaiting => _btWaiting;

  // ---------------------------------------------------------------------------
  // Session state
  // ---------------------------------------------------------------------------

  String? _sessionId;
  String? get sessionId => _sessionId;
  String? _joinCode;
  String? get joinCode => _joinCode;
  String? _peerName;
  String? get peerName => _peerName;
  bool _isHost = false;
  bool get isHost => _isHost;

  // ---------------------------------------------------------------------------
  // Phase
  // ---------------------------------------------------------------------------

  BattlePhase _phase = BattlePhase.home;
  BattlePhase get phase => _phase;

  // ---------------------------------------------------------------------------
  // Turn
  // ---------------------------------------------------------------------------

  bool _myTurn = false;
  bool get myTurn => _myTurn;
  String? _activeTurnDeviceId;
  String? get activeTurnDeviceId => _activeTurnDeviceId;

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  String _displayName = 'Player';
  String get displayName => _displayName;
  String? _deviceId;
  String? get deviceId => _deviceId;

  // ---------------------------------------------------------------------------
  // Banner
  // ---------------------------------------------------------------------------

  String? _banner;
  String? get banner => _banner;
  String? _bannerType;
  String? get bannerType => _bannerType;

  // ---------------------------------------------------------------------------
  // Placement phase
  // ---------------------------------------------------------------------------

  bool _fleetValid = false;
  bool get fleetValid => _fleetValid;

  bool _ready = false;
  bool get ready => _ready;

  bool _peerReady = false;
  bool get peerReady => _peerReady;

  // ---------------------------------------------------------------------------
  // Battle phase
  // ---------------------------------------------------------------------------

  BattleGrid _opponentGrid = BattleGrid();
  BattleGrid get opponentGrid => _opponentGrid;

  BattleGrid _myGrid = BattleGrid();
  BattleGrid get myGrid => _myGrid;

  List<Ship> _myShips = [];

  int _shotsFired = 0;
  int get shotsFired => _shotsFired;

  int _hits = 0;
  int get hits => _hits;

  int _myShipsSunk = 0;
  int get myShipsSunk => _myShipsSunk;

  int _theirShipsSunk = 0;
  int get theirShipsSunk => _theirShipsSunk;

  // ---------------------------------------------------------------------------
  // Game over
  // ---------------------------------------------------------------------------

  String? _winnerDeviceId;
  String? get winnerDeviceId => _winnerDeviceId;
  String? _winnerName;
  String? get winnerName => _winnerName;

  bool get iWon => _winnerDeviceId != null && _winnerDeviceId == _deviceId;

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _displayName = prefs.getString('display_name') ?? 'Player';
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null) {
      final r = Random.secure();
      final hex = List.generate(
        8,
        (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _deviceId = 'flutter_${DateTime.now().millisecondsSinceEpoch}_$hex';
      await prefs.setString('device_id', _deviceId!);
    }
    // Restore saved connection mode preference
    final savedMode = prefs.getString('connection_mode');
    if (savedMode == 'bluetooth') {
      _connectionMode = ConnectionMode.btHost;
    }
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name.trim().isEmpty ? 'Player' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', _displayName);
    notifyListeners();
  }

  void _attachTransportCallbacks(GameTransport t) {
    t.onMessage = _handleMessage;
    t.onDisconnect = _handleDisconnect;
  }

  void _switchTransport(GameTransport t) {
    // Detach old callbacks before swapping.
    _transport.onMessage = null;
    _transport.onDisconnect = null;
    _transport = t;
    _attachTransportCallbacks(_transport);
  }

  // ---------------------------------------------------------------------------
  // Connection mode switching
  // ---------------------------------------------------------------------------

  /// Switch to Online mode (WebSocket).
  /// Safe to call when already in online mode.
  void selectOnlineMode() async {
    if (_connectionMode == ConnectionMode.online) return;
    _reset();
    _connectionMode = ConnectionMode.online;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connection_mode', 'online');
    _wsTransport ??= WsGameTransport();
    _switchTransport(_wsTransport!);
    _btWaiting = false;
    notifyListeners();
  }

  /// Switch to Bluetooth mode (no connection yet).
  void selectBluetoothMode() async {
    if (_connectionMode == ConnectionMode.btHost ||
        _connectionMode == ConnectionMode.btGuest) {
      return;
    }
    _reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connection_mode', 'bluetooth');
    _connectionMode = ConnectionMode.btHost; // will be refined on action
    _btWaiting = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Bluetooth actions
  // ---------------------------------------------------------------------------

  /// Start hosting a Bluetooth game. Requests permissions, makes device
  /// discoverable, waits for a guest to connect.
  Future<void> connectBtHost() async {
    if (_deviceId == null) {
      _setBanner('Still loading — try again', 'warning');
      notifyListeners();
      return;
    }

    final btEnabled = await BtPermissions.isBluetoothEnabled();
    if (!btEnabled) {
      _setBanner('Bluetooth is off — please enable it first', 'error');
      notifyListeners();
      return;
    }

    _reset();
    _connectionMode = ConnectionMode.btHost;
    _isHost = true;
    _btWaiting = true;
    _setBanner('Waiting for nearby player...', 'info');
    notifyListeners();

    final hostTransport = BtHostTransport(
      hostDeviceId: _deviceId!,
      hostDisplayName: _displayName,
      appVersion: '1.0.0',
    );
    _switchTransport(hostTransport);

    // connect() blocks until a guest arrives (or fails).
    await _transport.connect();

    if (!_transport.isConnected) {
      _btWaiting = false;
      // onDisconnect will already have set a banner if there was an error.
      notifyListeners();
      return;
    }

    _btWaiting = false;
    _connected = true;

    // For BT host mode: the transport's LocalBattleHost handles hello/session
    // internally.  We trigger the standard hello + create_session flow so the
    // host's own provider state reflects the session.
    _transport.send({
      'type': 'hello',
      'payload': {
        'device_id': _deviceId!,
        'display_name': _displayName,
        'platform': 'android',
        'app_version': '1.0.0',
      },
    });

    await Future.delayed(const Duration(milliseconds: 100));

    _transport.send({
      'type': 'create_session',
      'payload': {'display_name': _displayName, 'app_version': '1.0.0'},
    });

    notifyListeners();
  }

  /// Connect as a Bluetooth guest to [device].
  Future<void> connectBtGuest(BluetoothDevice device) async {
    if (_deviceId == null) {
      _setBanner('Still loading — try again', 'warning');
      notifyListeners();
      return;
    }

    _reset();
    _connectionMode = ConnectionMode.btGuest;
    _isHost = false;
    _setBanner('Connecting to ${device.name ?? device.address}...', 'info');
    notifyListeners();

    final guestTransport = BtGuestTransport()..targetDevice = device;
    _switchTransport(guestTransport);

    await _transport.connect();

    if (!_transport.isConnected) {
      // onDisconnect will set the error banner.
      notifyListeners();
      return;
    }

    _connected = true;

    // Send hello then join the fixed local session code ('001').
    _transport.send({
      'type': 'hello',
      'payload': {
        'device_id': _deviceId!,
        'display_name': _displayName,
        'platform': 'android',
        'app_version': '1.0.0',
      },
    });

    await Future.delayed(const Duration(milliseconds: 100));

    _transport.send({
      'type': 'join_session',
      'payload': {
        'join_code': '001',
        'display_name': _displayName,
        'app_version': '1.0.0',
      },
    });

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Online connection helpers
  // ---------------------------------------------------------------------------

  WsGameTransport get _ws {
    // Lazily cast the active transport to WsGameTransport for WS-only calls.
    // This is only valid when in online mode.
    return _transport as WsGameTransport;
  }

  Future<void> _connectAndHello() async {
    if (_deviceId == null) {
      _setBanner('Loading... try again', 'warning');
      return;
    }
    // Ensure we're using the WS transport.
    if (_transport is! WsGameTransport) {
      _wsTransport ??= WsGameTransport();
      _switchTransport(_wsTransport!);
    }
    await _ws.connect();
    _ws.sendHello(_deviceId!, _displayName, '1.0.0');
    _connected = true;
    notifyListeners();
  }

  void _handleDisconnect(String reason) {
    _connected = false;
    _btWaiting = false;
    // Show user-friendly message instead of raw error codes
    final friendlyMsg = reason.contains('1001') || reason.contains('401')
        ? 'Connection lost — no opponent found'
        : reason.contains('refused')
            ? 'Cannot connect to server'
            : 'Disconnected';
    _setBanner(friendlyMsg, 'error');
    _phase = BattlePhase.home; // return to home so user can retry
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Online game actions
  // ---------------------------------------------------------------------------

  Future<void> autoMatch() async {
    _connectionMode = ConnectionMode.online;
    await _connectAndHello();
    await Future.delayed(const Duration(milliseconds: 300));
    _ws.autoMatch(_displayName, '1.0.0');
  }

  Future<void> createSession() async {
    _connectionMode = ConnectionMode.online;
    _isHost = true;
    await _connectAndHello();
    await Future.delayed(const Duration(milliseconds: 300));
    _ws.createSession(_displayName, '1.0.0');
  }

  Future<void> joinSession(String code) async {
    _connectionMode = ConnectionMode.online;
    _isHost = false;
    await _connectAndHello();
    await Future.delayed(const Duration(milliseconds: 300));
    _ws.joinSession(code, _displayName, '1.0.0');
  }

  // ---------------------------------------------------------------------------
  // Shared game actions (work for both online and BT)
  // ---------------------------------------------------------------------------

  void submitFleet(List<Ship> ships) {
    if (_sessionId == null) return;
    _myShips = List.unmodifiable(ships);
    final payload = ships.map((s) => s.toJson()).toList();
    _transport.send({
      'type': 'submit_fleet',
      'session_id': _sessionId!,
      'payload': {'ships': payload},
    });
  }

  void setReady(bool value) {
    if (_sessionId == null) return;
    _ready = value;
    _transport.send({
      'type': 'set_ready',
      'session_id': _sessionId!,
      'payload': {'ready': value},
    });
    notifyListeners();
  }

  void fireShot(int x, int y) {
    if (_sessionId == null) return;
    if (!_myTurn) return;
    if (_opponentGrid.get(x, y) != CellState.empty) return;
    _transport.send({
      'type': 'fire_shot',
      'session_id': _sessionId!,
      'payload': {'x': x, 'y': y},
    });
  }

  void requestRematch() {
    if (_sessionId == null) return;
    _transport.send({'type': 'request_rematch', 'session_id': _sessionId!});
  }

  void leave() {
    if (_sessionId != null) {
      _transport.send({'type': 'leave_session', 'session_id': _sessionId!});
    }
    _transport.disconnect();
    _reset();
    notifyListeners();
  }

  void _reset() {
    _connected = false;
    _btWaiting = false;
    _sessionId = null;
    _joinCode = null;
    _peerName = null;
    _isHost = false;
    _phase = BattlePhase.home;
    _myTurn = false;
    _activeTurnDeviceId = null;
    _banner = null;
    _bannerType = null;
    _fleetValid = false;
    _ready = false;
    _peerReady = false;
    _opponentGrid = BattleGrid();
    _myGrid = BattleGrid();
    _myShips = [];
    _shotsFired = 0;
    _hits = 0;
    _myShipsSunk = 0;
    _theirShipsSunk = 0;
    _winnerDeviceId = null;
    _winnerName = null;
  }

  // ---------------------------------------------------------------------------
  // Message handling (identical to old provider — transport-agnostic)
  // ---------------------------------------------------------------------------

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String;
    final payload = msg['payload'] as Map<String, dynamic>? ?? {};
    final sid = msg['session_id'] as String?;

    switch (type) {
      case 'session_created':
        _sessionId = sid;
        _joinCode = payload['join_code'] as String?;
        _isHost = true;
        _phase = BattlePhase.lobby;
        final isAuto = payload['auto_match'] as bool? ?? false;
        if (isAuto) {
          _setBanner('Looking for opponent...', 'info');
        } else if (_connectionMode == ConnectionMode.btHost) {
          _setBanner('Waiting for nearby player...', 'info');
        } else {
          _setBanner('Code: $_joinCode', 'info');
        }

      case 'peer_joined':
        _peerName = payload['peer_name'] as String?;
        _phase = BattlePhase.place;
        _setBanner('${_peerName ?? 'Opponent'} joined! Place your ships.', 'success');

      case 'lobby_state':
        _sessionId = sid;
        _peerName = _isHost
            ? payload['guest_name'] as String?
            : payload['host_name'] as String?;
        final isRematch = payload['rematch'] as bool? ?? false;
        if (isRematch) {
          _opponentGrid = BattleGrid();
          _myGrid = BattleGrid();
          _myShips = [];
          _shotsFired = 0;
          _hits = 0;
          _myShipsSunk = 0;
          _theirShipsSunk = 0;
          _winnerDeviceId = null;
          _winnerName = null;
          _fleetValid = false;
          _ready = false;
          _peerReady = false;
          _myTurn = false;
          _activeTurnDeviceId = null;
          _setBanner('Rematch! Place your ships.', 'success');
        }
        _phase = BattlePhase.place;

      case 'fleet_valid':
        _fleetValid = true;
        _setBanner('Fleet accepted!', 'success');

      case 'fleet_invalid':
        _fleetValid = false;
        final errMsg = payload['error'] as String? ?? 'Invalid fleet';
        _setBanner(errMsg, 'error');

      case 'peer_fleet_placed':
        _setBanner('Opponent has placed their fleet.', 'info');

      case 'peer_ready_state':
        final peerIsReady = payload['ready'] as bool? ?? false;
        _peerReady = peerIsReady;
        if (peerIsReady) {
          _setBanner('Opponent is ready!', 'info');
        }

      case 'both_ready':
        _setBanner('Both players ready — starting battle!', 'success');

      case 'battle_started':
        final activeTurn = payload['active_turn'] as String?;
        _activeTurnDeviceId = activeTurn;
        _myTurn = activeTurn == _deviceId;
        _opponentGrid = BattleGrid();
        _myGrid = BattleGrid();
        for (final ship in _myShips) {
          for (final pt in ship.cells) {
            _myGrid.set(pt.x, pt.y, CellState.ship);
          }
        }
        _shotsFired = 0;
        _hits = 0;
        _myShipsSunk = 0;
        _theirShipsSunk = 0;
        _winnerDeviceId = null;
        _winnerName = null;
        _phase = BattlePhase.battle;

      case 'shot_result':
        _handleShotResult(payload);

      case 'opponent_shot':
        _handleOpponentShot(payload);

      case 'turn_changed':
        final activeDevice = payload['active_device_id'] as String?;
        _activeTurnDeviceId = activeDevice;
        _myTurn = activeDevice == _deviceId;

      case 'game_over':
        _winnerDeviceId = payload['winner_device_id'] as String?;
        _winnerName = payload['winner_name'] as String?;
        _myTurn = false;
        _phase = BattlePhase.gameOver;
        if (iWon) {
          SoundService.playWin();
        }

      case 'version_mismatch':
        _setBanner(payload['message'] as String? ?? 'Version mismatch', 'error');

      case 'peer_left':
        _setBanner('${_peerName ?? 'Opponent'} left', 'error');

      case 'error':
        final raw = payload['message'] as String? ?? '';
        // Map technical server errors to kid-friendly messages
        final friendly = raw.contains('hello') ? 'Connection issue — try again'
            : raw.contains('not found') ? 'Game not found'
            : raw.contains('full') ? 'Game is full'
            : raw.contains('not your turn') ? 'Wait for your turn'
            : raw.isEmpty ? 'Something went wrong'
            : raw;
        _setBanner(friendly, 'error');

      case 'pong':
        break;
    }

    notifyListeners();
  }

  void _handleShotResult(Map<String, dynamic> payload) {
    final x = payload['x'] as int? ?? 0;
    final y = payload['y'] as int? ?? 0;
    final result = payload['result'] as String? ?? 'miss';
    final sunkCellsRaw = payload['sunk_cells'] as List<dynamic>? ?? [];

    _shotsFired++;

    if (result == 'miss') {
      _opponentGrid.set(x, y, CellState.miss);
      SoundService.playSplash();
    } else if (result == 'hit') {
      _opponentGrid.set(x, y, CellState.hit);
      _hits++;
      SoundService.playHit();
    } else if (result == 'sunk') {
      for (final cellRaw in sunkCellsRaw) {
        final cell = cellRaw as Map<String, dynamic>;
        final cx = cell['x'] as int? ?? 0;
        final cy = cell['y'] as int? ?? 0;
        _opponentGrid.set(cx, cy, CellState.sunk);
      }
      _hits++;
      _theirShipsSunk++;
      SoundService.playSunk();
    }
  }

  void _handleOpponentShot(Map<String, dynamic> payload) {
    final x = payload['x'] as int? ?? 0;
    final y = payload['y'] as int? ?? 0;
    final result = payload['result'] as String? ?? 'miss';
    final sunkCellsRaw = payload['sunk_cells'] as List<dynamic>? ?? [];

    if (result == 'miss') {
      _myGrid.set(x, y, CellState.miss);
      SoundService.playSplash();
    } else if (result == 'hit') {
      _myGrid.set(x, y, CellState.hit);
      SoundService.playHit();
    } else if (result == 'sunk') {
      for (final cellRaw in sunkCellsRaw) {
        final cell = cellRaw as Map<String, dynamic>;
        final cx = cell['x'] as int? ?? 0;
        final cy = cell['y'] as int? ?? 0;
        _myGrid.set(cx, cy, CellState.sunk);
      }
      _myShipsSunk++;
      SoundService.playSunk();
    }
  }

  void _setBanner(String text, String type) {
    _banner = text;
    _bannerType = type;
    if (type != 'error') {
      Future.delayed(const Duration(seconds: 4), () {
        if (_banner == text) {
          _banner = null;
          _bannerType = null;
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _transport.disconnect();
    super.dispose();
  }
}
