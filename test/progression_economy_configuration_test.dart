import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/progression/progression_economy_configuration.dart';
import 'package:archer_fm/monsters/monster_models.dart';

Map<String, dynamic> _validConfig() => {
  'version': 1,
  'weapons': {
    for (final hero in archerFmHeroes)
      for (final weapon in hero.weapons)
        weapon.id: {
          'unlockCost': 100,
          'upgradeCosts': {
            for (var level = 1; level <= 40; level++) '$level': level * 10,
          },
        },
  },
  'monsters': {
    for (final type in MonsterType.values)
      type.name: {
        'upgradeCosts': {
          for (var level = 2; level <= 40; level++) '$level': level * 20,
        },
      },
  },
};

void main() {
  test('loads all canonical weapon and monster prices without defaults', () {
    final config = ProgressionEconomyConfiguration.fromJson(_validConfig());
    expect(config.unlockCost('ranger_longbow'), 100);
    expect(config.weaponUpgradeCost('ranger_longbow', 3), 30);
    expect(config.monsterUpgradeCost('runner', 4), 80);
    expect(config.weaponUpgradeCost('ranger_longbow', 41), isNull);
  });

  test('rejects a missing weapon from the server price catalog', () {
    final json = _validConfig();
    (json['weapons'] as Map).remove('storm_lance');
    expect(
      () => ProgressionEconomyConfiguration.fromJson(json),
      throwsFormatException,
    );
  });

  test('rejects missing levels and non-positive prices', () {
    final missingLevel = _validConfig();
    ((missingLevel['weapons'] as Map)['ranger_longbow'] as Map)
        ['upgradeCosts'] = {'1': 0};
    expect(
      () => ProgressionEconomyConfiguration.fromJson(missingLevel),
      throwsFormatException,
    );
    final invalidPrice = _validConfig();
    ((invalidPrice['monsters'] as Map)['runner'] as Map)
        ['upgradeCosts'] = {
      for (var level = 2; level <= 40; level++) '$level': level == 3 ? 0 : 20,
    };
    expect(
      () => ProgressionEconomyConfiguration.fromJson(invalidPrice),
      throwsFormatException,
    );
  });

  test('rejects monster prices that differ from live combat progression costs', () {
    final config = ProgressionEconomyConfiguration.fromJson(_validConfig());
    final matching = {
      for (final type in MonsterType.values)
        type.name: {
          for (var level = 2; level <= 40; level++) level: level * 20,
        },
    };
    expect(() => config.validateMonsterUpgradeCosts(matching), returnsNormally);

    final changedPrice = {
      for (final type in MonsterType.values)
        type.name: {
          for (var level = 2; level <= 40; level++)
            level: type == MonsterType.runner && level == 3
                ? level * 20 + 1
                : level * 20,
        },
    };
    expect(
      () => config.validateMonsterUpgradeCosts(changedPrice),
      throwsFormatException,
    );

    final missingMonster = Map<String, Map<int, int>>.from(matching)
      ..remove('ranged');
    expect(
      () => config.validateMonsterUpgradeCosts(missingMonster),
      throwsFormatException,
    );
  });

  test('rejects unsupported IDs and schema versions', () {
    final unknown = _validConfig();
    (unknown['weapons'] as Map)['unknown_weapon'] = {
      'unlockCost': 1,
      'upgradeCosts': {
        for (var level = 1; level <= 40; level++) '$level': 1,
      },
    };
    expect(
      () => ProgressionEconomyConfiguration.fromJson(unknown),
      throwsFormatException,
    );
    final version = _validConfig()..['version'] = 2;
    expect(
      () => ProgressionEconomyConfiguration.fromJson(version),
      throwsFormatException,
    );
  });
}
