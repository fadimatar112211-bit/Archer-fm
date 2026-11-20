import 'dart:io';

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const heroIds = ['ranger_new', 'flame', 'shadow', 'storm'];

  group('hero balance rules', () {
    test('all heroes share base HP, energy and regen; speeds differ', () {
      final kits = heroIds.map(kitForHero).toList();
      for (final kit in kits) {
        expect(kit.baseMaxHp, kits.first.baseMaxHp);
        expect(kit.baseMaxEnergy, kits.first.baseMaxEnergy);
        expect(kit.energyRegenPerSec, kits.first.energyRegenPerSec);
      }
      expect(kits.map((k) => k.moveSpeed).toSet().length, kits.length);
    });

    for (final id in heroIds) {
      test('$id has 5 combo hits and 4 abilities unlocking at 1/10/20/30', () {
        final kit = kitForHero(id);
        expect(kit.comboHits.map((h) => h.multiplier),
            [1.00, 1.10, 1.20, 1.35, 1.55]);
        expect(kit.comboWindowMs, 1800);
        expect(kit.abilities.map((a) => a.unlockLevel), [1, 10, 20, 30]);
        expect(kit.abilities.map((a) => a.id).toSet().length, 4);
      });
    }
  });

  group('ability names match docs/game/special_abilities.md', () {
    final doc = File('docs/game/special_abilities.md').readAsStringSync();
    for (final id in heroIds) {
      final kit = kitForHero(id);
      for (final ability in kit.abilities) {
        test('${kit.heroId}/${ability.id} uses the same Arabic name', () {
          expect(
            doc.contains('${ability.nameAr} `${ability.id}`'),
            isTrue,
            reason: 'docs must list "${ability.nameAr} `${ability.id}`"',
          );
        });
      }
    }
  });
}
