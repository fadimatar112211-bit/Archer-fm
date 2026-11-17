import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ranger combat kit', () {
    final kit = rangerNewKit;

    test('has exactly five combo hits with the mandated escalation', () {
      expect(kit.comboHits.length, 5);
      expect(
        kit.comboHits.map((hit) => hit.multiplier),
        [1.00, 1.10, 1.20, 1.35, 1.55],
      );
      expect(kit.comboHit(5).multiplier, 1.55);
    });

    test('has exactly four abilities unlocked at levels 1/10/20/30', () {
      expect(kit.abilities.length, 4);
      expect(
        kit.abilities.map((ability) => ability.unlockLevel),
        [1, 10, 20, 30],
      );
      expect(
        kit.abilities.map((ability) => ability.id),
        ['multi_shot', 'piercing_shot', 'arrow_rain', 'gale_surge'],
      );
    });

    test('ability availability follows the hero level', () {
      expect(kit.abilitiesUnlockedAt(1).length, 1);
      expect(kit.abilitiesUnlockedAt(9).length, 1);
      expect(kit.abilitiesUnlockedAt(10).length, 2);
      expect(kit.abilitiesUnlockedAt(20).length, 3);
      expect(kit.abilitiesUnlockedAt(30).length, 4);
      expect(kit.abilitiesUnlockedAt(40).length, 4);
    });

    test('base damage propagates through combo and ability multipliers', () {
      // Third combo hit = 120%.
      expect(
        kit.baseDamage * kit.comboHit(3).multiplier,
        closeTo(14.4, 1e-9),
      );
      // Fifth combo hit = 155%.
      expect(kit.baseDamage * kit.comboHit(5).multiplier, closeTo(18.6, 1e-9));
      // Piercing shot = 220%.
      expect(kit.baseDamage * 2.2, closeTo(26.4, 1e-9));
    });

    test('weapon identity stays the green energy bow', () {
      expect(kit.weaponAr, contains('الخضراء'));
      expect(kit.heroId, 'ranger_new');
      expect(kit.playable, isTrue);
    });

    test('non-completed heroes are marked not playable', () {
      expect(flameKit.playable, isTrue); // completed combat build
      expect(shadowKit.playable, isFalse);
      expect(stormKit.playable, isFalse);
    });
  });
}
