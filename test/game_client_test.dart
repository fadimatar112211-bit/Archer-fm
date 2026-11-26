import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/game_client.dart';

void main() {
  late HttpServer server;
  late GameClient client;
  WebSocket? socket;
  StreamSubscription<dynamic>? socketSubscription;
  final received = <Map<String, dynamic>>[];
  late Completer<void> messageReceived;

  setUp(() async {
    messageReceived = Completer<void>();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      socket = await WebSocketTransformer.upgrade(request);
      socketSubscription = socket!.listen((raw) {
        received.add(jsonDecode(raw as String) as Map<String, dynamic>);
        if (!messageReceived.isCompleted) messageReceived.complete();
      });
    });
    client = GameClient('ws://127.0.0.1:${server.port}');
    received.clear();
  });

  tearDown(() async {
    await client.dispose();
    await socketSubscription?.cancel();
    await socket?.close();
    await server.close(force: true);
  });

  test('connects, receives welcome, and sends sequenced commands', () async {
    await client.create();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    socket!.add(jsonEncode({
      'type': 'welcome',
      'id': 'p1',
      'code': '123456',
      'token': 'resume-token',
      'profile': 'profile-key',
      'lastSeq': 0,
    }));

    final welcome = await client.messages.firstWhere(
      (message) => message['type'] == 'welcome',
    );
    expect(welcome['code'], '123456');
    expect(client.isConnected, isTrue);

    received.clear();
    messageReceived = Completer<void>();
    expect(client.send('attack', {'target': 'p2'}), isTrue);
    await messageReceived.future;
    expect(received.single['type'], 'attack');
    expect(received.single['seq'], 1);
  });

  test('does not queue combat or movement while disconnected', () {
    expect(client.send('move', {'dx': 1, 'dy': 0}), isFalse);
    expect(client.send('attack', {'target': 'p2'}), isFalse);
  });
}
