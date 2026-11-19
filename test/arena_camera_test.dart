import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:archer_fm/game/arena_camera.dart';
import 'package:archer_fm/game/world/arena_projection.dart';
import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArenaCameraTransform', () {
    test('pointer conversion uses the smoothed camera origin used to paint', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(17),
        spawnWaves: false,
      );
      world.player.position += const Offset(180, 90);
      world.update(16);

      final transform = ArenaCameraTransform.forViewport(
        const Size(1200, 700),
        world,
      );
      final widgetPoint = transform.worldToLocal(
        world.cameraOrigin + const Offset(320, 210),
      );

      expect(
        transform.localToWorld(widgetPoint).dx,
        closeTo(world.cameraOrigin.dx + 320, 1e-9),
      );
      expect(
        transform.localToWorld(widgetPoint).dy,
        closeTo(world.cameraOrigin.dy + 210, 1e-9),
      );
      expect(transform.cameraOrigin, world.cameraOrigin);
    });

    test('letterboxed viewport round-trips points at phone aspect ratios', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(23),
        spawnWaves: false,
      );
      for (final size in const [
        Size(2400, 1080),
        Size(1920, 1080),
        Size(1280, 720),
        Size(2340, 1080),
      ]) {
        final transform = ArenaCameraTransform.forViewport(size, world);
        final worldPoint = world.cameraOrigin + const Offset(123, 456);
        final screenPoint = transform.worldToLocal(worldPoint);
        final restored = transform.localToWorld(screenPoint);
        expect(restored.dx, closeTo(worldPoint.dx, 1e-9));
        expect(restored.dy, closeTo(worldPoint.dy, 1e-9));
      }
    });

    test('arena tap helper uses the exact camera transform used by painter', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(41),
        spawnWaves: false,
      );
      world.player.position += const Offset(240, 120);
      world.update(16);
      const size = Size(2400, 1080);
      final transform = ArenaCameraTransform.forViewport(size, world);
      const worldPoint = Offset(510, 330);
      final screenPoint = transform.worldToLocal(worldPoint);
      final tapWorldPoint = arenaToWorld(screenPoint, size, world);

      expect(tapWorldPoint.dx, closeTo(worldPoint.dx, 1e-9));
      expect(tapWorldPoint.dy, closeTo(worldPoint.dy, 1e-9));
    });

    test('round-trips viewport corners while the smoothed camera moves', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(67),
        spawnWaves: false,
      );
      final initialOrigin = world.cameraOrigin;
      world.player.position += const Offset(360, 210);

      for (var frame = 0; frame < 8; frame++) {
        world.update(16);
        expect(world.cameraOrigin, isNot(initialOrigin));
        for (final size in const [
          Size(1280, 800),
          Size(1920, 1080),
          Size(2400, 1080),
        ]) {
          final transform = ArenaCameraTransform.forViewport(size, world);
          final inset = transform.viewportOrigin;
          final points = [
            inset + const Offset(1, 1),
            Offset(size.width - inset.dx - 1, inset.dy + 1),
            Offset(inset.dx + 1, size.height - inset.dy - 1),
            Offset(size.width - inset.dx - 1, size.height - inset.dy - 1),
            Offset(size.width / 2, size.height / 2),
          ];
          for (final screen in points) {
            final worldPoint = transform.localToWorld(screen);
            final restored = transform.worldToLocal(worldPoint);
            expect(restored.dx, closeTo(screen.dx, 1e-8));
            expect(restored.dy, closeTo(screen.dy, 1e-8));
          }
        }
      }
    });

    test('oblique projection keeps camera center fixed and compresses depth', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(53),
        spawnWaves: false,
      );
      const size = Size(2400, 1080);
      final transform = ArenaCameraTransform.forViewport(size, world);
      final centerWorld = world.cameraOrigin + const Offset(
        arenaWidth / 2,
        arenaHeight / 2,
      );
      final centerScreen = transform.worldToLocal(centerWorld);
      expect(centerScreen.dx, closeTo(size.width / 2, 1e-9));
      expect(centerScreen.dy, closeTo(size.height / 2, 1e-9));

      final point = centerWorld + const Offset(0, 100);
      final screen = transform.worldToLocal(point);
      expect(screen.dy - centerScreen.dy, closeTo(100 * 0.82 * transform.scale, 1e-9));
      final restored = transform.localToWorld(screen);
      expect(restored.dx, closeTo(point.dx, 1e-9));
      expect(restored.dy, closeTo(point.dy, 1e-9));
    });

    test('camera input round-trips with a yawed ground projection', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(73),
        spawnWaves: false,
      );
      const size = Size(1920, 1080);
      const projection = ArenaWorldProjection(
        yawRadians: 0.24,
        groundScaleY: 0.82,
      );
      final transform = ArenaCameraTransform.forViewport(
        size,
        world,
        projection: projection,
      );
      for (final point in const [
        Offset(180, 140),
        Offset(960, 540),
        Offset(1740, 900),
      ]) {
        final restored = transform.localToWorld(transform.worldToLocal(point));
        expect(restored.dx, closeTo(point.dx, 1e-8));
        expect(restored.dy, closeTo(point.dy, 1e-8));
      }
    });

    test('visible world rectangle matches the camera window', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(31),
        spawnWaves: false,
      );
      final rect = ArenaCameraTransform.forViewport(
        const Size(1200, 700),
        world,
      ).visibleWorldRect;
      expect(rect.center.dx, closeTo(world.cameraOrigin.dx + arenaWidth / 2, 1e-9));
      expect(rect.center.dy, closeTo(world.cameraOrigin.dy + arenaHeight / 2, 1e-9));
      expect(rect.width, closeTo(arenaWidth, 1e-9));
      expect(rect.height, closeTo(arenaHeight / 0.82, 1e-9));
    });
  });
}
