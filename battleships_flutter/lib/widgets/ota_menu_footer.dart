import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../controllers/ota_controller.dart';

/// Pinned at the bottom of the burger-menu drawer.
/// Shows current version, and — when an update is available — an update button
/// or progress bar directly above it.
class OtaMenuFooter extends StatefulWidget {
  const OtaMenuFooter({super.key, required this.controller});

  final OtaController controller;

  @override
  State<OtaMenuFooter> createState() => _OtaMenuFooterState();
}

class _OtaMenuFooterState extends State<OtaMenuFooter> {
  String _versionText = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _versionText = 'v${info.version} (${info.buildNumber})');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
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
                    color: Color(0xFF444444),
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
              ],

              // Action area (button / progress / permission prompt)
              _buildAction(state),

              // Version text — cached, no FutureBuilder flicker
              Text(
                _versionText,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                ),
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
      case OtaPhase.noUpdate:
      case OtaPhase.checkError:
        return const SizedBox.shrink();

      case OtaPhase.checking:
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: _AnimatedDots(text: 'Checking for updates'),
        );

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
              onPressed: widget.controller.startOrResumeUpdate,
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
                    backgroundColor: const Color(0xFFDDDDDD),
                    color: Colors.black,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.progress >= 0
                      ? 'Downloading ${(state.progress * 100).toInt()}%'
                      : 'Downloading\u2026',
                  style: const TextStyle(color: Color(0xFF444444), fontSize: 17),
                ),
              ],
            ),
          ),
        );

      case OtaPhase.verifying:
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: _AnimatedDots(text: 'Verifying'),
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
                style: TextStyle(color: Color(0xFF444444), fontSize: 17),
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
                  onPressed: widget.controller.startOrResumeUpdate,
                  child: Text(label, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        );

      case OtaPhase.installing:
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: _AnimatedDots(text: 'Installing'),
        );
    }
  }
}

/// Displays "Text..." with cycling dots (1->2->3->1->...).
class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots({required this.text});
  final String text;

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> {
  int _dots = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _dots = (_dots % 3) + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.text}${'.' * _dots}',
      style: const TextStyle(color: Color(0xFF444444), fontSize: 17),
    );
  }
}
