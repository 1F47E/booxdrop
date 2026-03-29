import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grid.dart';
import '../models/ship.dart';
import '../services/battle_service.dart';
import '../services/sound_service.dart';

enum BattlePhase { home, lobby, place, battle, gameOver }

class BattleProvider extends ChangeNotifier {
  final BattleService _service = BattleService();

  // Connection
  bool _connected = false;
  bool get connected => _connected;

  // Session
  String? _sessionId;
  String? get sessionId => _sessionId;
  String? _joinCode;
  String? get joinCode => _joinCode;
  String? _peerName;
  String? get peerName => _peerName;
  bool _isHost = false;
  bool get isHost => _isHost;

  // Phase
  BattlePhase _phase = BattlePhase.home;
  BattlePhase get phase => _phase;

  // Turn
  bool _myTurn = false;
  bool get myTurn => _myTurn;
  String? _activeTurnDeviceId;
  String? get activeTurnDeviceId => _activeTurnDeviceId;

  // Settings
  String _displayName = 'Player';
  String get displayName => _displayName;
  String? _deviceId;
  String? get deviceId => _deviceId;

  // Banner
  String? _banner;
  String? get banner => _banner;
  String? _bannerType;
  String? get bannerType => _bannerType;

  // --- Placement phase state ---

  /// Whether the server has confirmed the fleet is valid.
  bool _fleetValid = false;
  bool get fleetValid => _fleetValid;

  /// Whether this player has pressed Ready.
  bool _ready = false;
  bool get ready => _ready;

  /// Whether the peer has pressed Ready.
  bool _peerReady = false;
  bool get peerReady => _peerReady;

  // --- Battle phase state ---

  /// The opponent's grid as seen by this player (shots fired, hits/misses).
  BattleGrid _opponentGrid = BattleGrid();
  BattleGrid get opponentGrid => _opponentGrid;

  /// This player's own grid (ships + opponent's shots on them).
  BattleGrid _myGrid = BattleGrid();
  BattleGrid get myGrid => _myGrid;

  /// Placed ships (kept for initialising myGrid at battle start).
  List<Ship> _myShips = [];

  // Battle stats
  int _shotsFired = 0;
  int get shotsFired => _shotsFired;

  int _hits = 0;
  int get hits => _hits;

  int _myShipsSunk = 0;
  int get myShipsSunk => _myShipsSunk;

  int _theirShipsSunk = 0;
  int get theirShipsSunk => _theirShipsSunk;

  // Game over
  String? _winnerDeviceId;
  String? get winnerDeviceId => _winnerDeviceId;
  String? _winnerName;
  String? get winnerName => _winnerName;

  bool get iWon => _winnerDeviceId != null && _winnerDeviceId == _deviceId;

  BattleProvider() {
    _service.onMessage = _handleMessage;
    _service.onDisconnect = _handleDisconnect;
    _loadSettings();
  }

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
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name.trim().isEmpty ? 'Player' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', _displayName);
    notifyListeners();
  }

  // --- Connection ---

  void _connectAndHello() {
    if (_deviceId == null) {
      _setBanner('Loading... try again', 'warning');
      return;
    }
    _service.connect();
    _service.sendHello(_deviceId!, _displayName, '1.0.0');
    _connected = true;
    notifyListeners();
  }

  void _handleDisconnect() {
    _connected = false;
    _setBanner('Disconnected', 'error');
    notifyListeners();
  }

  // --- Actions ---

  void autoMatch() {
    _connectAndHello();
    Future.delayed(const Duration(milliseconds: 200), () {
      _service.autoMatch(_displayName, '1.0.0');
    });
  }

  void createSession() {
    _isHost = true;
    _connectAndHello();
    Future.delayed(const Duration(milliseconds: 200), () {
      _service.createSession(_displayName, '1.0.0');
    });
  }

  void joinSession(String code) {
    _isHost = false;
    _connectAndHello();
    Future.delayed(const Duration(milliseconds: 200), () {
      _service.joinSession(code, _displayName, '1.0.0');
    });
  }

  /// Sends the fleet to the server for validation, and caches ships for grid init.
  void submitFleet(List<Ship> ships) {
    if (_sessionId == null) return;
    _myShips = List.unmodifiable(ships);
    final payload = ships.map((s) => s.toJson()).toList();
    _service.submitFleet(_sessionId!, payload);
  }

  /// Sends set_ready to the server.
  void setReady(bool value) {
    if (_sessionId == null) return;
    _ready = value;
    _service.setReady(_sessionId!, value);
    notifyListeners();
  }

  /// Fires a shot at the opponent's grid.
  void fireShot(int x, int y) {
    if (_sessionId == null) return;
    if (!_myTurn) return;
    if (_opponentGrid.get(x, y) != CellState.empty) return;
    _service.fireShot(_sessionId!, x, y);
  }

  /// Requests a rematch — server resets to placement phase.
  void requestRematch() {
    if (_sessionId == null) return;
    _service.requestRematch(_sessionId!);
  }

  void leave() {
    if (_sessionId != null) {
      _service.leaveSession(_sessionId!);
    }
    _service.disconnect();
    _reset();
    notifyListeners();
  }

  void _reset() {
    _connected = false;
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

  // --- Message Handling ---

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
          // Reset battle state for rematch, go back to placement
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

      // --- Fleet / ready messages ---

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
        // Initialise grids from placed ships
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

      // --- Battle messages ---

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

      // --- Other messages ---

      case 'version_mismatch':
        _setBanner(payload['message'] as String? ?? 'Version mismatch', 'error');

      case 'peer_left':
        _setBanner('${_peerName ?? 'Opponent'} left', 'error');

      case 'error':
        _setBanner(payload['message'] as String? ?? 'Error', 'error');

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
      // Mark all sunk cells on opponent grid
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
    _service.disconnect();
    super.dispose();
  }
}
