import '../heroes/hero_roster.dart';

enum ProgressionResult {
  ok,
  unknownWeapon,
  alreadyOwned,
  weaponLocked,
  insufficientCurrency,
  maxLevel,
  invalidCost,
  invalidAmount,
}

/// Permanent player progression data.
///
/// Costs are supplied by the authoritative economy configuration. No prices
/// from the multiplayer sample ZIP are embedded here because that file marks
/// its balance numbers as temporary and the product balance is not approved.
class HeroProgress {
  HeroProgress({
    int permanentCurrency = 0,
    Set<String>? unlockedWeaponIds,
    Map<String, int>? weaponUpgradeLevels,
  })  : permanentCurrency = permanentCurrency,
        unlockedWeaponIds = unlockedWeaponIds ?? _initialWeaponIds(),
        weaponUpgradeLevels = weaponUpgradeLevels ?? {} {
    _validate();
  }

  factory HeroProgress.fresh() => HeroProgress();

  factory HeroProgress.fromJson(Map<String, dynamic> json) {
    final currency = json['permanentCurrency'];
    final unlocked = json['unlockedWeaponIds'];
    final levels = json['weaponUpgradeLevels'];
    if (currency is! int || unlocked is! List || levels is! Map) {
      throw const FormatException('Invalid hero progression document.');
    }
    return HeroProgress(
      permanentCurrency: currency,
      unlockedWeaponIds: unlocked.cast<String>().toSet(),
      weaponUpgradeLevels: Map<String, int>.from(levels),
    );
  }

  int permanentCurrency;
  final Set<String> unlockedWeaponIds;
  final Map<String, int> weaponUpgradeLevels;

  static Set<String> _initialWeaponIds() => {
        for (final hero in archerFmHeroes) hero.weapons.first.id,
      };

  static final Set<String> _allWeaponIds = {
    for (final hero in archerFmHeroes)
      for (final weapon in hero.weapons) weapon.id,
  };

  static final Set<String> _initialIds = _initialWeaponIds();

  void _validate() {
    if (permanentCurrency < 0) {
      throw const FormatException('Permanent currency cannot be negative.');
    }
    if (!unlockedWeaponIds.every(_allWeaponIds.contains) ||
        !weaponUpgradeLevels.keys.every(_allWeaponIds.contains) ||
        weaponUpgradeLevels.values.any(
          (level) => level < 0 || level > heroLevelCap,
        )) {
      throw const FormatException('Unknown weapon or invalid upgrade level.');
    }
    if (!unlockedWeaponIds.containsAll(_initialIds)) {
      throw const FormatException('Every hero initial weapon must be unlocked.');
    }
    if (weaponUpgradeLevels.keys.any((id) => !unlockedWeaponIds.contains(id))) {
      throw const FormatException('A locked weapon cannot have upgrade levels.');
    }
  }

  bool ownsWeapon(String weaponId) => unlockedWeaponIds.contains(weaponId);
  int weaponLevel(String weaponId) => weaponUpgradeLevels[weaponId] ?? 0;

  ProgressionResult unlockWeapon(String weaponId, {required int cost}) {
    if (!_allWeaponIds.contains(weaponId)) return ProgressionResult.unknownWeapon;
    if (cost < 0) return ProgressionResult.invalidCost;
    if (ownsWeapon(weaponId)) return ProgressionResult.alreadyOwned;
    if (permanentCurrency < cost) return ProgressionResult.insufficientCurrency;
    permanentCurrency -= cost;
    unlockedWeaponIds.add(weaponId);
    weaponUpgradeLevels[weaponId] = 0;
    return ProgressionResult.ok;
  }

  ProgressionResult upgradeWeapon(
    String weaponId, {
    required int cost,
    required int maxLevel,
  }) {
    if (!_allWeaponIds.contains(weaponId)) return ProgressionResult.unknownWeapon;
    if (!ownsWeapon(weaponId)) return ProgressionResult.weaponLocked;
    if (cost < 0 || maxLevel < 0 || maxLevel > heroLevelCap) {
      return ProgressionResult.invalidCost;
    }
    final current = weaponLevel(weaponId);
    if (current >= maxLevel) return ProgressionResult.maxLevel;
    if (permanentCurrency < cost) return ProgressionResult.insufficientCurrency;
    permanentCurrency -= cost;
    weaponUpgradeLevels[weaponId] = current + 1;
    return ProgressionResult.ok;
  }

  ProgressionResult awardCurrency(int amount) {
    if (amount < 0) return ProgressionResult.invalidAmount;
    permanentCurrency += amount;
    return ProgressionResult.ok;
  }

  Map<String, Object> toJson() => {
        'schemaVersion': 1,
        'permanentCurrency': permanentCurrency,
        'unlockedWeaponIds': unlockedWeaponIds.toList()..sort(),
        'weaponUpgradeLevels': weaponUpgradeLevels,
      };
}
