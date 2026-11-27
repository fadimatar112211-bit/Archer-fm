import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/match_combat_configuration.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';

Map<String, Object?> _validConfiguration() => {
  'projectileSpeed': 120,
  'weaponUpgradeDamagePerLevel': 0.04,
  'monsterKillScore': 5,
  'monsterKillResources': 3,
  'heroKillScore': 15,
  'heroKillResources': 10,
  'maxActiveProjectiles': 128,
  'maxUnitsPerArmy': 100,
  'worldUnitsPerSecond': 100,
  'comboResetWindowMs': 1200,
  'maxHeroEnergy': 100,
  'energyRegenerationPerSecond': 1,
  'ultimateEnergyCosts': {
    for (final hero in archerFmHeroes)
      for (final ultimate in hero.ultimates) ultimate.id: 20,
  },
  'monsterCatalog': {
    for (final type in MonsterType.values)
      type.name: {
        'maxHealth': 1000,
        'damage': 12,
        'moveSpeed': 20,
        'attackRange': 36,
        'attackCooldownMs': 700,
        'purchaseCost': 10,
      },
  },
};

void main() {
  test('committed development balance file decodes through the strict server schema', () {
    final json = jsonDecode(
      File('config/match-combat.example.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final config = decodeMatchCombatConfiguration(json);
    expect(config.monsterCatalog.all, hasLength(4));
    expect(config.ultimateEnergyCosts, hasLength(16));
    expect(config.weaponUpgradeDamagePerLevel, 0.04);
    expect(config.monsterKillScore, 5);
    expect(config.monsterKillResources, 3);
    expect(config.heroKillScore, 15);
    expect(config.heroKillResources, 10);
    expect(config.maxHeroEnergy, 100);
    expect(config.energyRegenerationPerSecond, 8);
    expect(config.weaponUpgradeDamagePerLevel, 0.04);
  });

  test('decodes all four explicit monster definitions and runtime limits', () {
    final config = decodeMatchCombatConfiguration(_validConfiguration());
    expect(config.monsterCatalog.all, hasLength(4));
    for (final type in MonsterType.values) {
      expect(config.monsterCatalog[type].baseStats.maxHealth, 1000);
      expect(config.monsterCatalog[type].baseStats.purchaseCost, 10);
    }
    expect(config.projectileSpeed, 120);
    expect(config.maxActiveProjectiles, 128);
    expect(config.maxUnitsPerArmy, 100);
    expect(config.worldUnitsPerSecond, 100);
    expect(config.comboResetWindowMs, 1200);
    expect(config.maxHeroEnergy, 100);
    expect(config.energyRegenerationPerSecond, 1);
    expect(config.ultimateEnergyCosts, hasLength(16));
  });

  Map<String, Object?> _monsterProgressionPolicy() => {
    'growth': {
      for (final type in MonsterType.values)
        type.name: {
          'healthPerLevel': 0.1,
          'damagePerLevel': 0.05,
          'speedPerLevel': 0.02,
        },
    },
    'upgradeCosts': {
      for (final type in MonsterType.values)
        type.name: {
          for (var level = 2; level <= 40; level++)
            level.toString(): level * 10,
        },
    },
  };

  test('loads cloud monster levels only when a complete approved policy is supplied', () {
    final withoutPolicy = decodeMatchCombatConfiguration(_validConfiguration());
    expect(withoutPolicy.monsterProgressionPolicy, isNull);

    final json = _validConfiguration()
      ..['monsterProgressionPolicy'] = _monsterProgressionPolicy();
    final config = decodeMatchCombatConfiguration(json);
    final progression = config.monsterProgressionPolicy!.restore(
      catalog: config.monsterCatalog,
      saveData: {
        'version': 1,
        'levels': {
          for (final type in MonsterType.values)
            type.name: type == MonsterType.werewolf ? 3 : 1,
        },
      },
    );
    expect(progression.statsFor(MonsterType.werewolf).maxHealth, 1200);
    expect(progression.statsFor(MonsterType.stoneGolem).maxHealth, 1000);
    expect(progression.costForNextLevel(MonsterType.werewolf), 40);
  });

  test('rejects incomplete monster growth and upgrade cost policies', () {
    final missingCost = _monsterProgressionPolicy();
    ((missingCost['upgradeCosts'] as Map)['werewolf'] as Map).remove('40');
    final json = _validConfiguration()
      ..['monsterProgressionPolicy'] = missingCost;
    expect(() => decodeMatchCombatConfiguration(json), throwsFormatException);

    final missingGrowth = _monsterProgressionPolicy();
    ((missingGrowth['growth'] as Map)['stoneGolem'] as Map).remove('damagePerLevel');
    final invalid = _validConfiguration()
      ..['monsterProgressionPolicy'] = missingGrowth;
    expect(() => decodeMatchCombatConfiguration(invalid), throwsFormatException);
  });

  test('rejects a missing monster type instead of silently using defaults', () {
    final json = _validConfiguration();
    (json['monsterCatalog'] as Map).remove('bogMonster');
    expect(() => decodeMatchCombatConfiguration(json), throwsFormatException);
  });

  test('rejects unknown monster types and unknown runtime fields', () {
    final json = _validConfiguration();
    (json['monsterCatalog'] as Map)['dragon'] =
        (json['monsterCatalog'] as Map)['werewolf'];
    expect(() => decodeMatchCombatConfiguration(json), throwsFormatException);
  });

  test('requires exact positive energy costs for all sixteen Ultimates', () {
    final missing = _validConfiguration();
    (missing['ultimateEnergyCosts'] as Map).remove('ranger_starfall');
    expect(() => decodeMatchCombatConfiguration(missing), throwsArgumentError);

    final extra = _validConfiguration();
    (extra['ultimateEnergyCosts'] as Map)['unknown_ultimate'] = 10;
    expect(() => decodeMatchCombatConfiguration(extra), throwsArgumentError);

    final tooExpensive = _validConfiguration();
    (tooExpensive['ultimateEnergyCosts'] as Map)['ranger_starfall'] = 101;
    expect(() => decodeMatchCombatConfiguration(tooExpensive), throwsArgumentError);
  });

  test('rejects invalid cooldowns, costs and runtime limits', () {
    final json = _validConfiguration();
    ((json['monsterCatalog'] as Map)['stoneGolem'] as Map)['attackCooldownMs'] = 0;
    expect(() => decodeMatchCombatConfiguration(json), throwsArgumentError);

    final invalidLimit = _validConfiguration();
    invalidLimit['maxUnitsPerArmy'] = 19;
    expect(() => decodeMatchCombatConfiguration(invalidLimit),
        throwsArgumentError);
  });

  test('rejects missing or non-finite runtime tuning values', () {
    final json = _validConfiguration()..remove('projectileSpeed');
    expect(() => decodeMatchCombatConfiguration(json), throwsFormatException);
    final missingUpgradeScaling =
        _validConfiguration()..remove('weaponUpgradeDamagePerLevel');
    expect(() => decodeMatchCombatConfiguration(missingUpgradeScaling),
        throwsFormatException);
    final nonFinite = _validConfiguration()..['projectileSpeed'] = double.infinity;
    expect(() => decodeMatchCombatConfiguration(nonFinite),
        throwsFormatException);
  });
}
