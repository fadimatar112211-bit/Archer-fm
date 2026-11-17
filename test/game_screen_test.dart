import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/game_screen.dart';
import 'package:archer_fm/game/progress/hero_progress.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Combat-enabled fake manifest: 2-frame clips whose attack/skill clips carry
/// the same weapon events as the production pipeline, so the game screen's
/// event → payload sync is exercised end to end.
Map<String, dynamic> _combatManifest(String heroId) {
  final eventSets = <String, Map<String, List<Map<String, dynamic>>>>{
    'ranger_new': {
      'attack': [
        {'frame': 0, 'name': 'bow_draw'},
        {'frame': 1, 'name': 'projectile_release'},
      ],
      'skill': [
        {'frame': 0, 'name': 'volley_charge'},
        {'frame': 1, 'name': 'volley_release'},
      ],
    },
    'flame': {
      'attack': [
        {'frame': 0, 'name': 'weapon_windup'},
        {'frame': 1, 'name': 'melee_impact'},
      ],
      'skill': [
        {'frame': 0, 'name': 'inferno_charge'},
        {'frame': 1, 'name': 'inferno_burst'},
      ],
    },
  };
  final eventsFor = eventSets[heroId] ?? eventSets['ranger_new']!;
  final animations = <String, dynamic>{};
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
  return {
    'hero_id': heroId,
    'frame_size': {'width': 192, 'height': 192},
    'pivot': {'x': 0.5, 'y': 0.86},
    'source': {'fps': 12},
    'atlases': [
      {
        'animation': 'idle_s',
        'image': 'atlases/idle_s.png',
        'meta': 'atlases/idle_s.json',
      },
    ],
    'animations': animations,
  };
}

class _CombatFakeLoader extends HeroAssetLoader {
  _CombatFakeLoader(this.hero);

  final HeroDefinition hero;

  @override
  String get heroId => hero.id;

  @override
  Future<HeroManifest> loadManifest() async =>
      HeroManifest.fromJson(_combatManifest(hero.id));

  @override
  Future<AtlasSheet> loadSheet(
    HeroManifest manifest,
    String animation,
  ) async {
    // One fresh image per sheet: sheets dispose their image when evicted.
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

class _Harness {
  _Harness({
    this.seedProgress,
    this.heroId = 'ranger_new',
    HeroKit? kit,
    this.dummyDistance = 150,
  }) : kit = kit ?? kitForHero(heroId);

  final HeroProgress? seedProgress;
  final String heroId;
  final HeroKit kit;
  final double dummyDistance;
  final store = MemoryProgressStore();
  GameWorld? world;

  Future<void> pump(WidgetTester tester) async {
    final harness = this;
    if (seedProgress != null) {
      await store.save(heroId, seedProgress!);
    }
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          hero: heroById(heroId),
          kit: kit,
          loaderFactory: _CombatFakeLoader.new,
          store: store,
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
    // Let the manifest + atlas load and the first frames run.
    await pumpFor(tester, 200);
  }
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

void main() {
  testWidgets(
    'normal attack chain deals the real escalating damage to an enemy',
    (tester) async {
      final harness = _Harness();
      await harness.pump(tester);
      final world = harness.world!;
      final enemy = world.enemies.single;
      final base = rangerNewKit.baseDamage;

      var total = 0.0;
      final multipliers = [1.00, 1.10, 1.20, 1.35, 1.55];
      for (var hit = 0; hit < 5; hit++) {
        await tester.tap(find.byKey(const ValueKey('btn_attack')));
        // One cycle: release frame (~150 ms) + arrow flight (~450 ms) +
        // the remaining attack cooldown, still inside the 1800 ms window.
        await pumpFor(tester, 1150);
        final landed = 500 - enemy.hp >= total + base * multipliers[hit] - 0.01;
        expect(landed, isTrue, reason: 'hit ${hit + 1} never landed');
        total = 500 - enemy.hp;
      }
      expect(
        total,
        closeTo(
          base *
              multipliers.reduce((a, b) => a + b),
          0.05,
        ),
      );
    },
  );

  testWidgets('locked abilities are rejected with an unlock hint',
      (tester) async {
    final harness = _Harness();
      await harness.pump(tester);
    await tester.tap(find.byKey(const ValueKey('ability_piercing_shot')));
    await pumpFor(tester, 100);
    expect(find.textContaining('المستوى 10'), findsOneWidget);
    expect(harness.world!.projectiles.where((p) => !p.fromEnemy), isEmpty);
    // Let the toast timer expire so no timer is left pending.
    await pumpFor(tester, 2300);
  });

  testWidgets('multi_shot volley fires five arrows on the release frame',
      (tester) async {
    final harness = _Harness();
      await harness.pump(tester);
    await tester.tap(find.byKey(const ValueKey('ability_multi_shot')));
    final fired = await pumpUntil(
      tester,
      () => harness.world!.projectiles.where((p) => !p.fromEnemy).length == 5,
      timeoutMs: 1500,
    );
    expect(fired, isTrue);
    final volley = harness.world!.projectiles
        .where((p) => !p.fromEnemy)
        .toList();
    expect(
      volley.every(
        (arrow) => (arrow.damage - rangerNewKit.baseDamage * 0.6).abs() < 0.01,
      ),
      isTrue,
    );
  });

  testWidgets('saved level 10 progress unlocks the piercing shot',
      (tester) async {
    final harness = _Harness(
      seedProgress: const HeroProgress(level: 10, xp: 40, kills: 3),
    );
    await harness.pump(tester);
    expect(harness.world!.level, 10);
    await tester.tap(find.byKey(const ValueKey('ability_piercing_shot')));
    final fired = await pumpUntil(
      tester,
      () => harness.world!.projectiles.any((p) => p.big && !p.fromEnemy),
      timeoutMs: 1500,
    );
    expect(fired, isTrue);
  });

  testWidgets('battle progress is persisted for the next session',
      (tester) async {
    final harness = _Harness();
      await harness.pump(tester);
    final world = harness.world!;
    // One clean kill: the dummy has 1 hp, first arrow kills it.
    world.enemies.single.hp = 1;
    await tester.tap(find.byKey(const ValueKey('btn_attack')));
    final killed = await pumpUntil(
      tester,
      () => world.kills == 1,
      timeoutMs: 1500,
    );
    expect(killed, isTrue);
    // Leaving the screen (dispose) saves the progress.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpFor(tester, 100);
    final saved = await harness.store.load(harness.heroId);
    expect(saved, isNotNull);
    expect(saved!.kills, 1);
  });

  testWidgets('dodge button triggers i-frames and resets the combo',
      (tester) async {
    final harness = _Harness();
      await harness.pump(tester);
    final world = harness.world!;
    await tester.tap(find.byKey(const ValueKey('btn_attack')));
    await pumpFor(tester, 1300);
    await tester.tap(find.byKey(const ValueKey('btn_attack')));
    await pumpFor(tester, 1300);
    expect(world.combo.chainLength, 2);
    await tester.tap(find.byKey(const ValueKey('btn_dodge')));
    await pumpFor(tester, 100);
    expect(world.player.invulnerableUntilMs, greaterThan(world.nowMs));
    expect(world.combo.chainLength, 0);
  });

  testWidgets('Flame melee chain deals the real escalating damage', (
    tester,
  ) async {
    final harness = _Harness(
      heroId: 'flame',
      dummyDistance: 90, // inside the swing arc
    );
    await harness.pump(tester);
    final world = harness.world!;
    final enemy = world.enemies.single;
    final base = flameKit.baseDamage;

    var total = 0.0;
    final multipliers = [1.00, 1.10, 1.20];
    for (var hit = 0; hit < 3; hit++) {
      await tester.tap(find.byKey(const ValueKey('btn_attack')));
      // Damage lands on the melee_impact frame (~150 ms), then the cycle
      // (1670/1.4 ≈ 1193 ms) elapses inside the 1800 ms combo window.
      await pumpFor(tester, 1300);
      final landed = 500 - enemy.hp >= total + base * multipliers[hit] - 0.01;
      expect(landed, isTrue, reason: 'hit ${hit + 1} never landed');
      total = 500 - enemy.hp;
    }
    expect(
      total,
      closeTo(base * (1.0 + 1.1 + 1.2), 0.05),
    );
  });

  testWidgets('Flame hell_burst explodes for 220% on the burst frame', (
    tester,
  ) async {
    final harness = _Harness(
      heroId: 'flame',
      dummyDistance: 90,
      seedProgress: const HeroProgress(level: 20, xp: 40, kills: 3),
    );
    await harness.pump(tester);
    final world = harness.world!;
    final enemy = world.enemies.single;
    await tester.tap(find.byKey(const ValueKey('ability_hell_burst')));
    final burst = await pumpUntil(
      tester,
      () => world.fx.any((effect) => effect.kind == 'burst') &&
          enemy.hp < 500 - flameKit.baseDamage * 2.2 + 0.01,
      timeoutMs: 1500,
    );
    expect(burst, isTrue);
    expect(
      500 - enemy.hp,
      closeTo(flameKit.baseDamage * 2.2, 0.05),
    );
  });
}
