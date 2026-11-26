import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/match_combat_configuration.dart';
import 'package:archer_fm/monsters/monster_models.dart';

Map<String, Object?> _validConfiguration() => {
  'projectileSpeed': 120,
  'maxActiveProjectiles': 128,
  'maxUnitsPerArmy': 100,
  'worldUnitsPerSecond': 100,
  'comboResetWindowMs': 1200,
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
  });

  test('rejects a missing monster type instead of silently using defaults', () {
    final json = _validConfiguration();
    (json['monsterCatalog'] as Map).remove('ranged');
    expect(() => decodeMatchCombatConfiguration(json), throwsFormatException);
  });

  test('rejects unknown monster types and unknown runtime fields', () {
    final json = _validConfiguration();
    (json['monsterCatalog'] as Map)['dragon'] =
        (json['monsterCatalog'] as Map)['runner'];
    expect(() => decodeMatchCombatConfiguration(json), throwsFormatException);
  });

  test('rejects invalid cooldowns, costs and runtime limits', () {
    final json = _validConfiguration();
    ((json['monsterCatalog'] as Map)['tank'] as Map)['attackCooldownMs'] = 0;
    expect(() => decodeMatchCombatConfiguration(json), throwsArgumentError);

    final invalidLimit = _validConfiguration();
    invalidLimit['maxUnitsPerArmy'] = 19;
    expect(() => decodeMatchCombatConfiguration(invalidLimit),
        throwsArgumentError);
  });

  test('rejects missing or non-finite runtime tuning values', () {
    final json = _validConfiguration()..remove('projectileSpeed');
    expect(() => decodeMatchCombatConfiguration(json), throwsFormatException);
    final nonFinite = _validConfiguration()..['projectileSpeed'] = double.infinity;
    expect(() => decodeMatchCombatConfiguration(nonFinite),
        throwsFormatException);
  });
}
