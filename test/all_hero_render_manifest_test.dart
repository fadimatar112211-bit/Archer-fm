import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _heroes = ['flame', 'shadow', 'storm', 'ranger_new'];
const _states = [
  'idle', 'walk', 'run', 'attack', 'skill', 'dodge', 'hit', 'death',
];
const _directions = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];

void main() {
  for (final hero in _heroes) {
    test('$hero has all 8 states × 8 directions and bundled atlases', () {
      final root = 'assets/heroes/$hero/renders';
      final manifestFile = File('$root/${hero}_manifest.json');
      expect(manifestFile.existsSync(), isTrue, reason: hero);
      final manifest = jsonDecode(manifestFile.readAsStringSync())
          as Map<String, dynamic>;
      expect(manifest['hero_id'], hero);
      final animations = manifest['animations'] as Map<String, dynamic>;
      final atlases = manifest['atlases'] as List<dynamic>;
      expect(animations.length, 64, reason: hero);
      expect(atlases.length, 64, reason: hero);

      if (hero == 'shadow') {
        // Phase 1 of the approved conversion plan is the user's supplied
        // eight-direction, four-frame Shadow walk sheet. Other Shadow states
        // intentionally hold that approved source pose until dedicated art is
        // available; do not count those held frames as finished animations.
        for (final direction in _directions) {
          final walk = animations['walk_$direction'] as Map<String, dynamic>;
          final frames = (walk['frames'] as List).cast<String>();
          expect(frames, hasLength(4), reason: 'shadow/walk_$direction');
          expect(frames.toSet(), hasLength(4),
              reason: 'shadow/walk_$direction must contain four real frames');
        }
      }
      for (final state in _states) {
        for (final direction in _directions) {
          final name = '${state}_${direction}';
          expect(animations.containsKey(name), isTrue, reason: '$hero/$name');
          final clip = animations[name] as Map<String, dynamic>;
          final frameIds = (clip['frames'] as List).cast<String>();
          final frameCount = frameIds.length;
          // Shadow currently has approved user art for its eight-way
          // walk cycle only. Until dedicated action art is supplied, its
          // combat clips intentionally hold the approved first walk pose;
          // their timing/events remain real and must not be faked with
          // unrelated generated atlas frames.
          final shadowHeldAction = hero == 'shadow' &&
              const {'attack', 'skill', 'dodge', 'hit', 'death'}.contains(state);
          if (state != 'idle' && !shadowHeldAction) {
            expect(
              frameIds.toSet().length,
              frameCount,
              reason: '$hero/$name must not repeat held-pose frames',
            );
          }
          // A one-frame looping idle is a deliberate static pose; all other
          // clips need multiple frames to animate.
          expect(
            frameCount,
            state == 'idle' ? greaterThanOrEqualTo(1) : greaterThanOrEqualTo(2),
            reason: '$hero/$name',
          );
          expect(clip['frame_duration_ms'], greaterThan(0),
              reason: '$hero/$name');
          final atlas = atlases.cast<Map<String, dynamic>>().firstWhere(
            (entry) => entry['animation'] == name,
            orElse: () => <String, dynamic>{},
          );
          expect(atlas, isNotEmpty, reason: '$hero/$name atlas entry');
          expect(File('$root/${atlas['image']}').existsSync(), isTrue,
              reason: '$hero/$name image');
          final metaFile = File('$root/${atlas['meta']}');
          expect(metaFile.existsSync(), isTrue, reason: '$hero/$name metadata');
          final atlasMeta = jsonDecode(metaFile.readAsStringSync())
              as Map<String, dynamic>;
          final atlasFrameIds = (atlasMeta['frames'] as Map<String, dynamic>)
              .keys
              .toSet();
          expect(
            frameIds.every(atlasFrameIds.contains),
            isTrue,
            reason: '$hero/$name must reference frames present in its own atlas',
          );
        }
      }
    });
  }
}
