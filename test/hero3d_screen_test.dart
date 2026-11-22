import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/game_screen.dart';
import 'package:archer_fm/game/progress/hero_progress.dart';
import 'package:archer_fm/game/render3/glb.dart';
import 'package:archer_fm/game/render3/hero3d_controller.dart';
import 'package:archer_fm/game/render3/hero3d_painter.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Combat-enabled fake manifest with the production event timing (frame ×
/// frame_duration_ms, 100 ms frames) so the 3D path's event → payload sync is
/// exercised the same way the atlas path is.
HeroManifest _combatManifest() {
  final animations = <String, dynamic>{};
  const eventsFor = <String, List<Map<String, dynamic>>>{
    'attack': [
      {'frame': 0, 'name': 'bow_draw'},
      {'frame': 1, 'name': 'projectile_release'},
    ],
    'skill': [
      {'frame': 0, 'name': 'volley_charge'},
      {'frame': 1, 'name': 'volley_release'},
    ],
  };
  for (final state in const [
    'idle',
    'walk',
    'run',
    'attack',
    'skill',
    'dodge',
    'hit',
    'death',
  ]) {
    for (final direction in const [
      's',
      'sw',
      'w',
      'nw',
      'n',
      'ne',
      'e',
      'se',
    ]) {
      final name = '${state}_$direction';
      animations[name] = {
        'loop': state == 'idle' || state == 'walk' || state == 'run',
        'frame_duration_ms': 100,
        'frames': ['$name#0', '$name#1'],
        'events': eventsFor[state] ?? <Map<String, dynamic>>[],
      };
    }
  }
  return HeroManifest.fromJson({
    'hero_id': 'ranger_new',
    'frame_size': {'width': 192, 'height': 192},
    'pivot': {'x': 0.5, 'y': 0.85},
    'atlases': [
      {'animation': 'idle_s', 'image': 'fake.png', 'meta': 'fake.json'},
    ],
    'animations': animations,
  });
}

/// The real ranger GLB (bones/rig/animations), injected through the screen's
/// `hero3dController` seam so the in-game 3D path is exercised end to end.
/// The model is built inside `tester.runAsync` because real async work cannot
/// complete inside a widget test's fake async zone.
Future<Hero3DController?> _buildHero3D(
  WidgetTester tester,
  HeroDefinition hero,
) async {
  final bytes = File('assets/heroes/ranger_new/ranger_animated.glb')
      .readAsBytesSync();
  final model = await tester.runAsync(
    () => GlbModel.load(Uint8List.fromList(bytes)),
  );
  return Hero3DController(Hero3DModel(model!));
}

ArenaPainter? _arenaPainter(WidgetTester tester) {
  final painters = tester.widgetList<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ArenaPainter),
  );
  for (final p in painters) {
    final painter = p.painter;
    if (painter is ArenaPainter) return painter;
  }
  return null;
}

void main() {
  testWidgets('the hero renders as the real 3D model in-game', (tester) async {
    final harness = _Harness3D();
    await harness.pump(tester);

    final painter = _arenaPainter(tester);
    expect(painter, isNotNull);
    final hero3d = painter!.presentation.hero3d;
    expect(hero3d, isNotNull, reason: 'the 3D controller must be active');
    expect(hero3d!.model.model.jointNames.length, 21);
    // The pose is driven by the state machine: idle by default.
    expect(hero3d.clipState, 'idle');
  });

  testWidgets(
    '3D hero remains playable when the optional sprite manifest is missing',
    (tester) async {
      final harness = _Harness3D(missingManifest: true);
      await harness.pump(tester);
      final world = harness.world!;
      final hero3d = _arenaPainter(tester)!.presentation.hero3d!;
      expect(hero3d.clipState, 'idle');

      await tester.tap(find.byKey(const ValueKey('btn_attack')));
      final fired = await pumpUntil(
        tester,
        () => world.projectiles.any((p) => !p.fromEnemy),
        timeoutMs: 3000,
      );
      expect(
        fired,
        isTrue,
        reason: 'GLB fallback must synthesize a release event without atlas data',
      );
      expect(world.combo.chainLength, 1);
    },
  );

  testWidgets('3D attack releases the arrow at the manifest event and lands '
      'real damage on the dummy', (tester) async {
    final harness = _Harness3D();
    await harness.pump(tester);
    final world = harness.world!;
    final enemy = world.enemies.single;

    await tester.tap(find.byKey(const ValueKey('btn_attack')));
    // projectile_release fires at frame 1 × 100 ms clip-local.
    final fired = await pumpUntil(
      tester,
      () => world.projectiles.any((p) => !p.fromEnemy),
      timeoutMs: 1500,
    );
    expect(fired, isTrue, reason: 'arrow never released in the 3D path');
    final landed = await pumpUntil(
      tester,
      () => enemy.hp < enemy.maxHp,
      timeoutMs: 2000,
    );
    expect(landed, isTrue, reason: 'arrow never damaged the dummy');
  });

  testWidgets('skill plays the non-loop clip through the 3D controller and '
      'returns to idle', (tester) async {
    final harness = _Harness3D();
    await harness.pump(tester);
    final hero3d = _arenaPainter(tester)!.presentation.hero3d!;

    await tester.tap(find.byKey(const ValueKey('ability_multi_shot')));
    await pumpFor(tester, 100);
    expect(hero3d.clipState, 'skill');
    // The skill clip is non-looping; afterwards the state machine resumes idle.
    final back = await pumpUntil(
      tester,
      () => hero3d.clipState == 'idle',
      timeoutMs: 2500,
    );
    expect(back, isTrue, reason: 'skill never returned to idle');
  });

  testWidgets('hit reaction and death advance through the 3D controller',
      (tester) async {
    final harness = _Harness3D();
    await harness.pump(tester);
    final world = harness.world!;
    final hero3d = _arenaPainter(tester)!.presentation.hero3d!;

    // Push the dummy onto the hero so its contact damage lands.
    final dummy = world.enemies.single;
    world.player.hp = 40;
    dummy.position = world.player.position + const Offset(20, 0);
    final reacted = await pumpUntil(
      tester,
      () => hero3d.clipState == 'hit',
      timeoutMs: 2500,
    );
    expect(reacted, isTrue, reason: 'hit react never played');

    // One more contact hit at 1 hp kills the hero → death clip.
    world.player.hp = 1;
    final died = await pumpUntil(
      tester,
      () => hero3d.clipState == 'death',
      timeoutMs: 4000,
    );
    expect(died, isTrue, reason: 'death clip never played');
    await pumpFor(tester, 300);
    expect(hero3d.clipState, 'death');
  });
}


Future<void> pumpFor(WidgetTester tester, int ms) async {
  var remaining = ms;
  while (remaining > 0) {
    final step = remaining > 16 ? 16 : remaining;
    await tester.pump(Duration(milliseconds: step));
    remaining -= step;
  }
}

/// Pumps until [condition] holds or [timeoutMs] elapses.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int timeoutMs = 4000,
}) async {
  for (var t = 0; t < timeoutMs; t += 16) {
    if (condition()) return true;
    await tester.pump(const Duration(milliseconds: 16));
  }
  return condition();
}

class _Harness3D {
  _Harness3D({this.missingManifest = false})
      : store = MemoryProgressStore();

  static const double dummyDistance = 150;
  final bool missingManifest;
  final MemoryProgressStore store;
  GameWorld? world;

  Future<void> pump(WidgetTester tester) async {
    final harness = this;
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hero3d = await _buildHero3D(tester, heroById('ranger_new'));
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          hero: heroById('ranger_new'),
          kit: rangerNewKit,
          loaderFactory: (hero) => _CombatFakeLoader(
            hero,
            failManifest: missingManifest,
          ),
          store: store,
          hero3dController: hero3d,
          worldFactory: (kit) {
            final created = GameWorld(
              kit: kit,
              random: math.Random(7),
              spawnWaves: false,
            );
            created.enemies.clear();
            // A scripted stationary training dummy east of the hero.
            created.enemies.add(
              EnemyState(
                id: 'dummy',
                kind: 'slime',
                position: created.player.position + Offset(dummyDistance, 0),
                maxHp: 500,
                speed: 0,
                contactDamage: 8,
                xpValue: 10,
              ),
            );
            harness.world = created;
            return created;
          },
        ),
      ),
    );
    // Let the manifest load and the first frames run.
    await pumpFor(tester, 250);
  }
}

/// Reuse of the screen test's fake loader pattern: manifest from memory, one
/// fresh 192×192 sheet per atlas (never used — the hero draws 3D).
class _CombatFakeLoader extends HeroAssetLoader {
  _CombatFakeLoader(this.hero, {this.failManifest = false});

  final HeroDefinition hero;
  final bool failManifest;

  @override
  String get heroId => hero.id;

  @override
  Future<HeroManifest> loadManifest() async {
    if (failManifest) throw StateError('sprite manifest intentionally absent');
    return _combatManifest();
  }

  @override
  Future<AtlasSheet> loadSheet(
    HeroManifest manifest,
    String animation,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 192, 192),
      Paint()..color = const Color(0xFF62E86C),
    );
    final image = await recorder.endRecording().toImage(192, 192);
    const rect = Rect.fromLTWH(0, 0, 192, 192);
    return AtlasSheet(
      image: image,
      frames: {
        '$animation#0': rect,
        '$animation#1': rect,
      },
      width: 192,
      height: 192,
    );
  }
}
