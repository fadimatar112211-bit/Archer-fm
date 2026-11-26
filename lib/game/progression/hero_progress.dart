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
/// Costs and reward amounts are supplied by the authoritative economy
/// configuration. No unapproved balance values are embedded here.
class HeroProgress {
  HeroProgress({
    int permanentCurrency = 0,
    Set<String>? unlockedWeaponIds,
    Map<String, int>? weaponUpgradeLevels,
    Map<String, int>? heroLevels,
    Map<String, int>? heroExperience,
  })  : permanentCurrency = permanentCurrency,
        unlockedWeaponIds = unlockedWeaponIds ?? _initialWeaponIds(),
        weaponUpgradeLevels = weaponUpgradeLevels ?? {},
        heroLevels = heroLevels ?? _initialHeroLevels(),
        heroExperience = heroExperience ?? {} {
    _validate();
  }

  factory HeroProgress.fresh() => HeroProgress();

  factory HeroProgress.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != null && schemaVersion != 1) {
      throw const FormatException('Unsupported hero progression schema.');
    }
    final currency = json['permanentCurrency'];
    final unlocked = json['unlockedWeaponIds'];
    final levels = json['weaponUpgradeLevels'];
    final savedHeroLevels = json['heroLevels'];
    final savedHeroExperience = json['heroExperience'];
    if (currency is! int || unlocked is! List || levels is! Map ||
        (savedHeroLevels != null && savedHeroLevels is! Map) ||
        (savedHeroExperience != null && savedHeroExperience is! Map)) {
      throw const FormatException('Invalid hero progression document.');
    }
    return HeroProgress(
      permanentCurrency: currency,
      unlockedWeaponIds: unlocked.cast<String>().toSet(),
      weaponUpgradeLevels: Map<String, int>.from(levels),
      heroLevels: savedHeroLevels == null
          ? null
          : Map<String, int>.from(savedHeroLevels),
      heroExperience: savedHeroExperience == null
          ? null
          : Map<String, int>.from(savedHeroExperience),
    );
  }

  int permanentCurrency;
  final Set<String> unlockedWeaponIds;
  final Map<String, int> weaponUpgradeLevels;

  /// Permanent hero levels and unspent XP, keyed by canonical hero ID.
  /// Missing entries represent level 1 with zero XP for backward compatibility.
  final Map<String, int> heroLevels;
  final Map<String, int> heroExperience;

  static Set<String> _initialWeaponIds() => {
        for (final hero in archerFmHeroes) hero.weapons.first.id,
      };

  static Map<String, int> _initialHeroLevels() => {
        for (final hero in archerFmHeroes) hero.id.name: 1,
      };

  static final Set<String> _allHeroIds = {
    for (final hero in archerFmHeroes) hero.id.name,
  };

  static final Set<String> _allWeaponIds = {
    for (final hero in archerFmHeroes)
      for (final weapon in hero.weapons) weapon.id,
  };

  static int experienceRequiredForLevel(int level) =>
      level >= heroLevelCap ? 0 : 100 + level * 50;

  int heroLevel(String heroId) => heroLevels[heroId] ?? 1;
  int heroXp(String heroId) => heroExperience[heroId] ?? 0;

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
    if (!unlockedWeaponIds.containsAll(_initialWeaponIds())) {
      throw const FormatException('Every hero initial weapon must be unlocked.');
    }
    if (weaponUpgradeLevels.keys.any((id) => !unlockedWeaponIds.contains(id))) {
      throw const FormatException('A locked weapon cannot have upgrade levels.');
    }
    if (!heroLevels.keys.every(_allHeroIds.contains) ||
        heroLevels.values.any((level) => level < 1 || level > heroLevelCap) ||
        !heroExperience.keys.every(_allHeroIds.contains) ||
        heroExperience.values.any((xp) => xp < 0)) {
      throw const FormatException('Unknown hero or invalid hero progression.');
    }
    for (final heroId in _allHeroIds) {
      final level = heroLevel(heroId);
      final xp = heroXp(heroId);
      if (level == heroLevelCap && xp != 0 ||
          level < heroLevelCap && xp >= experienceRequiredForLevel(level)) {
        throw const FormatException('Hero XP is outside the current level range.');
      }
    }
  }

  /// Awards permanent XP after a server-validated match/reward transaction.
  /// The caller supplies the award amount; this method never invents rewards.
  int awardHeroExperience(String heroId, int amount) {
    if (!_allHeroIds.contains(heroId)) return -1;
    if (amount < 0) throw RangeError.value(amount, 'amount');
    var level = heroLevel(heroId);
    if (level >= heroLevelCap || amount == 0) return 0;

    var xp = heroXp(heroId) + amount;
    var gained = 0;
    while (level < heroLevelCap) {
      final required = experienceRequiredForLevel(level);
      if (xp < required) break;
      xp -= required;
      level++;
      gained++;
    }
    if (level == heroLevelCap) xp = 0;
    heroLevels[heroId] = level;
    heroExperience[heroId] = xp;
    return gained;
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
        'heroLevels': heroLevels,
        'heroExperience': heroExperience,
      };
}
