import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Raw 32-byte Ed25519 public key for OTA manifest signature verification.
const _otaPublicKeyBytes = <int>[
  0xdb, 0x75, 0x2b, 0xa9, 0x7a, 0xdb, 0xd0, 0x98, //
  0x8e, 0x44, 0xcd, 0xbc, 0x28, 0x36, 0x8c, 0x05,
  0x34, 0x30, 0x09, 0xc9, 0xde, 0x67, 0xf9, 0xbe,
  0x6a, 0x88, 0x5c, 0xe7, 0xe5, 0x0d, 0xdd, 0x41,
];

const _manifestUrl = 'https://ota.mos6581.cc/manifest.json';
const _manifestSigUrl = 'https://ota.mos6581.cc/manifest.sig';
const _timeout = Duration(seconds: 5);

const _installChannel = MethodChannel('dev.kass.ota/install');

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class OtaUpdate {
  final String versionName;
  final int versionCode;
  final String url;
  final String sha256;

  const OtaUpdate({
    required this.versionName,
    required this.versionCode,
    required this.url,
    required this.sha256,
  });

  Map<String, dynamic> toJson() => {
        'versionName': versionName,
        'versionCode': versionCode,
        'url': url,
        'sha256': sha256,
      };

  factory OtaUpdate.fromJson(Map<String, dynamic> j) => OtaUpdate(
        versionName: j['versionName'] as String,
        versionCode: j['versionCode'] as int,
        url: j['url'] as String,
        sha256: j['sha256'] as String,
      );
}

sealed class OtaCheckResult {
  const OtaCheckResult();
}

class OtaNoUpdate extends OtaCheckResult {
  const OtaNoUpdate();
}

class OtaUpdateAvailable extends OtaCheckResult {
  final OtaUpdate update;
  const OtaUpdateAvailable(this.update);
}

class OtaCheckError extends OtaCheckResult {
  final String message;
  const OtaCheckError(this.message);
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class OtaService {
  const OtaService._();

  /// Check the OTA manifest for an update for [appId].
  static Future<OtaCheckResult> checkForUpdate(String appId) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.parse(info.buildNumber);

      final responses = await Future.wait([
        http.get(Uri.parse(_manifestUrl)).timeout(_timeout),
        http.get(Uri.parse(_manifestSigUrl)).timeout(_timeout),
      ]);
      final manifestResp = responses[0];
      final sigResp = responses[1];

      if (manifestResp.statusCode != 200 || sigResp.statusCode != 200) {
        return const OtaCheckError('Server error');
      }

      // Verify Ed25519 signature
      final valid = await _verifySignature(
        manifestResp.bodyBytes,
        sigResp.bodyBytes,
      );
      if (!valid) {
        return const OtaCheckError('Invalid signature');
      }

      final manifest =
          jsonDecode(manifestResp.body) as Map<String, dynamic>;
      final entry = manifest[appId] as Map<String, dynamic>?;
      if (entry == null) return const OtaNoUpdate();

      final latestCode = entry['versionCode'] as int;
      if (latestCode > currentCode) {
        return OtaUpdateAvailable(OtaUpdate(
          versionName: entry['versionName'] as String,
          versionCode: latestCode,
          url: entry['url'] as String,
          sha256: entry['sha256'] as String,
        ));
      }
      return const OtaNoUpdate();
    } on SocketException {
      return const OtaCheckError('No connection');
    } catch (e) {
      return OtaCheckError(e.toString().length > 60
          ? '${e.toString().substring(0, 60)}…'
          : e.toString());
    }
  }

  /// Download APK to app-private storage. Reports progress via [onProgress]
  /// as a 0.0–1.0 fraction (-1 if content-length unknown).
  static Future<File> downloadApk(
    OtaUpdate update, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getApplicationCacheDirectory();
    final file = File('${dir.path}/ota_update.apk');
    if (await file.exists()) await file.delete();

    final request = http.Request('GET', Uri.parse(update.url));
    final streamed =
        await request.send().timeout(const Duration(seconds: 30));
    final total = streamed.contentLength ?? -1;
    var received = 0;

    final sink = file.openWrite();
    try {
      await for (final chunk in streamed.stream
          .timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null) {
          onProgress(total > 0 ? received / total : -1);
        }
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  /// Verify downloaded APK SHA-256 matches expected hash (streaming).
  static Future<bool> verifyApk(File file, String expectedSha256) async {
    Digest? result;
    final sink = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback(
        (chunks) => result = chunks.single,
      ),
    );
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    return result.toString() == expectedSha256.toLowerCase();
  }

  /// Check if the app can install unknown packages.
  static Future<bool> canInstallPackages() async {
    try {
      return await _installChannel.invokeMethod<bool>('canInstallPackages') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Open the system settings screen for install-unknown-apps permission.
  static Future<void> openInstallPermissionSettings() async {
    await _installChannel.invokeMethod<void>('openInstallPermissionSettings');
  }

  /// Launch the Android package installer for the given APK file.
  static Future<void> installApk(File file) async {
    await _installChannel
        .invokeMethod<void>('installApk', {'path': file.path});
  }

  /// Clean up any leftover OTA APK in cache.
  static Future<void> cleanupApk() async {
    try {
      final dir = await getApplicationCacheDirectory();
      final file = File('${dir.path}/ota_update.apk');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Signature verification
  // -------------------------------------------------------------------------

  static Future<bool> _verifySignature(
    Uint8List manifestBytes,
    Uint8List signatureBytes,
  ) async {
    if (signatureBytes.length != 64) return false;
    try {
      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(
        _otaPublicKeyBytes,
        type: KeyPairType.ed25519,
      );
      final signature = Signature(
        signatureBytes,
        publicKey: publicKey,
      );
      return await algorithm.verify(manifestBytes, signature: signature);
    } catch (_) {
      return false;
    }
  }
}
