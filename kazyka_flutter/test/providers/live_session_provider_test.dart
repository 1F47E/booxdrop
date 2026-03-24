import 'package:flutter_test/flutter_test.dart';
import 'package:kazyka/providers/live_session_provider.dart';
import 'package:kazyka/services/fake_collaboration_transport.dart';

void main() {
  group('LiveSessionProvider', () {
    late FakeCollaborationTransport transport;
    late LiveSessionProvider provider;

    setUp(() {
      transport = FakeCollaborationTransport();
      provider = LiveSessionProvider(transport);
    });

    tearDown(() {
      provider.dispose();
    });

    test('starts in idle state', () {
      expect(provider.state, LiveSessionState.idle);
      expect(provider.isLive, isFalse);
      expect(provider.sessionId, isNull);
      expect(provider.joinCode, isNull);
    });

    test('createSession transitions to waiting then connected', () async {
      final states = <LiveSessionState>[];
      provider.addListener(() => states.add(provider.state));

      await provider.createSession(
        deviceId: 'test_device',
        displayName: 'Test User',
        serverUrl: 'ws://fake',
      );

      // Allow microtasks to complete
      await Future.delayed(const Duration(milliseconds: 200));

      expect(states, contains(LiveSessionState.creating));
      expect(states, contains(LiveSessionState.waiting));
      expect(provider.joinCode, isNotNull);
      expect(provider.joinCode!.length, 6);
      expect(provider.role, 'host');
      expect(provider.isHost, isTrue);

      // Wait for fake peer to join (2 seconds)
      await Future.delayed(const Duration(seconds: 3));

      expect(provider.state, LiveSessionState.connected);
      expect(provider.peer, isNotNull);
      expect(provider.peer!.displayName, 'Test Buddy');
    });

    test('joinSession transitions to connected', () async {
      await provider.joinSession(
        code: 'ABCDEF',
        deviceId: 'test_device',
        displayName: 'Joiner',
        serverUrl: 'ws://fake',
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect(provider.state, LiveSessionState.connected);
      expect(provider.peer, isNotNull);
      expect(provider.peer!.displayName, 'Test Host');
      expect(provider.role, 'guest');
    });

    test('leaveSession resets to idle', () async {
      await provider.createSession(
        deviceId: 'test_device',
        displayName: 'Test User',
        serverUrl: 'ws://fake',
      );
      await Future.delayed(const Duration(milliseconds: 200));

      await provider.leaveSession();

      expect(provider.state, LiveSessionState.idle);
      expect(provider.sessionId, isNull);
      expect(provider.peer, isNull);
    });

    test('PeerIdentity.label prefers displayName over deviceLabel', () {
      final withName = PeerIdentity(
        deviceId: 'abc',
        displayName: 'Kass',
        deviceLabel: 'ABC1',
      );
      expect(withName.label, 'Kass');

      final withoutName = PeerIdentity(
        deviceId: 'abc',
        displayName: '',
        deviceLabel: 'ABC1',
      );
      expect(withoutName.label, 'device ABC1');
    });
  });
}
