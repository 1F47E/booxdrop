import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ota_service.dart';

const _sentinel = Object();

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum OtaPhase {
  idle,
  checking,
  noUpdate,
  updateAvailable,
  checkError,
  downloading,
  verifying,
  permissionRequired,
  installing,
  downloadError,
}

class OtaState {
  final OtaPhase phase;
  final OtaUpdate? update;
  final double progress; // 0.0–1.0, or -1 if unknown
  final String? error;

  const OtaState({
    this.phase = OtaPhase.idle,
    this.update,
    this.progress = 0,
    this.error,
  });

  OtaState copyWith({
    OtaPhase? phase,
    OtaUpdate? update,
    double? progress,
    Object? error = _sentinel,
  }) =>
      OtaState(
        phase: phase ?? this.phase,
        update: update ?? this.update,
        progress: progress ?? this.progress,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class OtaController extends ChangeNotifier with WidgetsBindingObserver {
  OtaController({required this.appId});

  final String appId;

  OtaState _state = const OtaState();
  OtaState get state => _state;

  int _opId = 0; // stale-result guard
  DateTime? _lastCheckAt;
  File? _downloadedApk;

  static const _pendingKey = 'ota_pending_update';
  static const _checkCooldown = Duration(seconds: 30);

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  /// Call once after construction, near app startup.
  Future<void> onAppStarted() async {
    WidgetsBinding.instance.addObserver(this);
    // Restore pending update from prefs (user went to settings and came back).
    await _restorePendingUpdate();
    if (_state.phase == OtaPhase.permissionRequired) return;
    // Silent check after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _silentCheck());
  }

  /// Call every time the drawer/menu opens.
  void onMenuOpened() {
    if (_state.phase == OtaPhase.downloading ||
        _state.phase == OtaPhase.installing) {
      return;
    }
    if (_state.phase == OtaPhase.permissionRequired) {
      return;
    }
    final now = DateTime.now();
    if (_lastCheckAt != null &&
        now.difference(_lastCheckAt!) < _checkCooldown) {
      return;
    }
    _silentCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _state.phase == OtaPhase.permissionRequired) {
      // User returned from settings — try to continue.
      _continueAfterPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Public actions (called from UI)
  // -----------------------------------------------------------------------

  /// Start or resume the update flow.
  Future<void> startOrResumeUpdate() async {
    if (_state.phase == OtaPhase.downloading ||
        _state.phase == OtaPhase.installing) {
      return;
    }

    if (_state.phase == OtaPhase.permissionRequired) {
      await _continueAfterPermission();
      return;
    }

    final update = _state.update;
    if (update == null) {
      // No cached metadata — do a fresh check then start.
      await _checkAndDownload();
      return;
    }
    await _downloadAndInstall(update);
  }

  /// Retry a failed check.
  Future<void> retryCheck() async => _silentCheck();

  // -----------------------------------------------------------------------
  // Internal flows
  // -----------------------------------------------------------------------

  Future<void> _silentCheck() async {
    if (_state.phase == OtaPhase.checking) return;
    final myOp = ++_opId;
    _setState(_state.copyWith(phase: OtaPhase.checking, error: null));

    final result = await OtaService.checkForUpdate(appId);
    if (myOp != _opId) return; // stale

    _lastCheckAt = DateTime.now();

    switch (result) {
      case OtaNoUpdate():
        _setState(_state.copyWith(phase: OtaPhase.noUpdate));
      case OtaUpdateAvailable(:final update):
        _setState(_state.copyWith(
          phase: OtaPhase.updateAvailable,
          update: update,
        ));
      case OtaCheckError(:final message):
        _setState(_state.copyWith(phase: OtaPhase.checkError, error: message));
    }
  }

  Future<void> _checkAndDownload() async {
    final myOp = ++_opId;
    _setState(_state.copyWith(phase: OtaPhase.checking, error: null));

    final result = await OtaService.checkForUpdate(appId);
    if (myOp != _opId) return;

    _lastCheckAt = DateTime.now();

    switch (result) {
      case OtaNoUpdate():
        _setState(_state.copyWith(phase: OtaPhase.noUpdate));
      case OtaUpdateAvailable(:final update):
        _setState(_state.copyWith(
          phase: OtaPhase.updateAvailable,
          update: update,
        ));
        await _downloadAndInstall(update);
      case OtaCheckError(:final message):
        _setState(_state.copyWith(phase: OtaPhase.checkError, error: message));
    }
  }

  Future<void> _downloadAndInstall(OtaUpdate update) async {
    if (_state.phase == OtaPhase.downloading ||
        _state.phase == OtaPhase.installing) {
      return;
    }
    final myOp = ++_opId;
    _setState(_state.copyWith(
      phase: OtaPhase.downloading,
      update: update,
      progress: 0,
      error: null,
    ));

    try {
      final file = await OtaService.downloadApk(
        update,
        onProgress: (p) {
          if (myOp != _opId) return;
          _setState(_state.copyWith(progress: p));
        },
      );
      if (myOp != _opId) return;

      // Verify SHA-256
      _setState(_state.copyWith(phase: OtaPhase.verifying));
      final valid = await OtaService.verifyApk(file, update.sha256);
      if (!valid) {
        await file.delete();
        _setState(_state.copyWith(
          phase: OtaPhase.downloadError,
          error: 'Integrity check failed',
        ));
        return;
      }

      _downloadedApk = file;

      // Check install permission
      final canInstall = await OtaService.canInstallPackages();
      if (!canInstall) {
        await _persistPendingUpdate(update);
        _setState(_state.copyWith(phase: OtaPhase.permissionRequired));
        await OtaService.openInstallPermissionSettings();
        return;
      }

      _setState(_state.copyWith(phase: OtaPhase.installing));
      await OtaService.installApk(file);
      // After handing off to installer, clean up.
      await _clearPendingUpdate();
    } catch (e) {
      if (myOp != _opId) return;
      _setState(_state.copyWith(
        phase: OtaPhase.downloadError,
        update: update,
        error: 'Download failed',
      ));
    }
  }

  Future<void> _continueAfterPermission() async {
    final update = _state.update;
    if (update == null) {
      await _clearPendingUpdate();
      _setState(const OtaState());
      return;
    }

    final canInstall = await OtaService.canInstallPackages();
    if (!canInstall) return; // still no permission

    if (_downloadedApk != null && await _downloadedApk!.exists()) {
      _setState(_state.copyWith(phase: OtaPhase.installing));
      await OtaService.installApk(_downloadedApk!);
      await _clearPendingUpdate();
    } else {
      // APK was lost — re-download.
      await _clearPendingUpdate();
      await _downloadAndInstall(update);
    }
  }

  // -----------------------------------------------------------------------
  // Persistence (survive settings detour)
  // -----------------------------------------------------------------------

  Future<void> _persistPendingUpdate(OtaUpdate update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(update.toJson()));
  }

  Future<void> _clearPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  Future<void> _restorePendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return;
    try {
      final update =
          OtaUpdate.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _downloadedApk = File(
        '${(await getApplicationCacheDirectory()).path}/ota_update.apk',
      );
      _setState(_state.copyWith(
        phase: OtaPhase.permissionRequired,
        update: update,
      ));
    } catch (_) {
      await _clearPendingUpdate();
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  void _setState(OtaState s) {
    _state = s;
    notifyListeners();
  }
}
