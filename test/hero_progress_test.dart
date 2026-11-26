import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/progression/hero_progress.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';

void main() {
  group('HeroProgress', () {
    test('fresh profile unlocks exactly one starting weapon per hero', () {
      final progress = HeroProgress.fresh();
      expect(progress.unlockedWeaponIds.length, 4);
      for (final hero in archerFmHeroes) {
        expect(progress.ownsWeapon(hero.weapons.first.id), isTrue);
        expect(progress.ownsWeapon(hero.weapons[1].id), isFalse);
        expect(progress.ownsWeapon(hero.weapons[2].id), isFalse);
      }
    });

    test('unlock uses server-supplied cost and persists ownership', () {
      final progress = HeroProgress(permanentCurrency: 500);
      final weaponId = heroCombatById(HeroId.ranger).weapons[1].id;
      expect(
        progress.unlockWeapon(weaponId, cost: 300),
        ProgressionResult.ok,
      );
      expect(progress.permanentCurrency, 200);
      expect(progress.ownsWeapon(weaponId), isTrue);
      expect(progress.weaponLevel(weaponId), 0);
    });

    test('rejects unknown, already-owned and unaffordable unlocks', () {
      final progress = HeroProgress(permanentCurrency: 100);
      expect(
        progress.unlockWeapon('missing_weapon', cost: 1),
        ProgressionResult.unknownWeapon,
      );
      expect(
        progress.unlockWeapon(
          heroCombatById(HeroId.ranger).weapons.first.id,
          cost: 1,
        ),
        ProgressionResult.alreadyOwned,
      );
      expect(
        progress.unlockWeapon(
          heroCombatById(HeroId.ranger).weapons[1].id,
          cost: 101,
        ),
        ProgressionResult.insufficientCurrency,
      );
    });

    test('upgrade requires ownership and respects configured cap', () {
      final progress = HeroProgress(permanentCurrency: 500);
      final weaponId = heroCombatById(HeroId.ranger).weapons[1].id;
      expect(
        progress.upgradeWeapon(weaponId, cost: 10, maxLevel: 5),
        ProgressionResult.weaponLocked,
      );
      progress.unlockWeapon(weaponId, cost: 100);
      expect(
        progress.upgradeWeapon(weaponId, cost: 50, maxLevel: 1),
        ProgressionResult.ok,
      );
      expect(progress.weaponLevel(weaponId), 1);
      expect(
        progress.upgradeWeapon(weaponId, cost: 50, maxLevel: 1),
        ProgressionResult.maxLevel,
      );
    });

    test('serializes and restores permanent progression', () {
      final progress = HeroProgress(permanentCurrency: 900);
      final weaponId = heroCombatById(HeroId.shadow).weapons[1].id;
      progress.unlockWeapon(weaponId, cost: 100);
      progress.upgradeWeapon(weaponId, cost: 50, maxLevel: 40);

      final restored = HeroProgress.fromJson(progress.toJson());
      expect(restored.permanentCurrency, 750);
      expect(restored.ownsWeapon(weaponId), isTrue);
      expect(restored.weaponLevel(weaponId), 1);
    });

    test('rejects corrupted progression documents', () {
      expect(
        () => HeroProgress.fromJson({
          'permanentCurrency': -1,
          'unlockedWeaponIds': <String>[],
          'weaponUpgradeLevels': <String, int>{},
        }),
        throwsFormatException,
      );
    });
  });
}
