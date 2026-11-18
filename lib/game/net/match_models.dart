import 'dart:convert';

/// Confirmed match lengths from PROJECT_STATUS.md §Match and victory.
enum MatchDuration {
  m10(10, '10 دقائق'),
  m20(20, '20 دقيقة'),
  m30(30, '30 دقيقة'),
  m45(45, '45 دقيقة'),
  m60(60, '60 دقيقة');

  const MatchDuration(this.minutes, this.labelAr);

  final int minutes;
  final String labelAr;

  static MatchDuration? fromMinutes(Object? value) {
    if (value is! int) return null;
    for (final duration in values) {
      if (duration.minutes == value) return duration;
    }
    return null;
  }
}

/// Why a match ended. Both values are confirmed by the specification.
enum MatchEndReason { timeUp, lastPlayerWithCrystals }

enum RoomMemberState { waiting, ready, playing, left }

/// One participant in a room or in a live four-player free-for-all.
class MatchPlayer {
  const MatchPlayer({
    required this.id,
    required this.username,
    required this.heroId,
    this.colorValue = 0xFFFFFFFF,
    this.score = 0,
    this.kills = 0,
    this.crystals = 7,
    this.hp = 100,
    this.maxHp = 100,
    this.connected = true,
    this.state = RoomMemberState.waiting,
  });

  final String id;
  final String username;
  final String heroId;
  final int colorValue;
  final int score;
  final int kills;
  final int crystals;
  final double hp;
  final double maxHp;
  final bool connected;
  final RoomMemberState state;

  MatchPlayer copyWith({
    String? id,
    String? username,
    String? heroId,
    int? colorValue,
    int? score,
    int? kills,
    int? crystals,
    double? hp,
    double? maxHp,
    bool? connected,
    RoomMemberState? state,
  }) => MatchPlayer(
        id: id ?? this.id,
        username: username ?? this.username,
        heroId: heroId ?? this.heroId,
        colorValue: colorValue ?? this.colorValue,
        score: score ?? this.score,
        kills: kills ?? this.kills,
        crystals: crystals ?? this.crystals,
        hp: hp ?? this.hp,
        maxHp: maxHp ?? this.maxHp,
        connected: connected ?? this.connected,
        state: state ?? this.state,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'heroId': heroId,
        'colorValue': colorValue,
        'score': score,
        'kills': kills,
        'crystals': crystals,
        'hp': hp,
        'maxHp': maxHp,
        'connected': connected,
        'state': state.name,
      };

  static MatchPlayer? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    final heroId = json['heroId'];
    final color = json['colorValue'];
    final score = json['score'];
    final kills = json['kills'];
    final crystals = json['crystals'];
    final hp = json['hp'];
    final maxHp = json['maxHp'];
    if (id is! String ||
        username is! String ||
        heroId is! String ||
        color is! int ||
        score is! int ||
        kills is! int ||
        crystals is! int ||
        hp is! num ||
        maxHp is! num) {
      return null;
    }
    return MatchPlayer(
      id: id,
      username: username,
      heroId: heroId,
      colorValue: color,
      score: score,
      kills: kills,
      crystals: crystals,
      hp: hp.toDouble(),
      maxHp: maxHp.toDouble(),
      connected: json['connected'] != false,
      state: RoomMemberState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => RoomMemberState.waiting,
      ),
    );
  }
}

/// A private room identified by a short invite code. The host is authoritative
/// for membership while the room is open; the match authority is separate.
class MatchRoom {
  MatchRoom({
    required this.code,
    required this.ownerId,
    required this.duration,
    List<MatchPlayer>? players,
  }) : players = List<MatchPlayer>.of(players ?? <MatchPlayer>[]);

  final String code;
  String ownerId;
  MatchDuration duration;
  final List<MatchPlayer> players;
  bool started = false;

  static const int maxPlayers = 4;

  MatchPlayer? player(String id) {
    for (final member in players) {
      if (member.id == id) return member;
    }
    return null;
  }

  bool add(MatchPlayer member) {
    if (players.length >= maxPlayers || player(member.id) != null) return false;
    players.add(member);
    return true;
  }

  bool remove(String id) {
    final before = players.length;
    players.removeWhere((member) => member.id == id);
    return players.length < before;
  }

  void setHero(String id, String heroId) {
    final index = players.indexWhere((member) => member.id == id);
    if (index < 0) return;
    players[index] = players[index].copyWith(heroId: heroId);
  }

  void setReady(String id, bool ready) {
    final index = players.indexWhere((member) => member.id == id);
    if (index < 0) return;
    players[index] = players[index].copyWith(
      state: ready ? RoomMemberState.ready : RoomMemberState.waiting,
    );
  }

  bool get everyoneReady =>
      players.length == maxPlayers &&
      players.every((member) => member.state == RoomMemberState.ready);

  Map<String, dynamic> toJson() => {
        'code': code,
        'ownerId': ownerId,
        'duration': duration.minutes,
        'started': started,
        'players': [for (final member in players) member.toJson()],
      };

  static MatchRoom? fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final ownerId = json['ownerId'];
    final duration = MatchDuration.fromMinutes(json['duration']);
    final rawPlayers = json['players'];
    if (code is! String || ownerId is! String || duration == null || rawPlayers is! List) {
      return null;
    }
    final players = <MatchPlayer>[];
    for (final raw in rawPlayers) {
      if (raw is! Map<String, dynamic>) return null;
      final player = MatchPlayer.fromJson(raw);
      if (player == null) return null;
      players.add(player);
    }
    final room = MatchRoom(
      code: code,
      ownerId: ownerId,
      duration: duration,
      players: players,
    );
    room.started = json['started'] == true;
    return room;
  }
}

/// Result of a finished match. Winners are a list because the specification
/// settles a score tie by crystals but does not define a second tie-breaker.
class MatchResult {
  const MatchResult({
    required this.reason,
    required this.winnerIds,
    required this.players,
  });

  final MatchEndReason reason;
  final List<String> winnerIds;
  final List<MatchPlayer> players;

  bool winner(String id) => winnerIds.contains(id);

  Map<String, dynamic> toJson() => {
        'reason': reason.name,
        'winners': winnerIds,
        'players': [for (final player in players) player.toJson()],
      };

  static MatchResult? fromJson(Map<String, dynamic> json) {
    final rawWinners = json['winners'];
    final rawPlayers = json['players'];
    final reason = MatchEndReason.values.firstWhere(
      (value) => value.name == json['reason'],
      orElse: () => MatchEndReason.timeUp,
    );
    if (rawWinners is! List || rawPlayers is! List) return null;
    final winners = <String>[];
    final players = <MatchPlayer>[];
    for (final value in rawWinners) {
      if (value is String) winners.add(value);
    }
    for (final value in rawPlayers) {
      if (value is! Map<String, dynamic>) return null;
      final player = MatchPlayer.fromJson(value);
      if (player == null) return null;
      players.add(player);
    }
    return MatchResult(reason: reason, winnerIds: winners, players: players);
  }
}

/// Applies the confirmed victory rules to an authoritative player snapshot.
MatchResult decideMatch(
  List<MatchPlayer> players,
  MatchEndReason reason,
) {
  final snapshot = List<MatchPlayer>.of(players);
  if (reason == MatchEndReason.lastPlayerWithCrystals) {
    final alive = snapshot.where((player) => player.crystals > 0).toList();
    if (alive.length == 1) {
      return MatchResult(
        reason: reason,
        winnerIds: [alive.first.id],
        players: snapshot,
      );
    }
  }
  var bestScore = 0;
  for (final player in snapshot) {
    if (player.score > bestScore) bestScore = player.score;
  }
  var candidates = snapshot.where((player) => player.score == bestScore).toList();
  var bestCrystals = 0;
  for (final player in candidates) {
    if (player.crystals > bestCrystals) bestCrystals = player.crystals;
  }
  candidates = candidates.where((player) => player.crystals == bestCrystals).toList();
  return MatchResult(
    reason: reason,
    winnerIds: [for (final player in candidates) player.id],
    players: snapshot,
  );
}

String encodeLine(Map<String, dynamic> message) => jsonEncode(message);

Map<String, dynamic>? decodeLine(String line) {
  try {
    final decoded = jsonDecode(line);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    // Malformed or truncated input is ignored by the transport layer.
  }
  return null;
}
