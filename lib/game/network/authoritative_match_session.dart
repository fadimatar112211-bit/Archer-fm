import 'dart:math';

import '../heroes/hero_roster.dart';
import '../match/match_rules.dart';
import 'websocket_game_host.dart';

/// Concrete four-player match session used by [WebSocketGameHost].
///
/// Client commands may choose a valid hero/loadout, start a full lobby, or
/// forfeit. Scores and crystal counts are updated only through trusted
/// server-side methods called by the authoritative combat/castle systems.
class AuthoritativeMatchSession implements GameServerSession {
  AuthoritativeMatchSession({
    required this.code,
    int durationMinutes = 30,
    Random? random,
  })  : duration = MatchDuration.fromMinutes(durationMinutes),
        _random = random ?? Random.secure();

  @override
  final String code;
  final MatchDuration duration;
  final Random _random;
  final List<_MatchPlayer> _players = [];
  MatchRulesEngine? _rules;
  int _nextPlayerNumber = 1;

  @override
  Iterable<GameServerPlayer> get players => List.unmodifiable(_players);

  MatchRulesEngine? get rules => _rules;

  @override
  bool get shouldRemove =>
      _players.isEmpty ||
      (_rules?.phase == MatchPhase.finished &&
          _players.every((player) => !player.connected));

  @override
  GameServerPlayer? join() {
    if (_rules != null || _players.length >= 4) return null;
    final number = _nextPlayerNumber++;
    final player = _MatchPlayer(
      id: 'p$number',
      resumeToken: _token(),
    );
    _players.add(player);
    return player;
  }

  @override
  GameServerPlayer? resume(String resumeToken) {
    for (final player in _players) {
      if (player.resumeToken == resumeToken) {
        player.connected = true;
        return player;
      }
    }
    return null;
  }

  @override
  void disconnect(GameServerPlayer player) {
    final matchPlayer = _find(player.id);
    if (matchPlayer != null) matchPlayer.connected = false;
  }

  @override
  void leave(GameServerPlayer player) {
    final matchPlayer = _find(player.id);
    if (matchPlayer == null) return;
    if (_rules?.phase == MatchPhase.running) {
      _rules!.forfeit(matchPlayer.id);
      matchPlayer.connected = false;
      return;
    }
    _players.remove(matchPlayer);
  }

  @override
  String? handle(GameServerPlayer player, Map<String, dynamic> message) {
    final current = _find(player.id);
    if (current == null || !current.connected) return 'player_unavailable';
    switch (message['type']) {
      case 'select':
        if (_rules != null) return 'match_already_started';
        final heroId = message['heroId'];
        final weaponId = message['weaponId'];
        if (heroId is! String || weaponId is! String) {
          return 'invalid_loadout';
        }
        final hero = archerFmHeroes.where((item) => item.id == heroId);
        if (hero.isEmpty ||
            !hero.single.weapons.any((weapon) => weapon.id == weaponId)) {
          return 'invalid_loadout';
        }
        current.heroId = heroId;
        current.weaponId = weaponId;
        return null;
      case 'start':
        if (_rules != null) return 'match_already_started';
        if (_players.length != 4) return 'need_four_players';
        if (_players.any((item) => item.heroId == null || item.weaponId == null)) {
          return 'all_players_must_select';
        }
        _rules = MatchRulesEngine(
          duration: duration,
          participants: [
            for (final item in _players)
              MatchParticipantSeed(playerId: item.id),
          ],
        )..start();
        return null;
      case 'forfeit':
        final rules = _rules;
        if (rules == null) return 'match_not_started';
        final result = rules.forfeit(current.id);
        return result.accepted ? null : 'forfeit_rejected';
      default:
        // Movement, attacks, damage, purchases and rewards must be routed
        // through the actual authoritative world/combat/economy services.
        return 'unsupported_command';
    }
  }

  /// Called only by trusted server-side combat/scoring code.
  MatchCommandResult awardScore(String playerId, int points) {
    final rules = _rules;
    if (rules == null) {
      return const MatchCommandResult.rejected('المباراة لم تبدأ');
    }
    return rules.addScore(playerId, points);
  }

  /// Called only by trusted server-side castle/crystal authority.
  MatchCommandResult updateLivingCrystals(String playerId, int count) {
    final rules = _rules;
    if (rules == null) {
      return const MatchCommandResult.rejected('المباراة لم تبدأ');
    }
    return rules.setLivingCrystals(playerId, count);
  }

  @override
  void tick(Duration elapsed) {
    final rules = _rules;
    if (rules?.phase == MatchPhase.running) rules!.advance(elapsed);
  }

  @override
  Map<String, Object?> snapshot() {
    final rules = _rules;
    return {
      'type': 'state',
      'roomCode': code,
      'durationMinutes': duration.minutes,
      'phase': rules?.phase.name ?? MatchPhase.waiting.name,
      'elapsedMs': rules?.elapsed.inMilliseconds ?? 0,
      'remainingMs': rules?.remaining.inMilliseconds ??
          duration.duration.inMilliseconds,
      'players': [
        for (final player in _players)
          {
            'id': player.id,
            'connected': player.connected,
            'heroId': player.heroId,
            'weaponId': player.weaponId,
          },
      ],
      if (rules?.result case final result?)
        'result': {
          'reason': result.reason.name,
          'winnerId': result.winnerId,
          'tiedPlayerIds': result.tiedPlayerIds,
          'standings': [
            for (final standing in result.standings)
              {
                'playerId': standing.playerId,
                'score': standing.score,
                'livingCrystals': standing.livingCrystals,
                'rank': standing.rank,
                'hasForfeited': standing.hasForfeited,
              },
          ],
        },
      'participants': [
        if (rules != null)
          for (final participant in rules.participants)
            {
              'playerId': participant.playerId,
              'score': participant.score,
              'livingCrystals': participant.livingCrystals,
              'hasForfeited': participant.hasForfeited,
            },
      ],
    };
  }

  _MatchPlayer? _find(String id) {
    for (final player in _players) {
      if (player.id == id) return player;
    }
    return null;
  }

  String _token() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _MatchPlayer implements GameServerPlayer {
  _MatchPlayer({required this.id, required this.resumeToken});

  @override
  final String id;
  @override
  final String resumeToken;
  @override
  int lastSequence = 0;
  @override
  bool connected = true;
  String? heroId;
  String? weaponId;
}
