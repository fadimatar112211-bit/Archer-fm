import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final heroId in ['ranger_new', 'flame', 'shadow', 'storm']) {
    test('$heroId production loader decodes every atlas and resolves every clip frame',
        () async {
      final hero = heroById(heroId);
      final manifestLoader = BundleHeroAssetLoader(hero);
      final manifest = await manifestLoader.loadManifest();
      manifestLoader.dispose();

      expect(manifest.heroId, heroId);
      expect(manifest.clips.length, 64);
      expect(manifest.atlases.length, 64);

      // Decode by unique image path. Shadow's eight walk clips intentionally
      // share one user-supplied 8×4 sheet and must reuse one decoded ui.Image.
      final entriesByImage = <String, List<String>>{};
      for (final entry in manifest.atlases) {
        entriesByImage.putIfAbsent(entry.image, () => []).add(entry.animation);
      }

      for (final animations in entriesByImage.values) {
        final loader = BundleHeroAssetLoader(hero);
        try {
          for (final animation in animations) {
            final sheet = await loader.loadSheet(manifest, animation);
            final resolvedClip = manifest.clips[animation];
            expect(resolvedClip, isNotNull, reason: animation);
            expect(sheet.width, greaterThan(0), reason: animation);
            expect(sheet.height, greaterThan(0), reason: animation);
            for (final frameId in resolvedClip!.frames) {
              final rect = sheet.rectFor(frameId);
              expect(rect, isNotNull, reason: '$animation: $frameId');
              expect(rect!.left, greaterThanOrEqualTo(0), reason: frameId);
              expect(rect.top, greaterThanOrEqualTo(0), reason: frameId);
              expect(rect.width, manifest.frameWidth.toDouble(), reason: frameId);
              expect(rect.height, manifest.frameHeight.toDouble(), reason: frameId);
              expect(rect.right, lessThanOrEqualTo(sheet.width.toDouble()),
                  reason: frameId);
              expect(rect.bottom, lessThanOrEqualTo(sheet.height.toDouble()),
                  reason: frameId);
            }
          }
          if (animations.length > 1) {
            final first = await loader.loadSheet(manifest, animations.first);
            for (final animation in animations.skip(1)) {
              final next = await loader.loadSheet(manifest, animation);
              expect(identical(next.image, first.image), isTrue,
                  reason: '$heroId shared image ${manifest.atlasFor(animation)!.image}');
            }
          }
        } finally {
          loader.dispose();
        }
      }
    });
  }
}
