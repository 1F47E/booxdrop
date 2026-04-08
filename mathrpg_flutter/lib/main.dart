import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/ota_controller.dart';
import 'providers/battle_provider.dart';
import 'providers/game_provider.dart';
import 'screens/adventure_map_screen.dart';
import 'screens/battle_screen.dart';
import 'screens/character_creation_screen.dart';
import 'screens/character_screen.dart';
import 'screens/defeat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/victory_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final otaController = OtaController(appId: 'math_rpg');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => BattleProvider()),
        ChangeNotifierProvider.value(value: otaController),
      ],
      child: const MathRpgApp(),
    ),
  );

  await otaController.onAppStarted();
}

class MathRpgApp extends StatelessWidget {
  const MathRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math RPG',
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
      home: const GameRouter(),
    );
  }
}

class GameRouter extends StatelessWidget {
  const GameRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<GameProvider>().phase;

    return switch (phase) {
      GamePhase.home => const HomeScreen(),
      GamePhase.characterCreation => const CharacterCreationScreen(),
      GamePhase.adventureMap => const AdventureMapScreen(),
      GamePhase.battle => const BattleScreen(),
      GamePhase.victory => const VictoryScreen(),
      GamePhase.defeat => const DefeatScreen(),
      GamePhase.inventory => const InventoryScreen(),
      GamePhase.characterSheet => const CharacterScreen(),
      GamePhase.settings => const SettingsScreen(),
    };
  }
}
