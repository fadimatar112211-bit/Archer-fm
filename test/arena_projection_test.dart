import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:archer_fm/game/world/arena_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArenaWorldProjection', () {
    test('default projection preserves existing top-down coordinates', () {
      const projection = ArenaWorldProjection();
      const point = Offset(420, 175);
      expect(projection.projectGround(point), point);
      expect(projection.unprojectGround(point), point);
    });

    test('oblique projection round-trips world points across camera angles', () {
      for (final projection in const [
        ArenaWorldProjection(
          yawRadians: 0.42,
          groundScaleY: 0.68,
          scale: 1.25,
          focus: Offset(480, 270),
        ),
        ArenaWorldProjection(
          yawRadians: -0.31,
          groundScaleY: 0.82,
          scale: 0.75,
          focus: Offset(1200, 800),
        ),
      ]) {
        for (final point in const [
          Offset.zero,
          Offset(480, 270),
          Offset(1920, 1080),
          Offset(2360, 1410),
        ]) {
          final restored =
              projection.unprojectGround(projection.projectGround(point));
          expect(restored.dx, closeTo(point.dx, 1e-9));
          expect(restored.dy, closeTo(point.dy, 1e-9));
        }
      }
    });

    test('ground depth is monotonic along the camera depth axis', () {
      const projection = ArenaWorldProjection(
        yawRadians: 0.5,
        groundScaleY: 0.7,
      );
      const near = Offset(100, 100);
      const far = Offset(100 + 100 * 0.4794255386, 100 + 100 * 0.8775825619);
      expect(projection.depthOf(far), greaterThan(projection.depthOf(near)));
    });

    test('tree crown layers sort behind the trunk in depth order', () {
      const projection = ArenaWorldProjection(groundScaleY: 0.82);
      const trunkAnchor = Offset(400, 300);
      const canopyAnchor = Offset(400, 300 - 58 * 0.35);
      const upperLobeAnchor = Offset(
        400 - 58 * 0.35,
        300 - 58 * 0.6,
      );

      expect(
        projection.depthOf(canopyAnchor),
        lessThan(projection.depthOf(trunkAnchor)),
      );
      expect(
        projection.depthOf(upperLobeAnchor),
        lessThan(projection.depthOf(canopyAnchor)),
      );
    });

    test('focus maps to projected origin for translated camera targets', () {
      for (final focus in const [
        Offset.zero,
        Offset(480, 270),
        Offset(1920, 1080),
      ]) {
        final projection = ArenaWorldProjection(
          yawRadians: 0.63,
          groundScaleY: 0.74,
          scale: 1.3,
          focus: focus,
        );
        expect(projection.projectGround(focus), Offset.zero);
      }
    });

    test('depth ordering is invariant under world translation', () {
      const projection = ArenaWorldProjection(
        yawRadians: -0.37,
        groundScaleY: 0.79,
      );
      const a = Offset(130, 260);
      const b = Offset(190, 330);
      const translation = Offset(900, 420);
      expect(
        projection.depthOf(b) - projection.depthOf(a),
        closeTo(
          projection.depthOf(b + translation) -
              projection.depthOf(a + translation),
          1e-9,
        ),
      );
    });

    test('negative world height moves projected point downward', () {
      const projection = ArenaWorldProjection(
        yawRadians: 0.2,
        groundScaleY: 0.8,
        scale: 1.4,
      );
      const anchor = Offset(250, 410);
      final ground = projection.projectGround(anchor);
      final belowGround = projection.projectHeight(anchor, -25);
      expect(belowGround.dx, closeTo(ground.dx, 1e-9));
      expect(belowGround.dy, closeTo(ground.dy + 35, 1e-9));
    });

    test('projected ground scale is linear for translated points', () {
      const projection = ArenaWorldProjection(
        yawRadians: 0.4,
        groundScaleY: 0.7,
        scale: 1.5,
      );
      const a = Offset(100, 200);
      const delta = Offset(30, -45);
      final projectedDelta =
          projection.projectGround(a + delta) - projection.projectGround(a);
      expect(projectedDelta.dx, closeTo(1.5 * (30 * 0.921060994 + 45 * 0.389418342), 1e-7));
      expect(projectedDelta.dy, closeTo(1.5 * 0.7 * (30 * 0.389418342 - 45 * 0.921060994), 1e-7));
    });

    test('zero projected point restores the configured focus', () {
      const focus = Offset(845, 612);
      const projection = ArenaWorldProjection(
        yawRadians: 0.71,
        groundScaleY: 0.63,
        scale: 1.8,
        focus: focus,
      );
      expect(projection.unprojectGround(Offset.zero), focus);
    });

    test('depth key is independent of visual scale and depth compression', () {
      const point = Offset(420, 760);
      const plain = ArenaWorldProjection(yawRadians: 0.29);
      const stylized = ArenaWorldProjection(
        yawRadians: 0.29,
        groundScaleY: 0.51,
        scale: 2.4,
      );
      expect(stylized.depthOf(point), closeTo(plain.depthOf(point), 1e-9));
    });

    test('depth key increases along positive camera depth for negative yaw', () {
      const projection = ArenaWorldProjection(yawRadians: -0.6);
      const origin = Offset(300, 500);
      final forward = origin +
          Offset(-100 * math.sin(0.6), 100 * math.cos(0.6));
      expect(projection.depthOf(forward), greaterThan(projection.depthOf(origin)));
    });

    test('height offset is independent of ground yaw', () {
      const projection = ArenaWorldProjection(
        yawRadians: 0.92,
        groundScaleY: 0.67,
        scale: 1.25,
      );
      const anchor = Offset(715, 388);
      final ground = projection.projectGround(anchor);
      final raised = projection.projectHeight(anchor, 32);
      expect(raised.dx, closeTo(ground.dx, 1e-9));
      expect(raised.dy, closeTo(ground.dy - 40, 1e-9));
    });

    test('visible bounds translate exactly with projection focus', () {
      const viewport = Rect.fromLTRB(-320, -180, 320, 180);
      const base = ArenaWorldProjection(
        yawRadians: 0.44,
        groundScaleY: 0.73,
      );
      const shift = Offset(640, 390);
      const moved = ArenaWorldProjection(
        yawRadians: 0.44,
        groundScaleY: 0.73,
        focus: shift,
      );
      final a = base.visibleWorldBounds(viewport);
      final b = moved.visibleWorldBounds(viewport);
      expect(b.left - a.left, closeTo(shift.dx, 1e-8));
      expect(b.top - a.top, closeTo(shift.dy, 1e-8));
      expect(b.right - a.right, closeTo(shift.dx, 1e-8));
      expect(b.bottom - a.bottom, closeTo(shift.dy, 1e-8));
    });

    test('projection round-trips a dense grid with non-zero focus', () {
      const projection = ArenaWorldProjection(
        yawRadians: -0.52,
        groundScaleY: 0.61,
        scale: 1.37,
        focus: Offset(1100, 720),
      );
      for (var x = -2; x <= 8; x++) {
        for (var y = -2; y <= 8; y++) {
          final point = Offset(x * 137.25, y * 91.75);
          final restored =
              projection.unprojectGround(projection.projectGround(point));
          expect(restored.dx, closeTo(point.dx, 1e-8));
          expect(restored.dy, closeTo(point.dy, 1e-8));
        }
      }
    });

    test('projection of a point is deterministic across repeated calls', () {
      const projection = ArenaWorldProjection(
        yawRadians: 0.28,
        groundScaleY: 0.84,
        scale: 0.93,
        focus: Offset(340, 210),
      );
      const point = Offset(1290.5, -75.25);
      final first = projection.projectGround(point);
      for (var i = 0; i < 20; i++) {
        expect(projection.projectGround(point), first);
      }
    });

    test('camera-right movement does not change the depth sort key', () {
      const yaw = 0.47;
      const projection = ArenaWorldProjection(yawRadians: yaw);
      const anchor = Offset(600, 420);
      final rightward = anchor + Offset(100 * math.cos(yaw), -100 * math.sin(yaw));
      expect(
        projection.depthOf(rightward),
        closeTo(projection.depthOf(anchor), 1e-8),
      );
    });

    test('camera-depth movement changes projected vertical coordinate only', () {
      const yaw = -0.36;
      const projection = ArenaWorldProjection(
        yawRadians: yaw,
        groundScaleY: 0.75,
        scale: 1.2,
      );
      const anchor = Offset(340, 520);
      final deeper =
          anchor + Offset(80 * math.sin(yaw), 80 * math.cos(yaw));
      final a = projection.projectGround(anchor);
      final b = projection.projectGround(deeper);
      expect(b.dx, closeTo(a.dx, 1e-8));
      expect(b.dy - a.dy, closeTo(80 * 0.75 * 1.2, 1e-8));
    });

    test('zero yaw leaves the world X axis horizontal', () {
      const projection = ArenaWorldProjection(groundScaleY: 0.82, scale: 1.4);
      const a = Offset(200, 300);
      const b = Offset(350, 300);
      final delta = projection.projectGround(b) - projection.projectGround(a);
      expect(delta.dx, closeTo(210, 1e-9));
      expect(delta.dy, closeTo(0, 1e-9));
    });

    test('zero yaw compresses only the world Y axis', () {
      const projection = ArenaWorldProjection(groundScaleY: 0.82, scale: 1.4);
      const a = Offset(200, 300);
      const b = Offset(200, 450);
      final delta = projection.projectGround(b) - projection.projectGround(a);
      expect(delta.dx, closeTo(0, 1e-9));
      expect(delta.dy, closeTo(172.2, 1e-9));
    });

    test('negative yaw remains invertible for points on both sides of focus', () {
      const projection = ArenaWorldProjection(
        yawRadians: -1.12,
        groundScaleY: 0.58,
        scale: 1.65,
        focus: Offset(920, 610),
      );
      for (final point in const [
        Offset(-800, -500),
        Offset(920, 610),
        Offset(0, 1200),
        Offset(2400, 1900),
      ]) {
        final projected = projection.projectGround(point);
        final restored = projection.unprojectGround(projected);
        expect(restored.dx, closeTo(point.dx, 1e-8));
        expect(restored.dy, closeTo(point.dy, 1e-8));
      }
    });

    test('zero projection scale is rejected by constructor assertions', () {
      expect(
        () => ArenaWorldProjection(scale: 0),
        throwsAssertionError,
      );
    });

    test('zero depth compression is rejected by constructor assertions', () {
      expect(
        () => ArenaWorldProjection(groundScaleY: 0),
        throwsAssertionError,
      );
    });

    test('very small positive depth compression remains invertible', () {
      const projection = ArenaWorldProjection(
        yawRadians: 0.3,
        groundScaleY: 0.01,
        scale: 0.5,
        focus: Offset(100, 200),
      );
      const point = Offset(900, 1300);
      final restored = projection.unprojectGround(projection.projectGround(point));
      expect(restored.dx, closeTo(point.dx, 1e-7));
      expect(restored.dy, closeTo(point.dy, 1e-7));
    });

    test('height lifts an anchor without changing its ground projection', () {
      const projection = ArenaWorldProjection(scale: 1.5);
      const anchor = Offset(200, 300);
      final ground = projection.projectGround(anchor);
      final elevated = projection.projectHeight(anchor, 40);
      expect(elevated.dx, ground.dx);
      expect(elevated.dy, closeTo(ground.dy - 60, 1e-9));
    });

    test('projected radius scales uniformly', () {
      const projection = ArenaWorldProjection(scale: 1.75);
      expect(projection.projectRadius(20), closeTo(35, 1e-9));
    });

    test('visible world bounds contain all inverse-projected corners', () {
      const projection = ArenaWorldProjection(
        yawRadians: 0.35,
        groundScaleY: 0.72,
        scale: 1.2,
        focus: Offset(500, 400),
      );
      const viewport = Rect.fromLTRB(-400, -220, 400, 220);
      final bounds = projection.visibleWorldBounds(viewport);
      for (final corner in const [
        Offset(-400, -220),
        Offset(400, -220),
        Offset(-400, 220),
        Offset(400, 220),
      ]) {
        final world = projection.unprojectGround(corner);
        expect(world.dx, greaterThanOrEqualTo(bounds.left - 1e-9));
        expect(world.dx, lessThanOrEqualTo(bounds.right + 1e-9));
        expect(world.dy, greaterThanOrEqualTo(bounds.top - 1e-9));
        expect(world.dy, lessThanOrEqualTo(bounds.bottom + 1e-9));
      }
    });
  });
}
