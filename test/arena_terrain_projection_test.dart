import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_camera.dart';
import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/arena_projection.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld _world(int seed) => GameWorld(
      kit: rangerNewKit,
      random: math.Random(seed),
      spawnWaves: false,
    );

ArenaPainter _painter(GameWorld world, ArenaWorldProjection projection) =>
    ArenaPainter(
      world: world,
      projection: projection,
      presentation: ArenaPresentation(
        kit: rangerNewKit,
        theme: ThemeData.dark(),
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

void _paint(ArenaPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final image = recorder.endRecording().toImageSync(
        size.width.round(),
        size.height.round(),
      );
  expect(image.width, size.width.round());
  expect(image.height, size.height.round());
  image.dispose();
}

void main() {
  group('Arena terrain projection', () {
    test('paints biomes, river banks and bridges under the shared oblique plane', () {
      final world = _world(601);
      expect(world.map.biomes, hasLength(4));
      expect(world.map.rivers, isNotEmpty);
      expect(world.map.rivers.first.bridges, isNotEmpty);
      const projection = ArenaWorldProjection(
        yawRadians: 0.23,
        groundScaleY: 0.82,
      );
      _paint(_painter(world, projection), const Size(1920, 1080));
    });

    test('terrain paint preserves generated river and bridge geometry', () {
      final world = _world(607);
      final before = world.map.rivers
          .map((river) => [
                List<Offset>.of(river.points),
                river.bridges.map((bridge) => bridge.rect).toList(),
              ])
          .toList();
      _paint(
        _painter(
          world,
          const ArenaWorldProjection(
            yawRadians: -0.31,
            groundScaleY: 0.74,
            scale: 1.05,
          ),
        ),
        const Size(1280, 720),
      );
      for (var i = 0; i < world.map.rivers.length; i++) {
        expect(world.map.rivers[i].points, before[i][0]);
        expect(
          world.map.rivers[i].bridges.map((bridge) => bridge.rect).toList(),
          before[i][1],
        );
      }
    });

    test('terrain rendering remains repeatable across projection angles', () {
      final world = _world(613);
      for (final yaw in const [-0.48, -0.16, 0.0, 0.21, 0.47]) {
        _paint(
          _painter(
            world,
            ArenaWorldProjection(yawRadians: yaw, groundScaleY: 0.82),
          ),
          const Size(1600, 900),
        );
      }
      expect(world.map.rivers, isNotEmpty);
    });

    test('projected obstacle shadows and softened biome edges paint without mutating the map', () {
      final world = _world(619);
      final before = world.map.obstacles
          .map((obstacle) => [obstacle.position, obstacle.radius, obstacle.kind])
          .toList();
      final painter = _painter(
        world,
        const ArenaWorldProjection(
          yawRadians: 0.34,
          groundScaleY: 0.71,
        ),
      );
      _paint(painter, const Size(1920, 1080));
      _paint(painter, const Size(1920, 1080));
      expect(
        world.map.obstacles
            .map((obstacle) => [obstacle.position, obstacle.radius, obstacle.kind])
            .toList(),
        before,
      );
    });

    test('bridges, split tree layers and rock facets paint at varied camera angles', () {
      final world = _world(631);
      final bridgeRects = world.map.rivers
          .expand((river) => river.bridges)
          .map((bridge) => bridge.rect)
          .toList();
      final treeAndRockCounts = [
        world.map.obstacles.where((o) => o.kind.name == 'tree').length,
        world.map.obstacles.where((o) => o.kind.name == 'rock').length,
      ];
      expect(bridgeRects, isNotEmpty);
      expect(treeAndRockCounts[0], greaterThan(0));
      expect(treeAndRockCounts[1], greaterThan(0));

      for (final yaw in const [-0.37, 0.0, 0.32]) {
        _paint(
          _painter(
            world,
            ArenaWorldProjection(yawRadians: yaw, groundScaleY: 0.8),
          ),
          const Size(1920, 1080),
        );
      }

      expect(
        world.map.rivers
            .expand((river) => river.bridges)
            .map((bridge) => bridge.rect)
            .toList(),
        bridgeRects,
      );
      expect([
        world.map.obstacles.where((o) => o.kind.name == 'tree').length,
        world.map.obstacles.where((o) => o.kind.name == 'rock').length,
      ], treeAndRockCounts);
    });

    test('camera hit mapping remains invertible for terrain yaw', () {
      final world = _world(617);
      const projection = ArenaWorldProjection(
        yawRadians: 0.29,
        groundScaleY: 0.77,
      );
      final transform = ArenaCameraTransform.forViewport(
        const Size(1920, 1080),
        world,
        projection: projection,
      );
      const worldPoint = Offset(780, 460);
      final screen = transform.worldToLocal(worldPoint);
      final restored = transform.localToWorld(screen);
      expect(restored.dx, closeTo(worldPoint.dx, 1e-8));
      expect(restored.dy, closeTo(worldPoint.dy, 1e-8));
    });
  });
}
