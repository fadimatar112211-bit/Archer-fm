import '../../monsters/monster_models.dart';
import '../../monsters/monster_progression.dart';

/// Owner-approved permanent monster growth and purchase-cost policy.
///
/// This policy is optional in the combat config. When absent, cloud monster
/// levels remain visible in the account but are not applied to match stats.
/// No prices or stat multipliers are inferred by this class.
class MonsterProgressionPolicy {
  MonsterProgressionPolicy({
    required Map<MonsterType, MonsterUpgradeGrowth> growth,
    required Map<MonsterType, Map<int, int>> upgradeCosts,
  })  : growth = Map.unmodifiable(growth),
        upgradeCosts = Map.unmodifiable({
          for (final entry in upgradeCosts.entries)
            entry.key: Map<int, int>.unmodifiable(entry.value),
        }) {
    if (this.growth.length != MonsterType.values.length ||
        this.upgradeCosts.length != MonsterType.values.length ||
        MonsterType.values.any((type) =>
            !this.growth.containsKey(type) ||
            !this.upgradeCosts.containsKey(type))) {
      throw ArgumentError('Monster progression policy must define all four types.');
    }
    for (final type in MonsterType.values) {
      this.growth[type]!.validate();
      final costs = this.upgradeCosts[type]!;
      if (costs.length != MonsterProgression.maxLevel - 1 ||
          List<int>.generate(MonsterProgression.maxLevel - 1, (i) => i + 2)
              .any((level) => !costs.containsKey(level)) ||
          costs.values.any((cost) => cost <= 0)) {
        throw ArgumentError(
          'Monster upgrade costs for ${type.name} must define positive costs for levels 2–40.',
        );
      }
    }
  }

  final Map<MonsterType, MonsterUpgradeGrowth> growth;
  final Map<MonsterType, Map<int, int>> upgradeCosts;

  factory MonsterProgressionPolicy.fromJson(Map<dynamic, dynamic> json) {
    final rawGrowth = json['growth'];
    final rawCosts = json['upgradeCosts'];
    if (rawGrowth is! Map || rawCosts is! Map) {
      throw const FormatException(
        'monsterProgressionPolicy requires growth and upgradeCosts maps.',
      );
    }
    final parsedGrowth = <MonsterType, MonsterUpgradeGrowth>{};
    final parsedCosts = <MonsterType, Map<int, int>>{};
    for (final type in MonsterType.values) {
      final rawTypeGrowth = rawGrowth[type.name];
      final rawTypeCosts = rawCosts[type.name];
      if (rawTypeGrowth is! Map || rawTypeCosts is! Map) {
        throw FormatException(
          'monsterProgressionPolicy must define ${type.name} growth and costs.',
        );
      }
      double growthValue(String key) {
        final value = rawTypeGrowth[key];
        if (value is! num || !value.toDouble().isFinite || value < 0) {
          throw FormatException(
            'monsterProgressionPolicy.growth.${type.name}.$key must be finite and non-negative.',
          );
        }
        return value.toDouble();
      }

      final costs = <int, int>{};
      for (var level = 2; level <= MonsterProgression.maxLevel; level++) {
        final value = rawTypeCosts[level.toString()];
        if (value is! int || value <= 0) {
          throw FormatException(
            'monsterProgressionPolicy.upgradeCosts.${type.name}.$level must be a positive integer.',
          );
        }
        costs[level] = value;
      }
      if (rawTypeGrowth.keys.toSet().difference({
            'healthPerLevel',
            'damagePerLevel',
            'speedPerLevel',
          }).isNotEmpty ||
          rawTypeCosts.keys.any((key) =>
              key is! String ||
              int.tryParse(key) == null ||
              int.parse(key) < 2 ||
              int.parse(key) > MonsterProgression.maxLevel)) {
        throw FormatException(
          'monsterProgressionPolicy has unknown keys for ${type.name}.',
        );
      }
      parsedGrowth[type] = MonsterUpgradeGrowth(
        healthPerLevel: growthValue('healthPerLevel'),
        damagePerLevel: growthValue('damagePerLevel'),
        speedPerLevel: growthValue('speedPerLevel'),
      );
      parsedCosts[type] = costs;
    }
    if (rawGrowth.keys.any((key) =>
            key is! String || !MonsterType.values.any((type) => type.name == key)) ||
        rawCosts.keys.any((key) =>
            key is! String || !MonsterType.values.any((type) => type.name == key))) {
      throw const FormatException(
        'monsterProgressionPolicy contains an unknown monster type.',
      );
    }
    return MonsterProgressionPolicy(
      growth: parsedGrowth,
      upgradeCosts: parsedCosts,
    );
  }

  MonsterProgression restore({
    required MonsterCatalog catalog,
    required Map<String, Object?> saveData,
  }) =>
      MonsterProgression.fromSaveData(
        catalog: catalog,
        growth: growth,
        costForLevel: (type, level) => upgradeCosts[type]![level]!,
        data: saveData,
      );
}
