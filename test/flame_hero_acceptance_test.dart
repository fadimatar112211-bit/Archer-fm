import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/heroes/hero_combat_runtime.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Flame ships all 64 directional animation clips and atlases', () async {
    final definition = heroById('flame');
    final manifestLoader = BundleHeroAssetLoader(definition);
    late final HeroManifest manifest;
    try {
      manifest = await manifestLoader.loadManifest();
    } finally {
      manifestLoader.dispose();
    }
    expect(manifest.heroId, 'flame');
    expect(manifest.clips, hasLength(64));
    expect(manifest.atlases, hasLength(64));

    // Decode one atlas at a time to keep test memory bounded on CI runners.
    for (final entry in manifest.atlases) {
      final clip = manifest.clips[entry.animation];
      expect(clip, isNotNull, reason: entry.animation);
      final sheetLoader = BundleHeroAssetLoader(definition);
      try {
        final sheet = await sheetLoader.loadSheet(manifest, entry.animation);
        expect(sheet.width, greaterThan(0), reason: entry.animation);
        expect(sheet.height, greaterThan(0), reason: entry.animation);
        for (final frameId in clip!.frames) {
          final rect = sheet.rectFor(frameId);
          expect(rect, isNotNull, reason: '${entry.animation}: $frameId');
          expect(rect!.width, manifest.frameWidth.toDouble());
          expect(rect.height, manifest.frameHeight.toDouble());
        }
      } finally {
        sheetLoader.dispose();
      }
    }
  });

  test('Flame has three weapons and four separately level-gated Ultimates', () {
    final flame = heroCombatById(HeroId.flame);
    expect(flame.weapons, hasLength(3));
    expect(flame.ultimates, hasLength(4));
    expect(
      flame.ultimates.map((ultimate) => ultimate.unlockLevel).toList(),
      [1, 10, 20, 30],
    );

    final levelOne = HeroCombatRuntime(hero: flame);
    expect(levelOne.useUltimate(0).accepted, isTrue);
    for (final index in [1, 2, 3]) {
      expect(levelOne.useUltimate(index).accepted, isFalse);
    }
  });

  test('Flame Ultimate does not consume or reset the five-hit manual combo', () {
    final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.flame));
    final first = runtime.attack();
    expect(first.accepted, isTrue);
    expect(first.comboIndex, 1);

    runtime.advance(const Duration(milliseconds: 650));
    expect(runtime.useUltimate(0).accepted, isTrue);
    expect(runtime.comboIndex, 1);

    runtime.advance(const Duration(milliseconds: 650));
    final second = runtime.attack();
    expect(second.accepted, isTrue);
    expect(second.comboIndex, 2);
  });
}
