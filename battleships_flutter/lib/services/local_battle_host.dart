// lib/services/local_battle_host.dart
//
// Local Battleships host engine — a Dart port of the Go server logic.
// Processes game messages and returns response envelopes that match
// exactly what BattleProvider._handleMessage already consumes.
//
// No network I/O — everything is pure function calls.

// ---------------------------------------------------------------------------
// Public response type
// ---------------------------------------------------------------------------

/// A response message tagged with its routing target.
class HostResponse {
  /// Who should receive this message: 'host', 'guest', or 'both'.
  final String target;

  /// The complete message envelope (type, session_id, payload).
  final Map<String, dynamic> message;

  const HostResponse(this.target, this.message);
}

// ---------------------------------------------------------------------------
// Internal types mirroring Go battleships package
// ---------------------------------------------------------------------------

/// Cell state constants — mirrors Go CellEmpty/Ship/Hit/Miss/Sunk.
class _Cell {
  static const int empty = 0;
  static const int ship = 1;
  static const int hit = 2;
  static const int miss = 3;
  static const int sunk = 4;
}

/// Result of a single FireShot call.
class _ShotOutcome {
  final String result; // 'hit', 'miss', 'sunk'
  final String shipTypeName; // non-empty when sunk
  final List<Map<String, int>> sunkCells; // non-empty when sunk
  final bool gameOver;

  const _ShotOutcome({
    required this.result,
    this.shipTypeName = '',
    this.sunkCells = const [],
    required this.gameOver,
  });
}

/// Placed ship record: type name, expected size, occupied cells.
class _PlacedShip {
  final String typeName;
  final int size;
  final List<Map<String, int>> cells; // [{'x':0,'y':0}, ...]

  const _PlacedShip({
    required this.typeName,
    required this.size,
    required this.cells,
  });
}

/// 8×8 battle grid — mirrors Go Grid.
class _BattleGrid {
  static const int gridSize = 8;

  final List<List<int>> cells;
  final List<_PlacedShip> ships;
  final Set<int> sunkShipIndices;

  _BattleGrid()
      : cells = List.generate(gridSize, (_) => List.filled(gridSize, _Cell.empty)),
        ships = [],
        sunkShipIndices = {};

  /// Place a ship onto this grid. Returns an error string or null on success.
  String? placeShip(_PlacedShip ship) {
    for (final pt in ship.cells) {
      final x = pt['x']!;
      final y = pt['y']!;
      if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) {
        return 'cell ($x,$y) out of bounds';
      }
      if (cells[y][x] != _Cell.empty) {
        return 'cell ($x,$y) already occupied';
      }
    }
    for (final pt in ship.cells) {
      cells[pt['y']!][pt['x']!] = _Cell.ship;
    }
    ships.add(ship);
    return null;
  }

  /// Fire a shot at (x, y). Mirrors Go Grid.FireShot.
  _ShotOutcome fireShot(int x, int y) {
    if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) {
      return const _ShotOutcome(result: 'miss', gameOver: false);
    }

    final cell = cells[y][x];

    if (cell == _Cell.empty) {
      cells[y][x] = _Cell.miss;
      return const _ShotOutcome(result: 'miss', gameOver: false);
    }

    if (cell == _Cell.hit || cell == _Cell.miss || cell == _Cell.sunk) {
      // Already fired here — treat as miss.
      return const _ShotOutcome(result: 'miss', gameOver: false);
    }

    // Ship cell hit.
    cells[y][x] = _Cell.hit;

    // Check if the ship this cell belongs to is now fully sunk.
    for (var i = 0; i < ships.length; i++) {
      if (sunkShipIndices.contains(i)) continue;
      final ship = ships[i];
      if (!_shipContainsPoint(ship.cells, x, y)) continue;

      // This ship was hit — check if all cells are hit.
      if (_allCellsHit(ship.cells)) {
        sunkShipIndices.add(i);
        for (final pt in ship.cells) {
          cells[pt['y']!][pt['x']!] = _Cell.sunk;
        }
        final gameOver = allShipsSunk();
        return _ShotOutcome(
          result: 'sunk',
          shipTypeName: ship.typeName,
          sunkCells: ship.cells,
          gameOver: gameOver,
        );
      }
      return const _ShotOutcome(result: 'hit', gameOver: false);
    }

    // Hit something with no ship record (shouldn't happen in valid play).
    return const _ShotOutcome(result: 'hit', gameOver: false);
  }

  bool allShipsSunk() {
    if (ships.isEmpty) return false;
    return sunkShipIndices.length == ships.length;
  }

  bool _allCellsHit(List<Map<String, int>> pts) {
    for (final pt in pts) {
      final c = cells[pt['y']!][pt['x']!];
      if (c != _Cell.hit && c != _Cell.sunk) return false;
    }
    return true;
  }

  static bool _shipContainsPoint(List<Map<String, int>> cells, int x, int y) {
    return cells.any((pt) => pt['x'] == x && pt['y'] == y);
  }
}

/// Per-player battle state — mirrors Go BattleState.
class _PlayerBattleState {
  final _BattleGrid myGrid; // ships + where opponent fired
  final _BattleGrid targetGrid; // shooter's view of opponent grid
  int shotsFired = 0;
  int hits = 0;
  int shipsSunk = 0;
  int shipsRemaining;

  _PlayerBattleState({required List<_PlacedShip> fleet})
      : myGrid = _BattleGrid(),
        targetGrid = _BattleGrid(),
        shipsRemaining = fleet.length {
    for (final ship in fleet) {
      myGrid.placeShip(ship); // already validated; ignore error
    }
  }
}

// ---------------------------------------------------------------------------
// Fleet validation — mirrors Go ValidateFleet
// ---------------------------------------------------------------------------

const _gridSize = 8;

const _requiredFleet = <String, int>{
  'Carrier': 4,
  'Battleship': 3,
  'Cruiser': 2,
  'Sub': 2,
};

/// Validates a full fleet of ships.
/// Returns null on success, an error string on failure.
String? _validateFleet(List<_PlacedShip> ships) {
  if (ships.length != 4) {
    return 'fleet must contain exactly 4 ships, got ${ships.length}';
  }

  // Validate each ship individually.
  for (var i = 0; i < ships.length; i++) {
    final err = _validateShipPlacement(ships[i]);
    if (err != null) return 'ship $i (${ships[i].typeName}): $err';
  }

  // Check fleet composition.
  final compErr = _validateFleetComposition(ships);
  if (compErr != null) return compErr;

  // Check no overlap.
  final overlapErr = _validateNoOverlap(ships);
  if (overlapErr != null) return overlapErr;

  // Check no diagonal adjacency.
  final adjErr = _validateNoAdjacentShips(ships);
  if (adjErr != null) return adjErr;

  return null;
}

String? _validateShipPlacement(_PlacedShip ship) {
  if (ship.cells.length != ship.size) {
    return 'expected ${ship.size} cells, got ${ship.cells.length}';
  }

  for (final pt in ship.cells) {
    final x = pt['x']!;
    final y = pt['y']!;
    if (x < 0 || x >= _gridSize || y < 0 || y >= _gridSize) {
      return 'cell ($x,$y) out of bounds';
    }
  }

  if (ship.cells.length == 1) return null;

  final firstX = ship.cells[0]['x']!;
  final firstY = ship.cells[0]['y']!;
  var allSameX = true;
  var allSameY = true;
  for (final pt in ship.cells) {
    if (pt['x'] != firstX) allSameX = false;
    if (pt['y'] != firstY) allSameY = false;
  }

  if (!allSameX && !allSameY) {
    return 'ship cells are not aligned horizontally or vertically';
  }

  if (allSameX) {
    final ys = ship.cells.map((pt) => pt['y']!).toList();
    final err = _checkConsecutive(ys);
    if (err != null) return 'vertical ship not contiguous: $err';
  } else {
    final xs = ship.cells.map((pt) => pt['x']!).toList();
    final err = _checkConsecutive(xs);
    if (err != null) return 'horizontal ship not contiguous: $err';
  }

  return null;
}

String? _checkConsecutive(List<int> vals) {
  var min = vals[0];
  var max = vals[0];
  final seen = <int>{};
  for (final v in vals) {
    if (v < min) min = v;
    if (v > max) max = v;
    if (!seen.add(v)) return 'duplicate coordinate $v';
  }
  if (max - min != vals.length - 1) {
    return 'coordinates are not consecutive ($min..$max for ${vals.length} cells)';
  }
  return null;
}

String? _validateFleetComposition(List<_PlacedShip> ships) {
  final count = <String, int>{};
  for (final ship in ships) {
    final expectedSize = _requiredFleet[ship.typeName];
    if (expectedSize == null) return 'unknown ship type: "${ship.typeName}"';
    if (ship.size != expectedSize) {
      return 'ship "${ship.typeName}" has wrong size ${ship.size} (expected $expectedSize)';
    }
    count[ship.typeName] = (count[ship.typeName] ?? 0) + 1;
  }
  for (final name in _requiredFleet.keys) {
    if ((count[name] ?? 0) != 1) {
      return 'fleet must have exactly 1 $name, got ${count[name] ?? 0}';
    }
  }
  return null;
}

String? _validateNoOverlap(List<_PlacedShip> ships) {
  final occupied = <String, String>{}; // 'x,y' -> shipName
  for (final ship in ships) {
    for (final pt in ship.cells) {
      final key = '${pt['x']},${pt['y']}';
      if (occupied.containsKey(key)) {
        return 'ships "${occupied[key]}" and "${ship.typeName}" overlap at (${pt['x']},${pt['y']})';
      }
      occupied[key] = ship.typeName;
    }
  }
  return null;
}

String? _validateNoAdjacentShips(List<_PlacedShip> ships) {
  // Map 'x,y' -> ship index.
  final cellToShip = <String, int>{};
  for (var i = 0; i < ships.length; i++) {
    for (final pt in ships[i].cells) {
      cellToShip['${pt['x']},${pt['y']}'] = i;
    }
  }

  const directions = [
    [-1, -1], [0, -1], [1, -1],
    [-1,  0],          [1,  0],
    [-1,  1], [0,  1], [1,  1],
  ];

  for (var i = 0; i < ships.length; i++) {
    for (final pt in ships[i].cells) {
      final x = pt['x']!;
      final y = pt['y']!;
      for (final d in directions) {
        final key = '${x + d[0]},${y + d[1]}';
        final j = cellToShip[key];
        if (j != null && j != i) {
          return 'ships "${ships[i].typeName}" and "${ships[j].typeName}" are adjacent at ($x,$y)';
        }
      }
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Device info (from hello messages)
// ---------------------------------------------------------------------------

class _DeviceInfo {
  final String name;
  final String version;
  const _DeviceInfo({required this.name, required this.version});
}

// ---------------------------------------------------------------------------
// Phase enum
// ---------------------------------------------------------------------------

enum _Phase { none, lobby, place, ready, battle, gameOver }

// ---------------------------------------------------------------------------
// LocalBattleHost
// ---------------------------------------------------------------------------

/// Local Battleships host engine.
///
/// Manages a single game session in memory. The caller (BtHostTransport)
/// routes incoming messages here and delivers the returned [HostResponse]
/// list to the correct peers.
class LocalBattleHost {
  static const String sessionId = 'local_session';
  // Keep an alias for internal use so usages inside this class stay clean.
  static const String _sessionId = sessionId;

  _Phase _phase = _Phase.none;

  // Pending device info from hello messages, keyed by deviceId.
  final Map<String, _DeviceInfo> _pendingInfo = {};

  // Player info
  String? _hostDeviceId;
  String? _hostDisplayName;
  String? _hostAppVersion;

  String? _guestDeviceId;
  String? _guestDisplayName;
  String? _guestAppVersion;

  // Fleets (raw validated placements)
  List<_PlacedShip>? _hostFleet;
  List<_PlacedShip>? _guestFleet;

  // Ready flags
  bool _hostReady = false;
  bool _guestReady = false;

  // Battle state
  _PlayerBattleState? _hostBattleState;
  _PlayerBattleState? _guestBattleState;

  String? _activeTurn; // deviceId
  String? _winner; // deviceId

  // Join code (fixed for local sessions)
  final String _joinCode = '001';

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Process an incoming message from [fromDeviceId].
  /// Returns a list of [HostResponse] to deliver to host/guest/both.
  List<HostResponse> processMessage(
    String fromDeviceId,
    Map<String, dynamic> msg,
  ) {
    final type = msg['type'] as String? ?? '';
    final payload = msg['payload'] as Map<String, dynamic>? ?? {};
    final sid = msg['session_id'] as String?;

    switch (type) {
      case 'hello':
        return _handleHello(fromDeviceId, payload);
      case 'auto_match':
        return _handleCreateOrAutoMatch(fromDeviceId, payload, auto: true);
      case 'create_session':
        return _handleCreateOrAutoMatch(fromDeviceId, payload, auto: false);
      case 'join_session':
        return _handleJoinSession(fromDeviceId, payload);
      case 'submit_fleet':
        return _handleSubmitFleet(fromDeviceId, sid, payload);
      case 'set_ready':
        return _handleSetReady(fromDeviceId, sid, payload);
      case 'fire_shot':
        return _handleFireShot(fromDeviceId, sid, payload);
      case 'request_rematch':
        return _handleRematch(fromDeviceId, sid);
      case 'leave_session':
        return _handleLeave(fromDeviceId, sid);
      case 'ping':
        return [_toSender(fromDeviceId, {'type': 'pong'})];
      default:
        return [_toSender(fromDeviceId, _errorMsg('', 'unknown message type: $type'))];
    }
  }

  // -------------------------------------------------------------------------
  // Handlers
  // -------------------------------------------------------------------------

  List<HostResponse> _handleHello(String deviceId, Map<String, dynamic> p) {
    // Store device info for lookup by later messages (create_session,
    // join_session, auto_match).  Do NOT pre-assign host/guest slots here —
    // that happens when the player actually creates or joins a session.
    final name = p['display_name'] as String? ?? '';
    final version = p['app_version'] as String? ?? '';

    _pendingInfo[deviceId] = _DeviceInfo(name: name, version: version);

    // If this device is already registered as host or guest, update their info.
    if (deviceId == _hostDeviceId) {
      _hostDisplayName = name;
      _hostAppVersion = version;
    } else if (deviceId == _guestDeviceId) {
      _guestDisplayName = name;
      _guestAppVersion = version;
    }

    return [];
  }

  List<HostResponse> _handleCreateOrAutoMatch(
    String deviceId,
    Map<String, dynamic> p, {
    required bool auto,
  }) {
    // Prefer explicit payload fields; fall back to pending hello info.
    final pending = _pendingInfo[deviceId];
    final name = (p['display_name'] as String?)?.isNotEmpty == true
        ? p['display_name'] as String
        : (pending?.name ?? _hostDisplayName ?? '');
    final version = (p['app_version'] as String?)?.isNotEmpty == true
        ? p['app_version'] as String
        : (pending?.version ?? _hostAppVersion ?? '');

    _hostDeviceId = deviceId;
    _hostDisplayName = name;
    _hostAppVersion = version;
    _phase = _Phase.lobby;

    final sessionMsg = <String, dynamic>{
      'type': 'session_created',
      'session_id': _sessionId,
      'payload': {
        'join_code': _joinCode,
        if (auto) 'auto_match': true,
      },
    };

    return [HostResponse('host', sessionMsg)];
  }

  List<HostResponse> _handleJoinSession(
    String deviceId,
    Map<String, dynamic> p,
  ) {
    if (_phase != _Phase.lobby) {
      return [_toSender(deviceId, _errorMsg('', 'no open session to join'))];
    }

    final code = p['join_code'] as String? ?? '';
    if (code != _joinCode) {
      return [_toSender(deviceId, _errorMsg('', 'invalid join code'))];
    }

    if (_guestDeviceId != null) {
      return [_toSender(deviceId, _errorMsg('', 'session is full'))];
    }

    final pending = _pendingInfo[deviceId];
    final name = (p['display_name'] as String?)?.isNotEmpty == true
        ? p['display_name'] as String
        : (pending?.name ?? _guestDisplayName ?? '');
    final version = (p['app_version'] as String?)?.isNotEmpty == true
        ? p['app_version'] as String
        : (pending?.version ?? _guestAppVersion ?? '');

    _guestDeviceId = deviceId;
    _guestDisplayName = name;
    _guestAppVersion = version;

    _phase = _Phase.place;

    final lobbyPayload = {
      'host_name': _hostDisplayName ?? '',
      'guest_name': _guestDisplayName ?? '',
      'host_app_version': _hostAppVersion ?? '',
      'guest_app_version': _guestAppVersion ?? '',
      'versions_match': (_hostAppVersion ?? '') == (_guestAppVersion ?? ''),
    };

    final lobbyMsg = <String, dynamic>{
      'type': 'lobby_state',
      'session_id': _sessionId,
      'payload': lobbyPayload,
    };

    final hostPeerJoined = <String, dynamic>{
      'type': 'peer_joined',
      'session_id': _sessionId,
      'payload': {'peer_name': _guestDisplayName ?? ''},
    };

    final guestPeerJoined = <String, dynamic>{
      'type': 'peer_joined',
      'session_id': _sessionId,
      'payload': {'peer_name': _hostDisplayName ?? ''},
    };

    return [
      HostResponse('both', lobbyMsg),
      HostResponse('host', hostPeerJoined),
      HostResponse('guest', guestPeerJoined),
    ];
  }

  List<HostResponse> _handleSubmitFleet(
    String deviceId,
    String? sid,
    Map<String, dynamic> p,
  ) {
    if (_phase == _Phase.lobby) {
      return [
        _toSender(deviceId, {
          'type': 'fleet_invalid',
          'session_id': _sessionId,
          'payload': {'error': 'cannot submit fleet before opponent joins'},
        })
      ];
    }

    final shipsRaw = p['ships'] as List<dynamic>? ?? [];
    final fleet = <_PlacedShip>[];
    for (final raw in shipsRaw) {
      final s = raw as Map<String, dynamic>;
      final typeMap = s['type'] as Map<String, dynamic>? ?? {};
      final cellsRaw = s['cells'] as List<dynamic>? ?? [];
      final cells = cellsRaw.map((c) {
        final cm = c as Map<String, dynamic>;
        return {'x': (cm['x'] as num).toInt(), 'y': (cm['y'] as num).toInt()};
      }).toList();
      fleet.add(_PlacedShip(
        typeName: typeMap['name'] as String? ?? '',
        size: (typeMap['size'] as num?)?.toInt() ?? 0,
        cells: cells,
      ));
    }

    final validationError = _validateFleet(fleet);
    if (validationError != null) {
      return [
        _toSender(deviceId, {
          'type': 'fleet_invalid',
          'session_id': _sessionId,
          'payload': {'error': validationError},
        })
      ];
    }

    final isHost = deviceId == _hostDeviceId;
    final isGuest = deviceId == _guestDeviceId;

    if (!isHost && !isGuest) {
      return [
        _toSender(deviceId, {
          'type': 'fleet_invalid',
          'session_id': _sessionId,
          'payload': {'error': 'player not in session'},
        })
      ];
    }

    if (isHost) {
      _hostFleet = fleet;
    } else {
      _guestFleet = fleet;
    }

    if (_hostFleet != null && _guestFleet != null && _phase == _Phase.place) {
      _phase = _Phase.ready;
    }

    final responses = <HostResponse>[
      _toSender(deviceId, {
        'type': 'fleet_valid',
        'session_id': _sessionId,
      }),
    ];

    // Notify opponent that peer has placed their fleet.
    final opponentId = isHost ? _guestDeviceId : _hostDeviceId;
    if (opponentId != null) {
      responses.add(
        _toDeviceId(opponentId, {
          'type': 'peer_fleet_placed',
          'session_id': _sessionId,
        }),
      );
    }

    return responses;
  }

  List<HostResponse> _handleSetReady(
    String deviceId,
    String? sid,
    Map<String, dynamic> p,
  ) {
    final ready = p['ready'] as bool? ?? false;

    if (deviceId == _hostDeviceId) {
      _hostReady = ready;
    } else if (deviceId == _guestDeviceId) {
      _guestReady = ready;
    }

    final responses = <HostResponse>[];

    // Notify opponent of ready state.
    final opponentId = deviceId == _hostDeviceId ? _guestDeviceId : _hostDeviceId;
    if (opponentId != null) {
      responses.add(
        _toDeviceId(opponentId, {
          'type': 'peer_ready_state',
          'session_id': _sessionId,
          'payload': {'ready': ready},
        }),
      );
    }

    if (_hostReady && _guestReady) {
      // Start the battle.
      if (_hostFleet == null || _guestFleet == null) {
        responses.add(
          _toSender(deviceId, _errorMsg(_sessionId, 'both fleets required before starting')),
        );
        return responses;
      }

      _hostBattleState = _PlayerBattleState(fleet: _hostFleet!);
      _guestBattleState = _PlayerBattleState(fleet: _guestFleet!);
      _phase = _Phase.battle;
      _activeTurn = _hostDeviceId; // host fires first

      final bothReadyMsg = <String, dynamic>{
        'type': 'both_ready',
        'session_id': _sessionId,
      };
      responses.add(HostResponse('both', bothReadyMsg));

      final battleStartedMsg = <String, dynamic>{
        'type': 'battle_started',
        'session_id': _sessionId,
        'payload': {'active_turn': _activeTurn},
      };
      responses.add(HostResponse('both', battleStartedMsg));
    }

    return responses;
  }

  List<HostResponse> _handleFireShot(
    String deviceId,
    String? sid,
    Map<String, dynamic> p,
  ) {
    if (_phase != _Phase.battle) {
      return [_toSender(deviceId, _errorMsg(_sessionId, 'not in battle phase'))];
    }
    if (_activeTurn != deviceId) {
      return [_toSender(deviceId, _errorMsg(_sessionId, 'not your turn'))];
    }

    final x = (p['x'] as num?)?.toInt() ?? 0;
    final y = (p['y'] as num?)?.toInt() ?? 0;

    final isHost = deviceId == _hostDeviceId;
    final shooterState = isHost ? _hostBattleState! : _guestBattleState!;
    final targetState = isHost ? _guestBattleState! : _hostBattleState!;

    // Fire on the opponent's MyGrid.
    final outcome = targetState.myGrid.fireShot(x, y);

    // Mirror the result onto the shooter's TargetGrid for UI display.
    if (outcome.result == 'miss') {
      shooterState.targetGrid.cells[y][x] = _Cell.miss;
    } else if (outcome.result == 'hit') {
      shooterState.targetGrid.cells[y][x] = _Cell.hit;
    } else {
      // sunk — mark all cells
      for (final pt in outcome.sunkCells) {
        shooterState.targetGrid.cells[pt['y']!][pt['x']!] = _Cell.sunk;
      }
    }

    // Update shooter stats.
    shooterState.shotsFired++;
    if (outcome.result == 'hit' || outcome.result == 'sunk') {
      shooterState.hits++;
    }
    if (outcome.result == 'sunk') {
      shooterState.shipsSunk++;
      targetState.shipsRemaining--;
    }

    // Determine next turn.
    String nextTurn = '';
    if (!outcome.gameOver) {
      _activeTurn = isHost ? _guestDeviceId! : _hostDeviceId!;
      nextTurn = _activeTurn!;
    } else {
      _phase = _Phase.gameOver;
      _winner = deviceId;
    }

    // Build shot result payload (matches Go ShotResult struct).
    final shotResultPayload = <String, dynamic>{
      'x': x,
      'y': y,
      'result': outcome.result,
      'ship_type': outcome.shipTypeName,
      if (outcome.sunkCells.isNotEmpty)
        'sunk_cells': outcome.sunkCells
            .map((pt) => {'x': pt['x'], 'y': pt['y']})
            .toList(),
      'game_over': outcome.gameOver,
      'next_turn': nextTurn,
    };

    final responses = <HostResponse>[];

    // shot_result → shooter only.
    responses.add(
      _toSender(deviceId, {
        'type': 'shot_result',
        'session_id': _sessionId,
        'payload': shotResultPayload,
      }),
    );

    // opponent_shot → opponent.
    final opponentId = isHost ? _guestDeviceId! : _hostDeviceId!;
    responses.add(
      _toDeviceId(opponentId, {
        'type': 'opponent_shot',
        'session_id': _sessionId,
        'payload': shotResultPayload,
      }),
    );

    if (outcome.gameOver) {
      // Determine winner/loser names.
      final winnerName = isHost ? (_hostDisplayName ?? '') : (_guestDisplayName ?? '');
      final loserName = isHost ? (_guestDisplayName ?? '') : (_hostDisplayName ?? '');
      final loserDeviceId = isHost ? (_guestDeviceId ?? '') : (_hostDeviceId ?? '');

      final gameOverMsg = <String, dynamic>{
        'type': 'game_over',
        'session_id': _sessionId,
        'payload': {
          'winner_device_id': deviceId,
          'winner_name': winnerName,
          'loser_device_id': loserDeviceId,
          'loser_name': loserName,
          'reason': 'all_ships_sunk',
        },
      };
      responses.add(HostResponse('both', gameOverMsg));
    } else {
      // turn_changed → both.
      final turnMsg = <String, dynamic>{
        'type': 'turn_changed',
        'session_id': _sessionId,
        'payload': {'active_device_id': nextTurn},
      };
      responses.add(HostResponse('both', turnMsg));
    }

    return responses;
  }

  List<HostResponse> _handleRematch(String deviceId, String? sid) {
    // Reset to placement phase — mirrors Go ResetForRematch.
    _phase = _Phase.place;
    _hostFleet = null;
    _guestFleet = null;
    _hostReady = false;
    _guestReady = false;
    _hostBattleState = null;
    _guestBattleState = null;
    _activeTurn = null;
    _winner = null;

    final resetMsg = <String, dynamic>{
      'type': 'lobby_state',
      'session_id': _sessionId,
      'payload': {
        'host_name': _hostDisplayName ?? '',
        'guest_name': _guestDisplayName ?? '',
        'host_app_version': _hostAppVersion ?? '',
        'guest_app_version': _guestAppVersion ?? '',
        'versions_match': (_hostAppVersion ?? '') == (_guestAppVersion ?? ''),
        'rematch': true,
      },
    };

    return [HostResponse('both', resetMsg)];
  }

  List<HostResponse> _handleLeave(String deviceId, String? sid) {
    final isHost = deviceId == _hostDeviceId;
    final opponentId = isHost ? _guestDeviceId : _hostDeviceId;
    final leaverName = isHost ? (_hostDisplayName ?? '') : (_guestDisplayName ?? '');

    if (opponentId == null) return [];

    return [
      _toDeviceId(opponentId, {
        'type': 'peer_left',
        'session_id': _sessionId,
        'payload': {'player_name': leaverName},
      }),
    ];
  }

  // -------------------------------------------------------------------------
  // Routing helpers
  // -------------------------------------------------------------------------

  /// Route a message to the device that sent the incoming message.
  HostResponse _toSender(String deviceId, Map<String, dynamic> msg) {
    return _toDeviceId(deviceId, msg);
  }

  /// Route a message to a specific device by ID.
  HostResponse _toDeviceId(String deviceId, Map<String, dynamic> msg) {
    if (deviceId == _hostDeviceId) return HostResponse('host', msg);
    if (deviceId == _guestDeviceId) return HostResponse('guest', msg);
    // Fallback: if we can't resolve, route to host (shouldn't happen).
    return HostResponse('host', msg);
  }

  Map<String, dynamic> _errorMsg(String? sid, String text) => {
        'type': 'error',
        if (sid != null && sid.isNotEmpty) 'session_id': sid,
        'payload': {'message': text},
      };

  // -------------------------------------------------------------------------
  // Accessors for testing / introspection
  // -------------------------------------------------------------------------

  String? get hostDeviceId => _hostDeviceId;
  String? get guestDeviceId => _guestDeviceId;
  String? get activeTurn => _activeTurn;
  String? get winner => _winner;
  String get joinCode => _joinCode;

  /// Expose current phase as a string matching Go's Phase constants.
  String get phase {
    switch (_phase) {
      case _Phase.none:
        return 'none';
      case _Phase.lobby:
        return 'lobby';
      case _Phase.place:
        return 'place';
      case _Phase.ready:
        return 'ready';
      case _Phase.battle:
        return 'battle';
      case _Phase.gameOver:
        return 'game_over';
    }
  }
}
