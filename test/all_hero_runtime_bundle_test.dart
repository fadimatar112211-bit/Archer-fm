import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final heroId in ['ranger_new', 'flame', 'shadow', 'storm']) {
    test('$heroId production bundle loads through the runtime asset loader',
        () async {
      final hero = heroById(heroId);
      final loader = BundleHeroAssetLoader(hero);
      try {
        final manifest = await loader.loadManifest();

        expect(loader.heroId, heroId);
        expect(manifest.heroId, heroId);
        expect(manifest.frameWidth, 192);
        expect(manifest.frameHeight, 192);
        expect(manifest.clips, hasLength(64));
        expect(manifest.atlases, hasLength(64));

        for (final direction in [
          's', 'sw', 'w', 'nw', 'n', 'ne', 'e', 'se',
        ]) {
          for (final state in [
            'idle', 'walk', 'run', 'attack', 'skill', 'dodge', 'hit', 'death',
          ]) {
            final name = '${state}_${direction}';
            expect(manifest.clipFor(state, direction), isNotNull,
                reason: '$heroId/$name');
            expect(manifest.atlasFor(name), isNotNull,
                reason: '$heroId/$name');
          }
        }

        // Decode representative locomotion and combat pages through the same
        // loader used in a match. This catches missing pubspec declarations,
        // broken image paths, unreadable PNGs and metadata/clip mismatches.
        for (final animation in ['walk_s', 'attack_s', 'skill_s']) {
          final sheet = await loader.loadSheet(manifest, animation);
          final clip = manifest.clips[animation]!;
          expect(sheet.width, greaterThanOrEqualTo(manifest.frameWidth),
              reason: '$heroId/$animation');
          expect(sheet.height, greaterThanOrEqualTo(manifest.frameHeight),
              reason: '$heroId/$animation');
          for (final frameId in clip.frames) {
            final rect = sheet.rectFor(frameId);
            expect(rect, isNotNull, reason: '$heroId/$animation/$frameId');
            expect(rect!.width, manifest.frameWidth.toDouble());
            expect(rect.height, manifest.frameHeight.toDouble());
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(sheet.width.toDouble()));
            expect(rect.bottom, lessThanOrEqualTo(sheet.height.toDouble()));
          }
        }
      } finally {
        loader.dispose();
      }
    });
  }
  test('asset loader rejects another hero manifest before reading its atlas', () async {
    final loader = BundleHeroAssetLoader(heroById('ranger_new'));
    final foreignManifest = HeroManifest(
      heroId: 'flame',
      frameWidth: 192,
      frameHeight: 192,
      pivotX: 0.5,
      pivotY: 0.86,
      clips: {
        'walk_s': AnimationClip(
          name: 'walk_s',
          loop: true,
          frameDurationMs: 100,
          frames: ['frame_0'],
          events: const [],
        ),
      },
      atlases: const [
        AtlasEntry(
          animation: 'walk_s',
          image: 'atlases/walk_s.png',
          meta: 'atlases/walk_s.json',
        ),
      ],
      fps: 12,
    );
    try {
      await expectLater(
        loader.loadSheet(foreignManifest, 'walk_s'),
        throwsA(isA<FormatException>()),
      );
    } finally {
      loader.dispose();
    }
  });

}
