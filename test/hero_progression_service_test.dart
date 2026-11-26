import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/progression/hero_progress.dart';
import 'package:archer_fm/game/progression/hero_progression_service.dart';

class _TestEconomy implements HeroProgressionEconomy {
  const _TestEconomy();

  @override
  int? unlockCost(String weaponId) => weaponId.endsWith('_longbow') ? 200 : null;

  @override
  int? upgradeCost(String weaponId, int nextLevel) =>
      weaponId.endsWith('_longbow') ? nextLevel * 50 : null;

  @override
  int maxUpgradeLevel(String weaponId) => 3;
}

void main() {
  late HeroProgressionService service;
  late HeroProgress progress;
  late String longbowId;

  setUp(() {
    service = const HeroProgressionService(_TestEconomy());
    progress = HeroProgress(permanentCurrency: 500);
    longbowId = heroCombatById(HeroId.ranger).weapons[1].id;
  });

  test('unlock transaction uses authoritative economy and deducts once', () {
    final result = service.unlock(progress, longbowId);
    expect(result.accepted, isTrue);
    expect(result.currencyBalance, 300);
    expect(result.weaponLevel, 0);
    expect(service.unlock(progress, longbowId).result,
        ProgressionResult.alreadyOwned);
    expect(progress.permanentCurrency, 300);
  });

  test('upgrade transaction uses next-level cost and configured cap', () {
    service.unlock(progress, longbowId);
    final first = service.upgrade(progress, longbowId);
    expect(first.accepted, isTrue);
    expect(first.currencyBalance, 250);
    expect(first.weaponLevel, 1);

    final second = service.upgrade(progress, longbowId);
    expect(second.accepted, isTrue);
    expect(second.currencyBalance, 150);
    expect(second.weaponLevel, 2);
  });

  test('unknown items and insufficient funds do not mutate progress', () {
    final before = progress.permanentCurrency;
    final unknown = service.unlock(progress, 'not_a_weapon');
    expect(unknown.result, ProgressionResult.unknownWeapon);
    expect(progress.permanentCurrency, before);

    progress.permanentCurrency = 100;
    final insufficient = service.unlock(progress, longbowId);
    expect(insufficient.result, ProgressionResult.insufficientCurrency);
    expect(progress.permanentCurrency, 100);
  });
}
