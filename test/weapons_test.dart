import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const heroIds = ['ranger_new', 'flame', 'shadow', 'storm'];

  group('three weapons per hero', () {
    for (final id in heroIds) {
      test('$id has exactly three weapons with unlocks 1/10/20', () {
        final kit = kitForHero(id);
        expect(kit.weapons.length, 3);
        expect(kit.weapons.map((w) => w.unlockLevel), [1, 10, 20]);
        expect(kit.weapons.map((w) => w.id).toSet().length, 3);
        // The starting weapon keeps the hero's original identity and numbers.
        expect(kit.weapons.first.nameAr, kit.weaponAr);
        expect(kit.weapons.first.damageMultiplier, 1.0);
        expect(kit.weapons.first.rateMultiplier, 1.0);
        expect(kit.weapons.first.rangeMultiplier, 1.0);
        expect(kit.weaponsUnlockedAt(1).length, 1);
        expect(kit.weaponsUnlockedAt(10).length, 2);
        expect(kit.weaponsUnlockedAt(20).length, 3);
      });
    }

    test('starting weapon keeps the untouched kit', () {
      final kit = kitForHero('ranger_new');
      expect(kit.withWeapon(kit.weapons.first.id), same(kit));
      expect(kit.withWeapon(null), same(kit));
      expect(kit.withWeapon('does_not_exist'), same(kit));
    });

    test('a chosen weapon changes damage, pace and reach numerically', () {
      final kit = kitForHero('ranger_new');
      final swift = kit.withWeapon('swift_bow');
      expect(swift.weaponAr, 'قوس خفيف');
      expect(swift.baseDamage, closeTo(kit.baseDamage * 0.85, 1e-9));
      expect(swift.attackPace, closeTo(kit.attackPace * 1.3, 1e-9));
      expect(swift.rangeMultiplier, closeTo(0.9, 1e-9));

      final heavy = kit.withWeapon('heavy_bow');
      expect(heavy.baseDamage, closeTo(kit.baseDamage * 1.35, 1e-9));
      expect(heavy.attackPace, closeTo(kit.attackPace * 0.8, 1e-9));
      expect(heavy.rangeMultiplier, closeTo(1.2, 1e-9));

      // The original kit is never mutated.
      expect(kit.baseDamage, 12);
      expect(kit.attackPace, 1.6);
      expect(kit.rangeMultiplier, 1.0);
    });

    test('the chosen weapon reaches the world simulation', () {
      final base = GameWorld(kit: kitForHero('ranger_new'), spawnWaves: false);
      final heavy = GameWorld(
        kit: kitForHero('ranger_new').withWeapon('heavy_bow'),
        spawnWaves: false,
      );
      expect(base.attackRange, closeTo(260, 1e-9));
      expect(heavy.attackRange, closeTo(260 * 1.2, 1e-9));
      expect(heavy.projectileRange, closeTo(330 * 1.2, 1e-9));
      expect(heavy.attackCycleMs, greaterThan(base.attackCycleMs));
    });
  });
}
