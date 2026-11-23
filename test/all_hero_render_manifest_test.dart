import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _heroes = ['flame', 'shadow', 'storm', 'ranger_new'];
// Dodge is intentionally excluded: it is not a gameplay action in the
// approved combat rules and must not block hero-art acceptance.
const _requiredStates = [
  'idle', 'walk', 'run', 'attack', 'skill', 'hit', 'death',
];
const _directions = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];

Future<void> _expectVisiblePng(String path, String reason) async {
  final bytes = await File(path).readAsBytes();
  expect(bytes.length, greaterThan(100), reason: '$reason must not be a tiny placeholder');
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      expect(image.width, greaterThanOrEqualTo(32), reason: '$reason width');
      expect(image.height, greaterThanOrEqualTo(32), reason: '$reason height');
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(rgba, isNotNull, reason: '$reason must decode to RGBA');
      final data = rgba!.buffer.asUint8List(
        rgba.offsetInBytes,
        rgba.lengthInBytes,
      );
      var visiblePixels = 0;
      for (var alpha = 3; alpha < data.length; alpha += 4) {
        if (data[alpha] != 0) visiblePixels++;
      }
      expect(visiblePixels, greaterThan(0), reason: '$reason must contain visible pixels');
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  for (final hero in _heroes) {
    test('$hero has all required states × 8 directions and real PNG atlases', () async {
      final root = 'assets/heroes/$hero/renders';
      final manifestFile = File('$root/${hero}_manifest.json');
      expect(manifestFile.existsSync(), isTrue, reason: hero);
      final manifest = jsonDecode(manifestFile.readAsStringSync())
          as Map<String, dynamic>;
      expect(manifest['hero_id'], hero);
      final animations = manifest['animations'] as Map<String, dynamic>;
      final atlases = manifest['atlases'] as List<dynamic>;
      final requiredClips = {
        for (final state in _requiredStates)
          for (final direction in _directions) '${state}_${direction}',
      };
      expect(animations.keys, containsAll(requiredClips), reason: hero);

      if (hero == 'shadow') {
        // Phase 1 is the user's supplied eight-direction, four-frame walk
        // sheet. Held action poses are explicitly not accepted as finished art.
        for (final direction in _directions) {
          final walk = animations['walk_${direction}'] as Map<String, dynamic>;
          final frames = (walk['frames'] as List).cast<String>();
          expect(frames, hasLength(4), reason: 'shadow/walk_${direction}');
          expect(frames.toSet(), hasLength(4),
              reason: 'shadow/walk_${direction} must contain four real frames');
        }
      }

      final atlasByAnimation = <String, Map<String, dynamic>>{};
      for (final raw in atlases) {
        final entry = raw as Map<String, dynamic>;
        atlasByAnimation[entry['animation'] as String] = entry;
      }
      final checkedImages = <String>{};
      for (final name in requiredClips) {
        final clip = animations[name] as Map<String, dynamic>;
        final frameIds = (clip['frames'] as List).cast<String>();
        final frameCount = frameIds.length;
        // Shadow currently has approved user art for its eight-way walk only.
        // Its other clips may hold poses, but must not be called complete.
        final shadowHeldAction = hero == 'shadow' &&
            const {'attack', 'skill', 'hit', 'death'}
                .contains(name.split('_').first);
        if (name.split('_').first != 'idle' && !shadowHeldAction) {
          expect(frameIds.toSet().length, frameCount,
              reason: '$hero/$name must not repeat held-pose frames');
        }
        expect(frameCount,
            name.startsWith('idle_') ? greaterThanOrEqualTo(1) : greaterThanOrEqualTo(2),
            reason: '$hero/$name');
        expect(clip['frame_duration_ms'], greaterThan(0), reason: '$hero/$name');

        final atlas = atlasByAnimation[name];
        expect(atlas, isNotNull, reason: '$hero/$name atlas entry');
        final imagePath = '$root/${atlas!['image']}';
        final metaFile = File('$root/${atlas['meta']}');
        expect(metaFile.existsSync(), isTrue, reason: '$hero/$name metadata');
        final atlasMeta = jsonDecode(metaFile.readAsStringSync())
            as Map<String, dynamic>;
        final atlasFrames = (atlasMeta['frames'] as Map<String, dynamic>)
            .keys
            .toSet();
        expect(frameIds.every(atlasFrames.contains), isTrue,
            reason: '$hero/$name must reference frames in its atlas');
        if (checkedImages.add(imagePath)) {
          await _expectVisiblePng(imagePath, '$hero/$name atlas');
        }
      }
    });
  }
}
