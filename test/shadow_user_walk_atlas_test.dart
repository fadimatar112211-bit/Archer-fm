import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _root = 'assets/heroes/shadow/renders';
const _atlasPath = 'atlases/shadow_walk_8dir_4frames_FINAL.png';
const _directions = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw'];

void main() {
  test('Shadow states use only approved user art and preserve combat timing', () async {
    final manifest = jsonDecode(
      File('$_root/shadow_manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final animations = manifest['animations'] as Map<String, dynamic>;
    final atlases = (manifest['atlases'] as List).cast<Map<String, dynamic>>();

    final bytes = File('$_root/$_atlasPath').readAsBytesSync();
    expect(bytes.length, greaterThan(32));
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(16), 768);
    expect(data.getUint32(20), 1536);
    expect(bytes[24], 8);
    expect(bytes[25], 6, reason: 'the atlas must retain a real alpha channel');

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
    expect(alphaAt(0, 0), 0);
    expect(alphaAt(767, 0), 0);
    expect(alphaAt(0, 1535), 0);
    expect(alphaAt(767, 1535), 0);
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

    final expectedEvents = <String, List<Map<String, Object>>>{
      'attack': [
        {'frame': 1, 'name': 'weapon_windup'},
        {'frame': 3, 'name': 'melee_impact'},
      ],
      'skill': [
        {'frame': 2, 'name': 'shadow_charge'},
        {'frame': 4, 'name': 'shadow_burst'},
      ],
      'dodge': [
        {'frame': 2, 'name': 'dodge_start'},
        {'frame': 8, 'name': 'dodge_end'},
      ],
      'hit': [
        {'frame': 2, 'name': 'hit_react'},
      ],
      'death': [
        {'frame': 8, 'name': 'death_complete'},
      ],
    };

    for (var row = 0; row < _directions.length; row++) {
      final direction = _directions[row];
      final firstFrame = 'shadow_walk_${direction}_user_000';
      final walkFrames = [
        for (var column = 0; column < 4; column++)
          'shadow_walk_${direction}_user_${column.toString().padLeft(3, '0')}',
      ];
      final metadataPath = 'atlases/walk_${direction}_user.json';
      final metadata = jsonDecode(
        File('$_root/$metadataPath').readAsStringSync(),
      ) as Map<String, dynamic>;
      final frames = metadata['frames'] as Map<String, dynamic>;

      for (var column = 0; column < 4; column++) {
        final id = walkFrames[column];
        final frame = (frames[id] as Map<String, dynamic>)['frame']
            as Map<String, dynamic>;
        expect(frame['x'], column * 192, reason: id);
        expect(frame['y'], row * 192, reason: id);
        expect(frame['w'], 192, reason: id);
        expect(frame['h'], 192, reason: id);
        expect(frame['x'] + frame['w'], lessThanOrEqualTo(768), reason: id);
        expect(frame['y'] + frame['h'], lessThanOrEqualTo(1536), reason: id);
      }

      final idle = animations['idle_$direction'] as Map<String, dynamic>;
      expect(idle['frames'], [firstFrame]);
      expect(idle['loop'], isTrue);

      final walk = animations['walk_$direction'] as Map<String, dynamic>;
      expect(walk['frames'], walkFrames);
      expect(walk['loop'], isTrue);
      expect(walk['frame_duration_ms'], 100);

      final run = animations['run_$direction'] as Map<String, dynamic>;
      expect(run['frames'], walkFrames);
      expect(run['loop'], isTrue);
      expect(run['frame_duration_ms'], 66);

      for (final state in [
        'idle', 'walk', 'run', 'attack', 'skill', 'dodge', 'hit', 'death',
      ]) {
        final entry = atlases.singleWhere(
          (item) => item['animation'] == '${state}_$direction',
        );
        expect(entry['image'], _atlasPath, reason: '${state}_$direction');
        expect(entry['meta'], metadataPath, reason: '${state}_$direction');
      }

      for (final entry in expectedEvents.entries) {
        final state = entry.key;
        final clip = animations['${state}_$direction'] as Map<String, dynamic>;
        final clipFrames = (clip['frames'] as List).cast<String>();
        expect(clip['loop'], isFalse, reason: '${state}_$direction');
        expect(clipFrames.length, greaterThanOrEqualTo(2));
        expect(
          clipFrames.every((frame) => frame == firstFrame),
          isTrue,
          reason: '${state}_$direction must hold the approved pose until action art is supplied',
        );
        expect(clip['events'], entry.value, reason: '${state}_$direction');
      }
    }
  });
}
