/// Play a complete Battleships game with random fleets.
/// Run: cd battleships_flutter && dart test/play_game.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const url = 'ws://localhost:8085/ws/battleships';

Future<void> main() async {
  print('🎮 Battleships — Full Game\n');

  final a = await Player.create('alice-01', 'Alice');
  final b = await Player.create('bob-02', 'Bob');

  // Match
  a.send('auto_match', {'display_name': 'Alice', 'app_version': '1.0.0'});
  await a.waitType('session_created');
  b.send('auto_match', {'display_name': 'Bob', 'app_version': '1.0.0'});
  await Future.delayed(Duration(milliseconds: 500));
  print('✅ Matched\n');

  // Random fleets
  final fa = randomFleet(42), fb = randomFleet(99);
  printFleet('Alice', fa); printFleet('Bob', fb); print('');

  a.sendRaw({'type': 'submit_fleet', 'session_id': a.sid, 'payload': {'ships': fa}});
  await a.waitType('fleet_valid');
  b.sendRaw({'type': 'submit_fleet', 'session_id': b.sid, 'payload': {'ships': fb}});
  await b.waitType('fleet_valid');

  a.sendRaw({'type': 'set_ready', 'session_id': a.sid, 'payload': {'ready': true}});
  b.sendRaw({'type': 'set_ready', 'session_id': b.sid, 'payload': {'ready': true}});
  await Future.delayed(Duration(milliseconds: 500));
  a.clearQueue(); b.clearQueue();
  print('✅ Battle!\n');

  // Each player has a shuffled target list
  final targetsA = allCells()..shuffle(Random(12345));
  final targetsB = allCells()..shuffle(Random(67890));
  var iA = 0, iB = 0;

  // Determine who goes first
  a.sendRaw({'type': 'request_state', 'session_id': a.sid});
  final state = await a.waitType('battle_state');
  var currentIsA = (state['active_turn'] == 'alice-01');
  a.clearQueue(); b.clearQueue();

  for (int round = 1; round <= 128; round++) {
    final current = currentIsA ? a : b;
    final targets = currentIsA ? targetsA : targetsB;
    final idx = currentIsA ? iA++ : iB++;
    if (idx >= targets.length) break;
    final x = targets[idx][0], y = targets[idx][1];

    current.clearQueue();
    current.sendRaw({'type': 'fire_shot', 'session_id': current.sid, 'payload': {'x': x, 'y': y}});

    // Wait for shot_result matching our coordinates
    final result = await current.waitForShot(x, y);
    final r = result['result'] as String? ?? '';
    final emoji = r == 'sunk' ? '🔥' : r == 'hit' ? '💥' : '💧';
    final extra = r == 'sunk' ? ' [${result['ship_type']}]' : '';
    print('  R$round ${current.name} → ($x,$y) $emoji $r$extra');

    if (result['game_over'] == true) {
      print('\n🏆 ${current.name} WINS in $round rounds!');
      print('   Alice fired: $iA, Bob fired: $iB');
      a.close(); b.close();
      exit(0);
    }

    // Small delay for server to process turn change
    await Future.delayed(Duration(milliseconds: 50));
    currentIsA = !currentIsA;
  }

  print('\n❌ Game did not end');
  a.close(); b.close();
  exit(1);
}

List<List<int>> allCells() => [for (int y = 0; y < 8; y++) for (int x = 0; x < 8; x++) [x, y]];

List<Map<String, dynamic>> randomFleet(int seed) {
  final rng = Random(seed);
  final ships = [('Carrier', 4), ('Battleship', 3), ('Cruiser', 2), ('Sub', 2)];
  final occ = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final (name, size) in ships) {
    for (int att = 0; att < 1000; att++) {
      final h = rng.nextBool();
      final x = rng.nextInt(h ? 9 - size : 8), y = rng.nextInt(h ? 8 : 9 - size);
      final cells = [for (int i = 0; i < size; i++) {'x': h ? x + i : x, 'y': h ? y : y + i}];
      bool ok = true;
      for (final c in cells) {
        for (int dy = -1; dy <= 1 && ok; dy++)
          for (int dx = -1; dx <= 1 && ok; dx++)
            if (occ.contains('${c['x']! + dx},${c['y']! + dy}')) ok = false;
      }
      if (!ok) continue;
      for (final c in cells) occ.add('${c['x']},${c['y']}');
      result.add({'type': {'name': name, 'size': size}, 'cells': cells});
      break;
    }
  }
  return result;
}

void printFleet(String n, List<Map<String, dynamic>> f) {
  print('  $n:');
  for (final s in f) {
    final t = s['type'] as Map;
    print('    ${t['name']}(${t['size']}): ${(s['cells'] as List).map((c) => '(${c['x']},${c['y']})').join(' ')}');
  }
}

class Player {
  final String id, name;
  final WebSocket _ws;
  final _queue = <Map<String, dynamic>>[];
  final _ctrl = StreamController<Map<String, dynamic>>.broadcast();
  String? sid;

  Player(this.id, this.name, this._ws) {
    _ws.listen((d) {
      final m = jsonDecode(d as String) as Map<String, dynamic>;
      if (m['session_id'] != null && sid == null) sid = m['session_id'] as String;
      _queue.add(m);
      _ctrl.add(m);
    });
  }

  static Future<Player> create(String id, String name) async {
    final ws = await WebSocket.connect(url);
    final p = Player(id, name, ws);
    p.send('hello', {'device_id': id, 'display_name': name, 'platform': 'sim', 'app_version': '1.0.0'});
    await Future.delayed(Duration(milliseconds: 100));
    return p;
  }

  void send(String type, Map<String, dynamic> payload) =>
      _ws.add(jsonEncode({'type': type, 'payload': payload}));
  void sendRaw(Map<String, dynamic> msg) => _ws.add(jsonEncode(msg));

  Future<Map<String, dynamic>> waitType(String type) async {
    // Check queue
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i]['type'] == type) {
        final m = _queue.removeAt(i);
        return m['payload'] is Map<String, dynamic> ? m['payload'] : {};
      }
    }
    // Wait on stream
    await for (final m in _ctrl.stream) {
      _queue.remove(m);
      if (m['type'] == type) {
        return m['payload'] is Map<String, dynamic> ? m['payload'] as Map<String, dynamic> : {};
      }
    }
    throw 'stream closed';
  }

  Future<Map<String, dynamic>> waitForShot(int x, int y) async {
    // Drain queue for matching shot_result
    for (int i = 0; i < _queue.length; i++) {
      final m = _queue[i];
      if (m['type'] == 'shot_result') {
        final p = m['payload'] as Map<String, dynamic>? ?? {};
        if (p['x'] == x && p['y'] == y) {
          _queue.removeAt(i);
          return p;
        }
      }
    }
    // Wait on stream
    await for (final m in _ctrl.stream) {
      _queue.remove(m);
      if (m['type'] == 'shot_result') {
        final p = m['payload'] as Map<String, dynamic>? ?? {};
        if (p['x'] == x && p['y'] == y) return p;
      }
    }
    throw 'stream closed';
  }

  void clearQueue() => _queue.clear();
  void close() => _ws.close();
}
