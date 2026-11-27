import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archer_fm/game/render3/arena_battlefield.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live battlefield loads 3D heroes and the four monster models',
      (tester) async {
    final players = [
      {'id': 'p1', 'heroId': 'ranger'},
      {'id': 'p2', 'heroId': 'flame'},
      {'id': 'p3', 'heroId': 'shadow'},
      {'id': 'p4', 'heroId': 'storm'},
    ];
    final snapshot = <String, dynamic>{
      'phase': 'running',
      'players': players,
      'world': {
        'size': {'width': 1920, 'height': 1080},
        'playerPositions': {
          'p1': {'x': 400, 'y': 400},
          'p2': {'x': 1400, 'y': 400},
          'p3': {'x': 400, 'y': 800},
          'p4': {'x': 1400, 'y': 800},
        },
        'biomes': const [],
        'rivers': const [],
        'obstacles': const [],
        'mapPickups': const [],
        'resourcePickups': const [],
        'mines': const [],
        'castles': const [],
      },
      'combat': {
        'heroes': {
          for (final player in players)
            player['id']: {
              'health': 600,
              'maxHealth': 600,
              'isAlive': true,
              'comboIndex': 0,
              'ultimateCooldowns': [0, 0, 0, 0],
            },
        },
        'monsters': [
          {
            'id': 'm-runner',
            'ownerId': 'p2',
            'type': 'runner',
            'x': 430,
            'y': 430,
            'health': 100,
            'maxHealth': 100,
            'targetId': 'p1',
          },
          {
            'id': 'm-tank',
            'ownerId': 'p2',
            'type': 'tank',
            'x': 450,
            'y': 440,
            'health': 160,
            'maxHealth': 160,
            'targetId': 'p1',
          },
          {
            'id': 'm-stalker',
            'ownerId': 'p3',
            'type': 'stalker',
            'x': 470,
            'y': 450,
            'health': 90,
            'maxHealth': 90,
            'targetId': 'p1',
          },
          {
            'id': 'm-ranged',
            'ownerId': 'p4',
            'type': 'ranged',
            'x': 490,
            'y': 460,
            'health': 110,
            'maxHealth': 110,
            'targetId': 'p1',
          },
        ],
        'dyingMonsters': const [],
        'projectiles': const [],
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 960,
              height: 540,
              child: ArenaBattlefield(
                snapshot: snapshot,
                localPlayerId: 'p1',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
