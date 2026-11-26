import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arena/arena_screen.dart';
import 'hero/hero_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ArcherFmApp());
}

class ArcherFmApp extends StatelessWidget {
  const ArcherFmApp({super.key, this.loaderFactory});

  /// Kept for backward-compatible constructor signature.
  final dynamic loaderFactory;

  @override
  Widget build(BuildContext context) {
    final hero = heroCatalog.first;
    return MaterialApp(
      title: 'Archer FM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: hero.theme.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: hero.theme.stageBottom,
        useMaterial3: true,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: ArenaScreen(),
      ),
    );
  }
}
