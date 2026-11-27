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

abstract interface class AccountBoundGameServerSession implements GameServerSession {
  GameServerPlayer? joinForAccount(String accountId);
  bool ownsResumeToken(String resumeToken, String accountId);
}

/// Optional server-side account hydration hook. The host calls this only after
/// Supabase has verified the access token and before sending the welcome state.
abstract interface class AccountProvisioningGameServerSession {
  Future<void> prepareAccount(GameServerPlayer player, String accountId);
}

typedef GameAccessTokenVerifier = Future<String?> Function(String accessToken);

typedef AccountProgressionPurchaseHandler = Future<Map<String, dynamic>> Function({
  required String trustedAccountId,
  required String purchaseType,
  required String targetId,
  required String idempotencyKey,
});

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
    this.progressionPurchaseHandler,
    this.authenticationRecheckInterval = const Duration(minutes: 1),
  })  : assert(port >= 0 && port <= 65535),
        assert(maxRooms > 0),
        assert(maxMessageCharacters > 0),
        assert(rateLimitBurst > 0),
        assert(rateLimitRefillPerSecond > 0),
        assert(tickInterval > Duration.zero),
        assert(broadcastInterval > Duration.zero),
        assert(authenticationRecheckInterval > Duration.zero);

  final GameServerSessionFactory sessionFactory;
  /// When set, all handshakes require a verified token and account-bound room.
  /// Keep null only for isolated local development and tests.
  final GameAccessTokenVerifier? accessTokenVerifier;
  /// Invoked only after the HTTP bearer token has been verified. The callback
  /// receives no client-supplied account ID, price, level cap or row revision.
  final AccountProgressionPurchaseHandler? progressionPurchaseHandler;
  /// Revalidates active bearer sessions so expired/revoked tokens cannot keep
  /// issuing commands indefinitely after a successful WebSocket handshake.
  final Duration authenticationRecheckInterval;
  final InternetAddress? address;
  final int port;
  final int maxRooms;
  final int maxMessageCharacters;
  final int rateLimitBurst;
  final int rateLimitRefillPerSecond;
  final Duration tickInterval;
  final Duration broadcastInterval;

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
    if (request.uri.path == '/v1/account/progression/purchase') {
      unawaited(_handleProgressionPurchaseRequest(request));
      return;
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      unawaited(request.response.close());
      return;
    }
    WebSocketTransformer.upgrade(request).then(_serve).catchError((Object error) {
      stderr.writeln('WebSocket upgrade failed: $error');
    });
  }

  Future<void> _handleProgressionPurchaseRequest(HttpRequest request) async {
    final handler = progressionPurchaseHandler;
    final verifier = accessTokenVerifier;
    if (request.method != 'POST') {
      await _writeJson(request.response, HttpStatus.methodNotAllowed,
          {'error': 'method_not_allowed'});
      return;
    }
    if (handler == null || verifier == null) {
      await _writeJson(request.response, HttpStatus.serviceUnavailable,
          {'error': 'purchase_service_unavailable'});
      return;
    }
    final authorization = request.headers.value(HttpHeaders.authorizationHeader);
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      await _writeJson(request.response, HttpStatus.unauthorized,
          {'error': 'unauthorized'});
      return;
    }
    try {
      final raw = await utf8.decoder.bind(request).join();
      if (raw.length > 4096) {
        await _writeJson(request.response, HttpStatus.requestEntityTooLarge,
            {'error': 'request_too_large'});
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.keys.toSet().difference(
            {'purchaseType', 'targetId', 'idempotencyKey'},
          ).isNotEmpty ||
          decoded['purchaseType'] is! String ||
          decoded['targetId'] is! String ||
          decoded['idempotencyKey'] is! String) {
        await _writeJson(request.response, HttpStatus.badRequest,
            {'error': 'invalid_purchase_request'});
        return;
      }
      final accountId = await verifier(authorization.substring(7));
      if (accountId == null || accountId.isEmpty) {
        await _writeJson(request.response, HttpStatus.unauthorized,
            {'error': 'unauthorized'});
        return;
      }
      final result = await handler(
        trustedAccountId: accountId,
        purchaseType: decoded['purchaseType'] as String,
        targetId: decoded['targetId'] as String,
        idempotencyKey: decoded['idempotencyKey'] as String,
      );
      await _writeJson(request.response, HttpStatus.ok, {
        'type': 'purchase_result',
        'currency_balance': result['currency_balance'],
        'hero_revision': result['hero_revision'],
        'monster_revision': result['monster_revision'],
        'resulting_level': result['resulting_level'],
        'already_applied': result['already_applied'],
      });
    } on FormatException catch (error) {
      final code = error.message.toString();
      await _writeJson(request.response, HttpStatus.conflict,
          {'error': code.length <= 64 ? code : 'purchase_rejected'});
    } on HttpException {
      await _writeJson(request.response, HttpStatus.serviceUnavailable,
          {'error': 'purchase_backend_unavailable'});
    } on Object {
      await _writeJson(request.response, HttpStatus.serviceUnavailable,
          {'error': 'purchase_temporarily_unavailable'});
    }
  }

  Future<void> _writeJson(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(jsonEncode(body));
    await response.close();
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
    Timer? authenticationTimer;
    var authenticationCheckInFlight = false;

    void detach() {
      authenticationTimer?.cancel();
      authenticationTimer = null;
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
            unawaited(_handshake(socket, message, (session, joined, verifiedAccountId) {
              room = session;
              player = joined;
              final verifier = accessTokenVerifier;
              final token = message['accessToken'];
              if (verifier != null && token is String) {
                authenticationTimer?.cancel();
                authenticationTimer = Timer.periodic(
                  authenticationRecheckInterval,
                  (timer) async {
                    if (authenticationCheckInFlight ||
                        !identical(_sockets[joined.id], socket)) {
                      return;
                    }
                    authenticationCheckInFlight = true;
                    try {
                      final verifiedAccount = await verifier(token);
                      if (verifiedAccount == null ||
                          verifiedAccount != verifiedAccountId) {
                        timer.cancel();
                        if (identical(_sockets[joined.id], socket)) {
                          socket.close(
                            WebSocketStatus.policyViolation,
                            'session_expired_or_revoked',
                          );
                        }
                      }
                    } on Object {
                      // Fail closed: an unverifiable session must not retain
                      // authority when the identity provider cannot be reached.
                      timer.cancel();
                      if (identical(_sockets[joined.id], socket)) {
                        socket.close(
                          WebSocketStatus.policyViolation,
                          'session_revalidation_failed',
                        );
                      }
                    } finally {
                      authenticationCheckInFlight = false;
                    }
                  },
                );
              }
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
    void Function(GameServerSession, GameServerPlayer, String?) attach,
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
          player = joinRoom(room);
          if (player == null) {
            _send(socket, {'type': 'error', 'reason': 'account_binding_unavailable'});
            return;
          }
          _rooms[code] = room;
          break;
        case 'join':
          final code = message['code'];
          if (code is String) room = _rooms[code];
          if (room != null) player = joinRoom(room);
          break;
        case 'resume':
          final code = message['code'];
          final token = message['token'];
          if (code is String) room = _rooms[code];
          if (room != null && token is String) {
            if (verifier == null) {
              player = room.resume(token);
            } else if (room is AccountBoundGameServerSession &&
                room.ownsResumeToken(token, accountId!)) {
              player = room.resume(token);
            }
          }
          break;
        default:
          _send(socket, {'type': 'error', 'reason': 'bad_handshake'});
          return;
      }

      final joinedRoom = room;
      final joinedPlayer = player;
      if (joinedRoom == null || joinedPlayer == null) {
        _send(socket, {'type': 'error', 'reason': 'no_session'});
        return;
      }
      if (accountId != null &&
          joinedRoom is AccountProvisioningGameServerSession) {
        try {
          await (joinedRoom as AccountProvisioningGameServerSession)
              .prepareAccount(joinedPlayer, accountId);
        } on Object {
          joinedRoom.leave(joinedPlayer);
          if (joinedRoom.players.isEmpty) {
            _rooms.remove(joinedRoom.code);
          }
          _send(socket, {'type': 'error', 'reason': 'account_restore_failed'});
          return;
        }
      }
      if (socket.readyState != WebSocket.open) {
        joinedRoom.disconnect(joinedPlayer);
        return;
      }
      joinedPlayer.connected = true;
      final oldSocket = _sockets[joinedPlayer.id];
      _sockets[joinedPlayer.id] = socket;
      oldSocket?.close();
      attach(joinedRoom, joinedPlayer, accountId);
      _send(socket, {
        'type': 'welcome',
        'id': joinedPlayer.id,
        'token': joinedPlayer.resumeToken,
        'code': joinedRoom.code,
        'lastSeq': joinedPlayer.lastSequence,
      });
      final initialSnapshot = joinedRoom is PlayerScopedSnapshotSession
          ? (joinedRoom as PlayerScopedSnapshotSession).snapshotFor(joinedPlayer)
          : joinedRoom.snapshot();
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
