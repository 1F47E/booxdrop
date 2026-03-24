import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/drawing_screen.dart';
import 'services/settings_service.dart';

void main() {
  runApp(const KazykaApp());
}

class KazykaApp extends StatelessWidget {
  const KazykaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsService(),
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
