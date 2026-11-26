import 'dart:io';
import 'dart:ui' as ui;

import 'package:archer_fm/game/render3/arena_battlefield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the production battlefield painter at 16:9',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final players = [
      {'id': 'p1', 'heroId': 'ranger'},
      {'id': 'p2', 'heroId': 'flame'},
      {'id': 'p3', 'heroId': 'shadow'},
      {'id': 'p4', 'heroId': 'storm'},
    ];
    final castlePositions = [
      const Offset(145, 120),
      const Offset(815, 120),
      const Offset(145, 420),
      const Offset(815, 420),
    ];

    final snapshot = <String, dynamic>{
      'phase': 'setup',
      'players': players,
      'world': {
        'size': {'width': 960, 'height': 540},
        'playerPositions': {
          'p1': {'x': 420, 'y': 250},
          'p2': {'x': 815, 'y': 120},
          'p3': {'x': 145, 'y': 420},
          'p4': {'x': 815, 'y': 420},
        },
        'biomes': [
          {'kind': 'forest', 'x': 170, 'y': 145, 'radius': 245},
          {'kind': 'desert', 'x': 790, 'y': 145, 'radius': 235},
          {'kind': 'snow', 'x': 170, 'y': 410, 'radius': 225},
          {'kind': 'volcanic', 'x': 790, 'y': 410, 'radius': 230},
        ],
        'rivers': [
          {
            'width': 74,
            'points': [
              {'x': 480, 'y': 0},
              {'x': 465, 'y': 160},
              {'x': 495, 'y': 360},
              {'x': 480, 'y': 540},
            ],
            'bridges': [
              {'x': 475, 'y': 270, 'width': 126, 'depth': 112},
              {'x': 480, 'y': 90, 'width': 112, 'depth': 92},
            ],
          },
        ],
        'obstacles': [
          {'kind': 'tree', 'x': 300, 'y': 150, 'radius': 25},
          {'kind': 'tree', 'x': 350, 'y': 205, 'radius': 22},
          {'kind': 'tree', 'x': 255, 'y': 310, 'radius': 28},
          {'kind': 'rock', 'x': 690, 'y': 185, 'radius': 25},
          {'kind': 'rock', 'x': 710, 'y': 365, 'radius': 29},
          {'kind': 'tree', 'x': 600, 'y': 420, 'radius': 23},
          {'kind': 'tree', 'x': 360, 'y': 430, 'radius': 24},
        ],
        'mapPickups': [
          {'kind': 'chest', 'x': 400, 'y': 180},
          {'kind': 'chest', 'x': 565, 'y': 365},
        ],
        'resourcePickups': [
          {'x': 390, 'y': 300, 'amount': 30},
          {'x': 570, 'y': 220, 'amount': 20},
        ],
        'mines': [
          {'id': 'mine-1', 'x': 390, 'y': 90, 'ownerId': 'p1', 'captureFraction': 1.0},
          {'id': 'mine-2', 'x': 570, 'y': 90, 'ownerId': 'p2', 'captureFraction': 1.0},
          {'id': 'mine-3', 'x': 390, 'y': 450, 'ownerId': 'p3', 'captureFraction': 0.7},
          {'id': 'mine-4', 'x': 570, 'y': 450, 'ownerId': 'p4', 'captureFraction': 0.45},
        ],
        'castles': [
          for (var i = 0; i < 4; i++)
            {
              'ownerId': 'p${i + 1}',
              'fallen': false,
              'anchor': {
                'x': castlePositions[i].dx,
                'y': castlePositions[i].dy,
              },
              'walls': [
                {'radius': 82, 'startAngle': 0.25, 'sweep': 2.1},
                {'radius': 68, 'startAngle': 3.1, 'sweep': 1.7},
              ],
              'crystals': [
                for (var j = 0; j < 7; j++)
                  {
                    'id': 'p${i + 1}_c${j + 1}',
                    'x': castlePositions[i].dx + (j % 3 - 1) * 23.0,
                    'y': castlePositions[i].dy + (j ~/ 3 - 1) * 24.0,
                    'hp': 500 + j * 150,
                    'maxHp': 500 + j * 150,
                  },
              ],
            },
        ],
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
            'x': 445,
            'y': 245,
            'health': 100,
            'maxHealth': 100,
          },
          {
            'id': 'm-tank',
            'ownerId': 'p3',
            'type': 'tank',
            'x': 485,
            'y': 305,
            'health': 160,
            'maxHealth': 160,
          },
          {
            'id': 'm-stalker',
            'ownerId': 'p4',
            'type': 'stalker',
            'x': 530,
            'y': 250,
            'health': 90,
            'maxHealth': 90,
          },
          {
            'id': 'm-ranged',
            'ownerId': 'p2',
            'type': 'ranged',
            'x': 525,
            'y': 320,
            'health': 110,
            'maxHealth': 110,
          },
        ],
        'dyingMonsters': const [],
        'projectiles': [
          {'id': 'shot-1', 'ownerId': 'p2', 'x': 465, 'y': 230},
          {'id': 'shot-2', 'ownerId': 'p3', 'x': 505, 'y': 285},
        ],
      },
    };

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
                child: ArenaBattlefield(
                  snapshot: snapshot,
                  localPlayerId: 'p1',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final captured = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        throw StateError('Could not encode the arena visual capture as PNG.');
      }
      final directory = Directory('build/arena-captures');
      await directory.create(recursive: true);
      final file = File('${directory.path}/phase3-arena-visual-review.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file.existsSync() && file.lengthSync() > 10000;
    });

    expect(captured, isTrue,
        reason: 'A non-empty 960x540 arena screenshot must be generated.');
  });
}
