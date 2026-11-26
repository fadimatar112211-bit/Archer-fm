import 'package:archer_fm/hero/hero3d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Hero3D loads all four hero bins and exposes ready state', () async {
    for (final id in const ['ranger', 'flame', 'storm', 'shadow']) {
      final hero = Hero3D(id, height: 90);
      expect(hero.isReady, isFalse);
      await hero.load();
      expect(hero.isReady, isTrue, reason: '$id should load');
      expect(hero.anim, 'idle');
      expect(hero.hp, 100);
      hero.dispose();
    }
  });

  test('Hero3D supports core movement commands', () async {
    final hero = Hero3D('flame', height: 90);
    await hero.load();

    hero.attack();
    expect(hero.anim, startsWith('attack'));
    hero.update(0.5, Offset.zero);
    hero.dash();
    // dash may or may not trigger depending on state; just ensure no crash
    hero.update(0.3, Offset.zero);

    hero.revive(100);
    expect(hero.isDead, isFalse);
    hero.hurt(20);
    expect(hero.hp, 80);
    hero.hurt(200);
    expect(hero.isDead, isTrue);

    hero.revive(100);
    expect(hero.hp, 100);
    expect(hero.isDead, isFalse);

    for (var n = 1; n <= 4; n++) {
      hero.revive(100);
      final ok = hero.ultimate(n);
      expect(ok, isTrue, reason: 'ult$n should trigger from idle');
    }
    hero.dispose();
  });
}
