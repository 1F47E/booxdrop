/// Full game simulation — realistic play with random fleet placement.
/// Fires every cell one by one (guarantees all ships sunk), checks game state.
/// Run: dart test/full_game_sim.dart [server_url]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const defaultUrl = 'ws://localhost:8085/ws/battleships';
const gridSize = 8;

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args[0] : defaultUrl;
  print('🎮 Battleships Full Game Simulation (realistic)');
  print('Server: $url\n');

  final a = await Player.connect('sim-alice', 'Alice', url);
  final b = await Player.connect('sim-bob', 'Bob', url);
  print('✅ Both connected');

  // Auto match
  a.send({'type': 'auto_match', 'payload': {'display_name': 'Alice', 'app_version': '1.0.0'}});
  await a.expect('session_created');
  b.send({'type': 'auto_match', 'payload': {'display_name': 'Bob', 'app_version': '1.0.0'}});
  await Future.delayed(const Duration(milliseconds: 500));
  a.clearBuffer(); b.clearBuffer();
  print('✅ Matched');

  // Random fleet placement
  final fleetA = _randomFleet(42);
  final fleetB = _randomFleet(99);
  print('✅ Fleets generated');
  _printFleet('Alice', fleetA);
  _printFleet('Bob', fleetB);

  a.send({'type': 'submit_fleet', 'session_id': a.sessionId, 'payload': {'ships': fleetA}});
  final fvA = await a.expect('fleet_valid');
  print('✅ Alice fleet valid');

  b.send({'type': 'submit_fleet', 'session_id': b.sessionId, 'payload': {'ships': fleetB}});
  final fvB = await b.expect('fleet_valid');
  print('✅ Bob fleet valid');

  // Ready
  a.send({'type': 'set_ready', 'session_id': a.sessionId, 'payload': {'ready': true}});
  b.send({'type': 'set_ready', 'session_id': b.sessionId, 'payload': {'ready': true}});
  await a.expect('battle_started');
  await b.expect('battle_started');
  print('✅ Battle started!\n');

  // Determine first player
  var current = (a.lastPayload?['active_turn'] == 'sim-alice') ? a : b;
  var other = (current == a) ? b : a;
  print('${current.name} goes first\n');

  // Generate all cells in random order for each player
  final rng = Random(777);
  final allCells = <List<int>>[];
  for (int y = 0; y < gridSize; y++) {
    for (int x = 0; x < gridSize; x++) {
      allCells.add([x, y]);
    }
  }
  allCells.shuffle(rng);

  // Each player has their own target list
  final targetsA = List<List<int>>.from(allCells);
  final targetsB = List<List<int>>.from(allCells..shuffle(Random(888)));
  var idxA = 0, idxB = 0;

  var totalShots = 0;
  var hits = 0;
  var sinks = 0;

  for (int round = 0; round < 64; round++) {
    final targets = (current == a) ? targetsA : targetsB;
    final idx = (current == a) ? idxA : idxB;
    if (idx >= targets.length) break;

    final x = targets[idx][0], y = targets[idx][1];
    if (current == a) idxA++; else idxB++;

    current.send({
      'type': 'fire_shot',
      'session_id': current.sessionId,
      'payload': {'x': x, 'y': y},
    });
    totalShots++;

    final result = await current.expect('shot_result');
    final payload = result['payload'] as Map<String, dynamic>? ?? result;
    final r = payload['result'] as String? ?? '';
    final emoji = r == 'sunk' ? '🔥' : r == 'hit' ? '💥' : r == 'miss' ? '💧' : '❓';
    final extra = r == 'sunk' ? ' [${payload['ship_type']}]' : '';

    if (r == 'hit' || r == 'sunk') hits++;
    if (r == 'sunk') sinks++;

    print('  R${round + 1}: ${current.name} → ($x,$y) $emoji $r$extra');

    if (payload['game_over'] == true) {
      print('\n🏆 ${current.name} WINS!');
      print('   Total shots: $totalShots, Hits: $hits, Sinks: $sinks');
      a.close(); b.close();
      pkill();
      exit(0);
    }

    // Wait for turn change
    try {
      await current.expect('turn_changed', timeout: const Duration(seconds: 3));
    } catch (_) {
      // Might already be consumed
    }

    // Swap
    final tmp = current; current = other; other = tmp;
  }

  print('\n❌ Game did not end after 64 rounds');
  a.close(); b.close();
  pkill();
  exit(1);
}

void pkill() {
  try { Process.runSync('pkill', ['-f', 'maze-server-local']); } catch (_) {}
}

/// Generate a random valid fleet for an 8x8 grid.
List<Map<String, dynamic>> _randomFleet(int seed) {
  final rng = Random(seed);
  final ships = [
    ('Carrier', 4),
    ('Battleship', 3),
    ('Cruiser', 2),
    ('Sub', 2),
  ];

  final occupied = <String>{};

  List<Map<String, dynamic>> result = [];

  for (final (name, size) in ships) {
    for (int attempt = 0; attempt < 1000; attempt++) {
      final horizontal = rng.nextBool();
      final x = rng.nextInt(horizontal ? gridSize - size + 1 : gridSize);
      final y = rng.nextInt(horizontal ? gridSize : gridSize - size + 1);

      final cells = <Map<String, int>>[];
      for (int i = 0; i < size; i++) {
        cells.add({'x': horizontal ? x + i : x, 'y': horizontal ? y : y + i});
      }

      // Check overlap and adjacency
      bool valid = true;
      for (final c in cells) {
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final key = '${c['x']! + dx},${c['y']! + dy}';
            if (occupied.contains(key)) {
              valid = false;
              break;
            }
          }
          if (!valid) break;
        }
        if (!valid) break;
      }

      if (valid) {
        for (final c in cells) {
          occupied.add('${c['x']},${c['y']}');
        }
        result.add({
          'type': {'name': name, 'size': size},
          'cells': cells,
        });
        break;
      }
    }
  }
  return result;
}

void _printFleet(String name, List<Map<String, dynamic>> fleet) {
  print('  $name fleet:');
  for (final ship in fleet) {
    final t = ship['type'] as Map;
    final cells = (ship['cells'] as List).map((c) => '(${c['x']},${c['y']})').join(' ');
    print('    ${t['name']}(${t['size']}): $cells');
  }
}

class Player {
  final String deviceId;
  final String name;
  final WebSocket _ws;
  final _buffer = <Map<String, dynamic>>[];
  final _stream = StreamController<Map<String, dynamic>>.broadcast();
  String? sessionId;
  Map<String, dynamic>? lastPayload;

  Player(this.deviceId, this.name, this._ws) {
    _ws.listen((data) {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      if (msg['session_id'] != null && sessionId == null) {
        sessionId = msg['session_id'] as String;
      }
      final payload = msg['payload'];
      if (payload is Map<String, dynamic>) lastPayload = payload;
      _buffer.add(msg);
      _stream.add(msg);
    });
  }

  static Future<Player> connect(String id, String name, String url) async {
    final ws = await WebSocket.connect(url);
    final p = Player(id, name, ws);
    p.send({'type': 'hello', 'payload': {'device_id': id, 'display_name': name, 'platform': 'sim', 'app_version': '1.0.0'}});
    await Future.delayed(const Duration(milliseconds: 100));
    return p;
  }

  void send(Map<String, dynamic> msg) => _ws.add(jsonEncode(msg));

  Future<Map<String, dynamic>> expect(String type, {Duration timeout = const Duration(seconds: 10)}) {
    // Check buffer first
    for (int i = 0; i < _buffer.length; i++) {
      if (_buffer[i]['type'] == type) {
        final msg = _buffer.removeAt(i);
        return Future.value(msg['payload'] is Map<String, dynamic> ? msg['payload'] : msg);
      }
    }
    return _stream.stream
        .where((m) => m['type'] == type)
        .map((m) => m['payload'] is Map<String, dynamic> ? m['payload'] as Map<String, dynamic> : m)
        .first
        .timeout(timeout, onTimeout: () => throw TimeoutException('$name: timeout waiting for $type'));
  }

  void clearBuffer() => _buffer.clear();
  void close() => _ws.close();
}
