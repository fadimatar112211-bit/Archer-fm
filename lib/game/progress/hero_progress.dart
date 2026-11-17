import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted combat progress for one hero: level, xp and kill count.
class HeroProgress {
  const HeroProgress({
    required this.level,
    required this.xp,
    required this.kills,
  });

  final int level;
  final int xp;
  final int kills;

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
      return HeroProgress(level: level, xp: xp, kills: kills);
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
  Future<void> save(String heroId, HeroProgress progress) =>
      Future.value(_values[heroId] = progress);
}
