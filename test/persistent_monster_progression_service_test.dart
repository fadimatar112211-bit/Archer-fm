import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/file_monster_progress_store.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_progression.dart';
import 'package:archer_fm/monsters/persistent_monster_progression_service.dart';

class _Economy implements MonsterProgressionEconomy {
  @override
  int? upgradeCost(MonsterType type, int nextLevel) => nextLevel * 10;
}

MonsterCatalog _catalog() => MonsterCatalog({
      for (final type in MonsterType.values)
        type: MonsterDefinition(
          type: type,
          baseStats: const MonsterStats(
            maxHealth: 100,
            damage: 10,
            moveSpeed: 10,
            attackRange: 20,
            attackCooldown: Duration(seconds: 1),
            purchaseCost: 10,
          ),
        ),
    });

Map<MonsterType, MonsterUpgradeGrowth> _growth() => {
      for (final type in MonsterType.values)
        type: const MonsterUpgradeGrowth(
          healthPerLevel: 0.1,
          damagePerLevel: 0.05,
          speedPerLevel: 0.02,
        ),
    };

MonsterProgression _progression(
  MonsterCatalog catalog, {
  required int runnerLevel,
}) =>
    MonsterProgression(
      catalog: catalog,
      growth: _growth(),
      costForLevel: (_, level) => level * 10,
      levels: {MonsterType.werewolf: runnerLevel},
    );

void main() {
  late Directory directory;
  late FileMonsterProgressStore store;
  late MonsterCatalog catalog;
  late PersistentMonsterProgressionService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('archer-monster-service-');
    store = FileMonsterProgressStore(directory);
    catalog = _catalog();
    service = PersistentMonsterProgressionService(
      store: store,
      catalog: catalog,
      growth: _growth(),
      economy: _Economy(),
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('debits and persists a successful upgrade before accepting it', () async {
    var currency = 100;
    final result = await service.upgrade(
      'account-one',
      type: MonsterType.werewolf,
      readCurrency: () => currency,
      tryDebit: (amount) {
        if (currency < amount) return false;
        currency -= amount;
        return true;
      },
      refund: (amount) => currency += amount,
    );

    expect(result.accepted, isTrue);
    expect(result.level, 2);
    expect(result.currencyBalance, 80);
    expect(currency, 80);
    expect((await service.load('account-one')).levelOf(MonsterType.werewolf), 2);
  });

  test('serializes concurrent upgrades against the live wallet balance', () async {
    var currency = 100;
    Future<PersistentMonsterUpgrade> upgrade() => service.upgrade(
          'account-one',
          type: MonsterType.werewolf,
          readCurrency: () => currency,
          tryDebit: (amount) {
            if (currency < amount) return false;
            currency -= amount;
            return true;
          },
          refund: (amount) => currency += amount,
        );

    final results = await Future.wait([upgrade(), upgrade()]);

    expect(results.every((result) => result.accepted), isTrue);
    expect(currency, 50);
    expect((await service.load('account-one')).levelOf(MonsterType.werewolf), 3);
    expect(results.map((result) => result.level).toSet(), {2, 3});
  });

  test('does not debit when currency is insufficient', () async {
    var currency = 10;
    final result = await service.upgrade(
      'account-one',
      type: MonsterType.werewolf,
      readCurrency: () => currency,
      tryDebit: (amount) {
        currency -= amount;
        return true;
      },
      refund: (amount) => currency += amount,
    );

    expect(result.result, MonsterUpgradeResult.insufficientCurrency);
    expect(currency, 10);
    expect((await service.load('account-one')).levelOf(MonsterType.werewolf), 1);
  });

  test('returns max-level result without asking for another cost', () async {
    await store.save('account-one', _progression(catalog, runnerLevel: 40));
    var currency = 100;
    final result = await service.upgrade(
      'account-one',
      type: MonsterType.werewolf,
      readCurrency: () => currency,
      tryDebit: (_) => fail('max-level upgrade must not debit'),
      refund: (_) => fail('max-level upgrade must not refund'),
    );

    expect(result.result, MonsterUpgradeResult.maxLevelReached);
    expect(result.level, 40);
    expect(currency, 100);
  });
}
