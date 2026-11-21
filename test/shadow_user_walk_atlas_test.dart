import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _root = 'assets/heroes/shadow/renders';
const _atlasPath = 'atlases/shadow_walk_8dir_4frames_FINAL.png';
const _directions = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw'];

void main() {
  test('Shadow user walk atlas is transparent RGBA 8x4 with all 32 frames', () async {
    final manifest = jsonDecode(
      File('$_root/shadow_manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final animations = manifest['animations'] as Map<String, dynamic>;
    final atlases = (manifest['atlases'] as List).cast<Map<String, dynamic>>();

    final bytes = File('$_root/$_atlasPath').readAsBytesSync();
    expect(bytes.length, greaterThan(32));
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    // PNG IHDR: width/height, bit depth and color type (6 = RGBA).
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(16), 768);
    expect(data.getUint32(20), 1536);
    expect(bytes[24], 8);
    expect(bytes[25], 6, reason: 'the atlas must retain a real alpha channel');

    // Decode the actual PNG rather than trusting its file extension or IHDR
    // alone. All four outer corners must be transparent, and the atlas must
    // contain both visible character pixels and transparent background pixels.
    final codec = await ui.instantiateImageCodec(bytes);
    addTearDown(codec.dispose);
    final decoded = await codec.getNextFrame();
    addTearDown(decoded.image.dispose);
    expect(decoded.image.width, 768);
    expect(decoded.image.height, 1536);
    final rgba = await decoded.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(rgba, isNotNull);
    final pixels = rgba!.buffer.asUint8List();
    int alphaAt(int x, int y) => pixels[(y * 768 + x) * 4 + 3];
    expect(alphaAt(0, 0), 0, reason: 'top-left must be transparent');
    expect(alphaAt(767, 0), 0, reason: 'top-right must be transparent');
    expect(alphaAt(0, 1535), 0, reason: 'bottom-left must be transparent');
    expect(alphaAt(767, 1535), 0, reason: 'bottom-right must be transparent');
    var transparentPixels = 0;
    var opaquePixels = 0;
    for (var i = 3; i < pixels.length; i += 4) {
      if (pixels[i] == 0) {
        transparentPixels++;
      } else if (pixels[i] == 255) {
        opaquePixels++;
      }
    }
    expect(transparentPixels, greaterThan(10000));
    expect(opaquePixels, greaterThan(10000));

    // Idle must preserve the exact same user-approved Shadow identity.
    // Until dedicated idle artwork is supplied, hold frame zero of each
    // directional user walk row instead of showing the legacy mismatched model.
    for (final direction in _directions) {
      final idle = animations['idle_$direction'] as Map<String, dynamic>;
      expect(idle['frames'], ['shadow_walk_${direction}_user_000']);
      expect(idle['loop'], isTrue);
      final idleEntry = atlases.singleWhere(
        (item) => item['animation'] == 'idle_$direction',
      );
      expect(idleEntry['image'], _atlasPath);
      expect(
        idleEntry['meta'],
        'atlases/walk_${direction}_user.json',
      );
    }

    for (var row = 0; row < _directions.length; row++) {
      final direction = _directions[row];
      final animation = 'walk_$direction';
      final clip = animations[animation] as Map<String, dynamic>;
      final frameIds = (clip['frames'] as List).cast<String>();
      expect(frameIds, [
        for (var column = 0; column < 4; column++)
          'shadow_walk_${direction}_user_${column.toString().padLeft(3, '0')}',
      ], reason: animation);
      expect(clip['loop'], isTrue, reason: animation);
      expect(clip['frame_duration_ms'], 100, reason: animation);

      final entry = atlases.singleWhere(
        (item) => item['animation'] == animation,
      );
      expect(entry['image'], _atlasPath, reason: animation);
      final metadata = jsonDecode(
        File('$_root/${entry['meta']}').readAsStringSync(),
      ) as Map<String, dynamic>;
      final frames = metadata['frames'] as Map<String, dynamic>;
      for (var column = 0; column < 4; column++) {
        final id = frameIds[column];
        final frame = (frames[id] as Map<String, dynamic>)['frame']
            as Map<String, dynamic>;
        expect(frame['x'], column * 192, reason: id);
        expect(frame['y'], row * 192, reason: id);
        expect(frame['w'], 192, reason: id);
        expect(frame['h'], 192, reason: id);
        expect(frame['x'] + frame['w'], lessThanOrEqualTo(768), reason: id);
        expect(frame['y'] + frame['h'], lessThanOrEqualTo(1536), reason: id);
      }
    }
  });
}
