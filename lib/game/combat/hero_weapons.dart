/// Per-hero weapon choices.
///
/// Each of the four heroes has exactly three weapons: the starting one plus
/// two unlocked by hero level (10 and 20). One is chosen before the match in
/// the army-selection screen. The numbers are explicit balance placeholders —
/// the project text never supplied weapon stats, so the starting weapon keeps
/// the kit's original numbers (all multipliers 1.0) and only the unlockable
/// variants trade damage for rate or reach.
library;

/// One selectable weapon of a hero.
class HeroWeapon {
  const HeroWeapon({
    required this.id,
    required this.nameAr,
    required this.descAr,
    required this.unlockLevel,
    required this.damageMultiplier,
    required this.rateMultiplier,
    required this.rangeMultiplier,
  });

  final String id;
  final String nameAr;
  final String descAr;

  /// Hero level that unlocks this weapon (1 = available from the start).
  final int unlockLevel;

  final double damageMultiplier;
  final double rateMultiplier;
  final double rangeMultiplier;

  bool unlockedAt(int level) => level >= unlockLevel;
}

/// The three weapons of each playable hero, in unlock order.
const Map<String, List<HeroWeapon>> heroWeapons = {
  'ranger_new': [
    _WeaponDefaults.bow,
    _WeaponDefaults.swiftBow,
    _WeaponDefaults.heavyBow,
  ],
  'flame': [
    _WeaponDefaults.sword,
    _WeaponDefaults.swiftSword,
    _WeaponDefaults.heavySword,
  ],
  'shadow': [
    _WeaponDefaults.daggers,
    _WeaponDefaults.swiftDaggers,
    _WeaponDefaults.heavyDaggers,
  ],
  'storm': [
    _WeaponDefaults.spear,
    _WeaponDefaults.swiftSpear,
    _WeaponDefaults.heavySpear,
  ],
};

/// Shared numeric pattern: starting weapon 1/1/1, fast variant trades damage
/// for rate, heavy variant trades rate for damage and reach.
class _WeaponDefaults {
  const _WeaponDefaults._();

  static const bow = HeroWeapon(
    id: 'energy_bow',
    nameAr: 'قوس الطاقة الخضراء',
    descAr: 'السلاح الأساسي — الأرقام الأصلية للبطل',
    unlockLevel: 1,
    damageMultiplier: 1.0,
    rateMultiplier: 1.0,
    rangeMultiplier: 1.0,
  );
  static const swiftBow = HeroWeapon(
    id: 'swift_bow',
    nameAr: 'قوس خفيف',
    descAr: 'ضرر ×0.85 · وتيرة ×1.3 · مدى ×0.9',
    unlockLevel: 10,
    damageMultiplier: 0.85,
    rateMultiplier: 1.3,
    rangeMultiplier: 0.9,
  );
  static const heavyBow = HeroWeapon(
    id: 'heavy_bow',
    nameAr: 'قوس ثقيل',
    descAr: 'ضرر ×1.35 · وتيرة ×0.8 · مدى ×1.2',
    unlockLevel: 20,
    damageMultiplier: 1.35,
    rateMultiplier: 0.8,
    rangeMultiplier: 1.2,
  );

  static const sword = HeroWeapon(
    id: 'flame_sword',
    nameAr: 'سيف اللهب العظيم',
    descAr: 'السلاح الأساسي — الأرقام الأصلية للبطل',
    unlockLevel: 1,
    damageMultiplier: 1.0,
    rateMultiplier: 1.0,
    rangeMultiplier: 1.0,
  );
  static const swiftSword = HeroWeapon(
    id: 'swift_sword',
    nameAr: 'سيف خفيف',
    descAr: 'ضرر ×0.85 · وتيرة ×1.3 · مدى ×0.9',
    unlockLevel: 10,
    damageMultiplier: 0.85,
    rateMultiplier: 1.3,
    rangeMultiplier: 0.9,
  );
  static const heavySword = HeroWeapon(
    id: 'heavy_sword',
    nameAr: 'سيف ثقيل',
    descAr: 'ضرر ×1.35 · وتيرة ×0.8 · مدى ×1.2',
    unlockLevel: 20,
    damageMultiplier: 1.35,
    rateMultiplier: 0.8,
    rangeMultiplier: 1.2,
  );

  static const daggers = HeroWeapon(
    id: 'shadow_daggers',
    nameAr: 'خنجران توأمان',
    descAr: 'السلاح الأساسي — الأرقام الأصلية للبطل',
    unlockLevel: 1,
    damageMultiplier: 1.0,
    rateMultiplier: 1.0,
    rangeMultiplier: 1.0,
  );
  static const swiftDaggers = HeroWeapon(
    id: 'swift_daggers',
    nameAr: 'خنجر سريع',
    descAr: 'ضرر ×0.85 · وتيرة ×1.3 · مدى ×0.9',
    unlockLevel: 10,
    damageMultiplier: 0.85,
    rateMultiplier: 1.3,
    rangeMultiplier: 0.9,
  );
  static const heavyDaggers = HeroWeapon(
    id: 'heavy_daggers',
    nameAr: 'خنجر ثقيل',
    descAr: 'ضرر ×1.35 · وتيرة ×0.8 · مدى ×1.2',
    unlockLevel: 20,
    damageMultiplier: 1.35,
    rateMultiplier: 0.8,
    rangeMultiplier: 1.2,
  );

  static const spear = HeroWeapon(
    id: 'storm_spear',
    nameAr: 'رمح الصاعقة',
    descAr: 'السلاح الأساسي — الأرقام الأصلية للبطل',
    unlockLevel: 1,
    damageMultiplier: 1.0,
    rateMultiplier: 1.0,
    rangeMultiplier: 1.0,
  );
  static const swiftSpear = HeroWeapon(
    id: 'swift_spear',
    nameAr: 'رمح خفيف',
    descAr: 'ضرر ×0.85 · وتيرة ×1.3 · مدى ×0.9',
    unlockLevel: 10,
    damageMultiplier: 0.85,
    rateMultiplier: 1.3,
    rangeMultiplier: 0.9,
  );
  static const heavySpear = HeroWeapon(
    id: 'heavy_spear',
    nameAr: 'رمح ثقيل',
    descAr: 'ضرر ×1.35 · وتيرة ×0.8 · مدى ×1.2',
    unlockLevel: 20,
    damageMultiplier: 1.35,
    rateMultiplier: 0.8,
    rangeMultiplier: 1.2,
  );
}
