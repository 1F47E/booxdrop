// test/services/local_battle_host_test.dart
//
// Unit tests for LocalBattleHost — the local Bluetooth game engine.
// Each test exercises a single part of the session lifecycle.

import 'package:flutter_test/flutter_test.dart';
import 'package:battleships/services/local_battle_host.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const String kHost = 'device_host';
const String kGuest = 'device_guest';
const String kHostName = 'Alice';
const String kGuestName = 'Bob';
const String kVersion = '1.0.0';

/// Build a valid fleet that passes all Go validation rules.
/// Ships are spread across the grid with no adjacency.
///
///   Carrier    (4): row 0, cols 0-3
///   Battleship (3): row 2, cols 0-2
///   Cruiser    (2): row 4, cols 0-1
///   Sub        (2): row 6, cols 0-1
List<Map<String, dynamic>> validFleet() => [
      {
        'type': {'name': 'Carrier', 'size': 4},
        'cells': [
          {'x': 0, 'y': 0},
          {'x': 1, 'y': 0},
          {'x': 2, 'y': 0},
          {'x': 3, 'y': 0},
        ],
      },
      {
        'type': {'name': 'Battleship', 'size': 3},
        'cells': [
          {'x': 0, 'y': 2},
          {'x': 1, 'y': 2},
          {'x': 2, 'y': 2},
        ],
      },
      {
        'type': {'name': 'Cruiser', 'size': 2},
        'cells': [
          {'x': 0, 'y': 4},
          {'x': 1, 'y': 4},
        ],
      },
      {
        'type': {'name': 'Sub', 'size': 2},
        'cells': [
          {'x': 0, 'y': 6},
          {'x': 1, 'y': 6},
        ],
      },
    ];

/// An alternative valid fleet used for the guest so the fleets don't collide.
/// Placed on the right half of the board (cols 4-7).
List<Map<String, dynamic>> validFleetAlt() => [
      {
        'type': {'name': 'Carrier', 'size': 4},
        'cells': [
          {'x': 4, 'y': 0},
          {'x': 5, 'y': 0},
          {'x': 6, 'y': 0},
          {'x': 7, 'y': 0},
        ],
      },
      {
        'type': {'name': 'Battleship', 'size': 3},
        'cells': [
          {'x': 4, 'y': 2},
          {'x': 5, 'y': 2},
          {'x': 6, 'y': 2},
        ],
      },
      {
        'type': {'name': 'Cruiser', 'size': 2},
        'cells': [
          {'x': 4, 'y': 4},
          {'x': 5, 'y': 4},
        ],
      },
      {
        'type': {'name': 'Sub', 'size': 2},
        'cells': [
          {'x': 4, 'y': 6},
          {'x': 5, 'y': 6},
        ],
      },
    ];

/// Send hello + create_session from the host, returning the host.
LocalBattleHost _setupHostSession() {
  final host = LocalBattleHost();
  host.processMessage(kHost, {
    'type': 'hello',
    'payload': {'device_id': kHost, 'display_name': kHostName, 'app_version': kVersion},
  });
  host.processMessage(kHost, {
    'type': 'create_session',
    'payload': {'display_name': kHostName, 'app_version': kVersion},
  });
  return host;
}

/// Set up host + guest joined (lobby_state + peer_joined sent).
LocalBattleHost _setupBothJoined() {
  final host = _setupHostSession();
  host.processMessage(kGuest, {
    'type': 'hello',
    'payload': {'device_id': kGuest, 'display_name': kGuestName, 'app_version': kVersion},
  });
  host.processMessage(kGuest, {
    'type': 'join_session',
    'payload': {
      'join_code': '001',
      'display_name': kGuestName,
      'app_version': kVersion,
    },
  });
  return host;
}

/// Advance past placement + both ready into battle phase.
/// Host's grid = validFleet(), Guest's grid = validFleetAlt().
LocalBattleHost _setupBattle() {
  final engine = _setupBothJoined();

  engine.processMessage(kHost, {
    'type': 'submit_fleet',
    'session_id': LocalBattleHost.sessionId,
    'payload': {'ships': validFleet()},
  });
  engine.processMessage(kGuest, {
    'type': 'submit_fleet',
    'session_id': LocalBattleHost.sessionId,
    'payload': {'ships': validFleetAlt()},
  });
  engine.processMessage(kHost, {
    'type': 'set_ready',
    'session_id': LocalBattleHost.sessionId,
    'payload': {'ready': true},
  });
  engine.processMessage(kGuest, {
    'type': 'set_ready',
    'session_id': LocalBattleHost.sessionId,
    'payload': {'ready': true},
  });

  return engine;
}

/// Helper: find the first response with a given [type] in [responses].
HostResponse? _findType(List<HostResponse> responses, String type) {
  return responses
      .where((r) => r.message['type'] == type)
      .cast<HostResponse?>()
      .firstOrNull;
}

/// Helper: find all responses with a given [type].
List<HostResponse> _allOfType(List<HostResponse> responses, String type) {
  return responses.where((r) => r.message['type'] == type).toList();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Create session
  // -------------------------------------------------------------------------
  group('create_session', () {
    test('returns session_created with join_code for host', () {
      final engine = LocalBattleHost();
      final responses = engine.processMessage(kHost, {
        'type': 'create_session',
        'payload': {'display_name': kHostName, 'app_version': kVersion},
      });

      expect(responses.length, greaterThanOrEqualTo(1));
      final r = _findType(responses, 'session_created');
      expect(r, isNotNull);
      expect(r!.target, equals('host'));
      expect(r.message['session_id'], equals('local_session'));
      final payload = r.message['payload'] as Map<String, dynamic>;
      expect(payload['join_code'], isNotEmpty);
    });

    test('session is in lobby phase after create', () {
      final engine = _setupHostSession();
      expect(engine.phase, equals('lobby'));
    });
  });

  // -------------------------------------------------------------------------
  // 2. Join session → lobby_state + peer_joined to both
  // -------------------------------------------------------------------------
  group('join_session', () {
    test('returns lobby_state to both and peer_joined to each player', () {
      final engine = _setupHostSession();
      final responses = engine.processMessage(kGuest, {
        'type': 'join_session',
        'payload': {
          'join_code': '001',
          'display_name': kGuestName,
          'app_version': kVersion,
        },
      });

      // lobby_state sent to 'both'
      final lobbyResps = _allOfType(responses, 'lobby_state');
      expect(lobbyResps.length, equals(1));
      expect(lobbyResps.first.target, equals('both'));

      final lobbyPayload = lobbyResps.first.message['payload'] as Map<String, dynamic>;
      expect(lobbyPayload['host_name'], equals(kHostName));
      expect(lobbyPayload['guest_name'], equals(kGuestName));

      // peer_joined: host gets guest's name, guest gets host's name
      final peerJoinedResps = _allOfType(responses, 'peer_joined');
      expect(peerJoinedResps.length, equals(2));

      final hostPJ = peerJoinedResps.firstWhere((r) => r.target == 'host');
      final hostPJPayload = hostPJ.message['payload'] as Map<String, dynamic>;
      expect(hostPJPayload['peer_name'], equals(kGuestName));

      final guestPJ = peerJoinedResps.firstWhere((r) => r.target == 'guest');
      final guestPJPayload = guestPJ.message['payload'] as Map<String, dynamic>;
      expect(guestPJPayload['peer_name'], equals(kHostName));
    });

    test('phase advances to place after join', () {
      final engine = _setupBothJoined();
      expect(engine.phase, equals('place'));
    });

    test('second join attempt returns error', () {
      final engine = _setupBothJoined();
      final responses = engine.processMessage('device_third', {
        'type': 'join_session',
        'payload': {'join_code': '001', 'display_name': 'Charlie', 'app_version': kVersion},
      });
      final err = _findType(responses, 'error');
      expect(err, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Submit valid fleet → fleet_valid
  // -------------------------------------------------------------------------
  group('submit_fleet valid', () {
    test('host submitting valid fleet returns fleet_valid', () {
      final engine = _setupBothJoined();
      final responses = engine.processMessage(kHost, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': validFleet()},
      });

      final valid = _findType(responses, 'fleet_valid');
      expect(valid, isNotNull);
      expect(valid!.target, equals('host'));
    });

    test('opponent receives peer_fleet_placed after host submits', () {
      final engine = _setupBothJoined();
      final responses = engine.processMessage(kHost, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': validFleet()},
      });

      final peerPlaced = _findType(responses, 'peer_fleet_placed');
      expect(peerPlaced, isNotNull);
      expect(peerPlaced!.target, equals('guest'));
    });
  });

  // -------------------------------------------------------------------------
  // 4. Submit invalid fleet (overlap) → fleet_invalid
  // -------------------------------------------------------------------------
  group('submit_fleet invalid', () {
    test('overlapping ships returns fleet_invalid', () {
      final engine = _setupBothJoined();

      // Cruiser overlaps with Carrier (both start at 0,0).
      final badFleet = [
        {
          'type': {'name': 'Carrier', 'size': 4},
          'cells': [
            {'x': 0, 'y': 0},
            {'x': 1, 'y': 0},
            {'x': 2, 'y': 0},
            {'x': 3, 'y': 0},
          ],
        },
        {
          'type': {'name': 'Battleship', 'size': 3},
          'cells': [
            {'x': 0, 'y': 2},
            {'x': 1, 'y': 2},
            {'x': 2, 'y': 2},
          ],
        },
        {
          'type': {'name': 'Cruiser', 'size': 2},
          'cells': [
            {'x': 0, 'y': 0}, // overlaps Carrier
            {'x': 1, 'y': 0},
          ],
        },
        {
          'type': {'name': 'Sub', 'size': 2},
          'cells': [
            {'x': 0, 'y': 6},
            {'x': 1, 'y': 6},
          ],
        },
      ];

      final responses = engine.processMessage(kHost, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': badFleet},
      });

      final invalid = _findType(responses, 'fleet_invalid');
      expect(invalid, isNotNull);
      final payload = invalid!.message['payload'] as Map<String, dynamic>;
      expect(payload['error'], isNotEmpty);
    });

    test('fleet with wrong ship count returns fleet_invalid', () {
      final engine = _setupBothJoined();

      final responses = engine.processMessage(kHost, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': <dynamic>[]}, // empty fleet
      });

      final invalid = _findType(responses, 'fleet_invalid');
      expect(invalid, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Both ready → both_ready + battle_started
  // -------------------------------------------------------------------------
  group('set_ready', () {
    test('both players ready triggers both_ready and battle_started', () {
      final engine = _setupBothJoined();

      engine.processMessage(kHost, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': validFleet()},
      });
      engine.processMessage(kGuest, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': validFleetAlt()},
      });
      engine.processMessage(kHost, {
        'type': 'set_ready',
        'session_id': 'local_session',
        'payload': {'ready': true},
      });
      final responses = engine.processMessage(kGuest, {
        'type': 'set_ready',
        'session_id': 'local_session',
        'payload': {'ready': true},
      });

      final bothReady = _findType(responses, 'both_ready');
      expect(bothReady, isNotNull);
      expect(bothReady!.target, equals('both'));

      final battleStarted = _findType(responses, 'battle_started');
      expect(battleStarted, isNotNull);
      expect(battleStarted!.target, equals('both'));

      final bsPayload = battleStarted.message['payload'] as Map<String, dynamic>;
      // Host fires first.
      expect(bsPayload['active_turn'], equals(kHost));
    });

    test('only one player ready does NOT trigger battle_started', () {
      final engine = _setupBothJoined();

      engine.processMessage(kHost, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': validFleet()},
      });
      engine.processMessage(kGuest, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': validFleetAlt()},
      });

      final responses = engine.processMessage(kHost, {
        'type': 'set_ready',
        'session_id': 'local_session',
        'payload': {'ready': true},
      });

      expect(_findType(responses, 'battle_started'), isNull);
      expect(_findType(responses, 'both_ready'), isNull);

      // Opponent receives peer_ready_state.
      final peerReady = _findType(responses, 'peer_ready_state');
      expect(peerReady, isNotNull);
      expect(peerReady!.target, equals('guest'));
    });
  });

  // -------------------------------------------------------------------------
  // 6. Fire shot miss → shot_result(miss) + turn_changed
  // -------------------------------------------------------------------------
  group('fire_shot miss', () {
    test('miss on empty cell returns shot_result(miss) and turn_changed', () {
      final engine = _setupBattle();

      // Guest fleet is at cols 4-7, rows 0-6 (validFleetAlt).
      // Shooting at (7, 7) is definitely empty.
      final responses = engine.processMessage(kHost, {
        'type': 'fire_shot',
        'session_id': 'local_session',
        'payload': {'x': 7, 'y': 7},
      });

      final shotResult = _findType(responses, 'shot_result');
      expect(shotResult, isNotNull);
      expect(shotResult!.target, equals('host'));
      final srPayload = shotResult.message['payload'] as Map<String, dynamic>;
      expect(srPayload['result'], equals('miss'));
      expect(srPayload['x'], equals(7));
      expect(srPayload['y'], equals(7));

      final opponentShot = _findType(responses, 'opponent_shot');
      expect(opponentShot, isNotNull);
      expect(opponentShot!.target, equals('guest'));

      final turnChanged = _findType(responses, 'turn_changed');
      expect(turnChanged, isNotNull);
      expect(turnChanged!.target, equals('both'));
      final tcPayload = turnChanged.message['payload'] as Map<String, dynamic>;
      expect(tcPayload['active_device_id'], equals(kGuest));
    });
  });

  // -------------------------------------------------------------------------
  // 7. Fire shot hit → shot_result(hit) + turn_changed
  // -------------------------------------------------------------------------
  group('fire_shot hit', () {
    test('hit on ship cell returns shot_result(hit) and turn_changed', () {
      final engine = _setupBattle();

      // Guest fleet Carrier is at row 0, cols 4-7.
      // Hit just one cell of Carrier — not all 4, so it won't sink.
      final responses = engine.processMessage(kHost, {
        'type': 'fire_shot',
        'session_id': 'local_session',
        'payload': {'x': 4, 'y': 0}, // Carrier cell
      });

      final shotResult = _findType(responses, 'shot_result');
      expect(shotResult, isNotNull);
      final payload = shotResult!.message['payload'] as Map<String, dynamic>;
      expect(payload['result'], equals('hit'));
      expect(payload['game_over'], isFalse);

      final turnChanged = _findType(responses, 'turn_changed');
      expect(turnChanged, isNotNull);
      final tcPayload = turnChanged!.message['payload'] as Map<String, dynamic>;
      expect(tcPayload['active_device_id'], equals(kGuest));
    });
  });

  // -------------------------------------------------------------------------
  // 8. Sink an entire ship
  // -------------------------------------------------------------------------
  group('fire_shot sunk', () {
    test('sinking all cells of Sub returns shot_result(sunk) with sunk_cells', () {
      final engine = _setupBattle();

      // Guest Sub is at row 6, cols 4-5 (validFleetAlt).
      // It only has 2 cells — shoot both.
      engine.processMessage(kHost, {
        'type': 'fire_shot',
        'session_id': 'local_session',
        'payload': {'x': 4, 'y': 6},
      });
      // Now it's guest's turn; guest shoots somewhere, then back to host.
      engine.processMessage(kGuest, {
        'type': 'fire_shot',
        'session_id': 'local_session',
        'payload': {'x': 7, 'y': 7}, // miss on host side
      });

      // Host takes second shot — sinks the Sub.
      final responses = engine.processMessage(kHost, {
        'type': 'fire_shot',
        'session_id': 'local_session',
        'payload': {'x': 5, 'y': 6},
      });

      final shotResult = _findType(responses, 'shot_result');
      expect(shotResult, isNotNull);
      final payload = shotResult!.message['payload'] as Map<String, dynamic>;
      expect(payload['result'], equals('sunk'));
      expect(payload['ship_type'], equals('Sub'));

      final sunkCells = payload['sunk_cells'] as List<dynamic>;
      expect(sunkCells.length, equals(2));
    });
  });

  // -------------------------------------------------------------------------
  // 9. Sink all ships → game_over
  // -------------------------------------------------------------------------
  group('game_over', () {
    test('sinking all opponent ships produces game_over to both', () {
      // We need to sink all 4 guest ships (validFleetAlt):
      //   Carrier    (4): row 0, cols 4-7
      //   Battleship (3): row 2, cols 4-6
      //   Cruiser    (2): row 4, cols 4-5
      //   Sub        (2): row 6, cols 4-5
      // Total cells: 4+3+2+2 = 11

      final engine = _setupBattle();

      // All guest ship cells
      final targets = [
        // Carrier
        [4, 0], [5, 0], [6, 0], [7, 0],
        // Battleship
        [4, 2], [5, 2], [6, 2],
        // Cruiser
        [4, 4], [5, 4],
        // Sub
        [4, 6], [5, 6],
      ];

      // Host always fires. After each host shot, guest fires a miss so turn
      // flips back to host.
      List<HostResponse> lastResponses = [];
      for (var i = 0; i < targets.length; i++) {
        final t = targets[i];
        lastResponses = engine.processMessage(kHost, {
          'type': 'fire_shot',
          'session_id': 'local_session',
          'payload': {'x': t[0], 'y': t[1]},
        });

        // Check if game_over was emitted.
        final gameOver = _findType(lastResponses, 'game_over');
        if (gameOver != null) {
          // We're done — verify we've processed all targets.
          expect(i, equals(targets.length - 1), reason: 'game_over should trigger on last shot');
          break;
        }

        // Not done yet — guest fires a miss to hand back the turn.
        // Use unique cells: row 7 cols 0-7, then row 1 cols 0-7
        final missX = i % 8;
        final missY = i < 8 ? 7 : 1; // both rows are empty in host fleet
        engine.processMessage(kGuest, {
          'type': 'fire_shot',
          'session_id': 'local_session',
          'payload': {'x': missX, 'y': missY},
        });
      }

      final gameOver = _findType(lastResponses, 'game_over');
      expect(gameOver, isNotNull);
      expect(gameOver!.target, equals('both'));

      final goPayload = gameOver.message['payload'] as Map<String, dynamic>;
      expect(goPayload['winner_device_id'], equals(kHost));
      expect(goPayload['reason'], equals('all_ships_sunk'));
    });
  });

  // -------------------------------------------------------------------------
  // 10. Wrong turn → error
  // -------------------------------------------------------------------------
  group('wrong turn', () {
    test('firing on wrong turn returns error', () {
      final engine = _setupBattle();
      // activeTurn is kHost initially; guest fires = wrong turn.
      final responses = engine.processMessage(kGuest, {
        'type': 'fire_shot',
        'session_id': 'local_session',
        'payload': {'x': 0, 'y': 0},
      });

      final err = _findType(responses, 'error');
      expect(err, isNotNull);
      final payload = err!.message['payload'] as Map<String, dynamic>;
      expect(payload['message'], contains('not your turn'));
    });
  });

  // -------------------------------------------------------------------------
  // 11. Rematch → lobby_state with rematch:true
  // -------------------------------------------------------------------------
  group('request_rematch', () {
    test('rematch resets state and sends lobby_state with rematch:true', () {
      final engine = _setupBattle();

      final responses = engine.processMessage(kHost, {
        'type': 'request_rematch',
        'session_id': 'local_session',
      });

      final lobbyState = _findType(responses, 'lobby_state');
      expect(lobbyState, isNotNull);
      expect(lobbyState!.target, equals('both'));

      final payload = lobbyState.message['payload'] as Map<String, dynamic>;
      expect(payload['rematch'], isTrue);
      expect(payload['host_name'], equals(kHostName));
      expect(payload['guest_name'], equals(kGuestName));

      // Phase should be back to 'place'.
      expect(engine.phase, equals('place'));
    });

    test('can submit fleet again after rematch', () {
      final engine = _setupBattle();
      engine.processMessage(kHost, {
        'type': 'request_rematch',
        'session_id': 'local_session',
      });

      final responses = engine.processMessage(kHost, {
        'type': 'submit_fleet',
        'session_id': 'local_session',
        'payload': {'ships': validFleet()},
      });

      expect(_findType(responses, 'fleet_valid'), isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // 12. Leave → peer_left
  // -------------------------------------------------------------------------
  group('leave_session', () {
    test('host leaving notifies guest with peer_left', () {
      final engine = _setupBothJoined();

      final responses = engine.processMessage(kHost, {
        'type': 'leave_session',
        'session_id': 'local_session',
      });

      final peerLeft = _findType(responses, 'peer_left');
      expect(peerLeft, isNotNull);
      expect(peerLeft!.target, equals('guest'));

      final payload = peerLeft.message['payload'] as Map<String, dynamic>;
      expect(payload['player_name'], equals(kHostName));
    });

    test('guest leaving notifies host with peer_left', () {
      final engine = _setupBothJoined();

      final responses = engine.processMessage(kGuest, {
        'type': 'leave_session',
        'session_id': 'local_session',
      });

      final peerLeft = _findType(responses, 'peer_left');
      expect(peerLeft, isNotNull);
      expect(peerLeft!.target, equals('host'));

      final payload = peerLeft.message['payload'] as Map<String, dynamic>;
      expect(payload['player_name'], equals(kGuestName));
    });

    test('leaving before guest joins returns empty responses', () {
      final engine = _setupHostSession();

      final responses = engine.processMessage(kHost, {
        'type': 'leave_session',
        'session_id': 'local_session',
      });

      // No opponent to notify.
      expect(_findType(responses, 'peer_left'), isNull);
    });
  });
}
