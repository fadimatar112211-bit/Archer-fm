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
        expect(bounds.contains(world), isTrue);
      }
    });
  });
}
