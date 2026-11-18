/// Unified experience curves and the persisted XP state used by every part of
/// Archer FM.
///
/// The hero curve is fixed by the project specification:
///
///     XP Required = 100 + 25 × (L - 1) + 3 × (L - 1)²
///
/// The monster curve is deliberately gentler because monsters are support
/// units: `60 + 14 × (L - 1) + (L - 1)²`. Both curves use this file as their
/// single source of truth; no other file may duplicate the arithmetic.
library;

const int heroMaxLevel = 40;
const int monsterXpMaxLevel = 40;

/// XP needed to advance from [level] to [level] + 1.
///
/// Levels outside 1..40 are clamped so a corrupted save can never produce a
/// negative or impossible requirement.
int heroXpRequired(int level) {
  final l = level.clamp(1, heroMaxLevel);
  final step = l - 1;
  return 100 + 25 * step + 3 * step * step;
}

/// Monster curve (support units, therefore lower than the hero curve).
int monsterXpRequired(int level) {
  final l = level.clamp(1, monsterXpMaxLevel);
  final step = l - 1;
  return 60 + 14 * step + step * step;
}

/// Cumulative XP required to reach [level] from level 1.
int heroTotalXpToLevel(int level) {
  var total = 0;
  for (var l = 1; l < level.clamp(1, heroMaxLevel); l++) {
    total += heroXpRequired(l);
  }
  return total;
}

int monsterTotalXpToLevel(int level) {
  var total = 0;
  for (var l = 1; l < level.clamp(1, monsterXpMaxLevel); l++) {
    total += monsterXpRequired(l);
  }
  return total;
}

/// Immutable hero XP state. `xp` is progress inside the current level, while
/// `totalXp` keeps the full history even after a level-up.
class HeroXpState {
  const HeroXpState({
    required this.level,
    required this.xp,
    required this.totalXp,
  });

  factory HeroXpState.fromTotal(int totalXp) {
    var total = totalXp < 0 ? 0 : totalXp;
    var level = 1;
    while (level < heroMaxLevel && total >= heroXpRequired(level)) {
      total -= heroXpRequired(level);
      level++;
    }
    if (level >= heroMaxLevel) {
      // At the cap the remainder is kept as history, not as level progress.
      return HeroXpState(
        level: heroMaxLevel,
        xp: 0,
        totalXp: totalXp < 0 ? 0 : totalXp,
      );
    }
    return HeroXpState(level: level, xp: total, totalXp: totalXp < 0 ? 0 : totalXp);
  }

  factory HeroXpState.fromLegacy(int level, int xp) {
    final safeLevel = level.clamp(1, heroMaxLevel);
    return HeroXpState.fromTotal(heroTotalXpToLevel(safeLevel) + (xp < 0 ? 0 : xp));
  }

  final int level;
  final int xp;
  final int totalXp;

  bool get isMax => level >= heroMaxLevel;

  int get required => isMax ? 0 : heroXpRequired(level);

  int get remaining => isMax ? 0 : (required - xp).clamp(0, required);

  double get progress => isMax || required <= 0 ? 1.0 : (xp / required).clamp(0.0, 1.0);

  /// Returns the state after [amount] XP. A capped hero gains nothing further.
  HeroXpState apply(int amount) {
    if (amount <= 0 || isMax) return this;
    return HeroXpState.fromTotal(totalXp + amount);
  }

  /// Number of levels crossed when [amount] is applied.
  int levelsGainedFrom(int amount) {
    if (amount <= 0 || isMax) return 0;
    return apply(amount).level - level;
  }
}

/// Independent XP state for one monster type.
class MonsterXpState {
  const MonsterXpState(this.xp);

  factory MonsterXpState.fromMap(Map<String, int> values, String key) =>
      MonsterXpState(values[key] ?? 0);

  final int xp;

  int get level {
    var total = xp < 0 ? 0 : xp;
    var level = 1;
    while (level < monsterXpMaxLevel && total >= monsterXpRequired(level)) {
      total -= monsterXpRequired(level);
      level++;
    }
    return level;
  }

  bool get isMax => level >= monsterXpMaxLevel;

  int get currentXp {
    var total = xp < 0 ? 0 : xp;
    for (var l = 1; l < level; l++) {
      total -= monsterXpRequired(l);
    }
    return isMax ? 0 : total;
  }

  int get required => isMax ? 0 : monsterXpRequired(level);

  int get remaining => isMax ? 0 : (required - currentXp).clamp(0, required);

  double get progress =>
      isMax || required <= 0 ? 1.0 : (currentXp / required).clamp(0.0, 1.0);

  MonsterXpState apply(int amount) {
    if (amount <= 0 || isMax) return this;
    return MonsterXpState(xp + amount);
  }
}

/// One persisted XP gain, stored so the UI can show the last match breakdown
/// and so a future cloud backend can reconcile the same record.
class XpGainRecord {
  const XpGainRecord({
    required this.matchId,
    required this.heroId,
    required this.heroXp,
    required this.monsterXp,
    required this.sources,
    required this.createdAtMs,
  });

  final String matchId;
  final String heroId;
  final int heroXp;
  final Map<String, int> monsterXp;
  final Map<String, int> sources;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'heroId': heroId,
        'heroXp': heroXp,
        'monsterXp': monsterXp,
        'sources': sources,
        'createdAtMs': createdAtMs,
      };

  factory XpGainRecord.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return const XpGainRecord(
        matchId: '',
        heroId: '',
        heroXp: 0,
        monsterXp: {},
        sources: {},
        createdAtMs: 0,
      );
    }
    final monster = <String, int>{};
    final rawMonster = raw['monsterXp'];
    if (rawMonster is Map) {
      for (final entry in rawMonster.entries) {
        if (entry.key is String && entry.value is int) {
          monster[entry.key as String] = entry.value as int;
        }
      }
    }
    final sources = <String, int>{};
    final rawSources = raw['sources'];
    if (rawSources is Map) {
      for (final entry in rawSources.entries) {
        if (entry.key is String && entry.value is int) {
          sources[entry.key as String] = entry.value as int;
        }
      }
    }
    return XpGainRecord(
      matchId: raw['matchId'] is String ? raw['matchId'] as String : '',
      heroId: raw['heroId'] is String ? raw['heroId'] as String : '',
      heroXp: raw['heroXp'] is int ? raw['heroXp'] as int : 0,
      monsterXp: monster,
      sources: sources,
      createdAtMs: raw['createdAtMs'] is int ? raw['createdAtMs'] as int : 0,
    );
  }
}

/// Confirmed reward table. The UI and the ledger both read these constants so
/// a reward can never drift between text and behaviour.
abstract final class HeroXpRewards {
  static const int participation = 150;
  static const int reducedParticipation = 75;
  static const int win = 100;
  static const int crystal = 30;
  static const int castle = 100;
  static const int neutralMine = 40;
  static const int mineCollection = 5;
  static const int monsterKill = 5;

  /// One XP for every 2 points of authority-confirmed hero damage.
  static const double heroDamagePerXp = 2.0;
  static const int heroDamageMax = 100;

  /// Total performance rewards (everything except participation) are capped so
  /// repeated objectives cannot farm unlimited XP.
  static const int performanceCap = 500;
}

abstract final class MonsterXpRewards {
  /// One XP for every 3 points of real damage dealt by a monster type.
  static const double damagePerXp = 3.0;
  static const int perUnitCap = 12;
  static const int kill = 6;
  static const int perTypePerMatchCap = 80;
}

/// Arabic labels for every XP source, used by the in-game HUD and the summary.
abstract final class XpSourceLabels {
  static const Map<String, String> hero = {
    'participation': 'مشاركة فعلية',
    'win': 'فوز بالمباراة',
    'crystal': 'تدمير كريستال خصم',
    'castle': 'تدمير قلعة خصم',
    'neutralMine': 'سيطرة على منجم محايد',
    'mineCollection': 'جمع موارد المنجم',
    'monsterKill': 'قتل وحش خصم',
    'heroDamage': 'ضرر على أبطال الخصوم',
  };

  static const Map<String, String> monster = {
    'damage': 'ضرر قتالي حقيقي',
    'kill': 'قتل وحش خصم',
    'objective': 'مساهمة في تدمير كريستال',
  };
}
