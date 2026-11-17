import 'dart:io';

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Storm is playable: the original uploaded storm.glb mesh + textures ride
/// the rigged house skeleton, and the kit's four lightning abilities are
/// wired into GameWorld. These tests lock that contract.
void main() {
  group('Storm combat kit (playable, original GLB in-game)', () {
    final kit = stormKit;

    test('is playable with the original model pipeline landed', () {
      expect(kit.heroId, 'storm');
      expect(kit.playable, isTrue,
          reason: 'the rigged original model + manifest exist');
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

    test('the playable asset pipeline is on disk', () async {
      final glb = File('assets/heroes/storm/model/storm_animated.glb');
      final manifest = File('assets/heroes/storm/renders/storm_manifest.json');
      expect(glb.existsSync(), isTrue,
          reason: 'the rigged original model must exist');
      expect(manifest.existsSync(), isTrue,
          reason: 'the manifest must exist for the 3D load path');
    });
  });
}
