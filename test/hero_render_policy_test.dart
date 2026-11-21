import 'package:archer_fm/hero/hero_render_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Shadow is the only approved 2.5D sprite pilot', () {
    expect(
      HeroRenderPolicy.routeFor('shadow'),
      HeroVisualRoute.approvedSpritePilot,
    );
  });

  test('only Shadow may display its sprite atlas in production', () {
    expect(HeroRenderPolicy.allowsSpriteAtlas('shadow'), isTrue);
    for (final heroId in ['ranger_new', 'flame', 'storm']) {
      expect(
        HeroRenderPolicy.allowsSpriteAtlas(heroId),
        isFalse,
        reason: '$heroId atlas has not passed visual acceptance',
      );
    }
  });

  test('Ranger, Flame and Storm retain GLB visuals until sprite approval', () {
    for (final heroId in ['ranger_new', 'flame', 'storm']) {
      expect(
        HeroRenderPolicy.routeFor(heroId),
        HeroVisualRoute.glbPrimary,
        reason: '$heroId must not switch to an unapproved sprite atlas',
      );
    }
  });
}
