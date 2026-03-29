import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef MsgHandler = void Function(Map<String, dynamic> msg);

class BattleService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  MsgHandler? onMessage;
  void Function()? onDisconnect;
  String? deviceId;
  String? displayName;

  static const serverUrl = 'wss://maze.mos6581.cc/ws/battleships';

  bool get isConnected => _channel != null;

  void connect() {
    disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    _sub = _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        onMessage?.call(msg);
      },
      onDone: () {
        _channel = null;
        onDisconnect?.call();
      },
      onError: (_) {
        _channel = null;
        onDisconnect?.call();
      },
    );
  }

  void send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  void sendHello(String deviceId, String name, String version) {
    this.deviceId = deviceId;
    displayName = name;
    send({
      'type': 'hello',
      'payload': {
        'device_id': deviceId,
        'display_name': name,
        'platform': 'android',
        'app_version': version,
      },
    });
  }

  void autoMatch(String name, String version) {
    send({
      'type': 'auto_match',
      'payload': {
        'display_name': name,
        'app_version': version,
      },
    });
  }

  void createSession(String name, String version) {
    send({
      'type': 'create_session',
      'payload': {
        'display_name': name,
        'app_version': version,
      },
    });
  }

  void joinSession(String code, String name, String version) {
    send({
      'type': 'join_session',
      'payload': {
        'join_code': code,
        'display_name': name,
        'app_version': version,
      },
    });
  }

  void leaveSession(String sessionId) {
    send({
      'type': 'leave_session',
      'session_id': sessionId,
    });
  }

  /// Sends submit_fleet.  [ships] is a list of serialised ship maps.
  void submitFleet(
      String sessionId, List<Map<String, dynamic>> ships) {
    send({
      'type': 'submit_fleet',
      'session_id': sessionId,
      'payload': {'ships': ships},
    });
  }

  /// Sends set_ready.
  void setReady(String sessionId, bool ready) {
    send({
      'type': 'set_ready',
      'session_id': sessionId,
      'payload': {'ready': ready},
    });
  }

  /// Sends fire_shot with coordinates (x, y).
  void fireShot(String sessionId, int x, int y) {
    send({
      'type': 'fire_shot',
      'session_id': sessionId,
      'payload': {'x': x, 'y': y},
    });
  }

  /// Sends request_rematch to reset the session for another game.
  void requestRematch(String sessionId) {
    send({
      'type': 'request_rematch',
      'session_id': sessionId,
    });
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
