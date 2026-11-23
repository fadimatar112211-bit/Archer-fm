import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/sprite_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Shadow runtime loader resolves all 8×4 walk frames from one shared atlas',
      () async {
    final hero = heroById('shadow');
    final loader = BundleHeroAssetLoader(hero);
    addTearDown(loader.dispose);

    final manifest = await loader.loadManifest();
    expect(manifest.heroId, 'shadow');
    expect(manifest.frameWidth, 192);
    expect(manifest.frameHeight, 192);
    expect(manifest.pivotX, 0.5);
    expect(manifest.pivotY, 0.86);

    // Source atlas row order differs from clockwise world-octant order.
    const directions = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw'];
    AtlasSheet? sharedImage;
    final seenFrameIds = <String>{};

    for (var row = 0; row < directions.length; row++) {
      final direction = directions[row];
      final clip = manifest.clipFor('walk', direction);
      expect(clip, isNotNull, reason: 'walk_$direction');
      expect(clip!.loop, isTrue);
      expect(clip.frames, hasLength(4));
      expect(clip.frames.toSet(), hasLength(4));

      final sheet = await loader.loadSheet(manifest, 'walk_$direction');
      sharedImage ??= sheet;
      expect(identical(sheet.image, sharedImage!.image), isTrue,
          reason: 'all directional clips must share one decoded GPU image');
      expect(sheet.width, 768);
      expect(sheet.height, 1536);

      for (var column = 0; column < clip.frames.length; column++) {
        final id = clip.frames[column];
        expect(seenFrameIds.add(id), isTrue,
            reason: 'frame id $id must belong to one direction only');
        final rect = sheet.rectFor(id);
        expect(rect, isNotNull, reason: id);
        expect(rect!.left, column * 192);
        expect(rect.top, row * 192);
        expect(rect.width, 192);
        expect(rect.height, 192);
      }

      final player = SpritePlayer(clip: clip);
      addTearDown(player.dispose);
      expect(player.frameId, clip.frames.first);
      player.advance(clip.frameDurationMs);
      expect(player.frameId, clip.frames[1]);
      player.advance(clip.frameDurationMs * 3);
      expect(player.frameIndex, 0,
          reason: 'the four-frame walk loop should wrap after frame four');
    }
    expect(seenFrameIds, hasLength(32));
  });
}
