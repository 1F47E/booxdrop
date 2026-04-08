import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:math_rpg/controllers/ota_controller.dart';
import 'package:math_rpg/providers/battle_provider.dart';
import 'package:math_rpg/providers/game_provider.dart';
import 'package:math_rpg/main.dart';

void main() {
  testWidgets('App builds and shows home screen', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GameProvider()),
          ChangeNotifierProvider(create: (_) => BattleProvider()),
          ChangeNotifierProvider(
              create: (_) => OtaController(appId: 'math_rpg')),
        ],
        child: const MathRpgApp(),
      ),
    );

    // Should show the title
    expect(find.text('Adventure Math'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);
  });
}
