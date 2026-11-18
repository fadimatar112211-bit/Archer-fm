import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedUnlocks = [1, 10, 20, 30];
  final kits = <HeroKit>[
    rangerNewKit,
    flameKit,
    shadowKit,
    stormKit,
  ];

  group('four-hero Ultimate contract', () {
    for (final kit in kits) {
      test('${kit.heroId} has four separate Ultimates at 1/10/20/30', () {
        expect(kit.abilities, hasLength(4));
        expect(
          kit.abilities.map((ability) => ability.unlockLevel).toList(),
          expectedUnlocks,
        );
        expect(kit.abilities.map((ability) => ability.id).toSet(), hasLength(4));
        expect(kit.abilities.every((ability) => ability.id.isNotEmpty), isTrue);
        expect(kit.abilities.every((ability) => ability.nameAr.isNotEmpty), isTrue);
        expect(kit.abilities.every((ability) => ability.descAr.isNotEmpty), isTrue);

        expect(kit.abilitiesUnlockedAt(1), hasLength(1));
        expect(kit.abilitiesUnlockedAt(9), hasLength(1));
        expect(kit.abilitiesUnlockedAt(10), hasLength(2));
        expect(kit.abilitiesUnlockedAt(19), hasLength(2));
        expect(kit.abilitiesUnlockedAt(20), hasLength(3));
        expect(kit.abilitiesUnlockedAt(29), hasLength(3));
        expect(kit.abilitiesUnlockedAt(30), hasLength(4));
        expect(kit.abilitiesUnlockedAt(40), hasLength(4));
      });

      test('${kit.heroId} keeps its five-hit combo independent', () {
        expect(
          kit.comboHits.map((hit) => hit.multiplier).toList(),
          [1.00, 1.10, 1.20, 1.35, 1.55],
        );
        expect(kit.comboHits, hasLength(5));
      });
    }
  });
}
