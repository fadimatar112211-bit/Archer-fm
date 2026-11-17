import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/combat/hero_kit.dart';
import 'game/game_screen.dart';
import 'hero/hero_assets.dart';
import 'hero/hero_catalog.dart';
import 'hero/hero_viewer_screen.dart';

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
        child: HomeScreen(loaderFactory: loaderFactory),
      ),
    );
  }
}

/// Main menu: pick a hero, inspect it in the viewer or take it into battle.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.loaderFactory});

  final HeroLoaderFactory? loaderFactory;

  @override
  Widget build(BuildContext context) {
    // Heroes with a completed combat build; the rest launch their viewer
    // instead of the battlefield.
    const playableIds = {'ranger_new', 'flame', 'shadow'};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archer FM — الأبطال'),
        backgroundColor: Colors.black.withValues(alpha: 0.3),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: heroCatalog.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final hero = heroCatalog[index];
            final kit = kitForHero(hero.id);
            final playable = playableIds.contains(hero.id) && kit.playable;
            return Container(
              decoration: BoxDecoration(
                color: hero.theme.stageMid.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hero.theme.accent.withValues(alpha: 0.4),
                ),
              ),
              child: ListTile(
                leading: Icon(hero.icon, color: hero.theme.accent, size: 32),
                title: Text(
                  '${hero.nameAr} — ${hero.weaponAr}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  playable
                      ? '${hero.roleAr} · قابلة للعب — ${kit.abilities.length} قدرات'
                      : '${hero.roleAr} · قيد التطوير',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: HeroViewerScreen(
                              initialHero: hero,
                              loaderFactory:
                                  loaderFactory ?? defaultHeroLoaderFactory,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('عرض'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: playable
                            ? hero.theme.accent
                            : Colors.white24,
                        foregroundColor:
                            playable ? Colors.black : Colors.white54,
                      ),
                      onPressed: playable
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GameScreen(
                                    hero: hero,
                                    loaderFactory: loaderFactory ??
                                        defaultHeroLoaderFactory,
                                  ),
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('لعب'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
