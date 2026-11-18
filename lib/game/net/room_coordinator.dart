import 'dart:math';

import '../net/match_models.dart';

/// Room state shared by the online matchmaking service and the local hotspot
/// host. Random matchmaking only pairs players who chose the same duration.
class RoomCoordinator {
  RoomCoordinator({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<String, MatchRoom> _rooms = {};
  final Map<String, String> _queueByPlayer = {};

  static const inviteCodeLength = 6;
  static const inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Iterable<MatchRoom> get rooms => _rooms.values;

  MatchRoom? room(String code) => _rooms[code.toUpperCase()];

  String generateCode() {
    while (true) {
      final buffer = StringBuffer();
      for (var i = 0; i < inviteCodeLength; i++) {
        buffer.write(inviteAlphabet[_random.nextInt(inviteAlphabet.length)]);
      }
      final code = buffer.toString();
      if (!_rooms.containsKey(code)) return code;
    }
  }

  MatchRoom createRoom({
    required String ownerId,
    required String username,
    required MatchDuration duration,
    required String heroId,
  }) {
    final room = MatchRoom(
      code: generateCode(),
      ownerId: ownerId,
      duration: duration,
      players: [
        MatchPlayer(
          id: ownerId,
          username: username,
          heroId: heroId,
          colorValue: playerColor(0),
        ),
      ],
    );
    _rooms[room.code] = room;
    return room;
  }

  /// Every player gets a distinct colour (spec: distinct player colours).
  static int playerColor(int index) => const [
        0xFF9BE845,
        0xFF59B6FF,
        0xFFFFB347,
        0xFFE36BE0,
      ][index % 4];

  MatchRoom? joinRoom({
    required String code,
    required String playerId,
    required String username,
    required String heroId,
  }) {
    final target = room(code);
    if (target == null || target.started) return null;
    if (target.player(playerId) != null) return target;
    if (!target.add(
      MatchPlayer(
        id: playerId,
        username: username,
        heroId: heroId,
        colorValue: playerColor(target.players.length),
      ),
    )) {
      return null;
    }
    return target;
  }

  MatchRoom? queueForMatch({
    required String playerId,
    required String username,
    required String heroId,
    required MatchDuration duration,
  }) {
    // A player is never queued twice and cannot be in two rooms at once.
    final previous = _queueByPlayer[playerId];
    if (previous != null) _rooms.remove(previous);
    final waiting = _rooms.values.where(
      (room) => !room.started && room.duration == duration && room.players.length < MatchRoom.maxPlayers,
    );
    for (final room in waiting) {
      if (room.add(
        MatchPlayer(
          id: playerId,
          username: username,
          heroId: heroId,
          colorValue: playerColor(room.players.length),
        ),
      )) {
        _queueByPlayer[playerId] = room.code;
        return room;
      }
    }
    final room = createRoom(
      ownerId: playerId,
      username: username,
      duration: duration,
      heroId: heroId,
    );
    _queueByPlayer[playerId] = room.code;
    return room;
  }

  void setHero(String code, String playerId, String heroId) {
    room(code)?.setHero(playerId, heroId);
  }

  bool setReady(String code, String playerId, bool ready) {
    final target = room(code);
    if (target == null || target.started || target.player(playerId) == null) {
      return false;
    }
    target.setReady(playerId, ready);
    return true;
  }

  /// Invites a friend by username. The friend only appears in the room once
  /// they join with the code, matching "invite by username" without granting
  /// the inviter power to spawn another player's account.
  String? inviteByUsername(String code, String username) {
    final target = room(code);
    if (target == null || target.started) return null;
    return target.code;
  }

  bool removePlayer(String code, String requesterId, String playerId) {
    final target = room(code);
    if (target == null || target.started || target.ownerId != requesterId) {
      return false;
    }
    if (playerId == target.ownerId) return false;
    return target.remove(playerId);
  }

  /// Leaving an open room is penalty-free. Returns the room the player left.
  MatchRoom? leaveRoom(String playerId) {
    final code = _queueByPlayer.remove(playerId);
    MatchRoom? left;
    if (code != null) {
      left = _rooms[code];
      left?.remove(playerId);
    } else {
      for (final candidate in _rooms.values) {
        if (candidate.player(playerId) != null) {
          left = candidate;
          candidate.remove(playerId);
          break;
        }
      }
    }
    if (left != null && left.players.isEmpty) _rooms.remove(left.code);
    if (left != null && left.ownerId == playerId && left.players.isNotEmpty) {
      left.ownerId = left.players.first.id;
    }
    return left;
  }

  bool startMatch(String code, String requesterId) {
    final target = room(code);
    if (target == null ||
        target.started ||
        target.ownerId != requesterId ||
        !target.everyoneReady) {
      return false;
    }
    target.started = true;
    for (var i = 0; i < target.players.length; i++) {
      final member = target.players[i];
      target.players[i] = member.copyWith(
        state: RoomMemberState.playing,
        colorValue: playerColor(i),
        crystals: 7,
      );
    }
    return true;
  }

  void endMatch(String code) => _rooms.remove(code);
}
