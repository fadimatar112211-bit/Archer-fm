import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/sprite_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Shadow walk loads all eight directional atlases and loops nine frames',
      () async {
    final loader = BundleHeroAssetLoader(heroById('shadow'));
    addTearDown(loader.dispose);

    final manifest = await loader.loadManifest();
    expect(manifest.heroId, 'shadow');
    expect(manifest.frameWidth, 192);
    expect(manifest.frameHeight, 192);
    expect(manifest.pivotX, 0.5);
    expect(manifest.pivotY, 0.86);

    const directions = ['e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne'];
    final seenFrameIds = <String>{};

    for (final direction in directions) {
      final clip = manifest.clipFor('walk', direction);
      expect(clip, isNotNull, reason: 'walk_$direction');
      final walkClip = clip!;
      expect(walkClip.loop, isTrue);
      expect(walkClip.frames, hasLength(9));
      expect(walkClip.frames.toSet(), hasLength(9));

      final sheet = await loader.loadSheet(manifest, 'walk_$direction');
      expect(sheet.width, 784);
      expect(sheet.height, 588);

      for (var index = 0; index < walkClip.frames.length; index++) {
        final id = walkClip.frames[index];
        expect(seenFrameIds.add(id), isTrue, reason: 'duplicate frame $id');
        final rect = sheet.rectFor(id);
        expect(rect, isNotNull, reason: id);
        final frameRect = rect!;
        expect(frameRect.left, (index % 4) * 196 + 2);
        expect(frameRect.top, (index ~/ 4) * 196 + 2);
        expect(frameRect.width, 192);
        expect(frameRect.height, 192);
      }

      final player = SpritePlayer(clip: walkClip);
      addTearDown(player.dispose);
      expect(player.frameId, walkClip.frames.first);
      player.advance(walkClip.frameDurationMs);
      expect(player.frameId, walkClip.frames[1]);
      player.advance(walkClip.frameDurationMs * 8);
      expect(player.frameIndex, 0,
          reason: 'the nine-frame walk loop should wrap after frame nine');
    }
    expect(seenFrameIds, hasLength(72));
  });
}
