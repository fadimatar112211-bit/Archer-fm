import 'package:flutter/material.dart';

import 'hero/hero_assets.dart';
import 'hero/hero_viewer_screen.dart';

/// One loader for the app lifetime so decoded atlases are not thrown away when
/// MaterialApp rebuilds.
final HeroAssetLoader _defaultLoader = BundleHeroAssetLoader();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArcherFmApp());
}

class ArcherFmApp extends StatelessWidget {
  const ArcherFmApp({super.key, this.loader});

  /// Tests can inject a loader; the running game uses the bundled Ranger atlas.
  final HeroAssetLoader? loader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archer FM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff247b51),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07110C),
        useMaterial3: true,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HeroViewerScreen(loader: loader ?? _defaultLoader),
      ),
    );
  }
}
