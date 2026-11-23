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

    expect(
      () => paint(sourceRect: Rect.fromLTWH(double.nan, 0, 8, 8)),
      throwsArgumentError,
    );
    expect(
      () => paint(sourceRect: Rect.fromLTWH(double.infinity, 0, 8, 8)),
      throwsArgumentError,
    );
  });
  test('paint applies opacity to actual atlas pixels without changing geometry', () async {
    final sourceRecorder = PictureRecorder();
    final sourceCanvas = Canvas(sourceRecorder);
    sourceCanvas.drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = const Color(0xFFFF0000),
    );
    final sourcePicture = sourceRecorder.endRecording();
    final sourceImage = await sourcePicture.toImage(4, 4);

    final targetRecorder = PictureRecorder();
    final targetCanvas = Canvas(targetRecorder);
    SpriteActorRenderer.paint(
      targetCanvas,
      image: sourceImage,
      sourceRect: const Rect.fromLTWH(0, 0, 4, 4),
      groundAnchor: const Offset(8, 12),
      frameSize: const Size(4, 4),
      pivotX: 0.5,
      pivotY: 1,
      targetHeight: 8,
      opacity: 0.5,
      filterQuality: FilterQuality.none,
    );
    final targetPicture = targetRecorder.endRecording();
    final targetImage = await targetPicture.toImage(16, 16);
    addTearDown(() {
      sourceImage.dispose();
      sourcePicture.dispose();
      targetImage.dispose();
      targetPicture.dispose();
    });

    final pixels = await targetImage.toByteData(
      format: ImageByteFormat.rawRgba,
    );
    expect(pixels, isNotNull);
    final bytes = pixels!.buffer.asUint8List(
      pixels.offsetInBytes,
      pixels.lengthInBytes,
    );
    final center = (8 * 16 + 8) * 4;
    expect(bytes[center], 255);
    expect(bytes[center + 1], 0);
    expect(bytes[center + 2], 0);
    expect(bytes[center + 3], closeTo(128, 2));
  });

}
