import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import '../../game/world/arena_map.dart';
import 'authority.dart';
import 'match_models.dart';
import 'protocol.dart';
import 'room_coordinator.dart';

/// Authoritative multiplayer host.
///
/// The same class powers online matches (a deployed process) and hotspot
/// matches (the hosting phone). All gameplay-sensitive values are validated in
/// [MatchAuthority]; clients only send intent and receive snapshots.
class OnlineMatchServer {
  OnlineMatchServer({
    RoomCoordinator? coordinator,
    this.autoTick = true,
    this.tickInterval = const Duration(milliseconds: 200),
    int? seed,
    int Function()? clock,
  })  : coordinator = coordinator ?? RoomCoordinator(),
        seed = seed ?? math.Random().nextInt(0x3fffffff),
        _now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final RoomCoordinator coordinator;
  final bool autoTick;
  final Duration tickInterval;
  final int seed;
  final int Function() _now;

  ServerSocket? _serverSocket;
  Timer? _timer;
  final Map<String, NetTransport> _transports = {};
  final Map<String, String> _roomByPlayer = {};
  MatchAuthority? _authority;
  MatchRoom? _activeRoom;
  int _matchStartedAt = 0;
  int _damageSeq = 0;
  int _connectionCounter = 0;
  String? _matchId;
  MatchResult? _lastResult;

  final List<String> errors = <String>[];

  int get port => _serverSocket?.port ?? 0;
  MatchAuthority? get authority => _authority;
  MatchResult? get lastResult => _lastResult;

  Future<void> start({
    InternetAddress? address,
    int port = 0,
  }) async {
    _serverSocket = await ServerSocket.bind(address ?? InternetAddress.anyIPv4, port);
    _serverSocket!.listen(_onSocket);
  }

  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    await _serverSocket?.close();
    _serverSocket = null;
    for (final transport in _transports.values.toList()) {
      await transport.close();
    }
    _transports.clear();
  }

  void _onSocket(Socket socket) {
    final transport = SocketTransport(socket);
    attach(transport);
  }

  /// Attaches any framed transport. Tests use loopback transports; production
  /// uses [SocketTransport].
  void attach(NetTransport transport) {
    final connectionId = 'p_${++_connectionCounter}';
    transport.messages.listen(
      (message) => handle(connectionId, transport, message),
      onDone: () => disconnect(connectionId),
      onError: (_) => disconnect(connectionId),
    );
  }

  void _send(NetTransport transport, String type, [Map<String, dynamic>? data]) {
    transport.send(envelope(type, payload: data));
  }

  void _broadcastRoom(MatchRoom room) {
    for (final entry in _transports.entries.toList()) {
      if (_roomByPlayer[entry.key] != room.code) continue;
      _send(
        entry.value,
        NetMessage.roomState,
        {'room': room.toJson()},
      );
    }
  }

  void _broadcast(String type, Map<String, dynamic> data) {
    for (final transport in _transports.values.toList()) {
      _send(transport, type, data);
    }
  }

  void handle(String id, NetTransport transport, Map<String, dynamic> message) {
    if (!validEnvelope(message)) {
      errors.add('invalid envelope');
      return;
    }
    if (message['v'] != NetMessage.version) {
      _send(transport, NetMessage.error, {'reason': 'protocol version'});
      return;
    }
    _transports[id] = transport;
    final type = message['type'] as String;
    switch (type) {
      case NetMessage.hello:
        _hello(id, transport, message);
      case NetMessage.createRoom:
        _createRoom(id, transport, message);
      case NetMessage.joinRoom:
        _joinRoom(id, transport, message);
      case NetMessage.queue:
        _queue(id, transport, message);
      case NetMessage.setHero:
        _setHero(id, message);
      case NetMessage.ready:
        _ready(id, message);
      case NetMessage.invite:
        _invite(id, message);
      case NetMessage.removePlayer:
        _removePlayer(id, message);
      case NetMessage.leaveRoom:
        _leaveRoom(id);
      case NetMessage.leaveMatch:
        disconnect(id);
      case NetMessage.matchStart:
        _startMatch(id, transport);
      case NetMessage.input:
        _input(id, message);
      case NetMessage.attack:
        _attack(id, transport, message);
      case NetMessage.crystal:
        _crystal(id, message);
      case NetMessage.pickup:
        _pickup(id, message);
      default:
        errors.add('unknown message $type');
    }
  }

  String _string(Map<String, dynamic> message, String key, [String fallback = '']) {
    final value = message[key];
    return value is String ? value : fallback;
  }

  void _hello(String id, NetTransport transport, Map<String, dynamic> message) {
    final roomCode = _string(message, 'roomCode');
    MatchRoom? room;
    if (roomCode.isNotEmpty) {
      room = coordinator.joinRoom(
        code: roomCode,
        playerId: id,
        username: _string(message, 'username', id),
        heroId: _string(message, 'heroId', 'ranger_new'),
      );
    }
    if (room != null) _roomByPlayer[id] = room.code;
    _send(transport, NetMessage.welcome, {
      'playerId': id,
      'seed': seed,
      'room': room?.toJson(),
    });
    if (room != null) _broadcastRoom(room);
  }

  void _createRoom(String id, NetTransport transport, Map<String, dynamic> message) {
    final room = coordinator.createRoom(
      ownerId: id,
      username: _string(message, 'username', id),
      duration: MatchDuration.fromMinutes(message['duration']) ?? MatchDuration.m10,
      heroId: _string(message, 'heroId', 'ranger_new'),
    );
    _roomByPlayer[id] = room.code;
    _send(transport, NetMessage.welcome, {
      'playerId': id,
      'seed': seed,
      'room': room.toJson(),
    });
    _broadcastRoom(room);
  }

  void _joinRoom(String id, NetTransport transport, Map<String, dynamic> message) {
    final room = coordinator.joinRoom(
      code: _string(message, 'code'),
      playerId: id,
      username: _string(message, 'username', id),
      heroId: _string(message, 'heroId', 'ranger_new'),
    );
    if (room == null) {
      _send(transport, NetMessage.error, {'reason': 'room unavailable'});
      return;
    }
    _roomByPlayer[id] = room.code;
    _send(transport, NetMessage.welcome, {
      'playerId': id,
      'seed': seed,
      'room': room.toJson(),
    });
    _broadcastRoom(room);
  }

  void _queue(String id, NetTransport transport, Map<String, dynamic> message) {
    final room = coordinator.queueForMatch(
      playerId: id,
      username: _string(message, 'username', id),
      heroId: _string(message, 'heroId', 'ranger_new'),
      duration: MatchDuration.fromMinutes(message['duration']) ?? MatchDuration.m10,
    );
    if (room == null) {
      _send(transport, NetMessage.error, {'reason': 'matchmaking failed'});
      return;
    }
    _roomByPlayer[id] = room.code;
    _send(transport, NetMessage.welcome, {
      'playerId': id,
      'seed': seed,
      'room': room.toJson(),
    });
    _broadcastRoom(room);
  }

  void _setHero(String id, Map<String, dynamic> message) {
    final code = _roomByPlayer[id];
    if (code != null) {
      coordinator.setHero(code, id, _string(message, 'heroId'));
      _broadcastRoom(coordinator.room(code)!);
    }
  }

  void _ready(String id, Map<String, dynamic> message) {
    final code = _roomByPlayer[id];
    if (code != null && coordinator.setReady(code, id, message['ready'] == true)) {
      _broadcastRoom(coordinator.room(code)!);
    }
  }

  void _invite(String id, Map<String, dynamic> message) {
    // Invite by username is resolved client-side against the friends list;
    // the room code is the only capability accepted by the authority.
    final code = _roomByPlayer[id];
    if (code != null) {
      coordinator.inviteByUsername(code, _string(message, 'username'));
    }
  }

  void _removePlayer(String id, Map<String, dynamic> message) {
    final code = _roomByPlayer[id];
    final target = _string(message, 'playerId');
    if (code != null && coordinator.removePlayer(code, id, target)) {
      _roomByPlayer.remove(target);
      _broadcastRoom(coordinator.room(code)!);
    }
  }

  void _leaveRoom(String id) {
    final left = coordinator.leaveRoom(id);
    _roomByPlayer.remove(id);
    if (left != null) _broadcastRoom(left);
  }

  void _startMatch(String id, NetTransport transport) {
    final code = _roomByPlayer[id];
    final room = code == null ? null : coordinator.room(code);
    if (room == null || !coordinator.startMatch(code!, id)) {
      _send(transport, NetMessage.error, {'reason': 'cannot start'});
      return;
    }
    _activeRoom = room;
    final mapSize = ArenaMap.generate(math.Random(seed)).size;
    _authority = MatchAuthority(
      players: [
        for (final member in room.players)
          AuthorityPlayer(
            id: member.id,
            username: member.username,
            heroId: member.heroId,
            maxHp: member.maxHp,
            position: Offset(0, 0),
            colorValue: member.colorValue,
          ),
      ],
      mapBounds: Rect.fromLTWH(0, 0, mapSize.width, mapSize.height),
    );
    final spawn = ArenaMap.generate(math.Random(seed)).playerSpawn;
    for (final member in room.players) {
      final player = _authority!.player(member.id);
      if (player != null) {
        player.position = spawn + Offset(
          (player.colorValue % 47).toDouble() - 23,
          (player.colorValue % 31).toDouble() - 15,
        );
      }
    }
    _matchStartedAt = _now();
    _matchId = '${room.code}_$_matchStartedAt';
    _broadcast(NetMessage.matchStart, {
      'seed': seed,
      'duration': room.duration.minutes,
      'matchId': _matchId,
      'players': [
        for (final player in _authority!.snapshot()) player.toJson(),
      ],
    });
    if (autoTick) {
      _timer?.cancel();
      _timer = Timer.periodic(tickInterval, (_) => tick());
    }
  }

  /// Called from the server clock (or directly by tests) to publish the
  /// authoritative snapshot and enforce the confirmed match length.
  void tick() {
    final authority = _authority;
    final room = _activeRoom;
    if (authority == null || room == null) return;
    final elapsed = _now() - _matchStartedAt;
    final limit = room.duration.minutes * 60 * 1000;
    if (elapsed >= limit) {
      _finish(MatchEndReason.timeUp);
      return;
    }
    if (authority.lastStanding()) {
      _finish(MatchEndReason.lastPlayerWithCrystals);
      return;
    }
    _broadcast(NetMessage.snapshot, {
      'elapsedMs': elapsed,
      'players': [for (final player in authority.snapshot()) player.toJson()],
    });
  }

  void _finish(MatchEndReason reason) {
    final authority = _authority;
    if (authority == null || _lastResult != null) return;
    _timer?.cancel();
    _timer = null;
    final result = decideMatch(authority.snapshot(), reason);
    _lastResult = result;
    _broadcast(NetMessage.matchEnd, {'result': result.toJson()});
  }

  void _input(String id, Map<String, dynamic> message) {
    final authority = _authority;
    if (authority == null) return;
    final x = message['x'];
    final y = message['y'];
    final at = message['atMs'];
    if (x is! num || y is! num || at is! int) return;
    authority.move(id, Offset(x.toDouble(), y.toDouble()), at);
  }

  void _attack(
    String id,
    NetTransport transport,
    Map<String, dynamic> message,
  ) {
    final authority = _authority;
    if (authority == null) return;
    final amount = message['amount'];
    final maximum = message['maxDamage'];
    final distance = message['distance'];
    if (amount is! num || maximum is! num) return;
    final targetId = _string(message, 'targetId');
    final accepted = authority.applyDamage(
      attackerId: id,
      targetId: targetId,
      amount: amount.toDouble(),
      maximumDamage: maximum.toDouble(),
      distance: distance is num ? distance.toDouble() : null,
    );
    if (!accepted) return;
    // Only the host confirms damage, and each confirmed hit gets a unique id
    // so a replayed packet can never pay twice.
    _send(transport, NetMessage.damageConfirmed, {
      'attackerId': id,
      'targetId': targetId,
      'amount': amount.toDouble(),
      'damageId': 'dmg_${_damageSeq++}',
    });
  }

  void _crystal(String id, Map<String, dynamic> message) {
    final authority = _authority;
    if (authority == null) return;
    authority.destroyCrystal(id, _string(message, 'ownerId'));
    if (authority.lastStanding()) _finish(MatchEndReason.lastPlayerWithCrystals);
  }

  void _pickup(String id, Map<String, dynamic> message) {
    final authority = _authority;
    if (authority == null) return;
    final x = message['x'];
    final y = message['y'];
    final amount = message['amount'];
    if (x is! num || y is! num || amount is! int) return;
    authority.collectResource(
      id: id,
      pickupPosition: Offset(x.toDouble(), y.toDouble()),
      amount: amount,
    );
  }

  void disconnect(String id) {
    final code = _roomByPlayer.remove(id);
    _transports.remove(id);
    if (_authority != null && _lastResult == null) {
      // Leaving an active match counts as a loss for the leaver.
      final authority = _authority!;
      final leaver = authority.player(id);
      if (leaver != null) leaver.hp = 0;
      _broadcast(NetMessage.playerLeft, {'playerId': id});
      _finish(MatchEndReason.timeUp);
      return;
    }
    if (code == null) return;
    final left = coordinator.leaveRoom(id);
    if (left != null) _broadcastRoom(left);
  }
}
