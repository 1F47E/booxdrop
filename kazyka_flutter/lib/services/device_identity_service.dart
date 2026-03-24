import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  static const _kDeviceId = 'device_id';
  static const _kDisplayName = 'artist_name';
  static const _platform = MethodChannel('dev.kass.kazyka/device');

  String? _deviceId;
  String? _displayName;

  String get deviceId => _deviceId ?? 'unknown';
  String get displayName => _displayName ?? '';

  /// Short label from last 4 hex chars of device ID, uppercased.
  String get deviceLabel {
    final id = deviceId;
    if (id.length >= 4) {
      return id.substring(id.length - 4).toUpperCase();
    }
    return id.toUpperCase();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _displayName = prefs.getString(_kDisplayName) ?? '';

    // Try Android ID first
    try {
      final androidId = await _platform.invokeMethod<String>('getAndroidId');
      if (androidId != null && androidId.isNotEmpty) {
        _deviceId = androidId;
        return;
      }
    } catch (_) {
      // Not on Android or method channel not available
    }

    // Fallback: persisted install ID
    _deviceId = prefs.getString(_kDeviceId);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = const Uuid().v4().replaceAll('-', '').substring(0, 16);
      await prefs.setString(_kDeviceId, _deviceId!);
    }
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDisplayName, _displayName!);
  }
}

/// Validates a join code format.
/// Valid: 6 chars, uppercase letters (no O/I) + digits (no 0/1).
bool isValidJoinCode(String code) {
  if (code.length != 6) return false;
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return code.split('').every((c) => alphabet.contains(c));
}
