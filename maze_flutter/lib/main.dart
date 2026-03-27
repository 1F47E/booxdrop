import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/home_screen.dart';
import 'screens/builder_screen.dart';
import 'screens/race_screen.dart';
import 'screens/result_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: const MazeRaceApp(),
    ),
  );
}

class MazeRaceApp extends StatelessWidget {
  const MazeRaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maze Race',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
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
      GamePhase.race => const RaceScreen(),
      GamePhase.gameOver => const ResultScreen(),
    };
  }
}
