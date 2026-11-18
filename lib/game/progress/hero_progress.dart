import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'equipment.dart';

/// Persisted combat progress for one hero: level, xp, kill count, permanent
/// monster upgrade levels and the monster essence wallet.
class HeroProgress {
  const HeroProgress({
    required this.level,
    required this.xp,
    required this.kills,
    this.armyLevels = const {},
    this.essence = 0,
    this.materials = const {},
    this.equipment = const [],
    this.equipped = const {},
    this.capacityLevel = 0,
    this.heroUpgradeLevel = 0,
  });

  final int level;
  final int xp;
  final int kills;
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

  static const initial = HeroProgress(level: 1, xp: 0, kills: 0);

  HeroProgress copyWith({
    int? level,
    int? xp,
    int? kills,
    Map<String, int>? armyLevels,
    int? essence,
    Map<String, int>? materials,
    List<EquipmentItem>? equipment,
    Map<String, String>? equipped,
    int? capacityLevel,
    int? heroUpgradeLevel,
  }) {
    return HeroProgress(
      level: level ?? this.level,
      xp: xp ?? this.xp,
      kills: kills ?? this.kills,
      armyLevels: armyLevels ?? this.armyLevels,
      essence: essence ?? this.essence,
      materials: materials ?? this.materials,
      equipment: equipment ?? this.equipment,
      equipped: equipped ?? this.equipped,
      capacityLevel: capacityLevel ?? this.capacityLevel,
      heroUpgradeLevel: heroUpgradeLevel ?? this.heroUpgradeLevel,
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
      final level = data['level'];
      final xp = data['xp'];
      final kills = data['kills'];
      if (level is! int || xp is! int || kills is! int) return null;
      final rawArmy = data['armyLevels'];
      final armyLevels = <String, int>{};
      if (rawArmy is Map) {
        for (final entry in rawArmy.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && value is int) armyLevels[key] = value;
        }
      }
      final essence = data['essence'];
      final rawMaterials = data['materials'];
      final materials = <String, int>{};
      if (rawMaterials is Map) {
        for (final entry in rawMaterials.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && value is int && value >= 0) {
            materials[key] = value;
          }
        }
      }
      final rawEquipment = data['equipment'];
      final equipment = <EquipmentItem>[];
      if (rawEquipment is List) {
        for (final value in rawEquipment) {
          final item = EquipmentItem.fromJson(value);
          if (item != null) equipment.add(item);
        }
      }
      final rawEquipped = data['equipped'];
      final equipped = <String, String>{};
      if (rawEquipped is Map) {
        for (final entry in rawEquipped.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && value is String) equipped[key] = value;
        }
      }
      final capacityLevel = data['capacityLevel'];
      final heroUpgradeLevel = data['heroUpgradeLevel'];
      return HeroProgress(
        level: level,
        xp: xp,
        kills: kills,
        armyLevels: armyLevels,
        essence: essence is int ? essence.clamp(0, 0x7fffffff) : 0,
        materials: materials,
        equipment: equipment,
        equipped: equipped,
        capacityLevel: capacityLevel is int
            ? capacityLevel.clamp(0, 20)
            : 0,
        heroUpgradeLevel: heroUpgradeLevel is int
            ? heroUpgradeLevel.clamp(0, 40)
            : 0,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(String heroId, HeroProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$heroId',
      jsonEncode({
        'level': progress.level,
        'xp': progress.xp,
        'kills': progress.kills,
        'armyLevels': progress.armyLevels,
        'essence': progress.essence,
        'materials': progress.materials,
        'equipment': [
          for (final item in progress.equipment) item.toJson(),
        ],
        'equipped': progress.equipped,
        'capacityLevel': progress.capacityLevel,
        'heroUpgradeLevel': progress.heroUpgradeLevel,
      }),
    );
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
