import 'dart:io';

import 'package:archer_fm/hero/hero_render_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Shadow production uses the fully rigged GLB, not partial sprite actions', () {
    expect(HeroRenderPolicy.routeFor('shadow'), HeroVisualRoute.glbPrimary);
    expect(HeroRenderPolicy.allowsSpriteAtlas('shadow'), isFalse);
    expect(
      File('assets/heroes/shadow/model/shadow_animated.glb').existsSync(),
      isTrue,
      reason: 'Shadow must ship its complete rigged model and action clips',
    );
  });
}
