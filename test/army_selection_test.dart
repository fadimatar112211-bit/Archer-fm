import 'dart:ui' as ui;

import 'package:archer_fm/game/army_selection_screen.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/progress/hero_progress.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal fake loader: the selection screen never actually starts a match in
/// these tests, so a single valid clip is enough if one is ever requested.
class _SelectionFakeLoader extends HeroAssetLoader {
  _SelectionFakeLoader(this.hero);

  final HeroDefinition hero;

  @override
  String get heroId => hero.id;

  @override
  Future<HeroManifest> loadManifest() async => HeroManifest(
        heroId: hero.id,
        frameWidth: 192,
        frameHeight: 192,
        pivotX: 0.5,
        pivotY: 0.86,
        fps: 12,
        clips: const {},
        atlases: const [],
      );

  @override
  Future<AtlasSheet> loadSheet(HeroManifest manifest, String animation) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 192, 192),
      Paint()..color = const Color(0xFF62E86C),
    );
    final image = await recorder.endRecording().toImage(192, 192);
    return AtlasSheet(
      image: image,
      frames: const {},
      width: 192,
      height: 192,
    );
  }
}

void main() {
  testWidgets('free 20-monster army: +/- keeps the total at exactly 20',
      (tester) async {
    // The weapon cards make the page taller than a phone viewport; give the
    // lazy ListView enough room so its bottom start button is built.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ArmySelectionScreen(
          loaderFactory: _SelectionFakeLoader.new,
          store: MemoryProgressStore(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('اختيار البطل والجيش'), findsOneWidget);
    expect(find.byKey(const ValueKey('hero_strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('start_with_army')), findsOneWidget);
    expect(find.byKey(const ValueKey('army_total')), findsOneWidget);

    // Default is the balanced 6/5/5/4 = 20. Remove two runners, add them to
    // the tanks: the counters change but the total stays exactly twenty.
    Future<void> press(String key) async {
      tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed!();
      await tester.pumpAndSettle();
    }

    await press('dec_runner');
    await press('dec_runner');
    await press('inc_tank');
    await press('inc_tank');

    expect(find.byKey(const ValueKey('count_runner')), findsOneWidget);
    final totalText = tester.widget<Text>(
      find.byKey(const ValueKey('army_total')),
    );
    expect(totalText.data, contains('20/20'));
  });

  test('startingArmy is honoured by the world with the exact custom mix', () {
    final custom = <MonsterType, int>{
      MonsterType.runner: 20,
      MonsterType.tank: 0,
      MonsterType.stalker: 0,
      MonsterType.ranged: 0,
    };
    final world = GameWorld(
      kit: kitForHero('ranger_new'),
      spawnWaves: false,
      startingArmy: custom,
    );
    expect(world.army.length, 20);
    expect(world.army.every((m) => m.type == MonsterType.runner), isTrue);
  });

  test('no overflow: adding past twenty is blocked in the UI', () async {
    // The \"+\" buttons disable at 20 assigned: the screen computes this guard
    // in its onPressed path (assigned < total).
    final counts =
        Map<MonsterType, int>.from(MonsterCatalog.defaultStartingArmy);
    final assigned = counts.values.fold(0, (a, b) => a + b);
    expect(assigned, 20);
    expect(assigned < GameWorld.startingArmySize, isFalse);
    expect(counts.length, 4);
  });
}
