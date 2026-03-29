import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/ota_controller.dart';
import 'providers/game_provider.dart';
import 'screens/home_screen.dart';
import 'screens/builder_screen.dart';
import 'screens/race_screen.dart';
import 'screens/result_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final otaController = OtaController(appId: 'maze_race');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider.value(value: otaController),
      ],
      child: const MazeRaceApp(),
    ),
  );

  await otaController.onAppStarted();
}

class MazeRaceApp extends StatelessWidget {
  const MazeRaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maze Game',
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
      GamePhase.home || GamePhase.lobby => const HomeScreen(),
      GamePhase.build || GamePhase.countdown => const BuilderScreen(),
      GamePhase.workshop => const BuilderScreen(),
      GamePhase.race => const RaceScreen(),
      GamePhase.gameOver => const ResultScreen(),
    };
  }
}
