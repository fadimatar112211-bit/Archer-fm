import 'dart:ui' show Offset;

import 'package:archer_fm/game/render3/sprite_actor_clip_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sprite clip resolver maps the eight world-facing octants', () {
    const cases = <({Offset facing, String direction})>[
      (facing: Offset(1, 0), direction: 'e'),
      (facing: Offset(0.7071, 0.7071), direction: 'se'),
      (facing: Offset(0, 1), direction: 's'),
      (facing: Offset(-0.7071, 0.7071), direction: 'sw'),
      (facing: Offset(-1, 0), direction: 'w'),
      (facing: Offset(-0.7071, -0.7071), direction: 'nw'),
      (facing: Offset(0, -1), direction: 'n'),
      (facing: Offset(0.7071, -0.7071), direction: 'ne'),
    ];

    for (final item in cases) {
      expect(SpriteActorClipResolver.directionFor(item.facing), item.direction);
      expect(
        SpriteActorClipResolver.clipName('walk', item.facing),
        'walk_${item.direction}',
      );
    }
    expect(SpriteActorClipResolver.directionFor(Offset.zero), 's');
  });

  test('direction selection is stable for vectors near octant boundaries', () {
    expect(
      SpriteActorClipResolver.directionFor(const Offset(1, 0.01)),
      'e',
    );
    expect(
      SpriteActorClipResolver.directionFor(const Offset(0.01, 1)),
      's',
    );
    expect(
      SpriteActorClipResolver.directionFor(const Offset(-1, -0.01)),
      'w',
    );
  });
}
