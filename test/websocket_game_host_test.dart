import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/websocket_game_host.dart';

class _FakePlayer implements GameServerPlayer {
  _FakePlayer(this.id, this.resumeToken);

  @override
  final String id;
  @override
  String resumeToken;
  @override
  int lastSequence = 0;
  @override
  bool connected = true;
}

class _FakeSession implements GameServerSession {
  _FakeSession(this.code);

  @override
  final String code;
  final List<_FakePlayer> _players = [];
  int handledCommands = 0;
  Duration totalTicked = Duration.zero;

  @override
  Iterable<GameServerPlayer> get players => _players;

  @override
  bool get shouldRemove => _players.isEmpty;

  @override
  GameServerPlayer? join() {
    if (_players.length >= 4) return null;
    final player = _FakePlayer('p${_players.length + 1}', 'token-${_players.length + 1}');
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
    player.connected = false;
  }

  @override
  void leave(GameServerPlayer player) {
    _players.removeWhere((item) => item.id == player.id);
  }

  @override
  String? handle(GameServerPlayer player, Map<String, dynamic> message) {
    handledCommands++;
    return null;
  }

  @override
  void tick(Duration elapsed) {
    totalTicked += elapsed;
  }

  @override
  Map<String, Object?> snapshot() => {
        'type': 'state',
        'phase': 'lobby',
        'players': [for (final player in _players) player.id],
      };
}

class _FakeScopedSession extends _FakeSession
    implements PlayerScopedSnapshotSession {
  _FakeScopedSession(super.code);

  @override
  Map<String, Object?> snapshotFor(GameServerPlayer player) => {
        'type': 'state',
        'recipient': player.id,
      };
}

class _FakeAccountSession extends _FakeSession
    implements AccountBoundGameServerSession, AccountProvisioningGameServerSession {
  _FakeAccountSession(super.code);

  final Map<String, String> _accounts = {};
  bool provisioningComplete = false;
  bool failProvisioning = false;

  @override
  GameServerPlayer? joinForAccount(String accountId) {
    if (_accounts.containsValue(accountId)) return null;
    final player = join();
    if (player != null) _accounts[player.id] = accountId;
    return player;
  }

  @override
  bool ownsResumeToken(String resumeToken, String accountId) =>
      _players.any((player) =>
          player.resumeToken == resumeToken &&
          _accounts[player.id] == accountId);

  @override
  Future<void> prepareAccount(GameServerPlayer player, String accountId) async {
    if (_accounts[player.id] != accountId) {
      throw StateError('account mismatch');
    }
    if (failProvisioning) throw StateError('cloud restore failed');
    provisioningComplete = true;
  }
}

class _FakeFactory {
  final Map<String, _FakeSession> sessions = {};
  bool scopedSnapshots = false;
  bool accountBound = false;
  bool failProvisioning = false;

  GameServerSession create(String code, Map<String, dynamic> message) =>
      sessions.putIfAbsent(
        code,
        () {
          if (accountBound) {
            final session = _FakeAccountSession(code)
              ..failProvisioning = failProvisioning;
            return session;
          }
          return scopedSnapshots
              ? _FakeScopedSession(code)
              : _FakeSession(code);
        },
      );
}

Future<Map<String, dynamic>> _nextType(
  Stream<Map<String, dynamic>> messages,
  String type,
) =>
    messages.firstWhere((message) => message['type'] == type);

Stream<Map<String, dynamic>> _messages(WebSocket socket) =>
    socket.map((raw) => jsonDecode(raw as String) as Map<String, dynamic>);

void main() {
  late _FakeFactory factory;
  late WebSocketGameHost host;

  setUp(() async {
    factory = _FakeFactory();
    host = WebSocketGameHost(
      sessionFactory: factory.create,
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    await host.start();
  });

  tearDown(() async {
    await host.close();
  });

  test('creates a room and sequence-validates commands', () async {
    final socket = await WebSocket.connect(host.uri.toString());
    final messages = _messages(socket).asBroadcastStream();

    final welcomeFuture = _nextType(messages, 'welcome');
    final stateFuture = _nextType(messages, 'state');
    socket.add(jsonEncode({'type': 'create'}));
    final welcome = await welcomeFuture;
    expect(welcome['code'], isA<String>());
    expect(welcome['id'], 'p1');
    expect(host.roomCount, 1);
    expect(host.connectedPlayerCount, 1);

    final state = await stateFuture;
    expect(state['players'], ['p1']);

    final ackFuture = _nextType(messages, 'ack');
    socket.add(jsonEncode({'type': 'attack', 'seq': 1, 'target': 'p2'}));
    final ack = await ackFuture;
    expect(ack['error'], isNull);
    expect(factory.sessions.values.single.handledCommands, 1);

    final duplicateFuture = _nextType(messages, 'ack');
    socket.add(jsonEncode({'type': 'attack', 'seq': 1, 'target': 'p2'}));
    final duplicate = await duplicateFuture;
    expect(duplicate['error'], 'duplicate');
    expect(factory.sessions.values.single.handledCommands, 1);

    await socket.close();
  });

  test('sends recipient-specific snapshots at handshake and during broadcasts', () async {
    factory.scopedSnapshots = true;
    final first = await WebSocket.connect(host.uri.toString());
    final firstMessages = _messages(first).asBroadcastStream();
    final firstWelcomeFuture = _nextType(firstMessages, 'welcome');
    final firstInitialStateFuture = _nextType(firstMessages, 'state');
    first.add(jsonEncode({'type': 'create'}));
    final firstWelcome = await firstWelcomeFuture;
    final firstInitialState = await firstInitialStateFuture;
    expect(firstWelcome['id'], 'p1');
    expect(firstInitialState['recipient'], 'p1');

    final second = await WebSocket.connect(host.uri.toString());
    final secondMessages = _messages(second).asBroadcastStream();
    final secondWelcomeFuture = _nextType(secondMessages, 'welcome');
    final secondInitialStateFuture = _nextType(secondMessages, 'state');
    second.add(jsonEncode({
      'type': 'join',
      'code': firstWelcome['code'],
    }));
    final secondWelcome = await secondWelcomeFuture;
    final secondInitialState = await secondInitialStateFuture;
    expect(secondWelcome['id'], 'p2');
    expect(secondInitialState['recipient'], 'p2');

    final firstBroadcastFuture = _nextType(firstMessages, 'state');
    final secondBroadcastFuture = _nextType(secondMessages, 'state');
    final states = await Future.wait([
      firstBroadcastFuture,
      secondBroadcastFuture,
    ]);
    expect(states[0]['recipient'], 'p1');
    expect(states[1]['recipient'], 'p2');

    await first.close();
    await second.close();
  });

  test('resumes the same player and returns the last accepted sequence', () async {
    final first = await WebSocket.connect(host.uri.toString());
    final firstMessages = _messages(first).asBroadcastStream();
    final welcomeFuture = _nextType(firstMessages, 'welcome');
    first.add(jsonEncode({'type': 'create'}));
    final welcome = await welcomeFuture;
    final code = welcome['code'] as String;
    final token = welcome['token'] as String;

    first.add(jsonEncode({'type': 'select', 'seq': 7}));
    await _nextType(firstMessages, 'ack');
    await first.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final resumed = await WebSocket.connect(host.uri.toString());
    final resumedMessages = _messages(resumed).asBroadcastStream();
    final resumedWelcomeFuture = _nextType(resumedMessages, 'welcome');
    resumed.add(jsonEncode({
      'type': 'resume',
      'code': code,
      'token': token,
    }));

    final resumedWelcome = await resumedWelcomeFuture;
    expect(resumedWelcome['id'], welcome['id']);
    expect(resumedWelcome['lastSeq'], 7);
    expect(host.connectedPlayerCount, 1);

    await resumed.close();
  });

  test('rejects non-WebSocket HTTP requests', () async {
    final client = HttpClient();
    final request = await client.getUrl(host.uri.replace(scheme: 'http'));
    final response = await request.close();
    expect(response.statusCode, HttpStatus.badRequest);
    client.close(force: true);
  });

  test('verified account is hydrated before the host sends welcome', () async {
    factory.accountBound = true;
    final accountHost = WebSocketGameHost(
      sessionFactory: factory.create,
      address: InternetAddress.loopbackIPv4,
      port: 0,
      accessTokenVerifier: (token) async =>
          token == 'valid-token' ? 'verified-account' : null,
    );
    await accountHost.start();
    addTearDown(accountHost.close);

    final socket = await WebSocket.connect(accountHost.uri.toString());
    final messages = _messages(socket).asBroadcastStream();
    final welcomeFuture = _nextType(messages, 'welcome');
    socket.add(jsonEncode({
      'type': 'create',
      'accessToken': 'valid-token',
    }));
    final welcome = await welcomeFuture;
    expect(welcome['id'], 'p1');
    expect((factory.sessions.values.single as _FakeAccountSession).provisioningComplete, isTrue);
    await socket.close();
  });

  test('disconnects an authenticated socket when its token is revoked', () async {
    factory.accountBound = true;
    var tokenRevoked = false;
    final accountHost = WebSocketGameHost(
      sessionFactory: factory.create,
      address: InternetAddress.loopbackIPv4,
      port: 0,
      authenticationRecheckInterval: const Duration(milliseconds: 20),
      accessTokenVerifier: (token) async =>
          token == 'valid-token' && !tokenRevoked
              ? 'verified-account'
              : null,
    );
    await accountHost.start();
    addTearDown(accountHost.close);

    final socket = await WebSocket.connect(accountHost.uri.toString());
    final messages = _messages(socket).asBroadcastStream();
    final welcomeFuture = _nextType(messages, 'welcome');
    socket.add(jsonEncode({
      'type': 'create',
      'accessToken': 'valid-token',
    }));
    await welcomeFuture;
    expect(accountHost.connectedPlayerCount, 1);

    tokenRevoked = true;
    await socket.done.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(accountHost.connectedPlayerCount, 0);
    expect((factory.sessions.values.single).handledCommands, 0);
  });

  test('cloud restore failure rejects the handshake without welcome', () async {
    factory
      ..accountBound = true
      ..failProvisioning = true;
    final accountHost = WebSocketGameHost(
      sessionFactory: factory.create,
      address: InternetAddress.loopbackIPv4,
      port: 0,
      accessTokenVerifier: (token) async => 'verified-account',
    );
    await accountHost.start();
    addTearDown(accountHost.close);

    final socket = await WebSocket.connect(accountHost.uri.toString());
    final messages = _messages(socket).asBroadcastStream();
    final errorFuture = _nextType(messages, 'error');
    socket.add(jsonEncode({
      'type': 'create',
      'accessToken': 'valid-token',
    }));
    final error = await errorFuture;
    expect(error['reason'], 'account_restore_failed');
    expect(accountHost.roomCount, 0);
    await socket.close();
  });

}
