import 'dart:ui' as ui;

import 'package:archer_fm/game/render3/arena_battlefield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the authoritative arena geometry and live entities',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ArenaBattlefield(
              localPlayerId: 'p1',
              snapshot: {
                'players': [
                  {'id': 'p1', 'heroId': 'ranger'},
                  {'id': 'p2', 'heroId': 'flame'},
                ],
                'world': {
                  'size': {'width': 2000, 'height': 1200},
                  'biomes': [
                    {'kind': 'forest', 'x': 400, 'y': 300, 'radius': 300},
                  ],
                  'rivers': [
                    {
                      'width': 80,
                      'points': [
                        {'x': 900, 'y': 0},
                        {'x': 950, 'y': 1200},
                      ],
                      'bridges': [
                        {'x': 925, 'y': 600, 'width': 120, 'depth': 140},
                      ],
                    },
                  ],
                  'obstacles': [
                    {'kind': 'tree', 'x': 600, 'y': 500, 'radius': 24},
                  ],
                  'mapPickups': [
                    {'kind': 'chest', 'x': 700, 'y': 600},
                  ],
                  'resources': {'p1': 50, 'p2': 30},
                  'playerPositions': {
                    'p1': {'x': 300, 'y': 400},
                    'p2': {'x': 1600, 'y': 800},
                  },
                  'castles': [
                    {
                      'ownerId': 'p1',
                      'fallen': false,
                      'anchor': {'x': 300, 'y': 300},
                      'walls': [
                        {'radius': 146, 'startAngle': 0.4, 'sweep': 1.2},
                      ],
                      'crystals': [
                        {
                          'id': 'p1_c1',
                          'x': 340,
                          'y': 340,
                          'hp': 300,
                          'maxHp': 500,
                        },
                      ],
                    },
                    {
                      'ownerId': 'p2',
                      'fallen': false,
                      'anchor': {'x': 1600, 'y': 800},
                      'walls': [
                        {'radius': 146, 'startAngle': 2.0, 'sweep': 1.2},
                      ],
                      'crystals': [
                        {
                          'id': 'p2_c1',
                          'x': 1640,
                          'y': 840,
                          'hp': 500,
                          'maxHp': 500,
                        },
                      ],
                    },
                  ],
                  'mines': [
                    {
                      'ownerId': 'p2',
                      'captureFraction': 0.6,
                      'x': 1000,
                      'y': 600,
                    },
                  ],
                  'resourcePickups': [
                    {'x': 1100, 'y': 700, 'amount': 10},
                  ],
                },
                'combat': {
                  'heroes': {
                    'p1': {'health': 100, 'maxHealth': 100, 'isAlive': true},
                    'p2': {'health': 75, 'maxHealth': 100, 'isAlive': true},
                  },
                  'projectiles': [
                    {'id': 'shot1', 'ownerId': 'p2', 'x': 850, 'y': 630},
                  ],
                  'monsters': [
                    {
                      'id': 'm1',
                      'ownerId': 'p2',
                      'type': 'tank',
                      'x': 900,
                      'y': 650,
                      'health': 80,
                      'maxHealth': 100,
                    },
                  ],
                },
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ArenaBattlefield), findsOneWidget);
  });

  testWidgets('fails closed when the local reveal position is missing',
      (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 960,
                height: 540,
                child: const ArenaBattlefield(
                  localPlayerId: 'p1',
                  snapshot: {
                    'world': {
                      'size': {'width': 2000, 'height': 1200},
                      'playerPositions': {},
                    },
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);
    final centerOffset = (image.width * (image.height ~/ 2) +
            (image.width ~/ 2)) *
        4;
    expect(bytes!.getUint8(centerOffset), lessThan(40));
    expect(bytes.getUint8(centerOffset + 1), lessThan(40));
    expect(bytes.getUint8(centerOffset + 2), lessThan(40));
    image.dispose();
  });

  testWidgets('shows a waiting label when no authoritative world exists',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArenaBattlefield(
            localPlayerId: 'p1',
            snapshot: {},
          ),
        ),
      ),
    );

    expect(find.text('بانتظار بيانات ساحة المعركة'), findsOneWidget);
  });
}
