/// Authoritative four-player free-for-all match rules.
///
/// This domain layer deliberately does not own map, castle, crystal, hero,
/// monster, networking, or persistence objects. The match host feeds it
/// authoritative score/crystal updates from those existing systems.
enum MatchPhase { waiting, running, finished }

enum MatchFinishReason {
  lastCrystalHolder,
  timeExpired,
  lastPlayerRemaining,
}

class MatchDuration {
  const MatchDuration._(this.minutes);

  final int minutes;

  Duration get duration => Duration(minutes: minutes);

  static const ten = MatchDuration._(10);
  static const twenty = MatchDuration._(20);
  static const thirty = MatchDuration._(30);
  static const fortyFive = MatchDuration._(45);
  static const sixty = MatchDuration._(60);

  static const List<MatchDuration> choices = [
    ten,
    twenty,
    thirty,
    fortyFive,
    sixty,
  ];

  factory MatchDuration.fromMinutes(int minutes) {
    return choices.firstWhere(
      (choice) => choice.minutes == minutes,
      orElse: () => throw ArgumentError.value(
        minutes,
        'minutes',
        'Allowed durations are 10, 20, 30, 45, and 60.',
      ),
    );
  }
}

class MatchParticipantSeed {
  const MatchParticipantSeed({required this.playerId});

  final String playerId;
}

class MatchParticipantSnapshot {
  const MatchParticipantSnapshot({
    required this.playerId,
    required this.score,
    required this.livingCrystals,
    required this.hasForfeited,
  });

  final String playerId;
  final int score;
  final int livingCrystals;
  final bool hasForfeited;
}

class MatchStanding {
  const MatchStanding({
    required this.playerId,
    required this.score,
    required this.livingCrystals,
    required this.hasForfeited,
    required this.rank,
  });

  final String playerId;
  final int score;
  final int livingCrystals;
  final bool hasForfeited;
  final int rank;
}

class MatchResult {
  const MatchResult({
    required this.reason,
    required this.winnerId,
    required this.tiedPlayerIds,
    required this.standings,
  });

  final MatchFinishReason reason;

  /// Null when the final result is a tie that the confirmed rules do not break.
  final String? winnerId;

  /// Players tied after applying the confirmed score/crystal ordering.
  final List<String> tiedPlayerIds;

  final List<MatchStanding> standings;
}

/// Result of a match command. Rejected commands do not mutate match state.
class MatchCommandResult {
  const MatchCommandResult.accepted() : accepted = true, message = null;
  const MatchCommandResult.rejected(this.message) : accepted = false;

  final bool accepted;
  final String? message;
}

/// Four-player free-for-all match clock, scoring, forfeits and victory rules.
///
/// Scoring values are supplied by the existing gameplay systems. This class
/// never invents points for kills, crystals, mines, or other events.
class MatchRulesEngine {
  MatchRulesEngine({
    required MatchDuration duration,
    required List<MatchParticipantSeed> participants,
    int startingCrystalsPerPlayer = 7,
  })  : duration = duration,
        startingCrystalsPerPlayer = startingCrystalsPerPlayer {
    if (startingCrystalsPerPlayer < 0 || startingCrystalsPerPlayer > 7) {
      throw RangeError.range(
        startingCrystalsPerPlayer,
        0,
        7,
        'startingCrystalsPerPlayer',
      );
    }
    if (participants.length != 4) {
      throw ArgumentError.value(
        participants.length,
        'participants',
        'A match requires exactly four players.',
      );
    }
    final ids = participants.map((item) => item.playerId).toList();
    if (ids.any((id) => id.trim().isEmpty) || ids.toSet().length != 4) {
      throw ArgumentError('Player IDs must be non-empty and unique.');
    }
    _players = {
      for (final participant in participants)
        participant.playerId: _MutableParticipant(
          playerId: participant.playerId,
          livingCrystals: startingCrystalsPerPlayer,
        ),
    };
  }

  final MatchDuration duration;
  final int startingCrystalsPerPlayer;
  late final Map<String, _MutableParticipant> _players;

  MatchPhase phase = MatchPhase.waiting;
  Duration elapsed = Duration.zero;
  MatchResult? result;

  Duration get remaining {
    final value = duration.duration - elapsed;
    return value.isNegative ? Duration.zero : value;
  }

  List<MatchParticipantSnapshot> get participants => List.unmodifiable([
        for (final player in _players.values)
          MatchParticipantSnapshot(
            playerId: player.playerId,
            score: player.score,
            livingCrystals: player.livingCrystals,
            hasForfeited: player.hasForfeited,
          ),
      ]);

  /// True when every non-forfeited player has zero crystals.
  ///
  /// The product rules do not yet define an immediate outcome for this case.
  /// The host can surface this state for a future approved rule; this engine
  /// intentionally does not invent one.
  bool get allRemainingPlayersHaveNoCrystals =>
      _players.values
          .where((player) => !player.hasForfeited)
          .every((player) => player.livingCrystals == 0);

  MatchCommandResult start() {
    if (phase != MatchPhase.waiting) {
      return const MatchCommandResult.rejected('المباراة بدأت مسبقاً');
    }
    phase = MatchPhase.running;
    return const MatchCommandResult.accepted();
  }

  /// Advances the authoritative match clock. Negative time is rejected.
  MatchCommandResult advance(Duration delta) {
    if (phase != MatchPhase.running) {
      return const MatchCommandResult.rejected('المباراة ليست قيد التشغيل');
    }
    if (delta.isNegative) {
      return const MatchCommandResult.rejected('لا يمكن تقديم وقت سالب');
    }
    elapsed += delta;
    if (elapsed >= duration.duration) {
      elapsed = duration.duration;
      _finishByTime();
    }
    return const MatchCommandResult.accepted();
  }

  /// Applies points already calculated by the authoritative gameplay system.
  MatchCommandResult addScore(String playerId, int points) {
    if (phase != MatchPhase.running) {
      return const MatchCommandResult.rejected('المباراة ليست قيد التشغيل');
    }
    final player = _players[playerId];
    if (player == null) {
      return const MatchCommandResult.rejected('لاعب غير معروف');
    }
    if (player.hasForfeited) {
      return const MatchCommandResult.rejected('اللاعب انسحب من المباراة');
    }
    if (points < 0) {
      return const MatchCommandResult.rejected('النقاط لا يمكن أن تكون سالبة');
    }
    player.score += points;
    return const MatchCommandResult.accepted();
  }

  /// Replaces the player's current crystal count from the castle authority.
  MatchCommandResult setLivingCrystals(String playerId, int count) {
    if (phase != MatchPhase.running) {
      return const MatchCommandResult.rejected('المباراة ليست قيد التشغيل');
    }
    final player = _players[playerId];
    if (player == null) {
      return const MatchCommandResult.rejected('لاعب غير معروف');
    }
    if (player.hasForfeited) {
      return const MatchCommandResult.rejected('اللاعب انسحب من المباراة');
    }
    if (count < 0 || count > 7) {
      return const MatchCommandResult.rejected('عدد البلورات غير صالح');
    }
    player.livingCrystals = count;
    _finishIfOneCrystalHolderRemains();
    return const MatchCommandResult.accepted();
  }

  /// Leaving an active match is a permanent loss for this participant.
  MatchCommandResult forfeit(String playerId) {
    if (phase != MatchPhase.running) {
      return const MatchCommandResult.rejected('لا يمكن الانسحاب الآن');
    }
    final player = _players[playerId];
    if (player == null) {
      return const MatchCommandResult.rejected('لاعب غير معروف');
    }
    if (player.hasForfeited) {
      return const MatchCommandResult.rejected('اللاعب انسحب مسبقاً');
    }
    player.hasForfeited = true;
    _finishIfOneNonForfeitedPlayerRemains();
    if (phase != MatchPhase.finished) {
      _finishIfOneCrystalHolderRemains();
    }
    return const MatchCommandResult.accepted();
  }

  void _finishIfOneCrystalHolderRemains() {
    final holders = _players.values
        .where((player) => !player.hasForfeited && player.livingCrystals > 0)
        .toList();
    if (holders.length == 1) {
      _finish(
        MatchFinishReason.lastCrystalHolder,
        winnerId: holders.single.playerId,
      );
    }
  }

  void _finishIfOneNonForfeitedPlayerRemains() {
    final remaining = _players.values
        .where((player) => !player.hasForfeited)
        .toList();
    if (remaining.length == 1) {
      _finish(
        MatchFinishReason.lastPlayerRemaining,
        winnerId: remaining.single.playerId,
      );
    } else if (remaining.isEmpty) {
      _finish(MatchFinishReason.lastPlayerRemaining);
    }
  }

  void _finishByTime() {
    final eligible = _players.values
        .where((player) => !player.hasForfeited)
        .toList()
      ..sort((a, b) {
        final scoreOrder = b.score.compareTo(a.score);
        return scoreOrder != 0
            ? scoreOrder
            : b.livingCrystals.compareTo(a.livingCrystals);
      });

    if (eligible.isEmpty) {
      _finish(MatchFinishReason.timeExpired);
      return;
    }

    final top = eligible.first;
    final tied = eligible
        .where((player) =>
            player.score == top.score &&
            player.livingCrystals == top.livingCrystals)
        .map((player) => player.playerId)
        .toList();

    _finish(
      MatchFinishReason.timeExpired,
      winnerId: tied.length == 1 ? top.playerId : null,
      tiedPlayerIds: tied.length > 1 ? tied : const [],
    );
  }

  void _finish(
    MatchFinishReason reason, {
    String? winnerId,
    List<String> tiedPlayerIds = const [],
  }) {
    if (phase == MatchPhase.finished) return;
    final sorted = _players.values.toList()
      ..sort((a, b) {
        if (a.hasForfeited != b.hasForfeited) {
          return a.hasForfeited ? 1 : -1;
        }
        final scoreOrder = b.score.compareTo(a.score);
        if (scoreOrder != 0) return scoreOrder;
        return b.livingCrystals.compareTo(a.livingCrystals);
      });

    final standings = <MatchStanding>[];
    var rank = 0;
    _MutableParticipant? previous;
    for (var i = 0; i < sorted.length; i++) {
      final player = sorted[i];
      final sameAsPrevious = previous != null &&
          previous.score == player.score &&
          previous.livingCrystals == player.livingCrystals &&
          previous.hasForfeited == player.hasForfeited;
      if (!sameAsPrevious) rank = i + 1;
      standings.add(
        MatchStanding(
          playerId: player.playerId,
          score: player.score,
          livingCrystals: player.livingCrystals,
          hasForfeited: player.hasForfeited,
          rank: rank,
        ),
      );
      previous = player;
    }

    result = MatchResult(
      reason: reason,
      winnerId: winnerId,
      tiedPlayerIds: List.unmodifiable(tiedPlayerIds),
      standings: List.unmodifiable(standings),
    );
    phase = MatchPhase.finished;
  }
}

class _MutableParticipant {
  _MutableParticipant({
    required this.playerId,
    required this.livingCrystals,
  });

  final String playerId;
  int score = 0;
  int livingCrystals;
  bool hasForfeited = false;
}
