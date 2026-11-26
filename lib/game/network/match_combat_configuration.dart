import '../../monsters/monster_models.dart';
import 'match_combat_authority.dart';

/// Strict decoder for a development/server-supplied match combat configuration.
///
/// No balance defaults are supplied here. Every gameplay/economy value must
/// come from an explicitly reviewed configuration file.
MatchCombatConfiguration decodeMatchCombatConfiguration(
  Map<String, dynamic> json,
) {
  final rawCatalog = json['monsterCatalog'];
  if (rawCatalog is! Map) {
    throw const FormatException('monsterCatalog must define all four monster types.');
  }

  final definitions = <MonsterType, MonsterDefinition>{};
  for (final type in MonsterType.values) {
    final raw = rawCatalog[type.name];
    if (raw is! Map) {
      throw FormatException('Missing monsterCatalog.${type.name}.');
    }
    final maxHealth = _number(raw, 'maxHealth', type);
    final damage = _number(raw, 'damage', type);
    final moveSpeed = _number(raw, 'moveSpeed', type);
    final attackRange = _number(raw, 'attackRange', type);
    final attackCooldownMs = _integer(raw, 'attackCooldownMs', type);
    final purchaseCost = _integer(raw, 'purchaseCost', type);
    final stats = MonsterStats(
      maxHealth: maxHealth,
      damage: damage,
      moveSpeed: moveSpeed,
      attackRange: attackRange,
      attackCooldown: Duration(milliseconds: attackCooldownMs),
      purchaseCost: purchaseCost,
    );
    stats.validate();
    definitions[type] = MonsterDefinition(type: type, baseStats: stats);
  }
  if (rawCatalog.keys.any(
    (key) => key is! String || !MonsterType.values.any((type) => type.name == key),
  )) {
    throw const FormatException('monsterCatalog contains an unknown monster type.');
  }

  final projectileSpeed = _number(json, 'projectileSpeed');
  final maxActiveProjectiles = _integer(json, 'maxActiveProjectiles');
  final maxUnitsPerArmy = _integer(json, 'maxUnitsPerArmy');
  final worldUnitsPerSecond = _number(json, 'worldUnitsPerSecond');

  return MatchCombatConfiguration(
    monsterCatalog: MonsterCatalog(definitions),
    projectileSpeed: projectileSpeed,
    maxActiveProjectiles: maxActiveProjectiles,
    maxUnitsPerArmy: maxUnitsPerArmy,
    worldUnitsPerSecond: worldUnitsPerSecond,
  );
}

double _number(Map<dynamic, dynamic> map, String key, [MonsterType? type]) {
  final value = map[key];
  if (value is! num || !value.toDouble().isFinite) {
    final prefix = type == null ? '' : 'monsterCatalog.${type.name}.';
    throw FormatException('${prefix}$key must be a finite number.');
  }
  return value.toDouble();
}

int _integer(Map<dynamic, dynamic> map, String key, [MonsterType? type]) {
  final value = map[key];
  if (value is! int) {
    final prefix = type == null ? '' : 'monsterCatalog.${type.name}.';
    throw FormatException('${prefix}$key must be an integer.');
  }
  return value;
}
