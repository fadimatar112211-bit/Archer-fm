import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:archer_fm/game/render3/sprite_actor_clip_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('eight-way direction boundaries', () {
    const cases = <(double degrees, String direction)>[
      (22.49, 'e'),
      (22.51, 'se'),
      (67.49, 'se'),
      (67.51, 's'),
      (112.49, 's'),
      (112.51, 'sw'),
      (157.49, 'sw'),
      (157.51, 'w'),
      (-22.49, 'e'),
      (-22.51, 'ne'),
      (-67.49, 'ne'),
      (-67.51, 'n'),
      (-112.49, 'n'),
      (-112.51, 'nw'),
      (-157.49, 'nw'),
      (-157.51, 'w'),
    ];

    test('switches direction on the correct side of every octant boundary', () {
      for (final item in cases) {
        final radians = item.$1 * math.pi / 180;
        final facing = Offset(math.cos(radians), math.sin(radians));
        expect(
          SpriteActorClipResolver.directionFor(facing),
          item.$2,
          reason: '${item.$1} degrees',
        );
      }
    });

    test('direction selection is invariant to facing-vector magnitude', () {
      for (final item in [
        (Offset(1, 0.2), 'e'),
        (Offset(0.2, 1), 's'),
        (Offset(-1, -0.2), 'w'),
        (Offset(0.2, -1), 'n'),
      ]) {
        for (final scale in [0.01, 0.5, 1.0, 25.0, 1000.0]) {
          expect(
            SpriteActorClipResolver.directionFor(item.$1 * scale),
            item.$2,
          );
        }
      }
    });
  });
}
