import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/progression/hero_progress.dart';
import 'package:archer_fm/game/progression/hero_progression_service.dart';
import 'package:archer_fm/game/progression/file_hero_progress_store.dart';

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

  test('persistent service serializes concurrent unlocks and saves the balance', () async {
    final directory = await Directory.systemTemp.createTemp('archer_progress_');
    try {
      final persistent = PersistentHeroProgressionService(
        store: FileHeroProgressStore(directory),
        economy: const _TestEconomy(),
      );
      await persistent.store.save(
        'verified-account-1',
        HeroProgress(permanentCurrency: 500),
      );

      final results = await Future.wait([
        persistent.unlockWeapon('verified-account-1', longbowId),
        persistent.unlockWeapon('verified-account-1', longbowId),
      ]);
      expect(results.where((result) => result.accepted), hasLength(1));
      expect(
        results.where((result) => result.result == ProgressionResult.alreadyOwned),
        hasLength(1),
      );

      final reloaded = await persistent.load('verified-account-1');
      expect(reloaded.ownsWeapon(longbowId), isTrue);
      expect(reloaded.permanentCurrency, 300);
      expect(await persistent.ownsWeapon('verified-account-1', longbowId), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('persistent service serializes and saves post-match hero XP awards', () async {
    final directory = await Directory.systemTemp.createTemp('archer_hero_xp_');
    try {
      final persistent = PersistentHeroProgressionService(
        store: FileHeroProgressStore(directory),
        economy: const _TestEconomy(),
      );
      await persistent.store.save(
        'verified-account-xp',
        HeroProgress.fresh(),
      );

      final results = await Future.wait([
        persistent.awardHeroExperience(
          'verified-account-xp',
          'ranger',
          amount: 100,
        ),
        persistent.awardHeroExperience(
          'verified-account-xp',
          'ranger',
          amount: 100,
        ),
      ]);
      expect(results, [0, 1]);
      final reloaded = await persistent.load('verified-account-xp');
      expect(reloaded.heroLevel('ranger'), 2);
      expect(reloaded.heroXp('ranger'), 50);
      expect(reloaded.heroLevel('flame'), 1);
    } finally {
      await directory.delete(recursive: true);
    }
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
