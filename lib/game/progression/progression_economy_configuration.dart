import '../heroes/hero_roster.dart';
import '../../monsters/monster_models.dart';

/// Strict, operator-approved permanent progression prices.
/// No prices are embedded in code: the production server must load this
/// complete catalog from a protected configuration file.
class ProgressionEconomyConfiguration {
  ProgressionEconomyConfiguration._({
    required this.weaponUnlockCosts,
    required this.weaponUpgradeCosts,
    required this.monsterUpgradeCosts,
  });

  factory ProgressionEconomyConfiguration.fromJson(Map<String, dynamic> json) {
    final rawWeapons = json['weapons'];
    final rawMonsters = json['monsters'];
    if (json['version'] != 1 || rawWeapons is! Map || rawMonsters is! Map) {
      throw const FormatException('Progression economy config needs version 1, weapons and monsters.');
    }
    final weaponIds = {
      for (final hero in archerFmHeroes)
        for (final weapon in hero.weapons) weapon.id,
    };
    final monsterIds = {for (final type in MonsterType.values) type.name};
    if (rawWeapons.keys.any((key) => key is! String || !weaponIds.contains(key)) ||
        rawMonsters.keys.any((key) => key is! String || !monsterIds.contains(key)) ||
        rawWeapons.length != weaponIds.length || rawMonsters.length != monsterIds.length) {
      throw const FormatException('Progression economy must define exactly the 12 launch weapons and four monsters.');
    }
    final starterWeaponIds = {
      for (final hero in archerFmHeroes) hero.weapons.first.id,
    };
    final unlockCosts = <String, int>{};
    final weaponCosts = <String, Map<int, int>>{};
    for (final id in weaponIds) {
      final raw = rawWeapons[id];
      final unlockCost = raw is Map ? raw['unlockCost'] : null;
      if (unlockCost is! int ||
          unlockCost < 0 ||
          (starterWeaponIds.contains(id) && unlockCost != 0) ||
          (!starterWeaponIds.contains(id) && unlockCost <= 0)) {
        throw FormatException(
          'weapons.$id.unlockCost must be zero only for the four free starter weapons and positive for other weapons.',
        );
      }
      unlockCosts[id] = unlockCost;
      weaponCosts[id] = _levelCosts(raw['upgradeCosts'], '$id upgradeCosts', 1);
    }
    final monsterCosts = <String, Map<int, int>>{};
    for (final id in monsterIds) {
      final raw = rawMonsters[id];
      if (raw is! Map) throw FormatException('Missing monsters.$id.');
      monsterCosts[id] = _levelCosts(raw['upgradeCosts'], '$id upgradeCosts', 2);
    }
    return ProgressionEconomyConfiguration._(
      weaponUnlockCosts: Map.unmodifiable(unlockCosts),
      weaponUpgradeCosts: Map.unmodifiable({
        for (final entry in weaponCosts.entries)
          entry.key: Map<int, int>.unmodifiable(entry.value),
      }),
      monsterUpgradeCosts: Map.unmodifiable({
        for (final entry in monsterCosts.entries)
          entry.key: Map<int, int>.unmodifiable(entry.value),
      }),
    );
  }

  final Map<String, int> weaponUnlockCosts;
  final Map<String, Map<int, int>> weaponUpgradeCosts;
  final Map<String, Map<int, int>> monsterUpgradeCosts;

  int? unlockCost(String weaponId) => weaponUnlockCosts[weaponId];
  int? weaponUpgradeCost(String weaponId, int nextLevel) =>
      weaponUpgradeCosts[weaponId]?[nextLevel];
  int? monsterUpgradeCost(String monsterId, int nextLevel) =>
      monsterUpgradeCosts[monsterId]?[nextLevel];

  /// Prevents the purchase catalog from charging for a progression level
  /// whose stat growth is absent or priced differently in match combat.
  void validateMonsterUpgradeCosts(
    Map<String, Map<int, int>> combatUpgradeCosts,
  ) {
    if (combatUpgradeCosts.length != monsterUpgradeCosts.length ||
        combatUpgradeCosts.keys.toSet().difference(monsterUpgradeCosts.keys.toSet()).isNotEmpty ||
        monsterUpgradeCosts.keys.toSet().difference(combatUpgradeCosts.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Combat and purchase catalogs must define the same four monster types.',
      );
    }
    for (final entry in monsterUpgradeCosts.entries) {
      final combatCosts = combatUpgradeCosts[entry.key];
      if (combatCosts == null || combatCosts.length != entry.value.length) {
        throw FormatException(
          'Combat and purchase costs differ for monster ${entry.key}.',
        );
      }
      for (final levelEntry in entry.value.entries) {
        if (combatCosts[levelEntry.key] != levelEntry.value) {
          throw FormatException(
            'Combat and purchase costs differ for ${entry.key} level ${levelEntry.key}.',
          );
        }
      }
    }
  }

  static Map<int, int> _levelCosts(Object? raw, String label, int firstLevel) {
    if (raw is! Map || raw.length != 40 - firstLevel + 1) {
      throw FormatException('$label must define every target level from $firstLevel through 40.');
    }
    final result = <int, int>{};
    for (var level = firstLevel; level <= 40; level++) {
      final value = raw['$level'];
      if (value is! int || value <= 0) {
        throw FormatException('$label.$level must be a positive integer.');
      }
      result[level] = value;
    }
    if (raw.keys.any((key) => key is! String || int.tryParse(key) == null ||
        int.parse(key) < firstLevel || int.parse(key) > 40)) {
      throw FormatException('$label contains an unsupported level.');
    }
    return result;
  }
}
