import 'package:flutter/material.dart';

import 'hero/hero_assets.dart';
import 'hero/hero_catalog.dart';
import 'hero/hero_viewer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArcherFmApp());
}

class ArcherFmApp extends StatelessWidget {
  const ArcherFmApp({super.key, this.loaderFactory});

  /// Tests inject fake loaders; the running game decodes the bundled atlases.
  final HeroLoaderFactory? loaderFactory;

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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HeroViewerScreen(
          loaderFactory: loaderFactory ?? defaultHeroLoaderFactory,
        ),
      ),
    );
  }
}
