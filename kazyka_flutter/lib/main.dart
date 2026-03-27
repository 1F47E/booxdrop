import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/ota_controller.dart';
import 'providers/live_session_provider.dart';
import 'screens/drawing_screen.dart';
import 'services/collaboration_transport.dart';
import 'services/device_identity_service.dart';
import 'services/settings_service.dart';
import 'services/websocket_collaboration_transport.dart';

const serverUrl = 'wss://booxchat.mos6581.cc/ws/live';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final identity = DeviceIdentityService();
  await identity.init();
  final otaController = OtaController(appId: 'kazyka');
  runApp(KazykaApp(identity: identity, otaController: otaController));
  await otaController.onAppStarted();
}

class KazykaApp extends StatelessWidget {
  final DeviceIdentityService identity;
  final OtaController otaController;
  const KazykaApp({
    super.key,
    required this.identity,
    required this.otaController,
  });

  @override
  Widget build(BuildContext context) {
    // Use real websocket in release, fake in debug/test
    final CollaborationTransport transport = kReleaseMode
        ? WebSocketCollaborationTransport()
        : WebSocketCollaborationTransport(); // Use real even in debug for now

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(
          create: (_) => LiveSessionProvider(transport),
        ),
        Provider.value(value: identity),
        ChangeNotifierProvider.value(value: otaController),
      ],
      child: MaterialApp(
        title: 'Kazyka',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: false,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.black,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(elevation: 0, shadowColor: Colors.transparent),
          ),
          appBarTheme: const AppBarTheme(elevation: 0, shadowColor: Colors.transparent),
        ),
        home: const DrawingScreen(),
      ),
    );
  }
}
