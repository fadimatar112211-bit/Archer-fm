import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Archer FM hero roster', () {
    test('contains all four heroes with three unique weapons each', () {
      expect(archerFmHeroes.map((hero) => hero.id).toSet(), HeroId.values.toSet());
      expect(archerFmHeroes.map((hero) => hero.modelAssetPath).toSet(), hasLength(4));
      for (final hero in archerFmHeroes) {
        expect(hero.weapons, hasLength(3), reason: hero.id.name);
        expect(hero.modelAssetPath, contains('/model/'));
        expect(hero.modelAssetPath, endsWith('_animated.glb'));
        expect(hero.weapons.map((weapon) => weapon.id).toSet(), hasLength(3));
      }
    });

    test('all heroes have equal health at every shared level', () {
      for (var level = 1; level <= heroLevelCap; level++) {
        final healthValues = archerFmHeroes.map((hero) => hero.healthAt(level)).toSet();
        expect(healthValues, hasLength(1), reason: 'level $level');
      }
    });

    test('hero movement speeds are distinct', () {
      expect(archerFmHeroes.map((hero) => hero.moveSpeed).toSet(), hasLength(4));
    });

    test('four independent Ultimates unlock at 1, 10, 20 and 30', () {
      for (final hero in archerFmHeroes) {
        expect(hero.ultimates, hasLength(4));
        expect(hero.ultimates.map((ultimate) => ultimate.unlockLevel).toList(),
            ultimateUnlockLevels);
        for (var index = 0; index < 4; index++) {
          final unlock = ultimateUnlockLevels[index];
          expect(hero.isUltimateUnlocked(index, unlock), isTrue);
          if (unlock > 1) {
            expect(hero.isUltimateUnlocked(index, unlock - 1), isFalse);
          }
        }
      }
    });

    test('five-hit combo is independent and has a stronger finisher', () {
      expect(comboHitCount, 5);
      final hits = List.generate(5, (index) => comboDamageForTap(100, index));
      expect(hits, [100, 105, 110, 120, 155]);
      expect(() => comboDamageForTap(100, 5), throwsRangeError);
    });

    test('level cap is 40 and progression stays defined through cap', () {
      expect(heroLevelCap, 40);
      for (final hero in archerFmHeroes) {
        expect(hero.healthAt(heroLevelCap), greaterThan(hero.healthAt(1)));
        expect(hero.damageAt(heroLevelCap), greaterThan(hero.damageAt(1)));
      }
    });
  });
}
