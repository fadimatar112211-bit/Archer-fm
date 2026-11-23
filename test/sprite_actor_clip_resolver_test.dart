import 'dart:ui' show Offset;

import 'package:archer_fm/game/render3/sprite_actor_clip_resolver.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpriteActorClipResolver', () {
    const directions = <({Offset facing, String direction})>[
      (facing: Offset(0, 1), direction: 's'),
      (facing: Offset(0.70710678, 0.70710678), direction: 'se'),
      (facing: Offset(1, 0), direction: 'e'),
      (facing: Offset(0.70710678, -0.70710678), direction: 'ne'),
      (facing: Offset(0, -1), direction: 'n'),
      (facing: Offset(-0.70710678, -0.70710678), direction: 'nw'),
      (facing: Offset(-1, 0), direction: 'w'),
      (facing: Offset(-0.70710678, 0.70710678), direction: 'sw'),
    ];

    test('maps all eight gameplay facings to the approved atlas row names', () {
      for (final item in directions) {
        expect(
          SpriteActorClipResolver.directionFor(item.facing),
          item.direction,
        );
        expect(
          SpriteActorClipResolver.clipName('walk', item.facing),
          'walk_${item.direction}',
        );
      }
    });

    test('zero facing uses the documented south-facing fallback', () {
      expect(SpriteActorClipResolver.directionFor(Offset.zero), 's');
      expect(SpriteActorClipResolver.clipName('idle', Offset.zero), 'idle_s');
    });

    test('resolves the exact directional clip without silently substituting', () {
      final clips = <String, AnimationClip>{
        for (final item in directions)
          'walk_${item.direction}': AnimationClip(
            name: 'walk_${item.direction}',
            loop: true,
            frameDurationMs: 100,
            frames: ['${item.direction}_0', '${item.direction}_1'],
            events: const [],
          ),
      };
      final manifest = HeroManifest(
        heroId: 'shadow',
        frameWidth: 192,
        frameHeight: 192,
        pivotX: 0.5,
        pivotY: 0.86,
        clips: clips,
        atlases: const [],
        fps: 10,
      );

      for (final item in directions) {
        final clip = SpriteActorClipResolver.clipFor(
          manifest,
          'walk',
          item.facing,
        );
        expect(clip?.name, 'walk_${item.direction}');
        expect(clip?.frames.first, '${item.direction}_0');
      }
      expect(
        SpriteActorClipResolver.clipFor(
          manifest,
          'attack',
          const Offset(1, 0),
        ),
        isNull,
        reason: 'missing art must stay missing instead of borrowing another direction',
      );
    });
  });
}
