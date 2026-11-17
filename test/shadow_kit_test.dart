import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shadow combat kit', () {
    final kit = shadowKit;

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
        ['twin_fangs', 'shadow_veil', 'venom_coat', 'shadow_execute'],
      );
      expect(kit.abilitiesUnlockedAt(1).length, 1);
      expect(kit.abilitiesUnlockedAt(10).length, 2);
      expect(kit.abilitiesUnlockedAt(20).length, 3);
      expect(kit.abilitiesUnlockedAt(30).length, 4);
    });

    test('is a fast dagger build with the purple identity', () {
      expect(kit.heroId, 'shadow');
      expect(kit.attackStyle, AttackStyle.melee);
      expect(kit.playable, isTrue);
      expect(kit.weaponAr, contains('خنجر'));
      expect(kit.accentColor, 0xFFB57BFF);
      expect(kit.moveSpeed, greaterThan(flameKit.moveSpeed));
    });

    test('abilities map to the right animation clips', () {
      expect(kit.abilityById('twin_fangs')!.usesAttackClip, isTrue);
      expect(kit.abilityById('shadow_veil')!.usesAttackClip, isFalse);
      expect(kit.abilityById('venom_coat')!.usesAttackClip, isFalse);
      expect(kit.abilityById('shadow_execute')!.usesAttackClip, isFalse);
    });

    test('identity stays distinct from the Flame build', () {
      expect(shadowKit.accentColor, isNot(flameKit.accentColor));
      expect(shadowKit.baseDamage, isNot(flameKit.baseDamage));
      // The veil speed boost lives outside the kit buff, so the venom buff
      // does not inherit Flame's rage movement.
      expect(shadowKit.buffMoveMult, 1.0);
    });
  });
}
