import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/maze.dart';
import '../services/game_service.dart';
import '../services/maze_storage.dart';

enum GamePhase { home, lobby, build, countdown, race, gameOver, workshop }

class GameProvider extends ChangeNotifier {
  final GameService _service = GameService();

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
  String? _peerBuildState;
  String? get peerBuildState => _peerBuildState;
  bool _isHost = false;

  // Phase
  GamePhase _phase = GamePhase.home;
  GamePhase get phase => _phase;

  // Builder
  final Maze _maze = Maze();
  Maze get maze => _maze;
  int _selectedTool = Tile.wall;
  int get selectedTool => _selectedTool;
  bool _isDone = false;
  bool get isDone => _isDone;
  String? _validationError;
  String? get validationError => _validationError;

  // Race
  List<List<int>> _raceGrid = [];
  List<List<int>> get raceGrid => _raceGrid;
  Point _playerPos = const Point(0, 0);
  Point get playerPos => _playerPos;
  bool _hasKey = false;
  bool get hasKey => _hasKey;
  int _moveCount = 0;
  int get moveCount => _moveCount;
  String? _lastEvent;
  String? get lastEvent => _lastEvent;
  String? _opponentEvent;
  String? get opponentEvent => _opponentEvent;
  bool _myTurn = false;
  bool get myTurn => _myTurn;

  // Result
  String? _winnerName;
  String? get winnerName => _winnerName;
  bool _iWon = false;
  bool get iWon => _iWon;

  // Countdown
  int _countdownValue = 0;
  int get countdownValue => _countdownValue;

  // Settings
  String _displayName = 'Player';
  String get displayName => _displayName;
  String _serverUrl = 'wss://maze.mos6581.cc/ws/maze';
  String get serverUrl => _serverUrl;
  String get serverBaseUrl => _serverUrl
      .replaceFirst('wss://', 'https://')
      .replaceFirst('ws://', 'http://')
      .replaceFirst('/ws/maze', '');
  String? _deviceId;
  String? get deviceId => _deviceId;

  // Banner
  String? _banner;
  String? get banner => _banner;
  String? _bannerType;
  String? get bannerType => _bannerType;

  GameProvider() {
    _service.onMessage = _handleMessage;
    _service.onDisconnect = _handleDisconnect;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _displayName = prefs.getString('display_name') ?? 'Player';
    _serverUrl = prefs.getString('server_url') ?? 'wss://maze.mos6581.cc/ws/maze';
    // Persistent device ID — generated once, reused forever
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null) {
      final r = Random.secure();
      final hex = List.generate(8, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
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

  void connect() {
    if (_deviceId == null) {
      _setBanner('Loading... try again', 'warning');
      return;
    }
    _service.connect(_serverUrl);
    _service.sendHello(_deviceId!, _displayName, '1.0.0');
    _connected = true;
    notifyListeners();
  }

  void _handleDisconnect() {
    _connected = false;
    _setBanner('Disconnected', 'error');
    notifyListeners();
  }

  // --- Workshop (offline builder) ---

  void enterWorkshop() {
    for (int y = 0; y < Maze.height; y++) {
      for (int x = 0; x < Maze.width; x++) {
        _maze.set(x, y, Tile.floor);
      }
    }
    _selectedTool = Tile.wall;
    _isDone = false;
    _validationError = null;
    _phase = GamePhase.workshop;
    notifyListeners();
  }

  void enterWorkshopWithMaze(SavedMaze saved) {
    final src = saved.toMaze();
    for (int y = 0; y < Maze.height; y++) {
      for (int x = 0; x < Maze.width; x++) {
        _maze.set(x, y, src.get(x, y));
      }
    }
    _selectedTool = Tile.wall;
    _isDone = false;
    _validationError = null;
    _phase = GamePhase.workshop;
    notifyListeners();
  }

  void exitWorkshop() {
    _phase = GamePhase.home;
    notifyListeners();
  }

  Future<bool> saveMaze() async {
    if (!_maze.hasRequiredTiles) return false;
    final existing = await MazeStorage.loadAll();
    final autoName = 'Maze ${existing.length + 1}';
    await MazeStorage.save(autoName, _maze.toJson());
    return true;
  }

  void loadMaze(SavedMaze saved) {
    final src = saved.toMaze();
    for (int y = 0; y < Maze.height; y++) {
      for (int x = 0; x < Maze.width; x++) {
        _maze.set(x, y, src.get(x, y));
      }
    }
    // Clear done state if in multiplayer build
    if (_isDone && _sessionId != null) {
      _isDone = false;
      _service.setDone(_sessionId!, false);
    }
    notifyListeners();
  }

  // --- Actions ---

  void autoMatch() {
    connect();
    _service.send({
      'type': 'auto_match',
      'payload': {
        'display_name': _displayName,
        'app_version': '1.0.0',
      },
    });
  }

  void startRace() {
    _isHost = true;
    connect();
    _service.createSession(_displayName, '1.0.0');
  }

  void joinRace(String code) {
    _isHost = false;
    connect();
    // Small delay to ensure hello is sent first
    Future.delayed(const Duration(milliseconds: 200), () {
      _service.joinSession(code, _displayName, '1.0.0');
    });
  }

  void selectTool(int tool) {
    _selectedTool = tool;
    notifyListeners();
  }

  void placeTile(int x, int y) {
    final tile = _selectedTool;

    // Don't erase the start tile (use start tool to move it)
    if (tile == Tile.floor && _maze.get(x, y) == Tile.start) return;

    // Enforce single special tiles (including start)
    if (tile == Tile.key || tile == Tile.door || tile == Tile.treasure || tile == Tile.start) {
      for (int r = 0; r < Maze.height; r++) {
        for (int c = 0; c < Maze.width; c++) {
          if (_maze.get(c, r) == tile) _maze.set(c, r, Tile.floor);
        }
      }
    }

    _maze.set(x, y, tile);

    // Clear done if editing
    if (_isDone) {
      _isDone = false;
      if (_sessionId != null) {
        _service.setDone(_sessionId!, false);
      }
    }

    notifyListeners();
  }

  void toggleDone() {
    if (_sessionId == null) return;

    if (!_isDone) {
      // Submit maze first
      _service.submitMaze(_sessionId!, _maze.toJson());

      // Then set done after brief delay
      Future.delayed(const Duration(milliseconds: 300), () {
        _isDone = true;
        _service.setDone(_sessionId!, true);
        notifyListeners();
      });
    } else {
      _isDone = false;
      _service.setDone(_sessionId!, false);
      notifyListeners();
    }
  }

  void move(String direction) {
    if (_phase != GamePhase.race || _sessionId == null) return;
    if (!_myTurn) return;
    _service.sendMove(_sessionId!, direction);
  }

  void rematch() {
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
    _peerBuildState = null;
    _isHost = false;
    _phase = GamePhase.home;
    _isDone = false;
    _validationError = null;
    _raceGrid = [];
    _playerPos = const Point(0, 0);
    _hasKey = false;
    _moveCount = 0;
    _lastEvent = null;
    _opponentEvent = null;
    _myTurn = false;
    _winnerName = null;
    _iWon = false;
    _banner = null;
    _bannerType = null;
    // Reset maze
    for (int y = 0; y < Maze.height; y++) {
      for (int x = 0; x < Maze.width; x++) {
        _maze.set(x, y, Tile.floor);
      }
    }
    _selectedTool = Tile.wall;
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
        _phase = GamePhase.lobby;
        final isAuto = payload['auto_match'] as bool? ?? false;
        if (isAuto) {
          _setBanner('Looking for opponent...', 'info');
        } else {
          _setBanner('Code: $_joinCode', 'info');
        }

      case 'peer_joined':
        _peerName = payload['peer_name'] as String?;
        _phase = GamePhase.build;
        _setBanner('$_peerName joined!', 'success');

      case 'lobby_state':
        _sessionId = sid;
        // Host sees guest name as peer, guest sees host name as peer
        _peerName = _isHost
            ? payload['guest_name'] as String?
            : payload['host_name'] as String?;
        _phase = GamePhase.build;

      case 'version_mismatch':
        _setBanner(payload['message'] as String? ?? 'Version mismatch', 'error');

      case 'maze_valid':
        _validationError = null;

      case 'maze_invalid':
        _validationError = payload['error'] as String?;
        _isDone = false;
        _setBanner(_validationError ?? 'Invalid maze', 'error');

      case 'peer_build_state':
        _peerBuildState = payload['state'] as String?;
        if (_peerBuildState == 'done') {
          _setBanner('$_peerName is done!', 'warning');
        }

      case 'both_done':
        _phase = GamePhase.countdown;
        _startCountdown(payload['countdown_seconds'] as int? ?? 3);

      case 'race_started':
        _phase = GamePhase.race;
        _playerPos = Point.fromJson(payload['position'] as Map<String, dynamic>);
        _hasKey = false;
        _moveCount = 0;
        _myTurn = (payload['active_turn'] as String?) == _deviceId;
        _raceGrid = List.generate(
          Maze.height,
          (_) => List.filled(Maze.width, Tile.hidden),
        );
        final revealed = payload['revealed'] as List? ?? [];
        for (final r in revealed) {
          final m = r as Map<String, dynamic>;
          _raceGrid[m['y'] as int][m['x'] as int] = m['tile'] as int;
        }
        _setBanner('GO! Find the treasure!', 'success');

      case 'turn_changed':
        _myTurn = (payload['active_device_id'] as String?) == _deviceId;

      case 'move_result':
        _playerPos = Point.fromJson(payload['position'] as Map<String, dynamic>);
        _hasKey = payload['has_key'] as bool? ?? _hasKey;
        _moveCount++;
        final revealed = payload['revealed'] as List? ?? [];
        for (final r in revealed) {
          final m = r as Map<String, dynamic>;
          _raceGrid[m['y'] as int][m['x'] as int] = m['tile'] as int;
        }
        final event = payload['event'] as String? ?? '';
        _lastEvent = event;
        if (event == 'found_key') _setBanner('Found the key!', 'warning');
        if (event == 'door_locked') _setBanner('Need key!', 'error');
        if (event == 'door_opened') _setBanner('Door opened!', 'success');

      case 'opponent_progress':
        final name = payload['player_name'] as String? ?? 'Opponent';
        final event = payload['event'] as String? ?? '';
        _opponentEvent = '$name: $event';
        if (event == 'found_key') _setBanner('$name found the key!', 'warning');
        if (event == 'door_opened') _setBanner('$name opened the door!', 'warning');

      case 'game_over':
        _phase = GamePhase.gameOver;
        _winnerName = payload['winner_name'] as String?;
        final winnerDeviceId = payload['winner_device_id'] as String?;
        _iWon = winnerDeviceId == _service.deviceId;

      case 'peer_left':
        _setBanner('$_peerName left', 'error');

      case 'error':
        _setBanner(payload['message'] as String? ?? 'Error', 'error');

      case 'pong':
        break;
    }

    notifyListeners();
  }

  void _setBanner(String text, String type) {
    _banner = text;
    _bannerType = type;
    // Auto-clear non-error banners
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

  void _startCountdown(int seconds) {
    _countdownValue = seconds;
    notifyListeners();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      _countdownValue--;
      notifyListeners();
      return _countdownValue > 0;
    });
  }

  @override
  void dispose() {
    _service.disconnect();
    super.dispose();
  }
}
