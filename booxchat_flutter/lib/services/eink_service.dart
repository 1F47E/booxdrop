import 'package:flutter/services.dart';

/// Wrapper around the Onyx SDK native channel.
/// All calls are silent no-ops on non-BOOX devices.
class EinkService {
  static const _channel = MethodChannel('com.booxchat.app/eink');

  /// Triggers a full e-ink screen refresh.
  /// Call after major UI changes to clear ghosting residue.
  static Future<void> requestFullRefresh() async {
    try {
      await _channel.invokeMethod<void>('requestFullRefresh');
    } on MissingPluginException {
      // Running on non-Android platform (web, iOS) — ignore
    } catch (_) {
      // Not a BOOX device or SDK unavailable — ignore
    }
  }

  /// Sets REGAL refresh mode for the app — optimised for text/reading.
  /// Called once at app start; persists for the app session.
  static Future<void> setRegalMode() async {
    try {
      await _channel.invokeMethod<void>('setRegalMode');
    } on MissingPluginException {
      // ignore
    } catch (_) {
      // ignore
    }
  }
}
