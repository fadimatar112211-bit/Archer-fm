/// Canonical playable-roster data for Archer FM.
///
/// This file deliberately contains game rules only; rendering and combat
/// systems consume these immutable definitions. Combo hits are separate from
/// Ultimate abilities and are never level-gated.
enum HeroId { ranger, flame, shadow, storm }
enum HeroWeaponRange { melee, reach, ranged }
enum UltimateUnlock { level1, level10, level20, level30 }

class HeroWeapon {
  const HeroWeapon({
    required this.id,
    required this.nameAr,
    required this.range,
    required this.damageMultiplier,
    required this.cooldownMs,
    required this.descriptionAr,
  });
  final String id;
  final String nameAr;
  final HeroWeaponRange range;
  final double damageMultiplier;
  final int cooldownMs;
  final String descriptionAr;
}

class HeroUltimate {
  const HeroUltimate({
    required this.id,
    required this.nameAr,
    required this.unlockLevel,
    required this.cooldownMs,
    required this.damageMultiplier,
    required this.radius,
    required this.descriptionAr,
  });
  final String id;
  final String nameAr;
  final int unlockLevel;
  final int cooldownMs;
  final double damageMultiplier;
  final double radius;
  final String descriptionAr;
}

class HeroCombatDefinition {
  const HeroCombatDefinition({
    required this.id,
    required this.modelAssetPath,
    required this.nameAr,
    required this.roleAr,
    required this.baseHealth,
    required this.baseDamage,
    required this.moveSpeed,
    required this.attackRange,
    required this.attackCooldownMs,
    required this.weapons,
    required this.ultimates,
  });
  final HeroId id;
  final String modelAssetPath;
  final String nameAr;
  final String roleAr;
  final int baseHealth;
  final double baseDamage;
  final double moveSpeed;
  final double attackRange;
  final int attackCooldownMs;
  final List<HeroWeapon> weapons;
  final List<HeroUltimate> ultimates;

  int healthAt(int level) => baseHealth + (level - 1) * 18;
  double damageAt(int level) => baseDamage * (1 + (level - 1) * 0.035);
  bool isUltimateUnlocked(int ultimateIndex, int level) =>
      level >= ultimates[ultimateIndex].unlockLevel;
}

const int heroLevelCap = 40;
const int comboHitCount = 5;
const List<int> ultimateUnlockLevels = [1, 10, 20, 30];

const List<HeroCombatDefinition> archerFmHeroes = [
  HeroCombatDefinition(
    id: HeroId.ranger,
    modelAssetPath: 'assets/heroes/ranger/model/ranger_animated.glb',
    nameAr: 'الرامي',
    roleAr: 'قتال بعيد المدى',
    baseHealth: 600,
    baseDamage: 54,
    moveSpeed: 1.12,
    attackRange: 5.2,
    attackCooldownMs: 520,
    weapons: [
      HeroWeapon(id: 'ranger_greenbow', nameAr: 'قوس الطاقة الخضراء', range: HeroWeaponRange.ranged, damageMultiplier: 1.0, cooldownMs: 520, descriptionAr: 'قوس متوازن سريع ودقيق.'),
      HeroWeapon(id: 'ranger_longbow', nameAr: 'قوس الصقر', range: HeroWeaponRange.ranged, damageMultiplier: 1.22, cooldownMs: 690, descriptionAr: 'مدى أطول وضربة أقوى.'),
      HeroWeapon(id: 'ranger_twinshot', nameAr: 'قوس الشفق المزدوج', range: HeroWeaponRange.ranged, damageMultiplier: 0.78, cooldownMs: 390, descriptionAr: 'سهمان سريعا الإطلاق.'),
    ],
    ultimates: [
      HeroUltimate(id: 'ranger_starfall', nameAr: 'وابل النجوم', unlockLevel: 1, cooldownMs: 18000, damageMultiplier: 2.2, radius: 2.2, descriptionAr: 'وابل سهام يسقط على منطقة محددة.'),
      HeroUltimate(id: 'ranger_piercing', nameAr: 'السهم الثاقب', unlockLevel: 10, cooldownMs: 22000, damageMultiplier: 3.1, radius: 0.7, descriptionAr: 'سهم يخترق الأعداء على خط مستقيم.'),
      HeroUltimate(id: 'ranger_nature', nameAr: 'حارس الغابة', unlockLevel: 20, cooldownMs: 28000, damageMultiplier: 2.7, radius: 3.0, descriptionAr: 'انفجار طاقة يبطئ الأعداء حول الرامي.'),
      HeroUltimate(id: 'ranger_apex', nameAr: 'القنص الأسطوري', unlockLevel: 30, cooldownMs: 36000, damageMultiplier: 5.0, radius: 1.2, descriptionAr: 'ضربة دقيقة هائلة على أقوى عدو.'),
    ],
  ),
  HeroCombatDefinition(
    id: HeroId.flame,
    modelAssetPath: 'assets/heroes/flame/model/flame_animated.glb',
    nameAr: 'فارس اللهب',
    roleAr: 'ضرر قريب وانفجارات',
    baseHealth: 600,
    baseDamage: 62,
    moveSpeed: 0.96,
    attackRange: 1.65,
    attackCooldownMs: 650,
    weapons: [
      HeroWeapon(id: 'flame_greatsword', nameAr: 'سيف اللهب العظيم', range: HeroWeaponRange.melee, damageMultiplier: 1.0, cooldownMs: 650, descriptionAr: 'ضربات ثقيلة متوازنة.'),
      HeroWeapon(id: 'flame_cleaver', nameAr: 'شفرة الحمم', range: HeroWeaponRange.melee, damageMultiplier: 1.28, cooldownMs: 820, descriptionAr: 'ضربة أبطأ تحطم الدروع.'),
      HeroWeapon(id: 'flame_dualblades', nameAr: 'نصال الجمر', range: HeroWeaponRange.melee, damageMultiplier: 0.76, cooldownMs: 430, descriptionAr: 'سلسلة ضربات نارية سريعة.'),
    ],
    ultimates: [
      HeroUltimate(id: 'flame_eruption', nameAr: 'ثوران الجحيم', unlockLevel: 1, cooldownMs: 19000, damageMultiplier: 2.3, radius: 2.5, descriptionAr: 'انفجار نار حول الفارس.'),
      HeroUltimate(id: 'flame_comet', nameAr: 'مذنب اللهب', unlockLevel: 10, cooldownMs: 23000, damageMultiplier: 3.2, radius: 2.0, descriptionAr: 'مذنب ناري يضرب المنطقة المستهدفة.'),
      HeroUltimate(id: 'flame_brand', nameAr: 'وسم الاحتراق', unlockLevel: 20, cooldownMs: 29000, damageMultiplier: 2.5, radius: 2.4, descriptionAr: 'يحرق الأعداء ويترك ضرراً مستمراً.'),
      HeroUltimate(id: 'flame_phoenix', nameAr: 'صحوة العنقاء', unlockLevel: 30, cooldownMs: 38000, damageMultiplier: 5.2, radius: 3.2, descriptionAr: 'اندفاع ناري واسع يضرب عدة مرات.'),
    ],
  ),
  HeroCombatDefinition(
    id: HeroId.shadow,
    modelAssetPath: 'assets/heroes/shadow/model/shadow_animated.glb',
    nameAr: 'ظل الليل',
    roleAr: 'اغتيال وسرعة',
    baseHealth: 600,
    baseDamage: 50,
    moveSpeed: 1.28,
    attackRange: 1.55,
    attackCooldownMs: 410,
    weapons: [
      HeroWeapon(id: 'shadow_twinfangs', nameAr: 'الخنجران التوأمان', range: HeroWeaponRange.melee, damageMultiplier: 1.0, cooldownMs: 410, descriptionAr: 'ضربات متتابعة سريعة.'),
      HeroWeapon(id: 'shadow_nightfang', nameAr: 'ناب الليل', range: HeroWeaponRange.melee, damageMultiplier: 1.34, cooldownMs: 610, descriptionAr: 'خنجر ثقيل لضربة اغتيال.'),
      HeroWeapon(id: 'shadow_soulblades', nameAr: 'شفرات الروح', range: HeroWeaponRange.reach, damageMultiplier: 0.82, cooldownMs: 360, descriptionAr: 'شفرات طاقة قصيرة المدى.'),
    ],
    ultimates: [
      HeroUltimate(id: 'shadow_vanish', nameAr: 'اختفاء قاتل', unlockLevel: 1, cooldownMs: 18000, damageMultiplier: 2.0, radius: 1.8, descriptionAr: 'اختفاء خاطف ثم ضربة خلف الهدف.'),
      HeroUltimate(id: 'shadow_cross', nameAr: 'تقاطع الظلال', unlockLevel: 10, cooldownMs: 22000, damageMultiplier: 3.0, radius: 2.2, descriptionAr: 'اندفاعان متقاطعان خلال الأعداء.'),
      HeroUltimate(id: 'shadow_poison', nameAr: 'سم العتمة', unlockLevel: 20, cooldownMs: 27000, damageMultiplier: 2.4, radius: 2.8, descriptionAr: 'ينشر سماً يسبب ضرراً مستمراً.'),
      HeroUltimate(id: 'shadow_execution', nameAr: 'حكم الظلام', unlockLevel: 30, cooldownMs: 35000, damageMultiplier: 5.4, radius: 1.4, descriptionAr: 'ضربة اغتيال مركزة على هدف واحد.'),
    ],
  ),
  HeroCombatDefinition(
    id: HeroId.storm,
    modelAssetPath: 'assets/heroes/storm/model/storm_animated.glb',
    nameAr: 'حامل العاصفة',
    roleAr: 'مدى متوسط وتحكم',
    baseHealth: 600,
    baseDamage: 57,
    moveSpeed: 1.04,
    attackRange: 3.2,
    attackCooldownMs: 570,
    weapons: [
      HeroWeapon(id: 'storm_spear', nameAr: 'رمح الصاعقة', range: HeroWeaponRange.reach, damageMultiplier: 1.0, cooldownMs: 570, descriptionAr: 'رمح متوازن بصعقات قصيرة.'),
      HeroWeapon(id: 'storm_halberd', nameAr: 'مطرقة الرعد', range: HeroWeaponRange.reach, damageMultiplier: 1.26, cooldownMs: 760, descriptionAr: 'ضربة ثقيلة تصعق مجموعة.'),
      HeroWeapon(id: 'storm_lance', nameAr: 'رمح البرق', range: HeroWeaponRange.ranged, damageMultiplier: 0.84, cooldownMs: 430, descriptionAr: 'مقذوف كهربائي سريع.'),
    ],
    ultimates: [
      HeroUltimate(id: 'storm_bolt', nameAr: 'صاعقة السماء', unlockLevel: 1, cooldownMs: 18000, damageMultiplier: 2.2, radius: 1.8, descriptionAr: 'صاعقة مباشرة على أقرب عدو.'),
      HeroUltimate(id: 'storm_chain', nameAr: 'سلسلة الرعد', unlockLevel: 10, cooldownMs: 23000, damageMultiplier: 2.8, radius: 3.0, descriptionAr: 'كهرباء تنتقل بين عدة أعداء.'),
      HeroUltimate(id: 'storm_field', nameAr: 'حقل العاصفة', unlockLevel: 20, cooldownMs: 29000, damageMultiplier: 2.5, radius: 3.4, descriptionAr: 'حقل يبطئ ويصعق كل من يدخله.'),
      HeroUltimate(id: 'storm_tempest', nameAr: 'طوفان البرق', unlockLevel: 30, cooldownMs: 37000, damageMultiplier: 5.0, radius: 3.8, descriptionAr: 'عاصفة برق واسعة متعددة الضربات.'),
    ],
  ),
];

HeroCombatDefinition heroCombatById(HeroId id) =>
    archerFmHeroes.firstWhere((hero) => hero.id == id);

/// Five-tap combo is available independently of Ultimate unlocks.
int comboDamageForTap(double baseDamage, int tapIndex) {
  if (tapIndex < 0 || tapIndex >= comboHitCount) {
    throw RangeError.range(tapIndex, 0, comboHitCount - 1, 'tapIndex');
  }
  const multipliers = [1.0, 1.05, 1.1, 1.2, 1.55];
  return (baseDamage * multipliers[tapIndex]).round();
}
