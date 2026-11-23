import 'package:archer_fm/hero/hero_render_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Shadow is the only temporary sprite fallback', () {
    expect(
      HeroRenderPolicy.routeFor('shadow'),
      HeroVisualRoute.approvedSpritePilot,
    );
  });

  test('only Shadow may use the temporary sprite fallback', () {
    expect(HeroRenderPolicy.allowsSpriteAtlas('shadow'), isTrue);
    for (final heroId in ['ranger_new', 'flame', 'storm']) {
      expect(
        HeroRenderPolicy.allowsSpriteAtlas(heroId),
        isFalse,
        reason: '$heroId atlas has not passed visual acceptance',
      );
    }
  });

  test('all four hero routes are explicitly defined', () {
    for (final heroId in ['ranger_new', 'flame', 'shadow', 'storm']) {
      expect(
        HeroRenderPolicy.routeFor(heroId),
        isNotNull,
        reason: '$heroId must never fall through to an implicit visual route',
      );
    }
  });

  test('Ranger, Flame and Storm retain GLB routing while final 3D visual acceptance remains open', () {
    for (final heroId in ['ranger_new', 'flame', 'storm']) {
      expect(
        HeroRenderPolicy.routeFor(heroId),
        HeroVisualRoute.glbPrimary,
        reason: '$heroId must not switch to an unapproved sprite atlas',
      );
    }
  });
}
