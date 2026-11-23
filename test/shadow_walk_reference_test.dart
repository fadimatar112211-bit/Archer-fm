import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'assets/heroes/shadow/renders';
  const directions = ['s', 'sw', 'w', 'nw', 'n', 'ne', 'e', 'se'];

  test('Shadow keeps the approved 8-direction x 4-frame walk sheet intact', () {
    final manifest = HeroManifest.fromJson(
      jsonDecode(File('$root/shadow_manifest.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    expect(manifest.heroId, 'shadow');
    expect(manifest.frameWidth, 192);
    expect(manifest.frameHeight, 192);
    expect(manifest.pivotX, 0.5);
    expect(manifest.pivotY, 0.86);

    final rows = <int>{};
    String? sharedImage;
    for (final direction in directions) {
      final animation = 'walk_$direction';
      final clip = manifest.clipFor('walk', direction);
      final atlas = manifest.atlasFor(animation);

      expect(clip, isNotNull, reason: 'missing $animation');
      expect(clip!.frames, [
        for (var frame = 0; frame < 4; frame++)
          'shadow_walk_${direction}_user_${frame.toString().padLeft(3, '0')}',
      ], reason: '$animation must preserve the four supplied frames');
      expect(clip.loop, isTrue, reason: '$animation must loop');
      expect(clip.frameDurationMs, greaterThan(0));
      expect(atlas, isNotNull, reason: 'missing atlas mapping for $animation');

      sharedImage ??= atlas!.image;
      expect(atlas!.image, sharedImage,
          reason: 'all directions must reference the original 8x4 sheet');

      final metadataFile = File('$root/${atlas.meta}');
      expect(metadataFile.existsSync(), isTrue, reason: atlas.meta);
      final metadata =
          jsonDecode(metadataFile.readAsStringSync()) as Map<String, dynamic>;
      final meta = metadata['meta'] as Map<String, dynamic>;
      expect(meta['image'], 'shadow_walk_8dir_4frames_FINAL.png');
      expect(meta['size'], {'w': 768, 'h': 1536});
      expect(meta['frame_size'], {'w': 192, 'h': 192});
      expect(meta['pivot'], {'x': 0.5, 'y': 0.86});

      final frames = metadata['frames'] as Map<String, dynamic>;
      expect(frames.keys.toSet(), clip.frames.toSet());
      int? rowY;
      for (var frame = 0; frame < 4; frame++) {
        final id = clip.frames[frame];
        final rect = (frames[id] as Map<String, dynamic>)['frame']
            as Map<String, dynamic>;
        expect(rect['x'], frame * 192, reason: id);
        expect(rect['w'], 192, reason: id);
        expect(rect['h'], 192, reason: id);
        rowY ??= rect['y'] as int;
        expect(rect['y'], rowY, reason: '$animation must stay on one row');
      }
      expect(rows.add(rowY!), isTrue,
          reason: '$animation must occupy its own direction row');
      expect(rowY % 192, 0);
    }

    expect(rows, hasLength(8));
    expect(File('$root/atlases/shadow_walk_8dir_4frames_FINAL.png').existsSync(),
        isTrue);
  });
}
