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
        type: MonsterType.werewolf,
        currentCurrency: currency,
        tryDebit: (amount) {
          currency -= amount;
          return true;
        },
        refund: (amount) => currency += amount,
      );

      expect(result, MonsterUpgradeResult.upgraded);
      expect(currency, 80);
      expect(progression.levelOf(MonsterType.werewolf), 2);
      expect(progression.levelOf(MonsterType.stoneGolem), 1);
      expect(progression.statsFor(MonsterType.werewolf).maxHealth, closeTo(110, 1e-9));
      expect(progression.statsFor(MonsterType.werewolf).damage, closeTo(10.5, 1e-9));
      expect(progression.statsFor(MonsterType.werewolf).moveSpeed, closeTo(10.2, 1e-9));
      expect(progression.statsFor(MonsterType.werewolf).purchaseCost, 10);
      expect(progression.statsFor(MonsterType.stoneGolem).maxHealth, closeTo(100, 1e-9));
    });

    test('does not debit when currency is insufficient', () {
      final progression = _progression();
      var debitCalled = false;

      final result = progression.upgrade(
        type: MonsterType.stoneGolem,
        currentCurrency: 19,
        tryDebit: (_) {
          debitCalled = true;
          return true;
        },
        refund: (_) {},
      );

      expect(result, MonsterUpgradeResult.insufficientCurrency);
      expect(debitCalled, isFalse);
      expect(progression.levelOf(MonsterType.stoneGolem), 1);
    });

    test('respects an atomic debit rejection', () {
      final progression = _progression();
      final result = progression.upgrade(
        type: MonsterType.blindStalker,
        currentCurrency: 100,
        tryDebit: (_) => false,
        refund: (_) {},
      );

      expect(result, MonsterUpgradeResult.debitRejected);
      expect(progression.levelOf(MonsterType.blindStalker), 1);
    });

    test('level 40 is terminal and never requests another price', () {
      var costRequested = false;
      final progression = _progression(
        levels: {MonsterType.bogMonster: 40},
        costForLevel: (_, __) {
          costRequested = true;
          return 1;
        },
      );

      final result = progression.upgrade(
        type: MonsterType.bogMonster,
        currentCurrency: 1000,
        tryDebit: (_) => true,
        refund: (_) {},
      );

      expect(result, MonsterUpgradeResult.maxLevelReached);
      expect(costRequested, isFalse);
      expect(progression.levelOf(MonsterType.bogMonster), 40);
    });

    test('serializes and restores all independent levels', () {
      final original = _progression(
        levels: {
          MonsterType.werewolf: 8,
          MonsterType.stoneGolem: 3,
          MonsterType.blindStalker: 17,
          MonsterType.bogMonster: 40,
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

    test('versioned player save envelope restores permanent levels', () {
      final original = _progression(
        levels: {
          MonsterType.werewolf: 4,
          MonsterType.stoneGolem: 9,
          MonsterType.blindStalker: 2,
          MonsterType.bogMonster: 40,
        },
      );
      final payload = original.toSaveData();
      final restored = MonsterProgression.fromSaveData(
        catalog: _catalog(),
        growth: _growth(),
        costForLevel: (_, nextLevel) => nextLevel * 10,
        data: payload,
      );

      expect(payload['version'], MonsterProgression.saveSchemaVersion);
      expect(restored.levels, original.levels);
      expect(
        () => MonsterProgression.fromSaveData(
          catalog: _catalog(),
          growth: _growth(),
          costForLevel: (_, __) => 1,
          data: {'version': 99, 'levels': original.toJson()},
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed saved levels and incomplete growth config', () {
      expect(
        () => MonsterProgression.fromJson(
          catalog: _catalog(),
          growth: _growth(),
          costForLevel: (_, __) => 1,
          json: const {'werewolf': 0, 'stoneGolem': 1, 'blindStalker': 1, 'bogMonster': 1},
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
        type: MonsterType.stoneGolem,
        currentCurrency: 100,
        tryDebit: (_) => true,
        refund: (_) {},
      );
      final counts = {for (final type in MonsterType.values) type: 0};
      counts[MonsterType.stoneGolem] = 20;
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
        type: MonsterType.stoneGolem,
        currentResources: 100,
      );
      expect(purchase, isNotNull);
      expect(purchase!.cost, 10);
      expect(purchase.unit.stats.maxHealth, closeTo(110, 1e-9));
    });
  });
}
