import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../controllers/ota_controller.dart';

/// Pinned at the bottom of the burger-menu drawer.
/// Shows current version, and — when an update is available — an update button
/// or progress bar directly above it.
class OtaMenuFooter extends StatelessWidget {
  const OtaMenuFooter({super.key, required this.controller});

  final OtaController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error line
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
              ],

              // Action area (button / progress / permission prompt)
              _buildAction(state),

              // Version text — always visible
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) {
                  final v = snap.data;
                  return Text(
                    v != null ? 'v${v.version} (${v.buildNumber})' : '',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAction(OtaState state) {
    switch (state.phase) {
      case OtaPhase.idle:
      case OtaPhase.checking:
      case OtaPhase.noUpdate:
      case OtaPhase.checkError:
        return const SizedBox.shrink();

      case OtaPhase.updateAvailable:
      case OtaPhase.downloadError:
        final label = state.update != null
            ? 'Update to ${state.update!.versionName}'
            : 'Update';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: controller.startOrResumeUpdate,
              child: Text(label, style: const TextStyle(fontSize: 18)),
            ),
          ),
        );

      case OtaPhase.downloading:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.progress >= 0 ? state.progress : null,
                    backgroundColor: Colors.black12,
                    color: Colors.black,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.progress >= 0
                      ? 'Downloading ${(state.progress * 100).toInt()}%'
                      : 'Downloading…',
                  style: const TextStyle(color: Colors.black54, fontSize: 17),
                ),
              ],
            ),
          ),
        );

      case OtaPhase.permissionRequired:
        final label = state.update != null
            ? 'Continue update to ${state.update!.versionName}'
            : 'Continue update';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Allow installing apps to continue',
                style: TextStyle(color: Colors.black54, fontSize: 17),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: controller.startOrResumeUpdate,
                  child: Text(label, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        );

      case OtaPhase.installing:
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Opening installer…',
            style: TextStyle(color: Colors.black54, fontSize: 17),
          ),
        );
    }
  }
}
