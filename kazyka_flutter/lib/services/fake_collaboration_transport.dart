import 'dart:async';
import 'dart:math';
import 'collaboration_transport.dart';

/// Fake transport for testing live session UX without a real server.
/// Simulates server responses for create/join/hello flows.
class FakeCollaborationTransport implements CollaborationTransport {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _connected = false;
  String? _sessionId;
  String? _joinCode;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  @override
  Future<void> connect(String url) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _connected = true;
  }

  @override
  void send(Map<String, dynamic> message) {
    if (!_connected) return;

    final type = message['type'] as String?;
    switch (type) {
      case 'hello':
        // Acknowledged silently
        break;
      case 'connect':
      case 'create_session':
        _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';
        _joinCode = _generateCode();
        _emit({
          'type': 'session_created',
          'payload': {
            'session_id': _sessionId,
            'join_code': _joinCode,
            'role': 'host',
            'reconnect_window_ms': 45000,
          },
        });
        _emit({'type': 'waiting_for_peer', 'session_id': _sessionId});
        // Simulate a peer joining after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (_connected) {
            _emit({
              'type': 'peer_joined',
              'session_id': _sessionId,
              'payload': {
                'role': 'guest',
                'peer': {
                  'device_id': 'fake_peer_001',
                  'display_name': 'Test Buddy',
                  'device_label': 'F001',
                },
                'resumed': false,
              },
            });
            _emit({
              'type': 'snapshot',
              'session_id': _sessionId,
              'payload': {'version': 0, 'items': []},
            });
          }
        });
        break;
      case 'join_session':
        final code = message['payload']?['join_code'] as String?;
        if (code == null || code.length != 6) {
          _emit({
            'type': 'error',
            'payload': {'message': 'Session not found'},
          });
          break;
        }
        _sessionId = 'sess_joined_${DateTime.now().millisecondsSinceEpoch}';
        _emit({
          'type': 'session_created',
          'payload': {
            'session_id': _sessionId,
            'join_code': code,
            'role': 'guest',
            'reconnect_window_ms': 45000,
          },
        });
        _emit({
          'type': 'peer_joined',
          'session_id': _sessionId,
          'payload': {
            'role': 'host',
            'peer': {
              'device_id': 'fake_host_001',
              'display_name': 'Test Host',
              'device_label': 'H001',
            },
            'resumed': false,
          },
        });
        _emit({
          'type': 'snapshot',
          'session_id': _sessionId,
          'payload': {'version': 0, 'items': []},
        });
        break;
      case 'leave_session':
        _sessionId = null;
        _joinCode = null;
        break;
      case 'stroke_start':
      case 'stroke_points':
      case 'stroke_end':
      case 'text_add':
      case 'clear':
        // In fake transport, echo back to simulate relay
        _emit(message);
        break;
      case 'ping':
        _emit({'type': 'pong'});
        break;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionId = null;
    _joinCode = null;
    await _controller.close();
  }

  void _emit(Map<String, dynamic> message) {
    if (!_controller.isClosed) {
      Future.microtask(() {
        if (!_controller.isClosed) _controller.add(message);
      });
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
