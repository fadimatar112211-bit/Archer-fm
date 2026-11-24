import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

const _atlasPath =
    'assets/heroes/shadow/renders/atlases/shadow_walk_8dir_4frames_FINAL.png';
const _root = 'assets/heroes/shadow/renders/atlases';
const _directions = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw'];

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

    final heroManifest = jsonDecode(
      await rootBundle.loadString(
        'assets/heroes/shadow/renders/shadow_manifest.json',
      ),
    ) as Map<String, dynamic>;
    expect(heroManifest['frame_size'], {'width': 192, 'height': 192});
    expect(heroManifest['pivot'], {'x': 0.5, 'y': 0.86});

    final animations = heroManifest['animations'] as Map<String, dynamic>;
    final atlases = heroManifest['atlases'] as List<dynamic>;

    // The runtime manifest must point every walk direction at its own
    // directional metadata and at exactly the four frames in that atlas row.
    for (var row = 0; row < _directions.length; row++) {
      final direction = _directions[row];
      final clip = animations['walk_$direction'] as Map<String, dynamic>;
      final clipFrames = clip['frames'] as List<dynamic>;
      expect(clipFrames, hasLength(4), reason: 'walk_$direction');
      for (var column = 0; column < 4; column++) {
        expect(
          clipFrames[column],
          'shadow_walk_${direction}_user_00$column',
          reason: 'walk_$direction frame $column',
        );
      }
      final atlasEntry = atlases.cast<Map<String, dynamic>>().singleWhere(
        (entry) => entry['animation'] == 'walk_$direction',
      );
      expect(
        atlasEntry['meta'],
        'atlases/walk_${direction}_user.json',
        reason: 'walk_$direction must use its own row metadata',
      );
      expect(
        atlasEntry['image'],
        'atlases/shadow_walk_8dir_4frames_FINAL.png',
      );
    }

    // Every runtime clip (not only walking) must resolve through exactly
    // one atlas entry, and every referenced frame must exist inside its
    // directional metadata page and the shared source image.
    final atlasByAnimation = <String, Map<String, dynamic>>{};
    for (final rawEntry in atlases) {
      final entry = rawEntry as Map<String, dynamic>;
      final animation = entry['animation'] as String;
      expect(
        atlasByAnimation.containsKey(animation),
        isFalse,
        reason: 'duplicate atlas mapping for $animation',
      );
      atlasByAnimation[animation] = entry;
    }
    expect(atlasByAnimation.keys.toSet(), animations.keys.toSet());

    for (final entry in atlasByAnimation.entries) {
      final animation = entry.key;
      final atlas = entry.value;
      final metaPath = 'assets/heroes/shadow/renders/${atlas['meta']}';
      final meta = jsonDecode(await rootBundle.loadString(metaPath))
          as Map<String, dynamic>;
      final frames = meta['frames'] as Map<String, dynamic>;
      final clip = animations[animation] as Map<String, dynamic>;
      final clipFrames = clip['frames'] as List<dynamic>;
      expect(clipFrames, isNotEmpty, reason: animation);
      for (final frameId in clipFrames) {
        final frameEntry = frames[frameId] as Map<String, dynamic>?;
        expect(frameEntry, isNotNull, reason: '$animation references $frameId');
        final rect = frameEntry!['frame'] as Map<String, dynamic>;
        expect(rect['x'], greaterThanOrEqualTo(0), reason: frameId);
        expect(rect['y'], greaterThanOrEqualTo(0), reason: frameId);
        expect(rect['w'], 192, reason: frameId);
        expect(rect['h'], 192, reason: frameId);
        expect(rect['x'] + rect['w'], lessThanOrEqualTo(768), reason: frameId);
        expect(rect['y'] + rect['h'], lessThanOrEqualTo(1536), reason: frameId);
      }
      final events = clip['events'] as List<dynamic>? ?? const [];
      for (final rawEvent in events) {
        final event = rawEvent as Map<String, dynamic>;
        expect(event['frame'], greaterThanOrEqualTo(0), reason: animation);
        expect(event['frame'], lessThan(clipFrames.length), reason: animation);
        expect(event['name'], isA<String>(), reason: animation);
        expect((event['name'] as String).isNotEmpty, isTrue, reason: animation);
      }
    }

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
