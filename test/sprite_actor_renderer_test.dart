import 'dart:ui' show Canvas, Color, Offset, Paint, PictureRecorder, Rect, Size;

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

  test('non-finite anchors, pivots and target sizes are rejected', () {
    for (final geometry in <Map<String, Object>>[
      {
        'anchor': const Offset(double.nan, 0),
        'frame': const Size(192, 192),
        'pivotX': 0.5,
        'pivotY': 1.0,
        'height': 96.0,
      },
      {
        'anchor': Offset.zero,
        'frame': const Size(192, 192),
        'pivotX': double.infinity,
        'pivotY': 1.0,
        'height': 96.0,
      },
      {
        'anchor': Offset.zero,
        'frame': const Size(192, 192),
        'pivotX': 0.5,
        'pivotY': 1.0,
        'height': double.nan,
      },
    ]) {
      expect(
        () => SpriteActorRenderer.destinationRect(
          groundAnchor: geometry['anchor'] as Offset,
          frameSize: geometry['frame'] as Size,
          pivotX: geometry['pivotX'] as double,
          pivotY: geometry['pivotY'] as double,
          targetHeight: geometry['height'] as double,
        ),
        throwsArgumentError,
      );
    }
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

  test('non-finite opacity and atlas rectangles outside the image are rejected', () async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 16, 16),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(16, 16);
    final validationCanvas = Canvas(PictureRecorder());
    addTearDown(() {
      image.dispose();
      picture.dispose();
    });

    void paint({required Rect sourceRect, double opacity = 1}) {
      SpriteActorRenderer.paint(
        validationCanvas,
        image: image,
        sourceRect: sourceRect,
        groundAnchor: Offset.zero,
        frameSize: const Size(16, 16),
        pivotX: 0.5,
        pivotY: 1,
        targetHeight: 16,
        opacity: opacity,
      );
    }

    expect(
      () => paint(
        sourceRect: const Rect.fromLTWH(0, 0, 16, 16),
        opacity: double.nan,
      ),
      throwsArgumentError,
    );
    expect(
      () => paint(sourceRect: const Rect.fromLTWH(8, 8, 16, 16)),
      throwsArgumentError,
    );
  });
}
