import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flame combat kit', () {
    final kit = flameKit;

    test('has exactly five combo hits with the mandated escalation', () {
      expect(kit.comboHits.length, 5);
      expect(
        kit.comboHits.map((hit) => hit.multiplier),
        [1.00, 1.10, 1.20, 1.35, 1.55],
      );
    });

    test('has exactly four abilities unlocked at levels 1/10/20/30', () {
      expect(kit.abilities.length, 4);
      expect(
        kit.abilities.map((ability) => ability.unlockLevel),
        [1, 10, 20, 30],
      );
      expect(
        kit.abilities.map((ability) => ability.id),
        ['flame_slash', 'fire_wave', 'hell_burst', 'inferno_rage'],
      );
      expect(kit.abilitiesUnlockedAt(1).length, 1);
      expect(kit.abilitiesUnlockedAt(10).length, 2);
      expect(kit.abilitiesUnlockedAt(20).length, 3);
      expect(kit.abilitiesUnlockedAt(30).length, 4);
    });

    test('is a melee build with the flaming sword identity', () {
      expect(kit.heroId, 'flame');
      expect(kit.attackStyle, AttackStyle.melee);
      expect(kit.meleeRange, greaterThan(0));
      expect(kit.playable, isTrue);
      expect(kit.weaponAr, contains('اللهب'));
      expect(kit.accentColor, 0xFFFF7A33);
    });

    test('abilities map to the right animation clips', () {
      expect(kit.abilityById('flame_slash')!.usesAttackClip, isTrue);
      expect(kit.abilityById('fire_wave')!.usesAttackClip, isFalse);
      expect(kit.abilityById('hell_burst')!.usesAttackClip, isFalse);
      expect(kit.abilityById('inferno_rage')!.usesAttackClip, isFalse);
    });

    test('identity stays distinct from the Ranger build', () {
      expect(flameKit.attackStyle, isNot(rangerNewKit.attackStyle));
      expect(flameKit.baseDamage, isNot(rangerNewKit.baseDamage));
      expect(flameKit.accentColor, isNot(rangerNewKit.accentColor));
    });
  });
}
