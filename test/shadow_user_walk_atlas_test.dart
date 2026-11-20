import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _root = 'assets/heroes/shadow/renders';
const _atlasPath = 'atlases/shadow_walk_8dir_4frames_FINAL.png';
const _directions = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw'];

void main() {
  test('Shadow user walk atlas is an RGBA 8x4 sheet with all 32 frames', () {
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
