import 'dart:io';

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Storm is intentionally NOT playable: the repo has only 4 design SVGs.
/// These tests lock the prepared gameplay data so that the moment the asset
/// pipeline lands, wiring is the only remaining work.
void main() {
  group('Storm combat kit (data ready, assets missing)', () {
    final kit = stormKit;

    test('is explicitly blocked until its asset pipeline lands', () {
      expect(kit.heroId, 'storm');
      expect(kit.playable, isFalse,
          reason: 'storm has no renders/atlases/manifest on disk yet');
    });

    test('keeps the mandated 5-hit combo escalation', () {
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
        ['thunder_thrust', 'chain_lightning', 'static_field', 'tempest_rage'],
      );
      expect(kit.abilitiesUnlockedAt(1).length, 1);
      expect(kit.abilitiesUnlockedAt(10).length, 2);
      expect(kit.abilitiesUnlockedAt(20).length, 3);
      expect(kit.abilitiesUnlockedAt(30).length, 4);
    });

    test('keeps the lightning-spear identity: longest reach, narrow arc', () {
      expect(kit.attackStyle, AttackStyle.melee);
      expect(kit.weaponAr, contains('رمح'));
      expect(kit.accentColor, 0xFFFFD54A);
      expect(kit.meleeRange, greaterThan(flameKit.meleeRange));
      expect(kit.meleeArcRadians, lessThan(flameKit.meleeArcRadians));
      expect(kit.abilityById('thunder_thrust')!.usesAttackClip, isTrue);
    });

    test('stat buff values are declared for the rage ability', () {
      expect(kit.buffDamageMult, 1.2);
      expect(kit.buffRateMult, 1.3);
      expect(kit.buffMoveMult, 1.0);
    });

    test('the asset gap is real, not a code bug', () async {
      // If this ever fails, storm renders landed and the kit can flip to
      // playable — re-check the pipeline doc first.
      final exists = await File('assets/heroes/storm/renders').exists();
      expect(exists, isFalse,
          reason: 'flip stormKit.playable once renders exist');
    });
  });
}
