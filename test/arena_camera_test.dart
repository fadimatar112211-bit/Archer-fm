import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:archer_fm/game/arena_camera.dart';
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
      expect(rect.left, world.cameraOrigin.dx);
      expect(rect.top, world.cameraOrigin.dy);
      expect(rect.width, closeTo(arenaWidth, 1e-9));
      expect(rect.height, closeTo(arenaHeight, 1e-9));
    });
  });
}
