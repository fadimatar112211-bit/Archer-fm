import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

const _atlasPath =
    'assets/heroes/shadow/renders/atlases/shadow_walk_8dir_4frames_FINAL.png';
const _root = 'assets/heroes/shadow/renders/atlases';
const _directions = ['s', 'sw', 'w', 'nw', 'n', 'ne', 'e', 'se'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('approved Shadow walk atlas is a transparent 8×4 sheet', () async {
    final data = await rootBundle.load(_atlasPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    addTearDown(() {
      image.dispose();
      codec.dispose();
    });

    expect(image.width, 768);
    expect(image.height, 1536);

    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(pixels, isNotNull);
    final rgba = pixels!.buffer.asUint8List(
      pixels.offsetInBytes,
      pixels.lengthInBytes,
    );

    var transparentPixels = 0;
    var opaquePixels = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] == 0) transparentPixels++;
      if (rgba[i] == 255) opaquePixels++;
    }
    expect(transparentPixels, greaterThan(0),
        reason: 'the source must use real alpha, not a checkerboard');
    expect(opaquePixels, greaterThan(0),
        reason: 'the sheet must contain visible character pixels');

    // Each directional manifest must describe four full, untrimmed 192×192
    // cells at the expected row in the one shared 4-column atlas.
    for (var row = 0; row < _directions.length; row++) {
      final direction = _directions[row];
      final text = await rootBundle.loadString('$_root/walk_${direction}_user.json');
      final json = jsonDecode(text) as Map<String, dynamic>;
      final frames = json['frames'] as Map<String, dynamic>;
      expect(frames.length, 4, reason: direction);
      for (var column = 0; column < 4; column++) {
        final id = 'shadow_walk_${direction}_user_00$column';
        final entry = frames[id] as Map<String, dynamic>;
        final rect = entry['frame'] as Map<String, dynamic>;
        expect(rect['x'], column * 192, reason: id);
        expect(rect['y'], row * 192, reason: id);
        expect(rect['w'], 192, reason: id);
        expect(rect['h'], 192, reason: id);
        expect(entry['rotated'], isFalse, reason: id);
        expect(entry['trimmed'], isFalse, reason: id);

        // Every cell must contain visible pixels; a manifest entry pointing
        // to an empty/transparent cell is not an accepted animation frame.
        var cellAlphaPixels = 0;
        final left = column * 192;
        final top = row * 192;
        for (var y = top; y < top + 192; y++) {
          for (var x = left; x < left + 192; x++) {
            final alphaIndex = (y * image.width + x) * 4 + 3;
            if (rgba[alphaIndex] != 0) cellAlphaPixels++;
          }
        }
        expect(cellAlphaPixels, greaterThan(0), reason: id);
      }
    }
  });
}
