import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio_service.dart';
import 'game/army_selection_screen.dart';
import 'game/combat/hero_kit.dart';
import 'game/home_screen.dart' as menu;
import 'game/settings.dart';
import 'game/settings_screen.dart';
import 'game/net/lobby_screen.dart';
import 'game/progress/hero_progress.dart';
import 'game/progress/progression_screen.dart';
import 'hero/hero_assets.dart';
import 'hero/hero_catalog.dart';
import 'hero/hero_viewer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final audio = MethodChannelAudioService();
  await audio.initialize();
  final settings = await SharedPreferencesSettingsStore().load();
  await audio.setMusicEnabled(settings.musicEnabled);
  await audio.setSfxEnabled(settings.sfxEnabled);
  runApp(ArcherFmApp(audioService: audio));
}

class ArcherFmApp extends StatelessWidget {
  const ArcherFmApp({super.key, this.loaderFactory, this.audioService});

  /// Tests inject fake loaders; the running game decodes the bundled atlases.
  final HeroLoaderFactory? loaderFactory;

  /// Injected by `main()` so playback uses the native channel. Tests that
  /// omit it get a silent service through [AudioScope].
  final AudioService? audioService;

  @override
  Widget build(BuildContext context) {
    final hero = heroCatalog.first;
    return AudioScope(
      service: audioService ?? const NoOpAudioService(),
      child: MaterialApp(
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
          child: menu.MainMenuScreen(
            loaderFactory: loaderFactory ?? defaultHeroLoaderFactory,
          ),
        ),
      ),
    );
  }
}

/// Legacy roster screen kept for its playability-gating tests; the running
/// app now opens the horizontal [menu.MainMenuScreen] instead.
class HeroRosterScreen extends StatelessWidget {
  const HeroRosterScreen({super.key, this.loaderFactory, this.store});

  final HeroLoaderFactory? loaderFactory;

  /// Injectable progress store (tests); the app uses shared preferences.
  final ProgressStore? store;

  @override
  Widget build(BuildContext context) {
    // Heroes with a completed combat build; the rest launch their viewer
    // instead of the battlefield.
    const playableIds = {'ranger_new', 'flame', 'shadow', 'storm'};
    final upgradeHero =
        heroCatalog.firstWhere((hero) => hero.id == 'ranger_new');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archer FM — الأبطال'),
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        actions: [
          TextButton.icon(
            key: const ValueKey('open_lobby'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: LobbyScreen(loaderFactory: loaderFactory, store: store),
                ),
              ),
            ),
            icon: const Icon(Icons.groups, color: Colors.white),
            label: const Text(
              'جماعي',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: const ValueKey('open_progression'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProgressionScreen(
                  hero: upgradeHero,
                  store: store,
                ),
              ),
            ),
            icon: const Icon(Icons.upgrade, color: Colors.white),
            label: const Text(
              'التطوير',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: const ValueKey('open_settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: SettingsScreen(),
                ),
              ),
            ),
            icon: const Icon(Icons.settings, color: Colors.white),
            label: const Text(
              'إعدادات',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
                    TextButton(
                      key: ValueKey('progress_${hero.id}'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProgressionScreen(
                            hero: hero,
                            store: store,
                            initialHeroId: playable ? hero.id : null,
                          ),
                        ),
                      ),
                      child: const Text('تطوير'),
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
                                  builder: (_) => Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: ArmySelectionScreen(
                                      loaderFactory: loaderFactory ??
                                          defaultHeroLoaderFactory,
                                      store: store,
                                    ),
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
