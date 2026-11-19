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

    test('letterbox offsets remain outside the projected world viewport', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(97),
        spawnWaves: false,
      );
      for (final size in const [Size(1280, 800), Size(2400, 1080)]) {
        final transform = ArenaCameraTransform.forViewport(size, world);
        expect(transform.viewportOrigin.dx, greaterThanOrEqualTo(0));
        expect(transform.viewportOrigin.dy, greaterThanOrEqualTo(0));
        expect(
          transform.viewportOrigin.dx * 2 +
              arenaWidth * transform.scale,
          closeTo(size.width, 1e-8),
        );
        expect(
          transform.viewportOrigin.dy * 2 +
              arenaHeight * transform.scale,
          closeTo(size.height, 1e-8),
        );
      }
    });

    test('yawed transform keeps logical arena center fixed', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(101),
        spawnWaves: false,
      );
      const size = Size(2340, 1080);
      const projection = ArenaWorldProjection(
        yawRadians: -0.41,
        groundScaleY: 0.76,
        scale: 1.15,
      );
      final transform = ArenaCameraTransform.forViewport(
        size,
        world,
        projection: projection,
      );
      final center = world.cameraOrigin +
          const Offset(arenaWidth / 2, arenaHeight / 2);
      final screen = transform.worldToLocal(center);
      expect(screen.dx, closeTo(size.width / 2, 1e-8));
      expect(screen.dy, closeTo(size.height / 2, 1e-8));
    });

    test('yawed visible bounds contain the inverse-projected viewport corners', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(103),
        spawnWaves: false,
      );
      const size = Size(1920, 1080);
      const projection = ArenaWorldProjection(
        yawRadians: 0.33,
        groundScaleY: 0.78,
      );
      final transform = ArenaCameraTransform.forViewport(
        size,
        world,
        projection: projection,
      );
      final bounds = transform.visibleWorldRect;
      final origin = transform.viewportOrigin;
      final corners = [
        origin,
        Offset(size.width - origin.dx, origin.dy),
        Offset(origin.dx, size.height - origin.dy),
        Offset(size.width - origin.dx, size.height - origin.dy),
      ];
      for (final corner in corners) {
        final point = transform.localToWorld(corner);
        expect(point.dx, inInclusiveRange(bounds.left - 1e-8, bounds.right + 1e-8));
        expect(point.dy, inInclusiveRange(bounds.top - 1e-8, bounds.bottom + 1e-8));
      }
    });

    test('world-screen round trips remain stable at ultrawide landscape sizes', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(107),
        spawnWaves: false,
      );
      for (final size in const [Size(2560, 1080), Size(2400, 1080), Size(1600, 900)]) {
        final transform = ArenaCameraTransform.forViewport(size, world);
        for (final offset in const [
          Offset(0, 0),
          Offset(120, 240),
          Offset(480, 270),
          Offset(900, 510),
          Offset(960, 540),
        ]) {
          final point = world.cameraOrigin + offset;
          final restored = transform.localToWorld(transform.worldToLocal(point));
          expect(restored.dx, closeTo(point.dx, 1e-8));
          expect(restored.dy, closeTo(point.dy, 1e-8));
        }
      }
    });

    test('yawed pointer mapping round-trips points beyond map center', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(109),
        spawnWaves: false,
      );
      const projection = ArenaWorldProjection(
        yawRadians: 0.58,
        groundScaleY: 0.69,
      );
      final transform = ArenaCameraTransform.forViewport(
        const Size(2400, 1080),
        world,
        projection: projection,
      );
      for (final point in const [
        Offset(-500, -300),
        Offset(0, 0),
        Offset(1200, 800),
        Offset(2600, 1700),
      ]) {
        final screen = transform.worldToLocal(point);
        final restored = transform.localToWorld(screen);
        expect(restored.dx, closeTo(point.dx, 1e-7));
        expect(restored.dy, closeTo(point.dy, 1e-7));
      }
    });

    test('camera snapshot remains stable if the world advances afterwards', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(113),
        spawnWaves: false,
      );
      final transform = ArenaCameraTransform.forViewport(
        const Size(1920, 1080),
        world,
      );
      final capturedOrigin = transform.cameraOrigin;
      world.player.position += const Offset(450, 260);
      for (var i = 0; i < 5; i++) {
        world.update(16);
      }
      expect(transform.cameraOrigin, capturedOrigin);
      expect(world.cameraOrigin, isNot(capturedOrigin));
    });

    test('letterboxed coordinates round-trip on each viewport edge', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(127),
        spawnWaves: false,
      );
      const size = Size(1280, 800);
      final transform = ArenaCameraTransform.forViewport(size, world);
      final left = transform.viewportOrigin.dx;
      final top = transform.viewportOrigin.dy;
      final right = size.width - left;
      final bottom = size.height - top;
      for (final screen in [
        Offset(left, size.height / 2),
        Offset(right, size.height / 2),
        Offset(size.width / 2, top),
        Offset(size.width / 2, bottom),
      ]) {
        final worldPoint = transform.localToWorld(screen);
        final restored = transform.worldToLocal(worldPoint);
        expect(restored.dx, closeTo(screen.dx, 1e-8));
        expect(restored.dy, closeTo(screen.dy, 1e-8));
      }
    });

    test('camera transforms preserve relative world displacement', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(131),
        spawnWaves: false,
      );
      const projection = ArenaWorldProjection(
        yawRadians: 0.19,
        groundScaleY: 0.82,
      );
      final transform = ArenaCameraTransform.forViewport(
        const Size(1920, 1080),
        world,
        projection: projection,
      );
      const a = Offset(650, 440);
      const b = Offset(780, 520);
      final screenDelta =
          transform.worldToLocal(b) - transform.worldToLocal(a);
      final restoredDelta =
          transform.localToWorld(transform.worldToLocal(b)) -
              transform.localToWorld(transform.worldToLocal(a));
      expect(restoredDelta.dx, closeTo(b.dx - a.dx, 1e-8));
      expect(restoredDelta.dy, closeTo(b.dy - a.dy, 1e-8));
      expect(screenDelta.distance, greaterThan(0));
    });

    test('default camera keeps horizontal scale and compresses vertical depth', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(137),
        spawnWaves: false,
      );
      const size = Size(2400, 1080);
      final transform = ArenaCameraTransform.forViewport(size, world);
      final origin = world.cameraOrigin + const Offset(arenaWidth / 2, arenaHeight / 2);
      final center = transform.worldToLocal(origin);
      final horizontal = transform.worldToLocal(origin + const Offset(100, 0));
      final vertical = transform.worldToLocal(origin + const Offset(0, 100));
      expect(horizontal.dx - center.dx, closeTo(100 * transform.scale, 1e-8));
      expect(horizontal.dy, closeTo(center.dy, 1e-8));
      expect(vertical.dx, closeTo(center.dx, 1e-8));
      expect(vertical.dy - center.dy, closeTo(82 * transform.scale, 1e-8));
    });

    test('projection scale participates in camera forward and inverse mapping', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(139),
        spawnWaves: false,
      );
      const projection = ArenaWorldProjection(
        yawRadians: 0.22,
        groundScaleY: 0.77,
        scale: 1.35,
      );
      final transform = ArenaCameraTransform.forViewport(
        const Size(1920, 1080),
        world,
        projection: projection,
      );
      for (final point in const [
        Offset(100, 100),
        Offset(960, 540),
        Offset(1800, 1000),
      ]) {
        final restored =
            transform.localToWorld(transform.worldToLocal(point));
        expect(restored.dx, closeTo(point.dx, 1e-7));
        expect(restored.dy, closeTo(point.dy, 1e-7));
      }
    });

    test('camera movement shifts a fixed world landmark by the expected screen delta', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(149),
        spawnWaves: false,
      );
      final first = ArenaCameraTransform.forViewport(
        const Size(1920, 1080),
        world,
      );
      final landmark = world.cameraOrigin + const Offset(700, 400);
      final firstScreen = first.worldToLocal(landmark);
      world.player.position += const Offset(320, 160);
      for (var i = 0; i < 6; i++) {
        world.update(16);
      }
      final second = ArenaCameraTransform.forViewport(
        const Size(1920, 1080),
        world,
      );
      final secondScreen = second.worldToLocal(landmark);
      expect(secondScreen, isNot(firstScreen));
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
