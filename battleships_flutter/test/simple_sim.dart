/// Minimal sim — test sinking one ship.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final url = 'ws://localhost:8085/ws/battleships';

  final a = await _connect('a-dev', 'A', url);
  final b = await _connect('b-dev', 'B', url);

  // Match
  a.send({'type': 'auto_match', 'payload': {'display_name': 'A', 'app_version': '1.0.0'}});
  await _wait(a, 'session_created');
  b.send({'type': 'auto_match', 'payload': {'display_name': 'B', 'app_version': '1.0.0'}});
  await Future.delayed(Duration(milliseconds: 500));
  print('Matched. A sid=${a.sid}, B sid=${b.sid}');

  // Simple fleet — sub at (0,0)-(1,0), cruiser at (3,0)-(4,0), battleship at (0,3)-(2,3), carrier at (0,5)-(3,5)
  final fleet = [
    {'type': {'name': 'Carrier', 'size': 4}, 'cells': [{'x':0,'y':5},{'x':1,'y':5},{'x':2,'y':5},{'x':3,'y':5}]},
    {'type': {'name': 'Battleship', 'size': 3}, 'cells': [{'x':0,'y':3},{'x':1,'y':3},{'x':2,'y':3}]},
    {'type': {'name': 'Cruiser', 'size': 2}, 'cells': [{'x':3,'y':0},{'x':4,'y':0}]},
    {'type': {'name': 'Sub', 'size': 2}, 'cells': [{'x':0,'y':0},{'x':1,'y':0}]},
  ];

  a.send({'type': 'submit_fleet', 'session_id': a.sid, 'payload': {'ships': fleet}});
  final fva = await _wait(a, 'fleet_valid');
  print('A fleet valid: $fva');

  b.send({'type': 'submit_fleet', 'session_id': b.sid, 'payload': {'ships': fleet}});
  await _wait(b, 'fleet_valid');
  print('B fleet valid');

  a.send({'type': 'set_ready', 'session_id': a.sid, 'payload': {'ready': true}});
  b.send({'type': 'set_ready', 'session_id': b.sid, 'payload': {'ready': true}});

  final bsA = await _wait(a, 'battle_started');
  await _wait(b, 'battle_started');
  print('Battle started! active_turn=${bsA['active_turn']}');

  // A fires at Bob's sub: (0,0) and (1,0) — should be hit, hit+sunk
  // But A might not go first. Check.
  var shooter = (bsA['active_turn'] == 'a-dev') ? a : b;
  var waiter = (shooter == a) ? b : a;

  // Request state to see the grid
  shooter.send({'type': 'request_state', 'session_id': shooter.sid});
  final st = await _wait(shooter, 'battle_state');
  print('Target grid: ${st['target_grid']}');
  print('Your grid row0: ${st['your_grid']?[0]}');
  print('Ships remaining: ${st['ships_remaining']}');

  // Fire at (0,0)
  shooter.send({'type': 'fire_shot', 'session_id': shooter.sid, 'payload': {'x': 0, 'y': 0}});
  final r1 = await _wait(shooter, 'shot_result');
  print('Shot (0,0): result=${r1['result']}, payload=$r1');

  // Swap turns
  await _wait(shooter, 'turn_changed');
  var tmp = shooter; shooter = waiter; waiter = tmp;

  // Other player fires somewhere
  shooter.send({'type': 'fire_shot', 'session_id': shooter.sid, 'payload': {'x': 7, 'y': 7}});
  final r2 = await _wait(shooter, 'shot_result');
  print('Shot (7,7): result=${r2['result']}');

  await _wait(shooter, 'turn_changed');
  tmp = shooter; shooter = waiter; waiter = tmp;

  // Request state to see B's grid after A hit (0,0)
  shooter.send({'type': 'request_state', 'session_id': shooter.sid});
  final st2 = await _wait(shooter, 'battle_state');
  print('After hit: target_grid row0=${st2['target_grid']?[0]}');

  // Fire at (1,0) — should sink the sub
  shooter.send({'type': 'fire_shot', 'session_id': shooter.sid, 'payload': {'x': 1, 'y': 0}});
  // Print ALL messages received
  await Future.delayed(Duration(milliseconds: 500));
  print('Shooter buffer after (1,0):');
  for (final m in shooter._buf) {
    print('  ${m['type']}: ${jsonEncode(m['payload'])}');
  }
  final r3 = shooter._buf.firstWhere((m) => m['type'] == 'shot_result', orElse: () => {});
  print('Shot (1,0) raw: $r3');

  print('\nDone!');
  a.ws.close(); b.ws.close();
  exit(0);
}

class _P {
  final String id;
  final WebSocket ws;
  String? sid;
  final _buf = <Map<String, dynamic>>[];
  final _c = StreamController<Map<String, dynamic>>.broadcast();

  _P(this.id, this.ws) {
    ws.listen((d) {
      final m = jsonDecode(d as String) as Map<String, dynamic>;
      if (m['session_id'] != null && sid == null) sid = m['session_id'] as String;
      _buf.add(m);
      _c.add(m);
    });
  }

  void send(Map<String, dynamic> m) => ws.add(jsonEncode(m));
}

Future<_P> _connect(String id, String name, String url) async {
  final ws = await WebSocket.connect(url);
  final p = _P(id, ws);
  p.send({'type': 'hello', 'payload': {'device_id': id, 'display_name': name, 'platform': 'sim', 'app_version': '1.0.0'}});
  await Future.delayed(Duration(milliseconds: 100));
  return p;
}

Future<Map<String, dynamic>> _wait(_P p, String type) async {
  for (int i = 0; i < p._buf.length; i++) {
    if (p._buf[i]['type'] == type) {
      final m = p._buf.removeAt(i);
      return m['payload'] is Map<String, dynamic> ? m['payload'] : {};
    }
  }
  return p._c.stream
    .where((m) => m['type'] == type)
    .map((m) => m['payload'] is Map<String, dynamic> ? m['payload'] as Map<String, dynamic> : <String, dynamic>{})
    .first
    .timeout(Duration(seconds: 5));
}
