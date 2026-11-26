import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/game/controls/virtual_joystick.dart';
import 'package:archer_fm/game/feedback/game_feedback_preferences.dart';
import 'package:archer_fm/game/match/match_loadout_screen.dart';
import 'package:archer_fm/game/render3/arena_battlefield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('running match opens a full-screen landscape battlefield with controls',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GameFeedbackPreferences.setMovementSensitivity(1.3);
    addTearDown(() => GameFeedbackPreferences.setMovementSensitivity(1.0));

    WebSocket? connectedSocket;
    final received = <Map<String, dynamic>>[];
    final createReceived = Completer<void>();
    final server = (await tester.runAsync(() async {
      final bound = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      // Register the listener in the real async zone so WebSocket upgrade and
      // socket events are serviced while the widget test advances frames.
      bound.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        connectedSocket = socket;
        void send(Map<String, dynamic> payload) {
          if (socket.readyState != WebSocket.open) return;
          try {
            socket.add(jsonEncode(payload));
          } on StateError {
            // The client may close while the test is tearing down.
          }
        }
        socket.listen((raw) {
          if (raw is! String) return;
          final message = jsonDecode(raw) as Map<String, dynamic>;
          received.add(message);
          if (message['type'] == 'create') {
            if (!createReceived.isCompleted) createReceived.complete();
            send({
              'type': 'welcome',
              'id': 'p1',
              'token': 'test-resume-token',
              'code': '123456',
              'lastSeq': 0,
            });
            send({
              'type': 'state',
            'phase': 'running',
            'players': [
              {'id': 'p1', 'heroId': 'ranger', 'weaponId': 'ranger_bow'},
              {'id': 'p2', 'heroId': 'flame', 'weaponId': 'flame_blade'},
            ],
            'world': {
              'size': {'width': 1920, 'height': 1080},
              'playerPositions': {
                'p1': {'x': 900, 'y': 540},
                'p2': {'x': 1200, 'y': 540},
              },
              'resources': {'p1': 100, 'p2': 100},
              'livingCrystals': {'p1': 7, 'p2': 7},
              'castles': [],
            },
            'combat': {
              'heroes': {
                'p1': {
                  'health': 100,
                  'maxHealth': 100,
                  'level': 1,
                  'isAlive': true,
                  'comboIndex': 0,
                  'attackCooldownMs': 0,
                  'ultimateCooldowns': [0, 0, 0, 0],
                },
                'p2': {
                  'health': 100,
                  'maxHealth': 100,
                  'level': 1,
                  'isAlive': true,
                  'comboIndex': 0,
                  'attackCooldownMs': 0,
                  'ultimateCooldowns': [0, 0, 0, 0],
                },
              },
              'monsters': [],
            },
            });
          } else if (message['seq'] is int) {
            send({
              'type': 'ack',
              'seq': message['seq'],
              'error': null,
            });
          }
        });
      });
      return bound;
    }))!;

    try {
      await tester.pumpWidget(
        const MaterialApp(home: MatchLoadoutScreen()),
      );
      await tester.enterText(
        find.byType(TextField).first,
        'ws://127.0.0.1:${server.port}',
      );
      await tester.tap(find.text('إنشاء غرفة'));
      await tester.pump();
      await tester.runAsync(
        () => createReceived.future.timeout(const Duration(seconds: 8)),
      );
      // Let the welcome and running-state frames reach the app before
      // asserting the screen transition; avoid a timing-only 250 ms guess.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();

      expect(find.byType(ArenaBattlefield), findsOneWidget);
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(tester.widget<VirtualJoystick>(find.byType(VirtualJoystick)).sensitivity, 1.3);
      expect(find.text('هجوم'), findsOneWidget);
      expect(find.text('تغيير الهدف'), findsOneWidget);
      expect(find.text('لوحة المباراة المباشرة'), findsNothing);
      expect(find.text('تجهيز المباراة'), findsNothing);
      expect(received.any((message) => message['type'] == 'create'), isTrue);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(568, 320);
      await tester.pump();
      expect(find.byType(ArenaBattlefield), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1280, 720);
      await tester.pump();
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(640, 360);
      await tester.pump();

      final joystickCenter = tester.getCenter(find.byType(VirtualJoystick));
      final gesture = await tester.startGesture(joystickCenter);
      await gesture.moveBy(const Offset(34, 0));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 40),
          ));
      await gesture.up();
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 40),
          ));
      final movementMessages = received
          .where((message) => message['type'] == 'move')
          .toList();
      expect(movementMessages, isNotEmpty);
      expect(movementMessages.any((message) => (message['dx'] as num) > 0), isTrue);
      expect(movementMessages.last['dx'], 0);
      expect(movementMessages.last['dy'], 0);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('هجوم'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 40),
          ));
      expect(
        received.any(
          (message) =>
              message['type'] == 'attack' && message['targetId'] == 'p2',
        ),
        isTrue,
      );

      final rejectionSocket = connectedSocket;
      expect(rejectionSocket, isNotNull);
      expect(rejectionSocket!.readyState, WebSocket.open);
      rejectionSocket.add(jsonEncode({
        'type': 'ack',
        'seq': 999,
        'error': 'attack_rejected',
      }));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 60),
          ));
      await tester.pump();
      expect(
        find.text('رفض الخادم الهجوم؛ تحقق من المدى والتبريد'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('إغلاق التنبيه'));
      await tester.pump();
      expect(
        find.text('رفض الخادم الهجوم؛ تحقق من المدى والتبريد'),
        findsNothing,
      );

      expect(rejectionSocket.readyState, WebSocket.open);
      rejectionSocket.add(jsonEncode({
        'type': 'state',
        'phase': 'finished',
        'players': [
          {'id': 'p1', 'heroId': 'ranger', 'weaponId': 'ranger_bow'},
          {'id': 'p2', 'heroId': 'flame', 'weaponId': 'flame_blade'},
        ],
        'world': {
          'size': {'width': 1920, 'height': 1080},
          'playerPositions': {
            'p1': {'x': 900, 'y': 540},
            'p2': {'x': 1200, 'y': 540},
          },
          'resources': {'p1': 100, 'p2': 100},
          'livingCrystals': {'p1': 7, 'p2': 7},
          'castles': [],
        },
        'combat': {
          'heroes': {
            'p1': {'health': 100, 'maxHealth': 100, 'level': 1, 'isAlive': true},
            'p2': {'health': 0, 'maxHealth': 100, 'level': 1, 'isAlive': false},
          },
          'monsters': [],
        },
        'result': {
          'winnerId': 'p1',
          'reason': 'timeExpired',
          'standings': [
            {'playerId': 'p1', 'rank': 1, 'score': 100, 'livingCrystals': 7},
            {'playerId': 'p2', 'rank': 2, 'score': 50, 'livingCrystals': 0},
          ],
        },
      }));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 80),
          ));
      await tester.pump();

      expect(find.text('الفائز: أنت'), findsOneWidget);
      expect(find.text('العودة للقائمة الرئيسية'), findsOneWidget);
      expect(find.byType(VirtualJoystick), findsNothing);
      expect(find.text('هجوم'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await connectedSocket?.close();
        await server.close(force: true);
      });
    }
  });
}
