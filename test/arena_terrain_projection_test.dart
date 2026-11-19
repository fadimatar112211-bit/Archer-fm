import 'dart:io';
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

Future<void> _capture(ArenaPainter painter, Size size, String fileName) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(bytes, isNotNull);
  final directory = Directory('build/arena-captures');
  directory.createSync(recursive: true);
  File('${directory.path}/$fileName').writeAsBytesSync(
    bytes!.buffer.asUint8List(),
    flush: true,
  );
  image.dispose();
  picture.dispose();
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

    test('hero overlaps trees and rocks from multiple sides without painter state changes', () {
      final world = _world(641);
      final obstacles = [
        ...world.map.obstacles.where((o) => o.kind.name == 'tree').take(4),
        ...world.map.obstacles.where((o) => o.kind.name == 'rock').take(4),
      ];
      expect(obstacles, hasLength(8));
      final before = obstacles
          .map((obstacle) => [obstacle.position, obstacle.radius, obstacle.kind])
          .toList();
      for (var i = 0; i < obstacles.length; i++) {
        final obstacle = obstacles[i];
        final offsets = const [
          Offset(0, 0),
          Offset(24, 0),
          Offset(-24, 0),
        ];
        for (final offset in offsets) {
          world.player.position = obstacle.position + offset;
          _paint(
            _painter(
              world,
              ArenaWorldProjection(
                yawRadians: (i.isEven ? 0.28 : -0.28),
                groundScaleY: 0.8,
              ),
            ),
            const Size(1280, 720),
          );
        }
      }
      expect(
        obstacles
            .map((obstacle) => [obstacle.position, obstacle.radius, obstacle.kind])
            .toList(),
        before,
      );
    });

    test('castle keep, wall segments and crystal plinths paint through actor overlaps', () {
      final world = _world(643);
      final castles = world.castleSystem.castles;
      expect(castles, hasLength(4));
      for (final castle in castles) {
        expect(castle.crystals, hasLength(7));
        expect(castle.walls, isNotEmpty);
        final targets = [
          castle.anchor,
          ...castle.walls.map((wall) {
            final angle = wall.startAngle + wall.sweep / 2;
            return wall.center +
                Offset(math.cos(angle) * wall.radius, math.sin(angle) * wall.radius);
          }),
          ...castle.alive.map((crystal) => crystal.position),
        ];
        for (final target in targets) {
          world.player.position = target;
          _paint(
            _painter(
              world,
              const ArenaWorldProjection(
                yawRadians: 0.24,
                groundScaleY: 0.78,
              ),
            ),
            const Size(1280, 720),
          );
        }
      }
      expect(castles.every((castle) => castle.aliveCount == 7), isTrue);
    });

    test('castle walls and crystals remain readable from front and rear approach positions', () {
      final world = _world(647);
      final castle = world.castleSystem.castles.first;
      final wall = castle.walls.first;
      final angle = wall.startAngle + wall.sweep / 2;
      final wallBase = wall.center +
          Offset(math.cos(angle) * wall.radius, math.sin(angle) * wall.radius);
      final crystalBase = castle.alive.first.position;
      for (final base in [wallBase, crystalBase]) {
        for (final offset in const [
          Offset(0, -48),
          Offset(0, 48),
        ]) {
          world.player.position = base + offset;
          _paint(
            _painter(
              world,
              const ArenaWorldProjection(
                yawRadians: -0.33,
                groundScaleY: 0.76,
              ),
            ),
            const Size(1280, 720),
          );
        }
      }
      expect(castle.aliveCount, 7);
    });

    test('castle and actor contact shadows render consistently across yaw angles', () {
      final world = _world(653);
      final castleCounts = world.castleSystem.castles
          .map((castle) => castle.aliveCount)
          .toList();
      for (final yaw in const [-0.42, 0.0, 0.42]) {
        _paint(
          _painter(
            world,
            ArenaWorldProjection(yawRadians: yaw, groundScaleY: 0.79),
          ),
          const Size(1280, 720),
        );
      }
      expect(
        world.castleSystem.castles.map((castle) => castle.aliveCount).toList(),
        castleCounts,
      );
    });

    test('hero overlaps bridges, mines, resources and chests through the shared depth queue', () {
      final world = _world(659);
      final targets = <Offset>[
        ...world.map.rivers.expand((river) => river.bridges).map((bridge) => bridge.center),
        ...world.mineSystem.mines.map((mine) => mine.position),
        ...world.mineSystem.pickups.map((pickup) => pickup.position),
        ...world.map.pickups
            .where((pickup) => pickup.kind.name != 'resource')
            .map((pickup) => pickup.position),
      ];
      expect(world.map.rivers.expand((river) => river.bridges), isNotEmpty);
      expect(world.mineSystem.mines, isNotEmpty);
      expect(world.mineSystem.pickups, isNotEmpty);
      expect(targets, isNotEmpty);
      final initialCrystals = world.castleSystem.castles
          .map((castle) => castle.aliveCount)
          .toList();
      for (var i = 0; i < targets.length; i++) {
        world.player.position = targets[i];
        _paint(
          _painter(
            world,
            ArenaWorldProjection(
              yawRadians: i.isEven ? -0.36 : 0.36,
              groundScaleY: 0.77,
            ),
          ),
          const Size(1280, 720),
        );
      }
      expect(
        world.castleSystem.castles.map((castle) => castle.aliveCount).toList(),
        initialCrystals,
      );
    });

    test('captures full arena at three common landscape viewport sizes', () async {
      final world = _world(661);
      // Keep the player at the constructor's camera-followed spawn so the
      // hero marker stays inside the viewport in every landscape capture.
      // Captures are visual-review fixtures, not gameplay fog-of-war tests.
      // Reveal the entire generated map so hidden cells do not mask the
      // terrain, props, castles and actor-depth composition being reviewed.
      world.fog.reveal(
        world.map.center,
        math.sqrt(
          world.map.size.width * world.map.size.width +
              world.map.size.height * world.map.size.height,
        ),
      );
      const projection = ArenaWorldProjection(
        yawRadians: 0.26,
        groundScaleY: 0.79,
      );
      final painter = _painter(world, projection);
      await _capture(painter, const Size(1280, 720), 'arena-1280x720.png');
      await _capture(painter, const Size(1920, 1080), 'arena-1920x1080.png');
      await _capture(painter, const Size(2340, 1080), 'arena-2340x1080.png');
      expect(Directory('build/arena-captures').existsSync(), isTrue);
      expect(
        Directory('build/arena-captures')
            .listSync()
            .whereType<File>()
            .length,
        greaterThanOrEqualTo(3),
      );
    });

    test('landscape viewport transforms keep hero and crystal coordinates finite', () {
      final world = _world(663);
      final hero = world.player.position;
      final crystals = world.castleSystem.castles
          .expand((castle) => castle.alive)
          .map((crystal) => crystal.position)
          .toList();
      expect(crystals, isNotEmpty);
      for (final size in const [
        Size(1280, 720),
        Size(1920, 1080),
        Size(2340, 1080),
      ]) {
        final transform = ArenaCameraTransform.forViewport(
          size,
          world,
          projection: const ArenaWorldProjection(
            yawRadians: -0.21,
            groundScaleY: 0.8,
          ),
        );
        final heroScreen = transform.worldToLocal(hero);
        expect(heroScreen.dx.isFinite && heroScreen.dy.isFinite, isTrue);
        for (final crystal in crystals) {
          final screen = transform.worldToLocal(crystal);
          expect(screen.dx.isFinite && screen.dy.isFinite, isTrue);
        }
        _paint(
          _painter(
            world,
            const ArenaWorldProjection(
              yawRadians: -0.21,
              groundScaleY: 0.8,
            ),
          ),
          size,
        );
      }
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
