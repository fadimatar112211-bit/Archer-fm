import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Minimal contract implemented by the canonical authoritative game session.
/// The gateway owns sockets/rooms only; it must not own combat or world rules.
abstract interface class GameServerPlayer {
  String get id;
  String get resumeToken;
  set resumeToken(String value);
  int get lastSequence;
  set lastSequence(int value);
  bool get connected;
  set connected(bool value);
}

/// Optional per-player state projection for games with fog of war or
/// private player data. The transport calls this once for each recipient.
abstract interface class PlayerScopedSnapshotSession {
  Map<String, Object?> snapshotFor(GameServerPlayer player);
}

abstract interface class GameServerSession {
  String get code;
  Iterable<GameServerPlayer> get players;
  bool get shouldRemove;

  GameServerPlayer? join();
  GameServerPlayer? resume(String resumeToken);
  void disconnect(GameServerPlayer player);
  void leave(GameServerPlayer player);

  /// Apply one already sequence-validated command; return a rejection code.
  String? handle(
    GameServerPlayer player,
    Map<String, dynamic> message,
  );

  void tick(Duration elapsed);
  Map<String, Object?> snapshot();
}

typedef GameServerSessionFactory = GameServerSession Function(
  String roomCode,
  Map<String, dynamic> createMessage,
);

abstract interface class AccountBoundGameServerSession {
  GameServerPlayer? joinForAccount(String accountId);
  bool ownsResumeToken(String resumeToken, String accountId);
}

typedef GameAccessTokenVerifier = Future<String?> Function(String accessToken);

/// WebSocket room gateway adapted from the supplied multiplayer sample.
///
/// It handles room codes, four-player transport sessions, reconnect tokens,
/// sequence deduplication, message/rate limits and state broadcasting. The
/// injected [GameServerSession] remains authoritative for all game rules.
class WebSocketGameHost {
  WebSocketGameHost({
    required this.sessionFactory,
    this.address,
    this.port = 8080,
    this.maxRooms = 200,
    this.maxMessageCharacters = 4096,
    this.rateLimitBurst = 150,
    this.rateLimitRefillPerSecond = 40,
    this.tickInterval = const Duration(milliseconds: 50),
    this.broadcastInterval = const Duration(milliseconds: 100),
    this.accessTokenVerifier,
  })  : assert(port >= 0 && port <= 65535),
        assert(maxRooms > 0),
        assert(maxMessageCharacters > 0),
        assert(rateLimitBurst > 0),
        assert(rateLimitRefillPerSecond > 0),
        assert(tickInterval > Duration.zero),
        assert(broadcastInterval > Duration.zero);

  final GameServerSessionFactory sessionFactory;
  final GameAccessTokenVerifier? accessTokenVerifier;
  final InternetAddress? address;
  final int port;
  final int maxRooms;
  final int maxMessageCharacters;
  final int rateLimitBurst;
  final int rateLimitRefillPerSecond;
  final Duration tickInterval;
  final Duration broadcastInterval;

  /// When set, all handshakes require a verified token and account-bound room.
  /// Keep null only for isolated local development and tests.

  final Map<String, GameServerSession> _rooms = {};
  final Map<String, WebSocket> _sockets = {};
  final Random _random = Random.secure();

  HttpServer? _server;
  Timer? _timer;
  Stopwatch? _clock;
  Duration _lastTick = Duration.zero;
  Duration _broadcastElapsed = Duration.zero;

  int get roomCount => _rooms.length;
  int get connectedPlayerCount => _sockets.length;
  bool get isRunning => _server != null;

  Uri get uri {
    final server = _server;
    if (server == null) throw StateError('WebSocketGameHost is not running.');
    return Uri(
      scheme: 'ws',
      host: server.address.address,
      port: server.port,
    );
  }

  Future<void> start() async {
    if (_server != null) throw StateError('WebSocketGameHost already started.');
    final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    _server = server;
    _clock = Stopwatch()..start();
    _lastTick = Duration.zero;
    _broadcastElapsed = Duration.zero;
    server.listen(_acceptRequest);
    _timer = Timer.periodic(tickInterval, (_) => _tick());
  }

  void _acceptRequest(HttpRequest request) {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      unawaited(request.response.close());
      return;
    }
    WebSocketTransformer.upgrade(request).then(_serve).catchError((Object error) {
      stderr.writeln('WebSocket upgrade failed: $error');
    });
  }

  void _tick() {
    final clock = _clock;
    if (clock == null) return;
    final now = clock.elapsed;
    final delta = now - _lastTick;
    _lastTick = now;

    for (final room in _rooms.values.toList()) {
      room.tick(delta);
    }

    _broadcastElapsed += delta;
    if (_broadcastElapsed >= broadcastInterval) {
      while (_broadcastElapsed >= broadcastInterval) {
        _broadcastElapsed -= broadcastInterval;
      }
      _broadcastSnapshots();
    }

    _rooms.removeWhere((_, room) => room.shouldRemove);
  }

  void _broadcastSnapshots() {
    for (final room in _rooms.values) {
      final players = room.players.toList();
      final sharedSnapshot =
          room is PlayerScopedSnapshotSession ? null : room.snapshot();
      for (final player in players) {
        final socket = _sockets[player.id];
        if (socket == null) continue;
        final snapshot = room is PlayerScopedSnapshotSession
            ? (room as PlayerScopedSnapshotSession).snapshotFor(player)
            : sharedSnapshot!;
        _send(socket, snapshot);
      }
    }
  }

  void _serve(WebSocket socket) {
    socket.pingInterval = const Duration(seconds: 5);
    var tokens = rateLimitBurst.toDouble();
    final refillClock = Stopwatch()..start();
    GameServerSession? room;
    GameServerPlayer? player;
    var handshakePending = false;

    void detach() {
      final currentPlayer = player;
      if (currentPlayer == null ||
          !identical(_sockets[currentPlayer.id], socket)) {
        return;
      }
      _sockets.remove(currentPlayer.id);
      room?.disconnect(currentPlayer);
    }

    socket.listen(
      (raw) {
        final elapsedSeconds = refillClock.elapsedMicroseconds / 1000000;
        tokens = min(
          rateLimitBurst.toDouble(),
          tokens + elapsedSeconds * rateLimitRefillPerSecond,
        );
        refillClock.reset();
        tokens -= 1;
        if (tokens < 0) {
          socket.close(WebSocketStatus.policyViolation, 'rate_limit');
          return;
        }

        if (raw is! String || raw.length > maxMessageCharacters) {
          _send(socket, {'type': 'error', 'reason': 'bad_message'});
          return;
        }

        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) {
            _send(socket, {'type': 'error', 'reason': 'bad_message'});
            return;
          }
          final message = decoded;
          if (player == null) {
            if (handshakePending) return;
            handshakePending = true;
            unawaited(_handshake(socket, message, (session, joined) {
              room = session;
              player = joined;
            }).whenComplete(() => handshakePending = false));
            return;
          }

          final currentPlayer = player!;
          final currentRoom = room!;
          if (!identical(_sockets[currentPlayer.id], socket)) return;

          if (message['type'] == 'leave') {
            _sockets.remove(currentPlayer.id);
            currentRoom.leave(currentPlayer);
            socket.close();
            return;
          }

          final sequence = message['seq'];
          if (sequence is! int || sequence <= currentPlayer.lastSequence) {
            _send(socket, {
              'type': 'ack',
              'seq': sequence,
              'error': 'duplicate',
            });
            return;
          }

          currentPlayer.lastSequence = sequence;
          final error = currentRoom.handle(currentPlayer, message);
          _send(socket, {
            'type': 'ack',
            'seq': sequence,
            'error': error,
          });
        } catch (_) {
          _send(socket, {'type': 'error', 'reason': 'bad_message'});
        }
      },
      onDone: detach,
      onError: (_) => detach(),
      cancelOnError: true,
    );
  }

  Future<void> _handshake(
    WebSocket socket,
    Map<String, dynamic> message,
    void Function(GameServerSession, GameServerPlayer) attach,
  ) async {
    try {
      final verifier = accessTokenVerifier;
      String? accountId;
      if (verifier != null) {
        final accessToken = message['accessToken'];
        if (accessToken is! String) {
          _send(socket, {'type': 'error', 'reason': 'unauthorized'});
          return;
        }
        accountId = await verifier(accessToken);
        if (accountId == null || accountId.isEmpty) {
          _send(socket, {'type': 'error', 'reason': 'unauthorized'});
          return;
        }
      }

      GameServerSession? room;
      GameServerPlayer? player;
      GameServerPlayer? joinRoom(GameServerSession session) {
        if (verifier == null) return session.join();
        if (session is! AccountBoundGameServerSession) return null;
        return session.joinForAccount(accountId!);
      }

      switch (message['type']) {
        case 'create':
          if (_rooms.length >= maxRooms) {
            _send(socket, {'type': 'error', 'reason': 'server_full'});
            return;
          }
          final code = _newRoomCode();
          room = sessionFactory(code, message);
          player = joinRoom(room!);
          if (player == null) {
            _send(socket, {'type': 'error', 'reason': 'account_binding_unavailable'});
            return;
          }
          _rooms[code] = room!;
          break;
        case 'join':
          final code = message['code'];
          if (code is String) room = _rooms[code];
          if (room != null) player = joinRoom(room!);
          break;
        case 'resume':
          final code = message['code'];
          final token = message['token'];
          if (code is String) room = _rooms[code];
          if (room != null && token is String) {
            if (verifier == null) {
              player = room!.resume(token);
            } else if (room is AccountBoundGameServerSession &&
                (room as AccountBoundGameServerSession).ownsResumeToken(token, accountId!)) {
              player = room!.resume(token);
            }
          }
          break;
        default:
          _send(socket, {'type': 'error', 'reason': 'bad_handshake'});
          return;
      }

      if (room == null || player == null) {
        _send(socket, {'type': 'error', 'reason': 'no_session'});
        return;
      }
      if (socket.readyState != WebSocket.open) {
        room!.disconnect(player!);
        return;
      }
      player!.connected = true;
      final oldSocket = _sockets[player!.id];
      _sockets[player!.id] = socket;
      oldSocket?.close();
      attach(room!, player!);
      _send(socket, {
        'type': 'welcome',
        'id': player!.id,
        'token': player!.resumeToken,
        'code': room!.code,
        'lastSeq': player!.lastSequence,
      });
      final initialSnapshot = room is PlayerScopedSnapshotSession
          ? (room as PlayerScopedSnapshotSession).snapshotFor(player!)
          : room!.snapshot();
      _send(socket, initialSnapshot);
    } catch (_) {
      _send(socket, {'type': 'error', 'reason': 'handshake_failed'});
    }
  }

  String _newRoomCode() {
    String code;
    do {
      code = (100000 + _random.nextInt(900000)).toString();
    } while (_rooms.containsKey(code));
    return code;
  }

  void _send(WebSocket socket, Object message) {
    if (socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(message));
    }
  }

  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    final sockets = _sockets.values.toList();
    _sockets.clear();
    for (final socket in sockets) {
      await socket.close();
    }
    final server = _server;
    _server = null;
    await server?.close(force: true);
    _rooms.clear();
    _clock = null;
  }
}
