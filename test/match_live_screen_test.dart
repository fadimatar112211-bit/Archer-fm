import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/game/controls/virtual_joystick.dart';
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

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    WebSocket? connectedSocket;
    final received = <Map<String, dynamic>>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      connectedSocket = socket;
      socket.listen((raw) {
        if (raw is! String) return;
        final message = jsonDecode(raw) as Map<String, dynamic>;
        received.add(message);
        if (message['type'] == 'create') {
          socket.add(jsonEncode({
            'type': 'welcome',
            'id': 'p1',
            'token': 'test-resume-token',
            'code': '123456',
            'lastSeq': 0,
          }));
          socket.add(jsonEncode({
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
          }));
        } else if (message['seq'] is int) {
          socket.add(jsonEncode({
            'type': 'ack',
            'seq': message['seq'],
            'error': null,
          }));
        }
      });
    });

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
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 250),
          ));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 100),
          ));
      await tester.pump();

      expect(find.byType(ArenaBattlefield), findsOneWidget);
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(find.text('هجوم'), findsOneWidget);
      expect(find.text('تغيير الهدف'), findsOneWidget);
      expect(find.text('لوحة المباراة المباشرة'), findsNothing);
      expect(find.text('تجهيز المباراة'), findsNothing);
      expect(received.any((message) => message['type'] == 'create'), isTrue);
      expect(tester.takeException(), isNull);

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

      connectedSocket!.add(jsonEncode({
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

      connectedSocket!.add(jsonEncode({
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
      await connectedSocket?.close();
      await server.close(force: true);
    }
  });
}
