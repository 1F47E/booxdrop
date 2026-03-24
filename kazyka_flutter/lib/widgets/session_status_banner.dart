import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          case LiveSessionState.creating:
          case LiveSessionState.joining:
            return const SizedBox.shrink();

          case LiveSessionState.waiting:
            return _Banner(
              icon: Icons.hourglass_empty,
              children: [
                if (session.joinCode != null) ...[
                  const Text('Live Session',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: session.joinCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Text(
                      'Share code ${session.joinCode}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Waiting for someone to join',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ],
              trailing: TextButton(
                onPressed: () => session.leaveSession(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.black)),
              ),
            );

          case LiveSessionState.connected:
            final peerLabel = session.peer?.label ?? 'peer';
            return _Banner(
              icon: Icons.people,
              children: [
                Text(
                  'Connected with $peerLabel',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
              trailing: TextButton(
                onPressed: () => session.leaveSession(),
                child: const Text('Leave',
                    style: TextStyle(color: Colors.black)),
              ),
            );

          case LiveSessionState.reconnecting:
            final peerName = session.peer?.label ?? 'Peer';
            return _Banner(
              icon: Icons.wifi_off,
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
              trailing: TextButton(
                onPressed: () => session.leaveSession(),
                child: const Text('Leave',
                    style: TextStyle(color: Colors.black)),
              ),
            );

          case LiveSessionState.error:
            return _Banner(
              icon: Icons.error_outline,
              children: [
                Text(
                  session.error ?? 'Connection error',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              trailing: TextButton(
                onPressed: () => session.leaveSession(),
                child: const Text('Dismiss',
                    style: TextStyle(color: Colors.black)),
              ),
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
