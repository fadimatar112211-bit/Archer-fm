import 'dart:math' as math;

enum WeaponDamageType { physical, fire, poison, lightning, shadow }
enum WeaponDelivery { projectile, melee, piercing, area }

class WeaponStats {
  const WeaponStats({required this.damage, required this.range, required this.cooldownMs, required this.targetCount});
  final int damage;
  final double range;
  final int cooldownMs;
  final int targetCount;
}

class WeaponDefinition {
  const WeaponDefinition({required this.id, required this.heroId, required this.nameAr, required this.descriptionAr, required this.damageType, required this.delivery, required this.baseStats, this.unlockLevel = 1});
  final String id, heroId, nameAr, descriptionAr;
  final WeaponDamageType damageType;
  final WeaponDelivery delivery;
  final WeaponStats baseStats;
  final int unlockLevel;

  WeaponStats statsAt(int level) {
    _checkLevel(level);
    final bonus = level - 1;
    return WeaponStats(
      damage: (baseStats.damage * (1 + bonus * 0.035)).round(),
      range: baseStats.range * (1 + bonus * 0.006),
      cooldownMs: math.max(180, (baseStats.cooldownMs * (1 - bonus * 0.004)).round()),
      targetCount: baseStats.targetCount + bonus ~/ 10,
    );
  }

  int upgradeCost(int currentLevel) {
    _checkLevel(currentLevel);
    if (currentLevel == maxWeaponLevel) throw StateError('Weapon is already at maximum level');
    return 35 + currentLevel * 18 + currentLevel * currentLevel ~/ 8;
  }

  static const int maxWeaponLevel = 40;
  void _checkLevel(int level) {
    if (level < 1 || level > maxWeaponLevel) throw RangeError.range(level, 1, maxWeaponLevel, 'level');
  }
}

/// Initial tuning values only; balance is not yet approved.
const List<WeaponDefinition> weaponCatalog = [
  WeaponDefinition(id:'ranger_bow',heroId:'ranger',nameAr:'قوس الغابة',descriptionAr:'سهم دقيق بعيد المدى',damageType:WeaponDamageType.physical,delivery:WeaponDelivery.projectile,baseStats:WeaponStats(damage:28,range:8,cooldownMs:520,targetCount:1)),
  WeaponDefinition(id:'ranger_volley',heroId:'ranger',nameAr:'قوس العاصفة',descriptionAr:'طلقات متتابعة تصيب أكثر من هدف',damageType:WeaponDamageType.physical,delivery:WeaponDelivery.piercing,baseStats:WeaponStats(damage:19,range:7,cooldownMs:680,targetCount:3),unlockLevel:10),
  WeaponDefinition(id:'ranger_thorn',heroId:'ranger',nameAr:'قوس الشوك',descriptionAr:'سهام سامة تضغط على الخصم',damageType:WeaponDamageType.poison,delivery:WeaponDelivery.projectile,baseStats:WeaponStats(damage:23,range:7.5,cooldownMs:610,targetCount:1),unlockLevel:20),
  WeaponDefinition(id:'flame_blade',heroId:'flame',nameAr:'سيف اللهب',descriptionAr:'ضربة ثقيلة تحرق الهدف',damageType:WeaponDamageType.fire,delivery:WeaponDelivery.melee,baseStats:WeaponStats(damage:38,range:1.8,cooldownMs:720,targetCount:1)),
  WeaponDefinition(id:'flame_cleaver',heroId:'flame',nameAr:'قاطع الحمم',descriptionAr:'قوس واسع يضرب عدة خصوم',damageType:WeaponDamageType.fire,delivery:WeaponDelivery.area,baseStats:WeaponStats(damage:27,range:2.2,cooldownMs:900,targetCount:3),unlockLevel:10),
  WeaponDefinition(id:'flame_greatsword',heroId:'flame',nameAr:'نصل الجحيم',descriptionAr:'ضربة بطيئة ذات ضرر مرتفع',damageType:WeaponDamageType.fire,delivery:WeaponDelivery.melee,baseStats:WeaponStats(damage:54,range:1.7,cooldownMs:1050,targetCount:1),unlockLevel:20),
  WeaponDefinition(id:'shadow_twin',heroId:'shadow',nameAr:'الخنجران التوأمان',descriptionAr:'ضربات سريعة متقاربة',damageType:WeaponDamageType.shadow,delivery:WeaponDelivery.melee,baseStats:WeaponStats(damage:17,range:1.6,cooldownMs:300,targetCount:1)),
  WeaponDefinition(id:'shadow_fang',heroId:'shadow',nameAr:'ناب الظل',descriptionAr:'طعنة دقيقة تخترق الصف',damageType:WeaponDamageType.shadow,delivery:WeaponDelivery.piercing,baseStats:WeaponStats(damage:25,range:3,cooldownMs:510,targetCount:2),unlockLevel:10),
  WeaponDefinition(id:'shadow_venom',heroId:'shadow',nameAr:'خنجر السم',descriptionAr:'هجمات سريعة بضرر سام',damageType:WeaponDamageType.poison,delivery:WeaponDelivery.melee,baseStats:WeaponStats(damage:20,range:1.7,cooldownMs:360,targetCount:1),unlockLevel:20),
  WeaponDefinition(id:'storm_spear',heroId:'storm',nameAr:'رمح الصاعقة',descriptionAr:'رمح متوسط المدى مشحون بالكهرباء',damageType:WeaponDamageType.lightning,delivery:WeaponDelivery.piercing,baseStats:WeaponStats(damage:31,range:3.8,cooldownMs:610,targetCount:2)),
  WeaponDefinition(id:'storm_lance',heroId:'storm',nameAr:'رمح الرعد',descriptionAr:'اندفاع خاطف يخترق الأعداء',damageType:WeaponDamageType.lightning,delivery:WeaponDelivery.piercing,baseStats:WeaponStats(damage:35,range:4.5,cooldownMs:760,targetCount:3),unlockLevel:10),
  WeaponDefinition(id:'storm_tempest',heroId:'storm',nameAr:'صولجان العاصفة',descriptionAr:'انفجار كهربائي حول نقطة الإصابة',damageType:WeaponDamageType.lightning,delivery:WeaponDelivery.area,baseStats:WeaponStats(damage:26,range:3.2,cooldownMs:820,targetCount:4),unlockLevel:20),
];
WeaponDefinition weaponById(String id) => weaponCatalog.firstWhere((weapon) => weapon.id == id);
List<WeaponDefinition> weaponsForHero(String heroId) => weaponCatalog.where((weapon) => weapon.heroId == heroId).toList(growable:false);
