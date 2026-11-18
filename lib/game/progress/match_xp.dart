/// Event-based XP accounting for one match.
///
/// Only the authoritative game systems call the `record*` methods. Every
/// reward has a deduplication key, performance rewards share a global cap and
/// participation is granted only for real activity at settlement. The ledger
/// is deliberately independent of Flutter so it is fully unit-testable.
library;

import '../monsters/monster_models.dart';
import 'xp.dart';

/// Immutable result of one finalized match.
class XpAward {
  const XpAward({
    required this.matchId,
    required this.heroXp,
    required this.sources,
    required this.monsterXp,
    required this.monsterSources,
    required this.heroDamage,
    required this.activities,
    required this.won,
    required this.earlyLeave,
  });

  final String matchId;
  final int heroXp;
  final Map<String, int> sources;
  final Map<MonsterType, int> monsterXp;
  final Map<MonsterType, Map<String, int>> monsterSources;
  final double heroDamage;
  final int activities;
  final bool won;
  final bool earlyLeave;

  int get totalMonsterXp => monsterXp.values.fold(0, (sum, value) => sum + value);

  int source(String key) => sources[key] ?? 0;

  XpGainRecord toRecord({required String heroId}) =>
      XpGainRecord(
        matchId: matchId,
        heroId: heroId,
        heroXp: heroXp,
        monsterXp: {
          for (final entry in monsterXp.entries) entry.key.name: entry.value,
        },
        sources: Map<String, int>.of(sources),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
}

/// Mutable outcome shared between the network screen and the match screen.
class MatchXpOutcome {
  bool won = false;
  bool earlyLeave = false;
  bool decided = false;

  void setResult({required bool won}) {
    this.won = won;
    decided = true;
  }

  void setEarlyLeave() {
    earlyLeave = true;
    decided = true;
  }
}

/// Owns the ledger and the final award for one match instance.
class MatchXpSession {
  MatchXpSession({required this.matchId, required this.heroId})
      : ledger = MatchXpLedger(matchId: matchId, heroId: heroId);

  final String matchId;
  final String heroId;
  final MatchXpLedger ledger;
  final MatchXpOutcome outcome = MatchXpOutcome();

  XpAward? _award;

  XpAward? get award => _award;

  bool get isFinalized => _award != null;

  XpAward finalize() {
    final existing = _award;
    if (existing != null) return existing;
    _award = ledger.finalize(
      won: outcome.won,
      earlyLeave: outcome.earlyLeave,
    );
    return _award!;
  }
}

/// Pure accounting ledger. Rewards are recorded as confirmed game events and
/// finalized exactly once.
class MatchXpLedger {
  MatchXpLedger({required this.matchId, required this.heroId});

  final String matchId;
  final String heroId;

  /// Optional hook so the live world HUD can refresh when an external authority
  /// (the network host) records confirmed damage.
  void Function()? onChange;

  final Set<String> _claimed = <String>{};
  final Map<String, int> _sources = <String, int>{};
  final Map<MonsterType, int> _monsterXp = {
    for (final type in MonsterType.values) type: 0,
  };
  final Map<MonsterType, Map<String, int>> _monsterSources = {
    for (final type in MonsterType.values) type: <String, int>{},
  };

  int _performance = 0;
  int _activities = 0;
  double _heroDamage = 0;
  int _heroDamageXp = 0;
  XpAward? _finalized;

  /// XP credited by real events so far (participation and the win bonus are
  /// only added at finalization). Used by the live hero HUD.
  int get currentHeroXp =>
      _sources.values.fold<int>(0, (sum, value) => sum + value);

  int get activityCount => _activities;

  /// True once the same event key has already been credited.
  bool _claim(String key) => !_claimed.add(key);

  /// Records a real player action. Three distinct actions are required for the
  /// full participation reward; one or two give the reduced reward; simply
  /// staying in the match gives nothing.
  void markActivity() {
    if (_activities < 1000) _activities++;
  }

  int _addCapped(String key, int amount, {bool once = true}) {
    if (amount <= 0) return 0;
    if (once && _claim(key)) return 0;
    final room = HeroXpRewards.performanceCap - _performance;
    if (room <= 0) return 0;
    final credited = amount > room ? room : amount;
    _performance += credited;
    _sources[key] = (_sources[key] ?? 0) + credited;
    return credited;
  }

  void _addMonster(MonsterType type, String source, int amount) {
    if (amount <= 0) return;
    final room = MonsterXpRewards.perTypePerMatchCap - (_monsterXp[type] ?? 0);
    if (room <= 0) return;
    final credited = amount > room ? room : amount;
    _monsterXp[type] = (_monsterXp[type] ?? 0) + credited;
    final perSource = _monsterSources[type]!;
    perSource[source] = (perSource[source] ?? 0) + credited;
  }

  /// A hostile monster was killed by the local hero's real attack.
  void recordEnemyKill(String enemyId) {
    markActivity();
    _addCapped('monsterKill_$enemyId', HeroXpRewards.monsterKill);
  }

  /// One rival crystal was destroyed. The same crystal can never pay twice.
  void recordCrystal(String ownerId, int slot) {
    markActivity();
    _addCapped('crystal_${ownerId}_$slot', HeroXpRewards.crystal);
  }

  /// A rival castle lost all seven crystals. Once per rival per match.
  void recordCastle(String ownerId) {
    markActivity();
    _addCapped('castle_$ownerId', HeroXpRewards.castle);
  }

  /// Only a neutral mine capture pays; taking an enemy mine is real activity
  /// but has no separate XP entry in the confirmed reward table.
  void recordMineCapture(String mineKey, {required bool neutral}) {
    markActivity();
    if (!neutral) return;
    _addCapped('mine_$mineKey', HeroXpRewards.neutralMine);
  }

  /// One actual resource pickup was touched by the hero.
  void recordMineCollection(String pickupId) {
    markActivity();
    _addCapped('pickup_$pickupId', HeroXpRewards.mineCollection);
  }

  /// Authority-confirmed damage to a rival hero, scaled 1 XP / 2 damage and
  /// capped at 100 XP for the match. Fake client damage never reaches here.
  void recordHeroDamage({
    required String damageId,
    required String targetId,
    required double amount,
  }) {
    if (amount <= 0) return;
    if (_claim('heroDamage_$damageId')) return;
    markActivity();
    _heroDamage += amount;
    final earned = (_heroDamage / HeroXpRewards.heroDamagePerXp).floor().clamp(
          0,
          HeroXpRewards.heroDamageMax,
        );
    final delta = earned - _heroDamageXp;
    _heroDamageXp = earned;
    if (delta > 0) {
      _addCapped('heroDamage', delta, once: false);
      onChange?.call();
    }
    // Keep the target id referenced in the claim so duplicate reports for the
    // same target at a different id are still deduplicated by the server id.
    assert(targetId.isNotEmpty);
  }

  /// Real damage dealt by one of the player's monsters to a hostile unit.
  /// [`unitId`] is unique for a spawned unit, so re-summoning cannot multiply
  /// the same kill. Damage is also capped per unit and per monster type.
  void recordMonsterDamage({
    required MonsterType type,
    required String unitId,
    required double amount,
  }) {
    if (amount <= 0) return;
    final key = 'monsterDamage_${type.name}_$unitId';
    if (_claim(key)) return;
    final cappedDamage = amount > 60 ? 60.0 : amount;
    final earned = (cappedDamage / MonsterXpRewards.damagePerXp).floor().clamp(
          0,
          MonsterXpRewards.perUnitCap,
        );
    if (earned > 0) {
      _addMonster(type, XpSourceLabels.monster['damage']!, earned);
      markActivity();
    }
  }

  /// A hostile unit killed by a specific monster type.
  void recordMonsterKill({
    required MonsterType type,
    required String unitId,
  }) {
    if (_claim('monsterKill_${type.name}_$unitId')) return;
    _addMonster(type, XpSourceLabels.monster['kill']!, MonsterXpRewards.kill);
    markActivity();
  }

  /// A rival crystal damaged by a monster type counts as real contribution.
  void recordMonsterObjective({
    required MonsterType type,
    required String crystalId,
    required double amount,
  }) {
    if (amount <= 0) return;
    final key = 'monsterObjective_${type.name}_$crystalId';
    if (_claim(key)) return;
    final earned = (amount / MonsterXpRewards.damagePerXp).floor().clamp(
          0,
          MonsterXpRewards.perUnitCap,
        );
    if (earned > 0) {
      _addMonster(type, XpSourceLabels.monster['objective']!, earned);
      markActivity();
    }
  }

  /// Finalizes the match. Calling twice returns the identical award.
  XpAward finalize({required bool won, required bool earlyLeave}) {
    final existing = _finalized;
    if (existing != null) return existing;

    if (!earlyLeave) {
      if (_activities >= 3) {
        _sources['participation'] = HeroXpRewards.participation;
      } else if (_activities > 0) {
        _sources['participation'] = HeroXpRewards.reducedParticipation;
      }
      if (won) _addCapped('win', HeroXpRewards.win);
    }

    final heroXp = _sources.values.fold<int>(0, (sum, value) => sum + value);
    _finalized = XpAward(
      matchId: matchId,
      heroXp: heroXp,
      sources: Map<String, int>.unmodifiable(_sources),
      monsterXp: Map<MonsterType, int>.unmodifiable(_monsterXp),
      monsterSources: Map<MonsterType, Map<String, int>>.unmodifiable(
        {
          for (final entry in _monsterSources.entries)
            entry.key: Map<String, int>.unmodifiable(entry.value),
        },
      ),
      heroDamage: _heroDamage,
      activities: _activities,
      won: won && !earlyLeave,
      earlyLeave: earlyLeave,
    );
    onChange?.call();
    return _finalized!;
  }
}
