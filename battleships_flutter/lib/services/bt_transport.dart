// lib/services/bt_transport.dart
//
// Bluetooth RFCOMM transports for Battleships.
//
// BtHostTransport  — becomes discoverable, accepts one guest connection, runs
//                    a LocalBattleHost in-process.
// BtGuestTransport — scans for devices, connects to a chosen host device.
//
// Both implement GameTransport with NDJSON framing over RFCOMM.
//
// NOTE ON SERVER SOCKETS
// flutter_bluetooth_serial 0.4.x is a client-only library — it exposes no
// server-socket (incoming connection) API from Dart.
//
// BtHostTransport solves this via a [connectionProvider] factory function that
// returns a Future<BluetoothConnection>.  The default implementation calls the
// 'battleships/bt_host' MethodChannel ('listen' method) which the Android host
// app must implement: open a BluetoothServerSocket with the SPP UUID, block on
// accept(), write the guest device address back, and then let
// BluetoothConnection.toAddress() connect outward to complete the handshake.
// This keeps all Dart code fully analyzable and avoids touching private APIs.
//
// Callers may inject their own [connectionProvider] for testing or alternative
// transport mechanisms (e.g. a pre-connected mock).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'game_transport.dart';
import 'local_battle_host.dart';
import 'ndjson_codec.dart';

/// Standard Serial Port Profile UUID — shared by host and guest so they agree
/// on the RFCOMM service channel.
const String _sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

/// How long to make the device discoverable when hosting (seconds).
const int _discoverabilitySeconds = 120;

/// MethodChannel used by the default [BtHostTransport] connection provider.
/// The native Android side must implement:
///   - 'listen'      → opens BluetoothServerSocket, blocks until a guest
///                     connects, returns the guest device MAC address (String).
///   - 'disconnect'  → closes the server socket if still waiting.
const MethodChannel _hostChannel = MethodChannel('battleships/bt_host');

/// Default server-side connection provider.
///
/// 1. Calls 'battleships/bt_host' → 'listen' to get the connecting guest's
///    MAC address.
/// 2. Then dials the guest back via [BluetoothConnection.toAddress].
///
/// Both devices end up with a [BluetoothConnection] to each other.
Future<BluetoothConnection> _defaultHostConnectionProvider() async {
  final guestAddress = await _hostChannel.invokeMethod<String>(
    'listen',
    {'uuid': _sppUuid},
  );
  if (guestAddress == null || guestAddress.isEmpty) {
    throw StateError('bt_host "listen" returned no guest address');
  }
  return BluetoothConnection.toAddress(guestAddress);
}

// ---------------------------------------------------------------------------
// BtHostTransport
// ---------------------------------------------------------------------------

/// Host-side Bluetooth transport.
///
/// Lifecycle:
///   1. Optionally supply [connectionProvider] to override how the incoming
///      connection is obtained (useful for tests / custom native code).
///   2. Call [connect] — makes the device discoverable and waits for a guest.
///   3. Once connected, the embedded [LocalBattleHost] processes all messages.
///      Messages routed to 'host' are delivered to [onMessage]; messages
///      routed to 'guest' are written to the RFCOMM stream.
///   4. Host player messages go through [send].
///   5. Call [disconnect] to tear down cleanly.
class BtHostTransport extends GameTransport {
  /// Stable device ID used when submitting host messages to the local engine.
  final String hostDeviceId;

  /// Display name forwarded to the game engine.
  final String hostDisplayName;

  /// App version string forwarded to the game engine.
  final String appVersion;

  /// Factory that produces the incoming [BluetoothConnection] on the host
  /// side.  Override to inject a mock or custom native bridge.
  final Future<BluetoothConnection> Function() connectionProvider;

  BtHostTransport({
    required this.hostDeviceId,
    required this.hostDisplayName,
    required this.appVersion,
    Future<BluetoothConnection> Function()? connectionProvider,
  }) : connectionProvider =
            connectionProvider ?? _defaultHostConnectionProvider;

  BluetoothConnection? _connection;
  late LocalBattleHost _localHost;
  final NdjsonCodec _codec = NdjsonCodec();
  bool _connected = false;
  StreamSubscription<Uint8List>? _inputSub;

  // -------------------------------------------------------------------------
  // GameTransport interface
  // -------------------------------------------------------------------------

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _localHost = LocalBattleHost();

    // Request discoverability so the guest can find this device.
    try {
      await FlutterBluetoothSerial.instance
          .requestDiscoverable(_discoverabilitySeconds);
    } catch (_) {
      // Discoverability may be denied — continue; already-paired guests can
      // still connect.
    }

    try {
      _connection = await connectionProvider();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('MissingPlugin')) {
        onDisconnect?.call('Bluetooth hosting not supported on this device');
      } else {
        onDisconnect?.call('Could not start Bluetooth game');
      }
      return;
    }

    _connected = true;
    _startListening();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _inputSub?.cancel();
    _inputSub = null;
    try {
      await _connection?.finish();
    } catch (_) {}
    _connection = null;
    _codec.reset();
    try {
      await _hostChannel.invokeMethod<void>('disconnect');
    } catch (_) {}
  }

  /// Send a message from the host player into the local engine.
  ///
  /// Responses routed to 'host' are delivered to [onMessage]; those routed to
  /// 'guest' are written to the RFCOMM stream.
  @override
  void send(Map<String, dynamic> msg) {
    if (!_connected) return;
    _routeHostMessage(msg);
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  void _startListening() {
    final input = _connection?.input;
    if (input == null) {
      _onConnectionLost();
      return;
    }
    _inputSub = input.listen(
      _onGuestBytes,
      onDone: _onConnectionLost,
      onError: (_) => _onConnectionLost(),
      cancelOnError: true,
    );
  }

  void _onGuestBytes(Uint8List bytes) {
    final chunk = utf8.decode(bytes, allowMalformed: true);
    final messages = _codec.decode(chunk);
    for (final msg in messages) {
      _processGuestMessage(msg);
    }
  }

  void _processGuestMessage(Map<String, dynamic> msg) {
    try {
      final guestId = _extractDeviceId(msg, fallback: 'guest_device');
      final responses = _localHost.processMessage(guestId, msg);
      _dispatchResponses(responses);
    } catch (_) {
      // Swallow — bad messages must not crash the host.
    }
  }

  void _routeHostMessage(Map<String, dynamic> msg) {
    try {
      final responses = _localHost.processMessage(hostDeviceId, msg);
      _dispatchResponses(responses);
    } catch (_) {}
  }

  void _dispatchResponses(List<HostResponse> responses) {
    for (final resp in responses) {
      switch (resp.target) {
        case 'host':
          onMessage?.call(resp.message);
        case 'guest':
          _sendToGuest(resp.message);
        case 'both':
          onMessage?.call(resp.message);
          _sendToGuest(resp.message);
        default:
          onMessage?.call(resp.message);
      }
    }
  }

  void _sendToGuest(Map<String, dynamic> msg) {
    if (!_connected || _connection == null) return;
    try {
      final line = NdjsonCodec.encode(msg);
      _connection!.output.add(Uint8List.fromList(utf8.encode(line)));
    } catch (_) {
      _onConnectionLost();
    }
  }

  void _onConnectionLost() {
    if (!_connected) return;
    _connected = false;
    onDisconnect?.call('bluetooth connection lost');
  }

  static String _extractDeviceId(
    Map<String, dynamic> msg, {
    required String fallback,
  }) {
    final payload = msg['payload'];
    if (payload is Map<String, dynamic>) {
      final id = payload['device_id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return fallback;
  }
}

// ---------------------------------------------------------------------------
// BtGuestTransport
// ---------------------------------------------------------------------------

/// Guest-side Bluetooth transport.
///
/// Lifecycle:
///   1. Set [targetDevice] to the [BluetoothDevice] to connect to (obtain via
///      [scanForDevices]).
///   2. Call [connect] — dials the host device over RFCOMM.
///   3. Use [send] to transmit messages; [onMessage] fires for each received
///      message.
///   4. Call [disconnect] to tear down cleanly.
class BtGuestTransport extends GameTransport {
  /// The remote host device.  Must be set before calling [connect].
  BluetoothDevice? targetDevice;

  BluetoothConnection? _connection;
  final NdjsonCodec _codec = NdjsonCodec();
  bool _connected = false;
  StreamSubscription<Uint8List>? _inputSub;

  // -------------------------------------------------------------------------
  // GameTransport interface
  // -------------------------------------------------------------------------

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    final device = targetDevice;
    if (device == null) {
      onDisconnect?.call('no target device set');
      return;
    }

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
    } catch (e) {
      onDisconnect?.call('failed to connect: $e');
      return;
    }

    _connected = true;
    _startListening();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _inputSub?.cancel();
    _inputSub = null;
    try {
      await _connection?.finish();
    } catch (_) {}
    _connection = null;
    _codec.reset();
  }

  @override
  void send(Map<String, dynamic> msg) {
    if (!_connected || _connection == null) return;
    try {
      final line = NdjsonCodec.encode(msg);
      _connection!.output.add(Uint8List.fromList(utf8.encode(line)));
    } catch (_) {
      _onConnectionLost();
    }
  }

  // -------------------------------------------------------------------------
  // Scanning helpers
  // -------------------------------------------------------------------------

  /// Returns a one-shot list of nearby discoverable Bluetooth devices.
  ///
  /// Discovery runs for at most [timeoutSeconds] seconds.
  static Future<List<BluetoothDevice>> scanForDevices({
    int timeoutSeconds = 12,
  }) async {
    final devices = <BluetoothDevice>[];
    try {
      final completer = Completer<void>();
      final sub = FlutterBluetoothSerial.instance.startDiscovery().listen(
        (result) => devices.add(result.device),
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      Future.delayed(Duration(seconds: timeoutSeconds), () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
      await sub.cancel();
      try {
        await FlutterBluetoothSerial.instance.cancelDiscovery();
      } catch (_) {}
    } catch (_) {}
    return devices;
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  void _startListening() {
    final input = _connection?.input;
    if (input == null) {
      _onConnectionLost();
      return;
    }
    _inputSub = input.listen(
      _onBytes,
      onDone: _onConnectionLost,
      onError: (_) => _onConnectionLost(),
      cancelOnError: true,
    );
  }

  void _onBytes(Uint8List bytes) {
    final chunk = utf8.decode(bytes, allowMalformed: true);
    final messages = _codec.decode(chunk);
    for (final msg in messages) {
      try {
        onMessage?.call(msg);
      } catch (_) {}
    }
  }

  void _onConnectionLost() {
    if (!_connected) return;
    _connected = false;
    onDisconnect?.call('bluetooth connection lost');
  }
}
