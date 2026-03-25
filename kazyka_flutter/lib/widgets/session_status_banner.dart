import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/live_session_provider.dart';

class SessionStatusBanner extends StatelessWidget {
  const SessionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LiveSessionProvider>(
      builder: (context, session, _) {
        switch (session.state) {
          case LiveSessionState.idle:
            return const SizedBox.shrink();

          case LiveSessionState.creating:
          case LiveSessionState.joining:
            return _Banner(
              icon: Icons.wifi_tethering,
              trailing: null,
              children: const [
                Text('Connecting...',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            );

          case LiveSessionState.waiting:
            return _Banner(
              icon: Icons.hourglass_empty,
              trailing: TextButton(
                onPressed: () => session.leaveSession(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.black)),
              ),
              children: const [
                Text('Live Drawing',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('Waiting for other device...',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            );

          case LiveSessionState.connected:
            final peerLabel = session.peer?.label ?? 'peer';
            return _Banner(
              icon: Icons.people,
              trailing: TextButton(
                onPressed: () => session.leaveSession(),
                child: const Text('Leave',
                    style: TextStyle(color: Colors.black)),
              ),
              children: [
                Text(
                  'Connected with $peerLabel',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            );

          case LiveSessionState.reconnecting:
            final peerName = session.peer?.label ?? 'Peer';
            return _Banner(
              icon: Icons.wifi_off,
              trailing: TextButton(
                onPressed: () => session.leaveSession(),
                child: const Text('Leave',
                    style: TextStyle(color: Colors.black)),
              ),
              children: [
                Text(
                  '$peerName lost connection',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'Waiting ${session.reconnectSecondsLeft}s for reconnect',
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            );

          case LiveSessionState.error:
            return _Banner(
              icon: Icons.error_outline,
              trailing: TextButton(
                onPressed: () => session.leaveSession(),
                child: const Text('Dismiss',
                    style: TextStyle(color: Colors.black)),
              ),
              children: [
                Text(
                  session.error ?? 'Connection error',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            );
        }
      },
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _Banner({
    required this.icon,
    required this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
          if (trailing != null) ?trailing,
        ],
      ),
    );
  }
}
