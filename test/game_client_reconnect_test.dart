import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/game_client.dart';

void main() {
  test('replays a durable purchase after reconnect when server has not acked it',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = StreamController<WebSocket>.broadcast();
    final sockets = <WebSocket>[];
    final firstPurchase = Completer<void>();
    final replayedPurchase = Completer<Map<String, dynamic>>();
    var connectionCount = 0;

    final subscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      accepted.add(socket);
      connectionCount++;

      if (connectionCount == 1) {
        socket.listen((raw) {
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          if (message['type'] == 'create') {
            socket.add(jsonEncode({
              'type': 'welcome',
              'id': 'p1',
              'code': '123456',
              'token': 'resume-token',
              'profile': 'profile-key',
              'lastSeq': 0,
            }));
          } else if (message['type'] == 'buy') {
            if (!firstPurchase.isCompleted) firstPurchase.complete();
            socket.close();
          }
        });
      } else {
        socket.listen((raw) {
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          if (message['type'] == 'resume') {
            socket.add(jsonEncode({
              'type': 'welcome',
              'id': 'p1',
              'code': '123456',
              'token': 'resume-token',
              'profile': 'profile-key',
              'lastSeq': 0,
            }));
          } else if (message['type'] == 'buy' &&
              !replayedPurchase.isCompleted) {
            replayedPurchase.complete(message);
          }
        });
      }
    });

    final client = GameClient(
      'ws://127.0.0.1:${server.port}',
      maxReconnectDelay: const Duration(seconds: 2),
    );

    try {
      await client.create();
      await client.messages.firstWhere((m) => m['type'] == 'welcome');
      expect(client.send('buy', {'unit': 'soldier'}), isTrue);
      await firstPurchase.future.timeout(const Duration(seconds: 3));

      final replay = await replayedPurchase.future.timeout(
        const Duration(seconds: 6),
      );
      expect(replay['seq'], 1);
      expect(replay['unit'], 'soldier');
      expect(connectionCount, 2);
    } finally {
      await client.dispose();
      await accepted.close();
      await subscription.cancel();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    }
  });

  test('replays pre-match army selection after reconnect when not acknowledged',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final firstSelection = Completer<void>();
    final replayedSelection = Completer<Map<String, dynamic>>();
    var connectionCount = 0;

    final subscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      connectionCount++;
      socket.listen((raw) {
        final message = jsonDecode(raw as String) as Map<String, dynamic>;
        if (connectionCount == 1 && message['type'] == 'create') {
          socket.add(jsonEncode({
            'type': 'welcome',
            'id': 'p1',
            'code': '654321',
            'token': 'army-resume-token',
            'lastSeq': 0,
          }));
        } else if (connectionCount == 1 &&
            message['type'] == 'army_select') {
          if (!firstSelection.isCompleted) firstSelection.complete();
          socket.close();
        } else if (connectionCount == 2 && message['type'] == 'resume') {
          socket.add(jsonEncode({
            'type': 'welcome',
            'id': 'p1',
            'code': '654321',
            'token': 'army-resume-token',
            'lastSeq': 0,
          }));
        } else if (connectionCount == 2 &&
            message['type'] == 'army_select' &&
            !replayedSelection.isCompleted) {
          replayedSelection.complete(message);
        }
      });
    });

    final client = GameClient(
      'ws://127.0.0.1:${server.port}',
      maxReconnectDelay: const Duration(seconds: 2),
    );
    try {
      await client.create();
      await client.messages.firstWhere((message) => message['type'] == 'welcome');
      expect(client.send('army_select', {
        'counts': {'runner': 20},
      }), isTrue);
      await firstSelection.future.timeout(const Duration(seconds: 3));
      final replay = await replayedSelection.future.timeout(
        const Duration(seconds: 6),
      );
      expect(replay['seq'], 1);
      expect(replay['counts'], {'runner': 20});
      expect(connectionCount, 2);
    } finally {
      await client.dispose();
      await subscription.cancel();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    }
  });

}
