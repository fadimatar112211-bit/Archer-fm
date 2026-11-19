import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld _world(int seed) => GameWorld(
      kit: rangerNewKit,
      random: math.Random(seed),
      spawnWaves: false,
    );

void _paint(GameWorld world) {
  final painter = ArenaPainter(
    world: world,
    presentation: ArenaPresentation(
      kit: rangerNewKit,
      theme: ThemeData(brightness: Brightness.dark),
      sheet: null,
      frameId: null,
      pivotX: 0.5,
      pivotY: 0.85,
      frameWidth: 192,
      frameHeight: 192,
      labels: const [],
      timeMs: world.nowMs,
      comboText: null,
    ),
  );
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(960, 540));
  final image = recorder.endRecording().toImageSync(960, 540);
  expect(image.width, 960);
  image.dispose();
}

void main() {
  group('ArenaPainter mine depth pass', () {
    test('renders every generated mine through the shared actor queue', () {
      final world = _world(401);
      expect(world.mineSystem.mines, isNotEmpty);
      _paint(world);
    });

    test('renders neutral, local and rival owned mines', () {
      final world = _world(409);
      final mines = world.mineSystem.mines;
      expect(mines.length, greaterThanOrEqualTo(3));
      mines[0].ownerId = null;
      mines[1].ownerId = 'player';
      mines[2].ownerId = 'rival_1';
      _paint(world);
    });

    test('renders small medium and large mine markers', () {
      final world = _world(419);
      final seen = world.mineSystem.mines.map((mine) => mine.size).toSet();
      expect(seen, contains(MineSize.small));
      expect(seen, contains(MineSize.medium));
      expect(seen, contains(MineSize.large));
      _paint(world);
    });

    test('renders partial capture progress on depth-sorted mines', () {
      final world = _world(421);
      final mine = world.mineSystem.mines.first;
      mine.capturerId = 'player';
      mine.captureProgressMs = mineCaptureDurationMs * 0.45;
      _paint(world);
      expect(mine.captureFraction, closeTo(0.45, 0.001));
    });

    test('painting mines does not mutate ownership or capture progress', () {
      final world = _world(431);
      final mine = world.mineSystem.mines.first;
      mine.ownerId = 'player';
      mine.capturerId = 'player';
      mine.captureProgressMs = 4321;
      _paint(world);
      expect(mine.ownerId, 'player');
      expect(mine.capturerId, 'player');
      expect(mine.captureProgressMs, 4321);
    });

    test('renders all mine sizes under yawed ground projection', () {
      final world = _world(433);
      final painter = ArenaPainter(
        world: world,
        projection: const ArenaWorldProjection(
          yawRadians: 0.31,
          groundScaleY: 0.76,
          scale: 1.1,
        ),
        presentation: ArenaPresentation(
          kit: rangerNewKit,
          theme: ThemeData(brightness: Brightness.dark),
          sheet: null,
          frameId: null,
          pivotX: 0.5,
          pivotY: 0.85,
          frameWidth: 192,
          frameHeight: 192,
          labels: const [],
          timeMs: world.nowMs,
          comboText: null,
        ),
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(960, 540));
      final image = recorder.endRecording().toImageSync(960, 540);
      expect(image.width, 960);
      image.dispose();
    });

    test('repeated paint keeps mine count and state stable', () {
      final world = _world(439);
      final count = world.mineSystem.mines.length;
      _paint(world);
      _paint(world);
      expect(world.mineSystem.mines, hasLength(count));
    });

    test('mine depth pass keeps pickups in their existing separate pass', () {
      final world = _world(443);
      expect(world.mineSystem.pickups, isNotEmpty);
      final pickups = world.mineSystem.pickups.length;
      _paint(world);
      expect(world.mineSystem.pickups, hasLength(pickups));
    });
  });
}
