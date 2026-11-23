import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/sprite_player.dart';
import 'package:flutter_test/flutter_test.dart';

const _directions = ['e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne'];
const _states = [
  'idle',
  'walk',
  'run',
  'attack',
  'skill',
  'dodge',
  'hit',
  'death',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Shadow manifest contains all 8 directions for all 8 states', () async {
    final loader = BundleHeroAssetLoader(heroById('shadow'));
    addTearDown(loader.dispose);

    final manifest = await loader.loadManifest();
    expect(manifest.heroId, 'shadow');
    expect(manifest.frameWidth, 192);
    expect(manifest.frameHeight, 192);
    expect(manifest.pivotX, 0.5);
    expect(manifest.pivotY, 0.86);
    expect(manifest.clips, hasLength(_states.length * _directions.length));
    expect(manifest.atlases, hasLength(_states.length * _directions.length));

    for (final state in _states) {
      for (final direction in _directions) {
        final name = '${state}_${direction}';
        final clip = manifest.clipFor(state, direction);
        expect(clip, isNotNull, reason: 'missing clip $name');
        expect(clip!.frames.length, greaterThanOrEqualTo(2), reason: name);
        expect(manifest.atlasFor(name), isNotNull, reason: 'missing atlas $name');
        if (state == 'idle' || state == 'walk' || state == 'run') {
          expect(clip.loop, isTrue, reason: name);
        } else {
          expect(clip.loop, isFalse, reason: name);
        }
      }
    }
  });

  test('all Shadow atlases decode and contain every declared frame', () async {
    final hero = heroById('shadow');
    final manifestLoader = BundleHeroAssetLoader(hero);
    final manifest = await manifestLoader.loadManifest();
    manifestLoader.dispose();

    for (final entry in manifest.atlases) {
      final loader = BundleHeroAssetLoader(hero);
      try {
        final sheet = await loader.loadSheet(manifest, entry.animation);
        final clip = manifest.clips[entry.animation];
        expect(clip, isNotNull, reason: entry.animation);
        expect(sheet.width, greaterThan(0), reason: entry.animation);
        expect(sheet.height, greaterThan(0), reason: entry.animation);
        for (final frameId in clip!.frames) {
          final rect = sheet.rectFor(frameId);
          expect(rect, isNotNull, reason: '${entry.animation}: $frameId');
          expect(rect!.width, manifest.frameWidth.toDouble(), reason: frameId);
          expect(rect.height, manifest.frameHeight.toDouble(), reason: frameId);
          expect(rect.left, greaterThanOrEqualTo(0), reason: frameId);
          expect(rect.top, greaterThanOrEqualTo(0), reason: frameId);
          expect(rect.right, lessThanOrEqualTo(sheet.width.toDouble()), reason: frameId);
          expect(rect.bottom, lessThanOrEqualTo(sheet.height.toDouble()), reason: frameId);
        }
      } finally {
        loader.dispose();
      }
    }
  });

  test('all eight Shadow walk directions advance and loop using their own atlases',
      () async {
    final loader = BundleHeroAssetLoader(heroById('shadow'));
    addTearDown(loader.dispose);
    final manifest = await loader.loadManifest();

    final seenFrameIds = <String>{};
    for (final direction in _directions) {
      final clip = manifest.clipFor('walk', direction)!;
      expect(clip.loop, isTrue, reason: 'walk_$direction');
      expect(clip.frames.toSet(), hasLength(clip.frames.length));

      final sheet = await loader.loadSheet(manifest, 'walk_$direction');
      expect(sheet.rectFor(clip.frames.first), isNotNull, reason: 'walk_$direction');
      for (final id in clip.frames) {
        expect(seenFrameIds.add(id), isTrue, reason: 'duplicate frame id $id');
      }

      final player = SpritePlayer(clip: clip);
      addTearDown(player.dispose);
      expect(player.frameId, clip.frames.first);
      player.advance(clip.frameDurationMs);
      expect(player.frameId, clip.frames[1]);
      player.advance(clip.frameDurationMs * (clip.frames.length - 1));
      expect(player.frameIndex, 0,
          reason: 'walk_$direction should wrap after its full frame count');
    }
    expect(seenFrameIds, hasLength(
      _directions.fold<int>(0, (sum, direction) =>
          sum + manifest.clipFor('walk', direction)!.frames.length),
    ));
  });
}
