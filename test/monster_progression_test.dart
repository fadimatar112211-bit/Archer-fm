import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_army.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_progression.dart';

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

MonsterProgression _progression({
  Map<MonsterType, int>? levels,
  MonsterUpgradeCostForLevel? costForLevel,
}) =>
    MonsterProgression(
      catalog: _catalog(),
      growth: _growth(),
      costForLevel: costForLevel ?? (_, nextLevel) => nextLevel * 10,
      levels: levels,
    );

void main() {
  group('Monster permanent progression', () {
    test('upgrades each monster type independently', () {
      final progression = _progression();
      var currency = 100;

      final result = progression.upgrade(
        type: MonsterType.runner,
        currentCurrency: currency,
        tryDebit: (amount) {
          currency -= amount;
          return true;
        },
        refund: (amount) => currency += amount,
      );

      expect(result, MonsterUpgradeResult.upgraded);
      expect(currency, 80);
      expect(progression.levelOf(MonsterType.runner), 2);
      expect(progression.levelOf(MonsterType.tank), 1);
      expect(progression.statsFor(MonsterType.runner).maxHealth, closeTo(110, 1e-9));
      expect(progression.statsFor(MonsterType.runner).damage, closeTo(10.5, 1e-9));
      expect(progression.statsFor(MonsterType.runner).moveSpeed, closeTo(10.2, 1e-9));
      expect(progression.statsFor(MonsterType.runner).purchaseCost, 10);
      expect(progression.statsFor(MonsterType.tank).maxHealth, closeTo(100, 1e-9));
    });

    test('does not debit when currency is insufficient', () {
      final progression = _progression();
      var debitCalled = false;

      final result = progression.upgrade(
        type: MonsterType.tank,
        currentCurrency: 19,
        tryDebit: (_) {
          debitCalled = true;
          return true;
        },
        refund: (_) {},
      );

      expect(result, MonsterUpgradeResult.insufficientCurrency);
      expect(debitCalled, isFalse);
      expect(progression.levelOf(MonsterType.tank), 1);
    });

    test('respects an atomic debit rejection', () {
      final progression = _progression();
      final result = progression.upgrade(
        type: MonsterType.stalker,
        currentCurrency: 100,
        tryDebit: (_) => false,
        refund: (_) {},
      );

      expect(result, MonsterUpgradeResult.debitRejected);
      expect(progression.levelOf(MonsterType.stalker), 1);
    });

    test('level 40 is terminal and never requests another price', () {
      var costRequested = false;
      final progression = _progression(
        levels: {MonsterType.ranged: 40},
        costForLevel: (_, __) {
          costRequested = true;
          return 1;
        },
      );

      final result = progression.upgrade(
        type: MonsterType.ranged,
        currentCurrency: 1000,
        tryDebit: (_) => true,
        refund: (_) {},
      );

      expect(result, MonsterUpgradeResult.maxLevelReached);
      expect(costRequested, isFalse);
      expect(progression.levelOf(MonsterType.ranged), 40);
    });

    test('serializes and restores all independent levels', () {
      final original = _progression(
        levels: {
          MonsterType.runner: 8,
          MonsterType.tank: 3,
          MonsterType.stalker: 17,
          MonsterType.ranged: 40,
        },
      );
      final restored = MonsterProgression.fromJson(
        catalog: _catalog(),
        growth: _growth(),
        costForLevel: (_, nextLevel) => nextLevel * 10,
        json: original.toJson(),
      );

      expect(restored.levels, original.levels);
    });

    test('rejects malformed saved levels and incomplete growth config', () {
      expect(
        () => MonsterProgression.fromJson(
          catalog: _catalog(),
          growth: _growth(),
          costForLevel: (_, __) => 1,
          json: const {'runner': 0, 'tank': 1, 'stalker': 1, 'ranged': 1},
        ),
        throwsFormatException,
      );
      expect(
        () => MonsterProgression(
          catalog: _catalog(),
          growth: const {},
          costForLevel: (_, __) => 1,
        ),
        throwsArgumentError,
      );
    });

    test('new match armies spawn with permanent upgraded stats', () {
      final progression = _progression();
      progression.upgrade(
        type: MonsterType.tank,
        currentCurrency: 100,
        tryDebit: (_) => true,
        refund: (_) {},
      );
      final counts = {for (final type in MonsterType.values) type: 0};
      counts[MonsterType.tank] = 20;
      final army = MonsterArmy(
        ownerId: 'p1',
        catalog: _catalog(),
        selection: InitialArmySelection(counts),
        castleX: 0,
        castleY: 0,
        statsForType: progression.statsFor,
      );

      expect(army.units.first.stats.maxHealth, closeTo(110, 1e-9));
      final purchase = army.purchase(
        type: MonsterType.tank,
        currentResources: 100,
      );
      expect(purchase, isNotNull);
      expect(purchase!.cost, 10);
      expect(purchase.unit.stats.maxHealth, closeTo(110, 1e-9));
    });
  });
}
