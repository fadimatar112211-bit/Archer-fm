import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../combat/hero_kit.dart';
import '../monsters/monster_models.dart';
import 'equipment.dart';
import 'match_xp.dart';
import 'xp.dart';

/// Persisted combat progress for one hero.
///
/// The payload is plain JSON on purpose: it is the single unit that a future
/// cloud backend will sync, but no cloud sync is implemented in this build.
/// `schemaVersion` lets an older payload be migrated without losing XP.
class HeroProgress {
  const HeroProgress({
    required this.level,
    required this.xp,
    required this.kills,
    this.totalXp = 0,
    this.armyLevels = const {},
    this.essence = 0,
    this.materials = const {},
    this.equipment = const [],
    this.equipped = const {},
    this.capacityLevel = 0,
    this.heroUpgradeLevel = 0,
    this.unlockedAbilityIds = const [],
    this.monsterXp = const {},
    this.monsterLevels = const {},
    this.weaponLevels = const {},
    this.unlockedWeaponIds = const [],
    this.xpHistory = const [],
    this.lastXpGain,
    this.settledMatchIds = const [],
  });

  final int level;
  final int xp;
  final int kills;

  /// Lifetime XP earned by this hero. Level and current XP are derived from
  /// this value so level-ups can never lose or duplicate experience.
  final int totalXp;

  /// Paid monster upgrade levels (kept alongside combat XP).
  final Map<String, int> armyLevels;

  /// Permanent progression currency (the same wallet the HUD calls essence).
  final int essence;

  /// Material counts keyed by `ProgressionMaterial.name`.
  final Map<String, int> materials;

  /// Owned equipment (six slots, five rarities, levels 1..40).
  final List<EquipmentItem> equipment;

  /// Equipped item ids keyed by `EquipmentSlot.name`.
  final Map<String, String> equipped;

  /// Permanent carry-capacity upgrade level (0..20).
  final int capacityLevel;

  /// Permanent hero stat upgrade level (0..40).
  final int heroUpgradeLevel;

  /// Special abilities permanently unlocked at levels 1/10/20/30.
  final List<String> unlockedAbilityIds;

  /// Independent XP per monster type, keyed by `MonsterType.name`.
  final Map<String, int> monsterXp;

  /// Derived monster XP levels, persisted so a backend can validate them.
  final Map<String, int> monsterLevels;

  /// Per-weapon upgrade levels keyed by weapon id (0..10).
  final Map<String, int> weaponLevels;

  /// Weapon ids unlocked by hero level, persisted for cloud-ready saves.
  final List<String> unlockedWeaponIds;

  /// Last ten XP gains, newest first.
  final List<XpGainRecord> xpHistory;

  /// Fast accessor for the post-match summary and the progression screen.
  final XpGainRecord? lastXpGain;

  /// Match ids already settled, so a restart/rejoin cannot pay twice.
  final List<String> settledMatchIds;

  static const int schemaVersion = 2;
  static const int maxHistoryRecords = 10;
  static const int maxSettledMatches = 32;

  static const initial = HeroProgress(level: 1, xp: 0, kills: 0);

  HeroProgress copyWith({
    int? level,
    int? xp,
    int? kills,
    int? totalXp,
    Map<String, int>? armyLevels,
    int? essence,
    Map<String, int>? materials,
    List<EquipmentItem>? equipment,
    Map<String, String>? equipped,
    int? capacityLevel,
    int? heroUpgradeLevel,
    List<String>? unlockedAbilityIds,
    Map<String, int>? monsterXp,
    Map<String, int>? monsterLevels,
    Map<String, int>? weaponLevels,
    List<String>? unlockedWeaponIds,
    List<XpGainRecord>? xpHistory,
    XpGainRecord? lastXpGain,
    List<String>? settledMatchIds,
  }) {
    return HeroProgress(
      level: level ?? this.level,
      xp: xp ?? this.xp,
      kills: kills ?? this.kills,
      totalXp: totalXp ?? this.totalXp,
      armyLevels: armyLevels ?? this.armyLevels,
      essence: essence ?? this.essence,
      materials: materials ?? this.materials,
      equipment: equipment ?? this.equipment,
      equipped: equipped ?? this.equipped,
      capacityLevel: capacityLevel ?? this.capacityLevel,
      heroUpgradeLevel: heroUpgradeLevel ?? this.heroUpgradeLevel,
      unlockedAbilityIds: unlockedAbilityIds ?? this.unlockedAbilityIds,
      monsterXp: monsterXp ?? this.monsterXp,
      monsterLevels: monsterLevels ?? this.monsterLevels,
      weaponLevels: weaponLevels ?? this.weaponLevels,
      unlockedWeaponIds: unlockedWeaponIds ?? this.unlockedWeaponIds,
      xpHistory: xpHistory ?? this.xpHistory,
      lastXpGain: lastXpGain ?? this.lastXpGain,
      settledMatchIds: settledMatchIds ?? this.settledMatchIds,
    );
  }

  /// Derived, authoritative hero XP state.
  ///
  /// A manually constructed profile (used widely in tests) may supply only
  /// `level`/`xp`; in that case the lifetime total is reconstructed so the
  /// explicit level is preserved. A profile serialized with an authoritative
  /// non-zero `totalXp` always wins.
  HeroXpState get heroXp => totalXp > 0
      ? HeroXpState.fromTotal(totalXp)
      : HeroXpState.fromTotal(
          heroTotalXpToLevel(level.clamp(1, heroMaxLevel)) + (xp < 0 ? 0 : xp),
        );

  /// Independent XP state of one monster type.
  MonsterXpState monsterXpState(MonsterType type) =>
      MonsterXpState.fromMap(monsterXp, type.name);

  /// Applies a finalized match award exactly once.
  ///
  /// A repeated match id leaves the profile untouched, which prevents XP
  /// duplication after a restart, a network rejoin or a replayed settlement.
  HeroProgress applyXpAward(XpAward award, {required String heroId}) {
    final matchId = award.matchId;
    if (matchId.isEmpty || settledMatchIds.contains(matchId)) return this;

    final state = HeroXpState.fromTotal(heroXp.totalXp).apply(award.heroXp);
    final kit = kitForHero(heroId);
    final nextMonsterXp = <String, int>{...monsterXp};
    final nextMonsterLevels = <String, int>{...monsterLevels};
    for (final type in MonsterType.values) {
      final gained = award.monsterXp[type] ?? 0;
      if (gained <= 0) continue;
      final updated = monsterXpState(type).apply(gained);
      nextMonsterXp[type.name] = updated.xp;
      nextMonsterLevels[type.name] = updated.level;
    }
    final record = award.toRecord(heroId: heroId);
    return copyWith(
      level: state.level,
      xp: state.xp,
      totalXp: state.totalXp,
      monsterXp: nextMonsterXp,
      monsterLevels: nextMonsterLevels,
      unlockedAbilityIds: [
        ...{
          ...unlockedAbilityIds,
          ...kit.abilitiesUnlockedAt(state.level).map((a) => a.id),
        },
      ],
      unlockedWeaponIds: [
        ...{
          ...unlockedWeaponIds,
          ...kit.weaponsUnlockedAt(state.level).map((w) => w.id),
        },
      ],
      xpHistory: [record, ...xpHistory].take(maxHistoryRecords).toList(),
      lastXpGain: record,
      settledMatchIds: [
        matchId,
        ...settledMatchIds,
      ].take(maxSettledMatches).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final state = heroXp;
    return {
      'schemaVersion': schemaVersion,
      'level': state.level,
      'xp': state.xp,
      'kills': kills,
      'totalXp': state.totalXp,
      'armyLevels': armyLevels,
      'essence': essence,
      'materials': materials,
      'equipment': [for (final item in equipment) item.toJson()],
      'equipped': equipped,
      'capacityLevel': capacityLevel,
      'heroUpgradeLevel': heroUpgradeLevel,
      'unlockedAbilityIds': unlockedAbilityIds,
      'monsterXp': monsterXp,
      'monsterLevels': monsterLevels,
      'weaponLevels': weaponLevels,
      'unlockedWeaponIds': unlockedWeaponIds,
      'xpHistory': [for (final record in xpHistory) record.toJson()],
      'lastXpGain': lastXpGain?.toJson(),
      'settledMatchIds': settledMatchIds,
    };
  }

  static HeroProgress fromJson(Map<String, dynamic> data) {
    final level = data['level'] is int
        ? (data['level'] as int).clamp(1, heroMaxLevel)
        : 1;
    final xp = data['xp'] is int && (data['xp'] as int) >= 0 ? data['xp'] as int : 0;
    final rawTotal = data['totalXp'];
    // A positive total is authoritative. Zero is treated as explicit only when
    // the saved level/xp also indicate level 1 with no progress; otherwise we
    // reconstruct from level/xp so legacy payloads and manually built progress
    // objects survive a round trip.
    final legacyTotal = heroTotalXpToLevel(level) + xp;
    final hasExplicitTotal = rawTotal is int && (rawTotal > 0 || legacyTotal == 0);
    final totalXp = hasExplicitTotal ? rawTotal : legacyTotal;
    final state = HeroXpState.fromTotal(totalXp);

    final rawArmy = data['armyLevels'];
    final armyLevels = <String, int>{};
    if (rawArmy is Map) {
      for (final entry in rawArmy.entries) {
        if (entry.key is String && entry.value is int) {
          armyLevels[entry.key as String] = (entry.value as int).clamp(1, 40);
        }
      }
    }

    final rawMaterials = data['materials'];
    final materials = <String, int>{};
    if (rawMaterials is Map) {
      for (final entry in rawMaterials.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is int && value >= 0) materials[key] = value;
      }
    }

    final equipment = <EquipmentItem>[];
    final rawEquipment = data['equipment'];
    if (rawEquipment is List) {
      for (final value in rawEquipment) {
        final item = EquipmentItem.fromJson(value);
        if (item != null) equipment.add(item);
      }
    }

    final equipped = <String, String>{};
    final rawEquipped = data['equipped'];
    if (rawEquipped is Map) {
      for (final entry in rawEquipped.entries) {
        if (entry.key is String && entry.value is String) {
          equipped[entry.key as String] = entry.value as String;
        }
      }
    }

    List<String> readStringList(Object? raw) {
      if (raw is! List) return const [];
      return [for (final value in raw) if (value is String) value];
    }

    Map<String, int> readIntMap(Object? raw) {
      final result = <String, int>{};
      if (raw is! Map) return result;
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is int) {
          result[entry.key as String] = entry.value as int;
        }
      }
      return result;
    }

    final monsterXp = readIntMap(data['monsterXp']);
    final monsterLevels = readIntMap(data['monsterLevels']);
    for (final type in MonsterType.values) {
      if (!monsterXp.containsKey(type.name)) {
        monsterXp[type.name] = MonsterXpState.fromMap(
          monsterLevels,
          type.name,
        ).xp;
      }
      monsterLevels[type.name] =
          MonsterXpState.fromMap(monsterXp, type.name).level;
    }

    final kit = kitForHero(data['heroId'] is String ? data['heroId'] as String : 'ranger_new');
    final abilities = <String>{
      ...readStringList(data['unlockedAbilityIds']),
      ...kit.abilitiesUnlockedAt(state.level).map((a) => a.id),
    }.toList();
    final weapons = <String>{
      ...readStringList(data['unlockedWeaponIds']),
      ...kit.weaponsUnlockedAt(state.level).map((w) => w.id),
    }.toList();

    final history = <XpGainRecord>[];
    final rawHistory = data['xpHistory'];
    if (rawHistory is List) {
      for (final value in rawHistory) {
        history.add(XpGainRecord.fromJson(value));
      }
    }

    final lastRaw = data['lastXpGain'];
    final last = lastRaw is Map<String, dynamic>
        ? XpGainRecord.fromJson(lastRaw)
        : (history.isEmpty ? null : history.first);

    return HeroProgress(
      level: state.level,
      xp: state.xp,
      kills: data['kills'] is int && (data['kills'] as int) >= 0
          ? data['kills'] as int
          : 0,
      totalXp: state.totalXp,
      armyLevels: armyLevels,
      essence: data['essence'] is int
          ? (data['essence'] as int).clamp(0, 0x7fffffff)
          : 0,
      materials: materials,
      equipment: equipment,
      equipped: equipped,
      capacityLevel: data['capacityLevel'] is int
          ? (data['capacityLevel'] as int).clamp(0, 20)
          : 0,
      heroUpgradeLevel: data['heroUpgradeLevel'] is int
          ? (data['heroUpgradeLevel'] as int).clamp(0, 40)
          : 0,
      unlockedAbilityIds: abilities,
      monsterXp: monsterXp,
      monsterLevels: monsterLevels,
      weaponLevels: readIntMap(data['weaponLevels']),
      unlockedWeaponIds: weapons,
      xpHistory: history.take(maxHistoryRecords).toList(),
      lastXpGain: last,
      settledMatchIds: readStringList(data['settledMatchIds'])
          .take(maxSettledMatches)
          .toList(),
    );
  }
}

/// Storage abstraction so tests can swap in an in-memory store.
abstract class ProgressStore {
  Future<HeroProgress?> load(String heroId);
  Future<void> save(String heroId, HeroProgress progress);
}

/// Shared-preferences backed store used by the running app.
class SharedPreferencesProgressStore implements ProgressStore {
  static const _prefix = 'archer_fm.progress.';

  @override
  Future<HeroProgress?> load(String heroId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$heroId');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      // heroId is not stored inside the payload; add it so fromJson can derive
      // the correct kit-based unlock list.
      return HeroProgress.fromJson({'heroId': heroId, ...data});
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(String heroId, HeroProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$heroId', jsonEncode(progress.toJson()));
  }
}

/// In-memory store for tests and for the "reset progress" flow.
class MemoryProgressStore implements ProgressStore {
  final Map<String, HeroProgress> _values = {};

  @override
  Future<HeroProgress?> load(String heroId) async => _values[heroId];

  @override
  Future<void> save(String heroId, HeroProgress progress) {
    _values[heroId] = progress;
    return Future.value();
  }
}
