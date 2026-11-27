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
      const Offset(960, 540),
      const Offset(1660, 200),
      const Offset(250, 900),
      const Offset(1660, 900),
    ];

    final snapshot = <String, dynamic>{
      'phase': 'running',
      'players': players,
      'world': {
        'size': {'width': 1920, 'height': 1080},
        'playerPositions': {
          'p1': {'x': 960, 'y': 540},
          'p2': {'x': 1660, 'y': 200},
          'p3': {'x': 250, 'y': 900},
          'p4': {'x': 1660, 'y': 900},
        },
        'biomes': [
          {'kind': 'forest', 'x': 680, 'y': 420, 'radius': 360},
          {'kind': 'desert', 'x': 1280, 'y': 420, 'radius': 340},
          {'kind': 'snow', 'x': 680, 'y': 760, 'radius': 330},
          {'kind': 'volcanic', 'x': 1280, 'y': 760, 'radius': 350},
        ],
        'rivers': [
          {
            'width': 74,
            'points': [
              {'x': 1160, 'y': 180},
              {'x': 1135, 'y': 420},
              {'x': 1175, 'y': 700},
              {'x': 1150, 'y': 1080},
            ],
            'bridges': [
              {'x': 1150, 'y': 540, 'width': 150, 'depth': 126},
              {'x': 1145, 'y': 350, 'width': 126, 'depth': 104},
            ],
          },
        ],
        'obstacles': [
          {'kind': 'tree', 'x': 760, 'y': 410, 'radius': 34},
          {'kind': 'tree', 'x': 830, 'y': 690, 'radius': 30},
          {'kind': 'tree', 'x': 700, 'y': 760, 'radius': 36},
          {'kind': 'rock', 'x': 1320, 'y': 420, 'radius': 34},
          {'kind': 'rock', 'x': 1370, 'y': 720, 'radius': 38},
          {'kind': 'tree', 'x': 900, 'y': 800, 'radius': 30},
          {'kind': 'tree', 'x': 1050, 'y': 340, 'radius': 29},
        ],
        'mapPickups': [
          {'kind': 'chest', 'x': 900, 'y': 430},
          {'kind': 'chest', 'x': 1250, 'y': 720},
        ],
        'resourcePickups': [
          {'x': 880, 'y': 620, 'amount': 30},
          {'x': 1240, 'y': 450, 'amount': 20},
        ],
        'mines': [
          {'id': 'mine-1', 'x': 820, 'y': 350, 'ownerId': 'p1', 'captureFraction': 1.0},
          {'id': 'mine-2', 'x': 1300, 'y': 350, 'ownerId': 'p2', 'captureFraction': 1.0},
          {'id': 'mine-3', 'x': 820, 'y': 790, 'ownerId': 'p3', 'captureFraction': 0.7},
          {'id': 'mine-4', 'x': 1300, 'y': 790, 'ownerId': 'p4', 'captureFraction': 0.45},
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
            'type': 'werewolf',
            'x': 1040,
            'y': 490,
            'health': 100,
            'maxHealth': 100,
          },
          {
            'id': 'm-tank',
            'ownerId': 'p3',
            'type': 'stoneGolem',
            'x': 1080,
            'y': 610,
            'health': 160,
            'maxHealth': 160,
          },
          {
            'id': 'm-stalker',
            'ownerId': 'p4',
            'type': 'blindStalker',
            'x': 1220,
            'y': 500,
            'health': 90,
            'maxHealth': 90,
          },
          {
            'id': 'm-ranged',
            'ownerId': 'p2',
            'type': 'bogMonster',
            'x': 1190,
            'y': 650,
            'health': 110,
            'maxHealth': 110,
          },
        ],
        'dyingMonsters': const [],
        'projectiles': [
          {'id': 'shot-1', 'ownerId': 'p2', 'x': 1060, 'y': 520},
          {'id': 'shot-2', 'ownerId': 'p3', 'x': 1110, 'y': 570},
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
                  selectedTargetId: 'm-runner',
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
