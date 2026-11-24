import 'package:archer_fm/hero/hero_render_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all four playable heroes use their rigged GLB models in combat', () {
    for (final heroId in ['ranger_new', 'flame', 'shadow', 'storm']) {
      expect(
        HeroRenderPolicy.routeFor(heroId),
        HeroVisualRoute.glbPrimary,
        reason: '$heroId must use its complete rigged GLB action set',
      );
      expect(HeroRenderPolicy.allowsSpriteAtlas(heroId), isFalse);
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

  test('Ranger, Flame and Storm retain safe transitional GLB routes until sprite acceptance', () {
    for (final heroId in ['ranger_new', 'flame', 'storm']) {
      expect(
        HeroRenderPolicy.routeFor(heroId),
        HeroVisualRoute.glbPrimary,
        reason: '$heroId must not switch to an unapproved sprite atlas',
      );
    }
  });
}
