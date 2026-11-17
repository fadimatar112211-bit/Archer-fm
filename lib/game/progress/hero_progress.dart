import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted combat progress for one hero: level, xp, kill count, permanent
/// monster upgrade levels and the monster essence wallet.
class HeroProgress {
  const HeroProgress({
    required this.level,
    required this.xp,
    required this.kills,
    this.armyLevels = const {},
    this.essence = 0,
  });

  final int level;
  final int xp;
  final int kills;
  final Map<String, int> armyLevels;
  final int essence;

  static const initial = HeroProgress(level: 1, xp: 0, kills: 0);
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
      return HeroProgress(
        level: level,
        xp: xp,
        kills: kills,
        armyLevels: armyLevels,
        essence: essence is int ? essence : 0,
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
