import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kits = <HeroKit>[
    rangerNewKit,
    flameKit,
    shadowKit,
    stormKit,
  ];

  group('hero special progression stays separate from the normal combo', () {
    test('every hero unlocks four abilities at levels 1, 10, 20 and 30', () {
      for (final kit in kits) {
        expect(kit.abilities, hasLength(4), reason: kit.heroId);
        expect(
          kit.abilities.map((ability) => ability.unlockLevel).toList(),
          [1, 10, 20, 30],
          reason: kit.heroId,
        );
        expect(kit.abilitiesUnlockedAt(1), hasLength(1), reason: kit.heroId);
        expect(kit.abilitiesUnlockedAt(9), hasLength(1), reason: kit.heroId);
        expect(kit.abilitiesUnlockedAt(10), hasLength(2), reason: kit.heroId);
        expect(kit.abilitiesUnlockedAt(19), hasLength(2), reason: kit.heroId);
        expect(kit.abilitiesUnlockedAt(20), hasLength(3), reason: kit.heroId);
        expect(kit.abilitiesUnlockedAt(29), hasLength(3), reason: kit.heroId);
        expect(kit.abilitiesUnlockedAt(30), hasLength(4), reason: kit.heroId);
        expect(kit.abilitiesUnlockedAt(40), hasLength(4), reason: kit.heroId);
      }
    });

    test('special ability names and IDs are unique within each hero', () {
      for (final kit in kits) {
        expect(kit.abilities.map((a) => a.id).toSet(), hasLength(4),
            reason: kit.heroId);
        expect(kit.abilities.map((a) => a.nameAr).toSet(), hasLength(4),
            reason: kit.heroId);
        expect(kit.abilities.map((a) => a.unlockLevel).toSet(),
            {1, 10, 20, 30}, reason: kit.heroId);
      }
    });

    test('five manual combo hits remain five independent normal attacks', () {
      for (final kit in kits) {
        expect(kit.comboHits, hasLength(5), reason: kit.heroId);
        expect(
          kit.comboHits.map((hit) => hit.index).toList(),
          [1, 2, 3, 4, 5],
          reason: kit.heroId,
        );
        expect(kit.comboHits.map((hit) => hit.multiplier).toList(),
            [1.0, 1.1, 1.2, 1.35, 1.55], reason: kit.heroId);
        expect(kit.abilities.map((ability) => ability.id).toSet(),
            hasLength(4), reason: kit.heroId);
      }
    });

    test('weapon choices unlock exactly at levels 1, 10 and 20', () {
      for (final kit in kits) {
        expect(kit.weaponsUnlockedAt(1).map((w) => w.id).toList(),
            [kit.weapons[0].id], reason: kit.heroId);
        expect(kit.weaponsUnlockedAt(9), hasLength(1), reason: kit.heroId);
        expect(kit.weaponsUnlockedAt(10), hasLength(2), reason: kit.heroId);
        expect(kit.weaponsUnlockedAt(19), hasLength(2), reason: kit.heroId);
        expect(kit.weaponsUnlockedAt(20), hasLength(3), reason: kit.heroId);
        expect(kit.weaponsUnlockedAt(40), hasLength(3), reason: kit.heroId);
      }
    });

    test('special abilities have valid energy and cooldown costs', () {
      for (final kit in kits) {
        for (final ability in kit.abilities) {
          expect(ability.id.trim(), isNotEmpty, reason: kit.heroId);
          expect(ability.nameAr.trim(), isNotEmpty, reason: kit.heroId);
          expect(ability.descAr.trim(), isNotEmpty, reason: kit.heroId);
          expect(ability.cooldownMs, greaterThan(0), reason: ability.id);
          expect(ability.energyCost, greaterThan(0), reason: ability.id);
          expect(ability.unlockLevel, inInclusiveRange(1, 40),
              reason: ability.id);
        }
      }
    });

    test('weapon variants have finite positive combat multipliers', () {
      for (final kit in kits) {
        for (final weapon in kit.weapons) {
          expect(weapon.damageMultiplier.isFinite &&
              weapon.damageMultiplier > 0, isTrue, reason: weapon.id);
          expect(weapon.rateMultiplier.isFinite &&
              weapon.rateMultiplier > 0, isTrue, reason: weapon.id);
          expect(weapon.rangeMultiplier.isFinite &&
              weapon.rangeMultiplier > 0, isTrue, reason: weapon.id);
        }
      }
    });

    test('same-level hero health is equal while movement speeds differ', () {
      expect(kits.map((kit) => kit.baseMaxHp).toSet(), {100.0});
      expect(kits.map((kit) => kit.moveSpeed).toSet(), hasLength(4));
    });

    test('each hero has three distinct weapon choices', () {
      for (final kit in kits) {
        expect(kit.weapons, hasLength(3), reason: kit.heroId);
        expect(kit.weapons.map((weapon) => weapon.id).toSet(),
            hasLength(3), reason: kit.heroId);
      }
    });
  });
}
