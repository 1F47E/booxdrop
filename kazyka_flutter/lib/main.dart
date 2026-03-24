import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/live_session_provider.dart';
import 'screens/drawing_screen.dart';
import 'services/device_identity_service.dart';
import 'services/fake_collaboration_transport.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final identity = DeviceIdentityService();
  await identity.init();
  runApp(KazykaApp(identity: identity));
}

class KazykaApp extends StatelessWidget {
  final DeviceIdentityService identity;
  const KazykaApp({super.key, required this.identity});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(
          create: (_) =>
              LiveSessionProvider(FakeCollaborationTransport()),
        ),
        Provider.value(value: identity),
      ],
      child: MaterialApp(
        title: 'Kazyka',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.black,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        home: const DrawingScreen(),
      ),
    );
  }
}
