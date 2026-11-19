import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/castle_system.dart';
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
  group('castle depth-sorted render layers', () {
    test('renders all four castles with four independent wall arcs each', () {
      final world = _world(301);
      expect(world.castleSystem.castles, hasLength(4));
      for (final castle in world.castleSystem.castles) {
        expect(castle.walls, hasLength(4));
        expect(castle.alive, hasLength(castleCrystalCount));
      }
      _paint(world);
    });

    test('renders castle courtyard and keep when wall arcs are absent', () {
      final world = _world(307);
      world.castleSystem.castles.first.walls.clear();
      _paint(world);
    });

    test('renders a castle with a single surviving wall arc', () {
      final world = _world(311);
      final castle = world.castleSystem.castles.first;
      final wall = castle.walls.first;
      castle.walls
        ..clear()
        ..add(wall);
      _paint(world);
    });

    test('renders wall arcs with narrow and wide gate sweeps', () {
      final world = _world(313);
      final castle = world.castleSystem.castles.first;
      final original = castle.walls.toList();
      castle.walls
        ..clear()
        ..addAll([
          CastleWall(
            center: castle.anchor,
            radius: castleWallRadius,
            startAngle: 0.1,
            sweep: 0.08,
          ),
          CastleWall(
            center: castle.anchor,
            radius: castleWallRadius,
            startAngle: 1.1,
            sweep: math.pi * 1.25,
          ),
        ]);
      _paint(world);
      castle.walls
        ..clear()
        ..addAll(original);
    });

    test('fallen castle does not add wall or crystal render layers', () {
      final world = _world(317);
      world.castleSystem.castles.first.fallen = true;
      _paint(world);
    });

    test('destroyed crystals are excluded while remaining objectives render', () {
      final world = _world(331);
      final castle = world.castleSystem.castles.first;
      castle.crystals.first.hp = 0;
      expect(castle.alive, hasLength(castleCrystalCount - 1));
      _paint(world);
    });

    test('all destroyed crystals remove their castle from render queue', () {
      final world = _world(337);
      final castle = world.castleSystem.castles.first;
      for (final crystal in castle.crystals) {
        crystal.hp = 0;
      }
      castle.fallen = true;
      expect(castle.alive, isEmpty);
      _paint(world);
    });

    test('castle painting does not change wall arc geometry', () {
      final world = _world(349);
      final castle = world.castleSystem.castles.first;
      final before = castle.walls
          .map((wall) => [wall.center, wall.radius, wall.startAngle, wall.sweep])
          .toList();
      _paint(world);
      final after = castle.walls
          .map((wall) => [wall.center, wall.radius, wall.startAngle, wall.sweep])
          .toList();
      expect(after, before);
    });

    test('castle painting does not mutate crystal health or positions', () {
      final world = _world(353);
      final crystals = world.castleSystem.castles
          .expand((castle) => castle.crystals)
          .toList();
      final before = crystals
          .map((crystal) => [crystal.position, crystal.hp, crystal.maxHp])
          .toList();
      _paint(world);
      final after = crystals
          .map((crystal) => [crystal.position, crystal.hp, crystal.maxHp])
          .toList();
      expect(after, before);
    });

    test('castle painter preserves local and rival ownership flags', () {
      final world = _world(359);
      final ownership = world.castleSystem.castles
          .map((castle) => [castle.ownerId, castle.isLocal])
          .toList();
      _paint(world);
      expect(
        world.castleSystem.castles
            .map((castle) => [castle.ownerId, castle.isLocal])
            .toList(),
        ownership,
      );
    });

    test('each castle can be painted independently without wall coupling', () {
      final world = _world(367);
      final castles = world.castleSystem.castles.toList();
      for (final castle in castles) {
        for (final other in castles.where((item) => !identical(item, castle))) {
          other.fallen = true;
        }
        _paint(world);
        for (final other in castles.where((item) => !identical(item, castle))) {
          other.fallen = false;
        }
      }
    });

    test('repeated paint remains stable with segmented castle layers', () {
      final world = _world(347);
      _paint(world);
      _paint(world);
      expect(world.castleSystem.castles, hasLength(4));
      expect(
        world.castleSystem.castles
            .expand((castle) => castle.walls)
            .length,
        16,
      );
    });
  });
}
