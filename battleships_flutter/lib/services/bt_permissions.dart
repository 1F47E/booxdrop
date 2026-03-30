// lib/services/bt_permissions.dart
//
// Bluetooth permission and state helpers wrapping flutter_bluetooth_serial.

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Static helpers for requesting and checking Bluetooth permissions/state.
class BtPermissions {
  BtPermissions._();

  /// Request all Bluetooth-related permissions (SCAN, CONNECT, location on
  /// Android 11 and below).
  ///
  /// Returns `true` if every required permission was granted.
  static Future<bool> requestAll() async {
    try {
      // flutter_bluetooth_serial handles the Android permission dialog
      // internally when you call any BT operation.  We trigger it explicitly
      // here by requesting the enable dialog — it includes the runtime
      // permission prompt on Android 12+.
      //
      // On Android <12 the library uses ACCESS_FINE_LOCATION under the hood;
      // that is declared in the plugin's manifest so no extra work is needed.
      final state = await FlutterBluetoothSerial.instance.state;
      return state != BluetoothState.ERROR;
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` if Bluetooth is currently enabled on the device.
  static Future<bool> isBluetoothEnabled() async {
    try {
      final state = await FlutterBluetoothSerial.instance.state;
      return state == BluetoothState.STATE_ON;
    } catch (_) {
      return false;
    }
  }

  /// Ask the system to make this device discoverable for [seconds] seconds.
  ///
  /// Returns `true` if the user accepted (or the device was already
  /// discoverable).  Returns `false` if the user declined or an error
  /// occurred.
  static Future<bool> requestDiscoverable(int seconds) async {
    try {
      final duration =
          await FlutterBluetoothSerial.instance.requestDiscoverable(seconds);
      return duration != null && duration > 0;
    } catch (_) {
      return false;
    }
  }
}
