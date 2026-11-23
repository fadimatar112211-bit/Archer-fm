import 'dart:ui' show Offset, Rect, Size;

import 'package:archer_fm/game/render3/sprite_actor_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sprite destination preserves normalized feet pivot at ground anchor', () {
    final rect = SpriteActorRenderer.destinationRect(
      groundAnchor: const Offset(300, 420),
      frameSize: const Size(192, 192),
      pivotX: 0.5,
      pivotY: 0.86,
      targetHeight: 120,
    );
    expect(rect, const Rect.fromLTWH(240, 316.8, 120, 120));
    expect(rect.center.dx, 300);
    expect(rect.bottom, closeTo(436.8, 1e-9));
  });

  test('sprite destination preserves source aspect ratio for wide frames', () {
    final rect = SpriteActorRenderer.destinationRect(
      groundAnchor: const Offset(500, 500),
      frameSize: const Size(384, 192),
      pivotX: 0.5,
      pivotY: 1,
      targetHeight: 96,
    );
    expect(rect, const Rect.fromLTWH(404, 404, 192, 96));
  });

  test('invalid frame geometry is rejected instead of producing NaN bounds', () {
    expect(
      () => SpriteActorRenderer.destinationRect(
        groundAnchor: Offset.zero,
        frameSize: const Size(0, 192),
        pivotX: 0.5,
        pivotY: 1,
        targetHeight: 96,
      ),
      throwsArgumentError,
    );
  });
}
