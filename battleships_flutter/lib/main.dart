import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/ota_controller.dart';
import 'providers/battle_provider.dart';
import 'screens/home_screen.dart';
import 'screens/placement_screen.dart';
import 'screens/battle_screen.dart';
import 'screens/result_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final otaController = OtaController(appId: 'battleships');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BattleProvider()),
        ChangeNotifierProvider.value(value: otaController),
      ],
      child: const BattleshipsApp(),
    ),
  );

  await otaController.onAppStarted();
}

class BattleshipsApp extends StatelessWidget {
  const BattleshipsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battleships',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: Colors.white,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      home: const BattleRouter(),
    );
  }
}

class BattleRouter extends StatelessWidget {
  const BattleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<BattleProvider>().phase;

    return switch (phase) {
      BattlePhase.home || BattlePhase.lobby => const HomeScreen(),
      BattlePhase.place => const PlacementScreen(),
      BattlePhase.battle => const BattleScreen(),
      BattlePhase.gameOver => const ResultScreen(),
    };
  }
}
