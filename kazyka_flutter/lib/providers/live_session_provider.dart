import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/canvas_item.dart';
import '../services/collaboration_transport.dart';

enum LiveSessionState {
  idle,
  creating,
  waiting,
  joining,
  connected,
  reconnecting,
  error,
}

class PeerIdentity {
  final String deviceId;
  final String displayName;
  final String deviceLabel;

  PeerIdentity({
    required this.deviceId,
    this.displayName = '',
    this.deviceLabel = '',
  });

  String get label => displayName.isNotEmpty ? displayName : 'device $deviceLabel';

  factory PeerIdentity.fromJson(Map<String, dynamic> json) => PeerIdentity(
        deviceId: json['device_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        deviceLabel: json['device_label'] as String? ?? '',
      );
}

class LiveSessionProvider extends ChangeNotifier {
  final CollaborationTransport _transport;

  LiveSessionState _state = LiveSessionState.idle;
  String? _sessionId;
  String? _joinCode;
  String? _role; // 'host' or 'guest'
  PeerIdentity? _peer;
  String? _error;
  int _reconnectSecondsLeft = 0;
  Timer? _reconnectTimer;
  StreamSubscription? _eventSub;

  // Canvas items from remote
  final List<CanvasStroke> remoteStrokes = [];
  final List<CanvasText> remoteTexts = [];

  // Callback for when remote host clears the canvas
  VoidCallback? onRemoteClear;

  LiveSessionState get state => _state;
  String? get sessionId => _sessionId;
  String? get joinCode => _joinCode;
  String? get role => _role;
  PeerIdentity? get peer => _peer;
  String? get error => _error;
  int get reconnectSecondsLeft => _reconnectSecondsLeft;
  bool get isLive => _state == LiveSessionState.connected ||
      _state == LiveSessionState.waiting;
  bool get isHost => _role == 'host';

  LiveSessionProvider(this._transport);

  Future<void> connectAuto({
    required String deviceId,
    required String displayName,
    required String serverUrl,
  }) async {
    _state = LiveSessionState.creating;
    _error = null;
    notifyListeners();

    try {
      await _transport.connect(serverUrl);
      _listenToEvents();

      _transport.send({
        'type': 'hello',
        'payload': {
          'device_id': deviceId,
          'display_name': displayName,
          'platform': 'android',
          'app_version': '1.0.0',
        },
      });

      _transport.send({
        'type': 'connect',
        'payload': {'device_id': deviceId},
      });
    } catch (e) {
      _state = LiveSessionState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> createSession({
    required String deviceId,
    required String displayName,
    required String serverUrl,
  }) async {
    _state = LiveSessionState.creating;
    _error = null;
    notifyListeners();

    try {
      await _transport.connect(serverUrl);
      _listenToEvents();

      _transport.send({
        'type': 'hello',
        'payload': {
          'device_id': deviceId,
          'display_name': displayName,
          'platform': 'android',
          'app_version': '1.0.0',
        },
      });

      _transport.send({
        'type': 'create_session',
        'payload': {'device_id': deviceId},
      });
    } catch (e) {
      _state = LiveSessionState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> joinSession({
    required String code,
    required String deviceId,
    required String displayName,
    required String serverUrl,
  }) async {
    _state = LiveSessionState.joining;
    _error = null;
    notifyListeners();

    try {
      await _transport.connect(serverUrl);
      _listenToEvents();

      _transport.send({
        'type': 'hello',
        'payload': {
          'device_id': deviceId,
          'display_name': displayName,
          'platform': 'android',
          'app_version': '1.0.0',
        },
      });

      _transport.send({
        'type': 'join_session',
        'payload': {
          'device_id': deviceId,
          'join_code': code.toUpperCase(),
        },
      });
    } catch (e) {
      _state = LiveSessionState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resumeSession({
    required String deviceId,
    required String displayName,
    required String serverUrl,
  }) async {
    // Check for cached session
    final prefs = await SharedPreferences.getInstance();
    final cachedSessionId = prefs.getString('live_session_id');
    if (cachedSessionId == null) return;

    _state = LiveSessionState.joining;
    _error = null;
    notifyListeners();

    try {
      await _transport.connect(serverUrl);
      _listenToEvents();

      _transport.send({
        'type': 'hello',
        'payload': {
          'device_id': deviceId,
          'display_name': displayName,
          'platform': 'android',
          'app_version': '1.0.0',
        },
      });

      _transport.send({
        'type': 'resume_session',
        'payload': {
          'session_id': cachedSessionId,
          'device_id': deviceId,
        },
      });
    } catch (e) {
      // Resume failed — clear cache and go idle
      await prefs.remove('live_session_id');
      _state = LiveSessionState.idle;
      notifyListeners();
    }
  }

  Future<void> _cacheSessionId() async {
    if (_sessionId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('live_session_id', _sessionId!);
    }
  }

  Future<void> _clearSessionCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('live_session_id');
  }

  Future<void> leaveSession() async {
    _reconnectTimer?.cancel();
    if (_sessionId != null) {
      _transport.send({
        'type': 'leave_session',
        'session_id': _sessionId,
      });
    }
    await _transport.disconnect();
    _eventSub?.cancel();
    await _clearSessionCache();
    _reset();
    notifyListeners();
  }

  void sendStrokeStart(CanvasStroke stroke) {
    if (!isLive) return;
    _transport.send({
      'type': 'stroke_start',
      'session_id': _sessionId,
      'payload': {
        'stroke_id': stroke.id,
        'color_value': stroke.colorValue,
        'width': stroke.width,
      },
    });
  }

  void sendStrokePoints(String strokeId, List<List<double>> points) {
    if (!isLive) return;
    _transport.send({
      'type': 'stroke_points',
      'session_id': _sessionId,
      'payload': {
        'stroke_id': strokeId,
        'points': points,
      },
    });
  }

  void sendStrokeEnd(String strokeId) {
    if (!isLive) return;
    _transport.send({
      'type': 'stroke_end',
      'session_id': _sessionId,
      'payload': {'stroke_id': strokeId},
    });
  }

  void sendTextAdd(CanvasText text) {
    if (!isLive) return;
    _transport.send({
      'type': 'text_add',
      'session_id': _sessionId,
      'payload': text.toJson(),
    });
  }

  void sendClear() {
    if (!isLive || !isHost) return;
    _transport.send({
      'type': 'clear',
      'session_id': _sessionId,
    });
  }

  void _listenToEvents() {
    _eventSub?.cancel();
    _eventSub = _transport.events.listen(_handleEvent);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final payload = event['payload'] as Map<String, dynamic>?;

    switch (type) {
      case 'session_created':
        _sessionId = payload?['session_id'] as String?;
        _joinCode = payload?['join_code'] as String?;
        _role = payload?['role'] as String?;
        // Host waits for peer; guest stays in joining until peer_joined arrives
        _state = _role == 'host'
            ? LiveSessionState.waiting
            : LiveSessionState.joining;
        _cacheSessionId();
        notifyListeners();
        break;

      case 'session_resumed':
        _sessionId = payload?['session_id'] as String?;
        _joinCode = payload?['join_code'] as String?;
        _role = payload?['role'] as String?;
        _state = LiveSessionState.connected;
        _cacheSessionId();
        notifyListeners();
        break;

      case 'waiting_for_peer':
        _state = LiveSessionState.waiting;
        notifyListeners();
        break;

      case 'peer_joined':
        final peerData = payload?['peer'] as Map<String, dynamic>?;
        if (peerData != null) {
          _peer = PeerIdentity.fromJson(peerData);
        }
        _state = LiveSessionState.connected;
        _reconnectTimer?.cancel();
        _reconnectSecondsLeft = 0;
        notifyListeners();
        break;

      case 'peer_left':
        final temporary = payload?['temporary'] as bool? ?? false;
        if (temporary) {
          final deadlineMs =
              payload?['reconnect_deadline_ms'] as int? ?? 45000;
          _state = LiveSessionState.reconnecting;
          _startReconnectCountdown(deadlineMs ~/ 1000);
        } else {
          _peer = null;
          _state = LiveSessionState.waiting;
        }
        notifyListeners();
        break;

      case 'snapshot':
        // version tracked for future sync validation
        final items = payload?['items'] as List? ?? [];
        remoteStrokes.clear();
        remoteTexts.clear();
        for (final item in items) {
          final map = item as Map<String, dynamic>;
          if (map.containsKey('points')) {
            remoteStrokes.add(CanvasStroke.fromJson(map));
          } else if (map.containsKey('text')) {
            remoteTexts.add(CanvasText.fromJson(map));
          }
        }
        notifyListeners();
        break;

      case 'stroke_start':
        if (payload != null) {
          final strokeId = payload['stroke_id'] as String?;
          final colorValue = payload['color_value'] as int?;
          final width = (payload['width'] as num?)?.toDouble();
          if (strokeId != null && colorValue != null && width != null) {
            remoteStrokes.add(CanvasStroke(
              id: strokeId,
              colorValue: colorValue,
              width: width,
            ));
            notifyListeners();
          }
        }
        break;

      case 'stroke_points':
        // Remote peer sent stroke points
        final strokeId = payload?['stroke_id'] as String?;
        final points = (payload?['points'] as List?)
            ?.map((p) =>
                (p as List).map((v) => (v as num).toDouble()).toList())
            .toList();
        if (strokeId != null && points != null) {
          final existing =
              remoteStrokes.where((s) => s.id == strokeId).firstOrNull;
          if (existing != null) {
            existing.points.addAll(points);
          }
        }
        notifyListeners();
        break;

      case 'stroke_end':
        notifyListeners();
        break;

      case 'text_add':
        if (payload != null) {
          remoteTexts.add(CanvasText.fromJson(payload));
          notifyListeners();
        }
        break;

      case 'clear':
        remoteStrokes.clear();
        remoteTexts.clear();
        onRemoteClear?.call();
        notifyListeners();
        break;

      case 'error':
        _error = payload?['message'] as String? ?? 'Unknown error';
        _state = LiveSessionState.error;
        notifyListeners();
        break;

      case 'pong':
        break;
    }
  }

  void _startReconnectCountdown(int seconds) {
    _reconnectSecondsLeft = seconds;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _reconnectSecondsLeft--;
      if (_reconnectSecondsLeft <= 0) {
        timer.cancel();
        _peer = null;
        _state = LiveSessionState.waiting;
      }
      notifyListeners();
    });
  }

  void _reset() {
    _state = LiveSessionState.idle;
    _sessionId = null;
    _joinCode = null;
    _role = null;
    _peer = null;
    _error = null;
    _reconnectSecondsLeft = 0;
    _reconnectTimer?.cancel();
    remoteStrokes.clear();
    remoteTexts.clear();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }
}
