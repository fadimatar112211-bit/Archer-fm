import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;

import '../audio_service.dart';
import '../hero/hero_assets.dart';
import '../hero/hero_catalog.dart';
import '../hero/hero_viewer_screen.dart';
import 'army_selection_screen.dart';
import 'net/hotspot_service.dart';
import 'net/lobby_screen.dart';
import 'social/account_service.dart';
import 'progress/hero_progress.dart';
import 'progress/progression.dart';
import 'progress/progression_screen.dart';
import 'render3/glb.dart';
import 'render3/hero3d_controller.dart';
import 'render3/hero3d_painter.dart';
import 'settings.dart';
import 'settings_screen.dart';

/// Archero-inspired horizontal home screen.
///
/// A skinned 3D hero stands in the middle while the player swipes left/right
/// between three cards: shop, heroes and progression. Navigation is a real
/// [PageView], so the swipe is horizontal and snaps to each card.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    super.key,
    this.loaderFactory = defaultHeroLoaderFactory,
    this.store,
    this.settingsStore,
    this.socialService,
    this.pendingResults,
    this.hero3dBytes,
  });

  final HeroLoaderFactory loaderFactory;
  final ProgressStore? store;
  final SettingsStore? settingsStore;
  final SocialService? socialService;
  final PendingResultStore? pendingResults;

  /// Injectable GLB bytes for tests. When null the bundled model is loaded.
  final Future<Uint8List?> Function(HeroDefinition hero)? hero3dBytes;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  static const playableIds = ['ranger_new', 'flame', 'shadow', 'storm'];

  late HeroDefinition _hero;
  HeroProgress _progress = HeroProgress.initial;
  ProgressionController? _shop;
  Hero3DController? _hero3d;
  Ticker? _ticker;
  int _nowMs = 0;
  int _page = 1;
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    _hero = heroCatalog.firstWhere((h) => playableIds.contains(h.id));
    _pages = PageController(viewportFraction: 0.86, initialPage: _page);
    _loadProgress();
    _load3D();
    AudioScope.of(context).playMusic(MusicTrack.menu);
    // The ticker only runs while a real skinned model is present, so the
    // icon-fallback menu stays idle (and widget tests can settle).
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _ticker?.stop();
    _pages.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _nowMs += elapsed.inMilliseconds.clamp(0, 100);
    final controller = _hero3d;
    if (controller != null) {
      if (controller.clipState != 'idle') {
        controller.playClip(
          'idle',
          loop: true,
          pace: 1.0,
          nowMs: _nowMs,
          events: const [],
        );
      }
      controller.advance(_nowMs, onEvent: (_) {});
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadProgress() async {
    final loaded = await widget.store?.load(_hero.id);
    if (!mounted) return;
    setState(() {
      _progress = loaded ?? HeroProgress.initial;
      _shop = ProgressionController.fromProgress(_hero.id, _progress);
    });
  }

  Future<void> _load3D() async {
    Uint8List? bytes;
    try {
      bytes = await widget.hero3dBytes?.call(_hero);
      if (bytes == null && widget.hero3dBytes == null) {
        for (final path in _candidatePaths(_hero.id)) {
          try {
            bytes = (await rootBundle.load(path)).buffer.asUint8List();
            debugPrint('Home 3D: loaded $path (${bytes.length} bytes)');
            break;
          } catch (error) {
            debugPrint('Home 3D: asset unavailable at $path: $error');
          }
        }
      }
    } catch (_) {
      bytes = null;
    }
    if (!mounted) return;
    if (bytes == null) {
      debugPrint('Home 3D: no bundled GLB found for ${_hero.id}');
      return;
    }
    try {
      debugPrint('Home 3D: parsing ${_hero.id} GLB');
      final model = await GlbModel.load(bytes);
      if (!mounted) return;
      setState(() => _hero3d = Hero3DController(Hero3DModel(model)));
      debugPrint('Home 3D: ${_hero.id} GLB ready');
      if (_ticker != null && !_ticker!.isActive) _ticker!.start();
    } catch (error, stackTrace) {
      debugPrint('Home 3D: failed to load ${_hero.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      // Fallback to the hero icon inside the 3D slot.
    }
  }

  static List<String> _candidatePaths(String heroId) => [
        'assets/heroes/$heroId/model/${heroId}_animated.glb',
        'assets/heroes/$heroId/${heroId}_animated.glb',
        if (heroId == 'ranger_new')
          'assets/heroes/ranger_new/ranger_animated.glb',
      ];

  void _selectHero(HeroDefinition hero) {
    _ticker?.stop();
    setState(() {
      _hero = hero;
      _hero3d = null;
      _shop = null;
      _progress = HeroProgress.initial;
    });
    _loadProgress();
    _load3D();
  }

  Future<void> _persistShop() async {
    final shop = _shop;
    if (shop == null) return;
    final updated = _progress.copyWith(
      essence: shop.currency,
      materials: {
        for (final material in ProgressionMaterial.values)
          material.name: shop.materialOf(material),
      },
      heroUpgradeLevel: shop.heroUpgradeLevel,
      capacityLevel: shop.capacityLevel,
    );
    await widget.store?.save(_hero.id, updated);
    if (!mounted) return;
    setState(() => _progress = updated);
  }

  void _tap() {
    AudioScope.of(context).play(SoundCue.uiTap);
  }

  void _openArmySelection() {
    _tap();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: ArmySelectionScreen(
            loaderFactory: widget.loaderFactory,
            store: widget.store,
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    _tap();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsScreen(store: widget.settingsStore),
        ),
      ),
    );
  }

  void _openLobby() {
    _tap();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: LobbyScreen(
            socialService: widget.socialService,
            pendingResults: widget.pendingResults,
            loaderFactory: widget.loaderFactory,
            store: widget.store,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = size.height < 320;
    return Scaffold(
      body: Stack(
        children: [
          _background(),
          // The skinned 3D hero stays centered while cards swipe underneath.
          Align(
            key: const ValueKey('home_3d_hero'),
            alignment: Alignment.center,
            child: SizedBox(
              width: size.width * 0.42,
              height: size.height * 0.7,
              child: CustomPaint(
                painter: _HomeHeroPainter(
                  controller: _hero3d,
                  color: _hero.theme.accent,
                  icon: _hero.icon,
                ),
              ),
            ),
          ),
          if (_hero3d != null)
            const SizedBox.shrink(key: ValueKey('home_3d_loaded')),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                if (!compactLandscape) const Spacer(),
                if (!compactLandscape) _pageIndicator(),
                SizedBox(
                  height: compactLandscape ? 72 : 132,
                  child: PageView(
                    key: const ValueKey('home_page_view'),
                    controller: _pages,
                    onPageChanged: (index) =>
                        setState(() => _page = index),
                    children: [
                      _shopPage(),
                      _heroesPage(),
                      _progressPage(),
                    ],
                  ),
                ),
                SizedBox(height: compactLandscape ? 4 : 10),
                Padding(
                  padding: EdgeInsets.only(bottom: compactLandscape ? 6 : 12),
                  child: FilledButton.icon(
                    style: compactLandscape
                        ? FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )
                        : null,
                    key: const ValueKey('home_play'),
                    onPressed: _openArmySelection,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('اللعب', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _background() => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _hero.theme.stageTop,
                _hero.theme.stageMid,
                const Color(0xFF08120C),
              ],
            ),
          ),
        ),
      );

  Widget _topBar() {
    final compact = MediaQuery.sizeOf(context).height < 320;
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: compact ? 1 : 6),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Text(
              'ARCHER FM',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 17 : 22,
                fontWeight: FontWeight.bold,
                letterSpacing: compact ? 1 : 2,
              ),
            ),
            const Spacer(),
            IconButton(
              constraints: compact ? const BoxConstraints.tightFor(width: 32, height: 32) : null,
              padding: compact ? EdgeInsets.zero : null,
              visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
              key: const ValueKey('home_online'),
              tooltip: 'جماعي',
              color: Colors.white,
              icon: const Icon(Icons.people),
              onPressed: _openLobby,
            ),
            IconButton(
              constraints: compact ? const BoxConstraints.tightFor(width: 32, height: 32) : null,
              padding: compact ? EdgeInsets.zero : null,
              visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
              key: const ValueKey('home_settings'),
              tooltip: 'إعدادات',
              color: Colors.white,
              icon: const Icon(Icons.settings),
              onPressed: _openSettings,
            ),
          ],
        ),
      );
  }

  Widget _pageIndicator() => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page
                      ? _hero.theme.accent
                      : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      );

  Widget _card({required Key key, required Widget child}) {
    final compactLandscape = MediaQuery.sizeOf(context).height < 320;
    return Container(
        key: key,
        margin: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: compactLandscape ? 2 : 4,
        ),
        padding: EdgeInsets.all(compactLandscape ? 6 : 12),
        decoration: BoxDecoration(
          color: const Color(0xCC0E1B12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _hero.theme.accent, width: 1.4),
        ),
        child: child,
      );
  }

  Widget _shopPage() => _card(
        key: const ValueKey('home_shop_page'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المتجر · الجوهر ${_shop?.currency ?? _progress.essence}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'قوة الحساب ${_shop?.accountPower ?? 1}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _upgradeButton(
                    key: const ValueKey('home_shop_hero_upgrade'),
                    label: 'ترقية البطل',
                    enabled: _shop?.canUpgradeHero ?? false,
                    onTap: () async {
                      if (_shop?.upgradeHero() ?? false) {
                        await _persistShop();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _upgradeButton(
                    key: const ValueKey('home_shop_capacity_upgrade'),
                    label: 'زيادة السعة',
                    enabled: _shop?.canUpgradeCapacity ?? false,
                    onTap: () async {
                      if (_shop?.upgradeCapacity() ?? false) {
                        await _persistShop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _upgradeButton({
    required Key key,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      OutlinedButton(
        key: key,
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: _hero.theme.accent),
          minimumSize: Size(0, MediaQuery.sizeOf(context).height < 320 ? 30 : 40),
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: MediaQuery.sizeOf(context).height < 320 ? 2 : 8,
          ),
          visualDensity: MediaQuery.sizeOf(context).height < 320
              ? VisualDensity.compact
              : VisualDensity.standard,
          tapTargetSize: MediaQuery.sizeOf(context).height < 320
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );

  Widget _heroesPage() => _card(
        key: const ValueKey('home_heroes_page'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الأبطال',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: MediaQuery.sizeOf(context).height < 320 ? 13 : 14,
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height < 320 ? 2 : 6),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: playableIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final hero = heroCatalog.firstWhere(
                      (h) => h.id == playableIds[index]);
                  return ChoiceChip(
                    key: ValueKey('home_hero_chip_${hero.id}'),
                    avatar: Icon(hero.icon,
                        color: hero.theme.accent, size: 16),
                    label: Text(hero.nameAr,
                        style: const TextStyle(fontSize: 11)),
                    selected: hero.id == _hero.id,
                    visualDensity: MediaQuery.sizeOf(context).height < 320
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                    materialTapTargetSize:
                        MediaQuery.sizeOf(context).height < 320
                            ? MaterialTapTargetSize.shrinkWrap
                            : MaterialTapTargetSize.padded,
                    onSelected: (_) => _selectHero(hero),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size(
                    0,
                    MediaQuery.sizeOf(context).height < 320 ? 22 : 36,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: MediaQuery.sizeOf(context).height < 320 ? 0 : 6,
                  ),
                  visualDensity: MediaQuery.sizeOf(context).height < 320
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  tapTargetSize: MediaQuery.sizeOf(context).height < 320
                      ? MaterialTapTargetSize.shrinkWrap
                      : MaterialTapTargetSize.padded,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: HeroViewerScreen(
                        loaderFactory: widget.loaderFactory,
                        initialHero: _hero,
                      ),
                    ),
                  ),
                ),
                child: const Text('معرض الأبطال',
                    style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      );

  Widget _progressPage() => _card(
        key: const ValueKey('home_progress_page'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('التطوير',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            Text(
              'المستوى ${_progress.level} · الجوهر ${_progress.essence} · '
              'المعدات ${_progress.equipment.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _hero.theme.accent,
                  minimumSize: Size(
                    0,
                    MediaQuery.sizeOf(context).height < 320 ? 30 : 40,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: MediaQuery.sizeOf(context).height < 320 ? 2 : 8,
                  ),
                  visualDensity: MediaQuery.sizeOf(context).height < 320
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  tapTargetSize: MediaQuery.sizeOf(context).height < 320
                      ? MaterialTapTargetSize.shrinkWrap
                      : MaterialTapTargetSize.padded,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: ProgressionScreen(
                        hero: _hero,
                        store: widget.store,
                      ),
                    ),
                  ),
                ),
                child: const Text('افتح مركز التطوير',
                    style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      );
}

/// Paints the persistent center hero: a real skinned GLB when loaded, with an
/// icon-only fallback when a hero has no bundled model yet.
class _HomeHeroPainter extends CustomPainter {
  _HomeHeroPainter({
    required this.controller,
    required this.color,
    required this.icon,
  });

  final Hero3DController? controller;
  final Color color;
  final IconData icon;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, size.height * 0.33),
        width: size.width * 0.8,
        height: size.height * 0.07,
      ),
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    final hero = controller;
    if (hero != null) {
      hero.paint(
        canvas,
        anchor: center + Offset(0, size.height * 0.34),
        facing: const Offset(0, 1),
        scale: hero.scaleForPixelHeight(size.height * 0.82),
      );
      return;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize: size.height * 0.46,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _HomeHeroPainter old) => true;
}
