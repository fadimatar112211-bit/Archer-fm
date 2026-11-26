import 'monster_models.dart';

typedef MonsterUpgradeCostForLevel = int Function(
  MonsterType type,
  int targetLevel,
);

enum MonsterUpgradeResult {
  upgraded,
  maxLevelReached,
  insufficientCurrency,
  debitRejected,
}

/// Percentage growth applied per permanent level above level 1.
/// Values are supplied by game-balance configuration; no prices or growth
/// values are silently invented by the progression system.
class MonsterUpgradeGrowth {
  const MonsterUpgradeGrowth({
    required this.healthPerLevel,
    required this.damagePerLevel,
    required this.speedPerLevel,
  });

  final double healthPerLevel;
  final double damagePerLevel;
  final double speedPerLevel;

  void validate() {
    for (final value in [healthPerLevel, damagePerLevel, speedPerLevel]) {
      if (!value.isFinite || value < 0) {
        throw ArgumentError(
          'Monster upgrade growth must be finite and non-negative.',
        );
      }
    }
  }
}

/// Permanent, independently persisted levels for the four launch monster types.
///
/// The host saves [toJson] outside matches and restores it with [fromJson].
/// Match armies receive upgraded stats through [statsFor], while existing
/// in-match units remain unchanged.
class MonsterProgression {
  MonsterProgression({
    required this.catalog,
    required Map<MonsterType, MonsterUpgradeGrowth> growth,
    required this.costForLevel,
    Map<MonsterType, int>? levels,
  })  : growth = Map.unmodifiable(growth),
        _levels = _normalizeLevels(levels) {
    if (this.growth.length != MonsterType.values.length ||
        MonsterType.values.any((type) => !this.growth.containsKey(type))) {
      throw ArgumentError(
        'Upgrade growth must be configured for all four monster types.',
      );
    }
    for (final type in MonsterType.values) {
      this.growth[type]!.validate();
    }
  }

  factory MonsterProgression.fromJson({
    required MonsterCatalog catalog,
    required Map<MonsterType, MonsterUpgradeGrowth> growth,
    required MonsterUpgradeCostForLevel costForLevel,
    required Map<String, Object?> json,
  }) {
    final levels = <MonsterType, int>{};
    for (final type in MonsterType.values) {
      final value = json[type.name];
      if (value is! int || value < 1 || value > maxLevel) {
        throw FormatException(
          'Invalid saved level for ' + type.name + ': ' + value.toString(),
        );
      }
      levels[type] = value;
    }
    if (json.keys.any(
      (key) => !MonsterType.values.any((type) => type.name == key),
    )) {
      throw const FormatException('Saved monster progression has unknown types.');
    }
    return MonsterProgression(
      catalog: catalog,
      growth: growth,
      costForLevel: costForLevel,
      levels: levels,
    );
  }

  static const int maxLevel = 40;
  static const int saveSchemaVersion = 1;

  /// Restores the versioned progression envelope stored in a player profile.
  factory MonsterProgression.fromSaveData({
    required MonsterCatalog catalog,
    required Map<MonsterType, MonsterUpgradeGrowth> growth,
    required MonsterUpgradeCostForLevel costForLevel,
    required Map<String, Object?> data,
  }) {
    if (data['version'] != saveSchemaVersion) {
      throw FormatException(
        'Unsupported monster progression save version: ${data['version']}.',
      );
    }
    final rawLevels = data['levels'];
    if (rawLevels is! Map) {
      throw const FormatException('Monster progression save has no levels map.');
    }
    final levels = <String, Object?>{};
    for (final entry in rawLevels.entries) {
      if (entry.key is! String) {
        throw const FormatException('Monster progression level keys must be strings.');
      }
      levels[entry.key as String] = entry.value;
    }
    return MonsterProgression.fromJson(
      catalog: catalog,
      growth: growth,
      costForLevel: costForLevel,
      json: levels,
    );
  }

  final MonsterCatalog catalog;
  final Map<MonsterType, MonsterUpgradeGrowth> growth;
  final MonsterUpgradeCostForLevel costForLevel;
  final Map<MonsterType, int> _levels;

  static Map<MonsterType, int> _normalizeLevels(
    Map<MonsterType, int>? levels,
  ) {
    if (levels != null &&
        levels.keys.any((type) => !MonsterType.values.contains(type))) {
      throw ArgumentError('Progression contains an unknown monster type.');
    }
    final normalized = <MonsterType, int>{
      for (final type in MonsterType.values) type: levels?[type] ?? 1,
    };
    for (final entry in normalized.entries) {
      if (entry.value < 1 || entry.value > maxLevel) {
        throw RangeError.range(
          entry.value,
          1,
          maxLevel,
          entry.key.name + ' level',
        );
      }
    }
    return normalized;
  }

  Map<MonsterType, int> get levels => Map.unmodifiable(_levels);

  int levelOf(MonsterType type) => _levels[type]!;

  MonsterStats statsFor(MonsterType type) {
    final configuredGrowth = growth[type]!;
    return catalog[type].baseStats.scaledForLevel(
      levelOf(type),
      healthPerLevel: configuredGrowth.healthPerLevel,
      damagePerLevel: configuredGrowth.damagePerLevel,
      speedPerLevel: configuredGrowth.speedPerLevel,
    );
  }

  int costForNextLevel(MonsterType type) {
    final current = levelOf(type);
    if (current >= maxLevel) {
      throw StateError(type.name + ' is already at level ' + maxLevel.toString());
    }
    final cost = costForLevel(type, current + 1);
    if (cost < 0) {
      throw ArgumentError.value(cost, 'cost', 'Upgrade cost cannot be negative.');
    }
    return cost;
  }

  MonsterUpgradeResult upgrade({
    required MonsterType type,
    required int currentCurrency,
    required bool Function(int amount) tryDebit,
    required void Function(int amount) refund,
  }) {
    if (currentCurrency < 0) {
      throw ArgumentError.value(currentCurrency, 'currentCurrency');
    }
    final current = levelOf(type);
    if (current >= maxLevel) return MonsterUpgradeResult.maxLevelReached;

    final cost = costForNextLevel(type);
    if (currentCurrency < cost) {
      return MonsterUpgradeResult.insufficientCurrency;
    }
    if (!tryDebit(cost)) return MonsterUpgradeResult.debitRejected;

    try {
      _levels[type] = current + 1;
      return MonsterUpgradeResult.upgraded;
    } catch (_) {
      refund(cost);
      rethrow;
    }
  }

  /// JSON-safe map with all four type names and their permanent levels.
  Map<String, int> toJson() => {
        for (final type in MonsterType.values) type.name: levelOf(type),
      };

  /// Versioned envelope suitable for storage inside a permanent player profile.
  Map<String, Object?> toSaveData() => {
        'version': saveSchemaVersion,
        'levels': toJson(),
      };
}
