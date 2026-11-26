import 'dart:async';

import 'package:archer_fm/game/controls/virtual_joystick.dart';
import 'package:archer_fm/game/feedback/game_feedback_preferences.dart';
import 'package:archer_fm/game/match/match_loadout_screen.dart';
import 'package:archer_fm/game/network/game_client.dart';
import 'package:archer_fm/game/render3/arena_battlefield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGameClient extends GameClient {
  _FakeGameClient() : super('ws://fake.test');

  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final _stateController =
      StreamController<GameConnectionState>.broadcast(sync: true);
  final sent = <Map<String, Object?>>[];
  GameConnectionState _connectionState = GameConnectionState.disconnected;
  bool created = false;
  bool _disposed = false;

  @override
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  @override
  Stream<GameConnectionState> get states => _stateController.stream;

  @override
  bool get isConnected => _connectionState == GameConnectionState.connected;

  @override
  Future<void> create({int durationMinutes = 30}) async {
    created = true;
    _connectionState = GameConnectionState.connected;
    _stateController.add(GameConnectionState.connected);
    _messageController.add({
      'type': 'welcome',
      'id': 'p1',
      'token': 'test-resume-token',
      'code': '123456',
      'lastSeq': 0,
    });
    _messageController.add(_runningSnapshot);
  }

  @override
  bool send(String type, [Map<String, Object?> data = const {}]) {
    if (!isConnected) return false;
    sent.add({...data, 'type': type});
    return true;
  }

  void emit(Map<String, dynamic> message) {
    _messageController.add(message);
  }

  @override
  Future<void> dispose({bool leave = false}) async {
    if (_disposed) return;
    _disposed = true;
    _connectionState = GameConnectionState.closed;
    await _messageController.close();
    await _stateController.close();
    await super.dispose(leave: leave);
  }

  static final Map<String, dynamic> _runningSnapshot = {
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
  };
}

void main() {
  testWidgets(
    'running match opens a full-screen landscape battlefield with controls',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      GameFeedbackPreferences.setMovementSensitivity(1.3);
      addTearDown(() => GameFeedbackPreferences.setMovementSensitivity(1.0));

      final fakeClient = _FakeGameClient();
      await tester.pumpWidget(
        MaterialApp(
          home: MatchLoadoutScreen(clientFactory: (_) => fakeClient),
        ),
      );
      await tester.enterText(
        find.byType(TextField).first,
        'ws://127.0.0.1:8080',
      );
      await tester.tap(find.text('إنشاء غرفة'));
      await tester.pump();
      await tester.pump();

      expect(fakeClient.created, isTrue);
      expect(find.byType(ArenaBattlefield), findsOneWidget);
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(
        tester.widget<VirtualJoystick>(find.byType(VirtualJoystick)).sensitivity,
        1.3,
      );
      expect(find.text('هجوم'), findsOneWidget);
      expect(find.text('تغيير الهدف'), findsOneWidget);
      expect(find.text('لوحة المباراة المباشرة'), findsNothing);
      expect(find.text('تجهيز المباراة'), findsNothing);
      expect(
        fakeClient.sent.any((message) => message['type'] == 'select'),
        isTrue,
      );
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
      await gesture.up();
      await tester.pump();

      final movementMessages = fakeClient.sent
          .where((message) => message['type'] == 'move')
          .toList();
      expect(movementMessages, isNotEmpty);
      expect(
        movementMessages.any((message) => (message['dx'] as num) > 0),
        isTrue,
      );
      expect(movementMessages.last['dx'], 0);
      expect(movementMessages.last['dy'], 0);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('هجوم'));
      await tester.pump();
      expect(
        fakeClient.sent.any(
          (message) =>
              message['type'] == 'attack' && message['targetId'] == 'hero_p2',
        ),
        isTrue,
      );

      fakeClient.emit({
        'type': 'ack',
        'seq': 999,
        'error': 'attack_rejected',
      });
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

      fakeClient.emit({
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
      });
      await tester.pump();

      expect(find.text('الفائز: أنت'), findsOneWidget);
      expect(find.text('العودة للقائمة الرئيسية'), findsOneWidget);
      expect(find.byType(VirtualJoystick), findsNothing);
      expect(find.text('هجوم'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await fakeClient.dispose();
    },
  );
}
