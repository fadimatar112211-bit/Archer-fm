import 'dart:math' as math;
import 'dart:ui' show Offset;

/// The four monster types approved for Archer FM. They are the legacy
/// Archero_fm archetypes, kept 1:1 so the army plays the same roles:
/// a fast dasher, a slow wall, a flanking harasser and a ranged attacker.
enum MonsterType { runner, tank, stalker, ranged }

/// Which side of the battle a monster belongs to.
enum MonsterTeam { player, enemy }

/// Animation states of a monster. `death` is only used by corpses, because a
/// dead army monster is permanently removed from the roster.
enum MonsterAnimState { idle, walk, attack, death }

const int monsterMaxLevel = 40;

/// Maps both the legacy enemy names (`slime`/`archer`/`brute`) and the
/// production names onto the four approved types. Tests and old captures can
/// keep constructing enemies with the legacy names.
MonsterType monsterTypeFromName(String name) {
  switch (name) {
    case 'tank':
    case 'brute':
      return MonsterType.tank;
    case 'stalker':
      return MonsterType.stalker;
    case 'ranged':
    case 'archer':
      return MonsterType.ranged;
    case 'runner':
    case 'slime':
    default:
      return MonsterType.runner;
  }
}

/// Immutable per-type design data (level 1 values).
class MonsterTypeDef {
  const MonsterTypeDef({
    required this.type,
    required this.nameAr,
    required this.roleAr,
    required this.baseHp,
    required this.baseSpeed,
    required this.baseDamage,
    required this.radius,
    required this.attackRange,
    required this.attackCooldownMs,
    required this.xpValue,
    required this.price,
    required this.preferredRange,
    required this.color,
    required this.accent,
  });

  final MonsterType type;
  final String nameAr;
  final String roleAr;
  final double baseHp;
  final double baseSpeed;
  final double baseDamage;

  /// Body radius in arena units, used for hit tests, shadows and HP bars.
  final double radius;
  final double attackRange;
  final int attackCooldownMs;
  final int xpValue;

  /// Match-resource price to buy one more of this type.
  final int price;

  /// Distance a ranged monster tries to hold from its target.
  final double preferredRange;
  final int color;
  final int accent;

  bool get isRanged => type == MonsterType.ranged;
}

/// The legacy-derived catalog. Names, roles and the relative stat triangle
/// follow `PROJECT_STATUS.md` (runner ×0.72 HP/×1.25 speed, tank ×1.8/×0.52,
/// stalker ×0.9/×0.90, ranged ×0.82/×0.68), lifted to the Archer FM scale.
class MonsterCatalog {
  const MonsterCatalog._();

  static const Map<MonsterType, MonsterTypeDef> defs = {
    MonsterType.runner: MonsterTypeDef(
      type: MonsterType.runner,
      nameAr: 'العدّاء',
      roleAr: 'سريع · اندفاع',
      baseHp: 64,
      baseSpeed: 138,
      baseDamage: 9,
      radius: 11,
      attackRange: 30,
      attackCooldownMs: 900,
      xpValue: 8,
      price: 30,
      preferredRange: 26,
      color: 0xFF4D9848,
      accent: 0xFFC5E99B,
    ),
    MonsterType.tank: MonsterTypeDef(
      type: MonsterType.tank,
      nameAr: 'المدرّع',
      roleAr: 'بطيء · صلب',
      baseHp: 190,
      baseSpeed: 72,
      baseDamage: 18,
      radius: 16,
      attackRange: 36,
      attackCooldownMs: 1300,
      xpValue: 20,
      price: 55,
      preferredRange: 30,
      color: 0xFF596474,
      accent: 0xFFD9B66F,
    ),
    MonsterType.stalker: MonsterTypeDef(
      type: MonsterType.stalker,
      nameAr: 'المتربص',
      roleAr: 'مناورة جانبية',
      baseHp: 88,
      baseSpeed: 108,
      baseDamage: 12,
      radius: 11,
      // The flanker gets a little more reach than the fast runner,
      // reinforcing its distinct side-entry/harass role without competing
      // with the ranged unit's long-distance attack.
      attackRange: 38,
      attackCooldownMs: 1000,
      xpValue: 12,
      price: 40,
      preferredRange: 26,
      color: 0xFFE5D9BD,
      accent: 0xFFFFF1D5,
    ),
    MonsterType.ranged: MonsterTypeDef(
      type: MonsterType.ranged,
      nameAr: 'الرامي',
      roleAr: 'بعيد · كرة نار',
      baseHp: 78,
      baseSpeed: 92,
      baseDamage: 10,
      radius: 11,
      attackRange: 210,
      attackCooldownMs: 2400,
      xpValue: 14,
      price: 45,
      preferredRange: 135,
      color: 0xFF57358F,
      accent: 0xFFBE83FF,
    ),
  };

  static MonsterTypeDef def(MonsterType type) => defs[type]!;

  static List<MonsterTypeDef> get all => MonsterType.values
      .map(def)
      .toList(growable: false);

  /// A balanced, tournament-legal 20-monster starting army.
  static const Map<MonsterType, int> defaultStartingArmy = {
    MonsterType.runner: 6,
    MonsterType.tank: 5,
    MonsterType.stalker: 5,
    MonsterType.ranged: 4,
  };
}

/// Level scaling for one monster type. Upgrades are permanent, improve HP,
/// damage and movement speed, and stop at level 40.
class MonsterStats {
  const MonsterStats({
    required this.type,
    required this.level,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.radius,
    required this.attackRange,
    required this.attackCooldownMs,
    required this.xpValue,
  });

  final MonsterType type;
  final int level;
  final double maxHp;
  final double speed;
  final double damage;
  final double radius;
  final double attackRange;
  final int attackCooldownMs;
  final int xpValue;

  static double hpScale(int level) => 1 + (level - 1) * 0.065;

  static double damageScale(int level) => 1 + (level - 1) * 0.05;

  static double speedScale(int level) => 1 + (level - 1) * 0.012;

  factory MonsterStats.of(MonsterType type, int level) {
    final def = MonsterCatalog.def(type);
    final lvl = level.clamp(1, monsterMaxLevel);
    final hp = def.baseHp * hpScale(lvl);
    return MonsterStats(
      type: type,
      level: lvl,
      maxHp: hp,
      speed: def.baseSpeed * speedScale(lvl),
      damage: def.baseDamage * damageScale(lvl),
      radius: def.radius,
      attackRange: def.attackRange,
      attackCooldownMs: def.attackCooldownMs,
      xpValue: (def.xpValue * (1 + (lvl - 1) * 0.04)).round(),
    );
  }
}

/// Per-type permanent upgrade levels (1..40) for the player's army.
class MonsterUpgrades {
  MonsterUpgrades([Map<MonsterType, int>? levels])
      : _levels = {
          for (final type in MonsterType.values)
            type: (levels?[type] ?? 1).clamp(1, monsterMaxLevel),
        };

  final Map<MonsterType, int> _levels;

  static const int maxLevel = monsterMaxLevel;

  int levelOf(MonsterType type) => _levels[type] ?? 1;

  Map<MonsterType, int> get levels => Map.unmodifiable(_levels);

  Map<String, int> toMap() => {
        for (final entry in _levels.entries) entry.key.name: entry.value,
      };

  void loadFromMap(Map<String, int> saved) {
    for (final type in MonsterType.values) {
      final value = saved[type.name];
      if (value != null) _levels[type] = value.clamp(1, maxLevel);
    }
  }

  /// Essence price of the next level for [type].
  int upgradeCost(MonsterType type) {
    final level = levelOf(type);
    if (level >= maxLevel) return 0;
    return 20 + (level - 1) * 12;
  }

  bool canUpgrade(MonsterType type, int essence) =>
      levelOf(type) < maxLevel && essence >= upgradeCost(type);

  /// Spends [essence] through the caller, then raises the level by one.
  /// Returns the new level, or the unchanged level when maxed/too poor.
  int upgrade(MonsterType type, {required int essence}) {
    final level = levelOf(type);
    if (level >= maxLevel || essence < upgradeCost(type)) return level;
    _levels[type] = level + 1;
    return level + 1;
  }
}

/// One short-lived corpse animation. Dead monsters are permanently removed
/// from the army, but their collapse stays on screen for a moment.
class MonsterCorpse {
  MonsterCorpse({
    required this.type,
    required this.team,
    required this.position,
    required this.facing,
    required this.bornAtMs,
  });

  final MonsterType type;
  final MonsterTeam team;
  final Offset position;
  final Offset facing;
  final int bornAtMs;

  static const int lifetimeMs = 700;

  MonsterAnimState stateAt(int nowMs) => MonsterAnimState.death;

  /// 0 at death, 1 when the corpse should be removed.
  double progressAt(int nowMs) =>
      ((nowMs - bornAtMs) / lifetimeMs).clamp(0.0, 1.0);
}

/// Formation offsets for the starting army / purchased reinforcements.
/// Elliptical rings keep purchased units within their castle spawn radius
/// while preserving a protective formation around the owner.
Offset armyFormationOffset(int slot, int total) {
  final ring = slot ~/ 8;
  final inRing = slot % 8;
  final countInRing = (total - ring * 8).clamp(1, 8);
  final angle = (inRing / countInRing) * math.pi * 2 + ring * 0.4;
  final radius = 54.0 + ring * 34.0;
  return Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.78);
}
