import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/game/world/arena_projection.dart';
import 'package:archer_fm/game/world/mine_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld _world(int seed) => GameWorld(
      kit: rangerNewKit,
      random: math.Random(seed),
      spawnWaves: false,
    );

void _paint(GameWorld world) {
  final painter = ArenaPainter(
    world: world,
    presentation: ArenaPresentation(
      kit: rangerNewKit,
      theme: ThemeData(brightness: Brightness.dark),
      sheet: null,
      frameId: null,
      pivotX: 0.5,
      pivotY: 0.85,
      frameWidth: 192,
      frameHeight: 192,
      labels: const [],
      timeMs: world.nowMs,
      comboText: null,
    ),
  );
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(960, 540));
  final image = recorder.endRecording().toImageSync(960, 540);
  expect(image.width, 960);
  image.dispose();
}

void main() {
  group('ArenaPainter mine depth pass', () {
    test('renders every generated mine through the shared actor queue', () {
      final world = _world(401);
      expect(world.mineSystem.mines, isNotEmpty);
      _paint(world);
    });

    test('renders neutral, local and rival owned mines', () {
      final world = _world(409);
      final mines = world.mineSystem.mines;
      expect(mines.length, greaterThanOrEqualTo(3));
      mines[0].ownerId = null;
      mines[1].ownerId = 'player';
      mines[2].ownerId = 'rival_1';
      _paint(world);
    });

    test('renders small medium and large mine markers', () {
      final world = _world(419);
      final seen = world.mineSystem.mines.map((mine) => mine.size).toSet();
      expect(seen, contains(MineSize.small));
      expect(seen, contains(MineSize.medium));
      expect(seen, contains(MineSize.large));
      _paint(world);
    });

    test('renders partial capture progress on depth-sorted mines', () {
      final world = _world(421);
      final mine = world.mineSystem.mines.first;
      mine.capturerId = 'player';
      mine.captureProgressMs = mineCaptureDurationMs * 0.45;
      _paint(world);
      expect(mine.captureFraction, closeTo(0.45, 0.001));
    });

    test('painting mines does not mutate ownership or capture progress', () {
      final world = _world(431);
      final mine = world.mineSystem.mines.first;
      mine.ownerId = 'player';
      mine.capturerId = 'player';
      mine.captureProgressMs = 4321;
      _paint(world);
      expect(mine.ownerId, 'player');
      expect(mine.capturerId, 'player');
      expect(mine.captureProgressMs, 4321);
    });

    test('renders all mine sizes under yawed ground projection', () {
      final world = _world(433);
      final painter = ArenaPainter(
        world: world,
        projection: const ArenaWorldProjection(
          yawRadians: 0.31,
          groundScaleY: 0.76,
          scale: 1.1,
        ),
        presentation: ArenaPresentation(
          kit: rangerNewKit,
          theme: ThemeData(brightness: Brightness.dark),
          sheet: null,
          frameId: null,
          pivotX: 0.5,
          pivotY: 0.85,
          frameWidth: 192,
          frameHeight: 192,
          labels: const [],
          timeMs: world.nowMs,
          comboText: null,
        ),
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(960, 540));
      final image = recorder.endRecording().toImageSync(960, 540);
      expect(image.width, 960);
      image.dispose();
    });

    test('renders map chests as depth-sorted world pickups', () {
      final world = _world(437);
      expect(
        world.map.pickups.where((pickup) => pickup.kind == PickupKind.chest),
        isNotEmpty,
      );
      _paint(world);
    });

    test('renders loose resource piles at their world depth', () {
      final world = _world(438);
      expect(world.mineSystem.pickups, isNotEmpty);
      _paint(world);
    });

    test('pickup rendering preserves map pickup positions and kinds', () {
      final world = _world(440);
      final before = world.map.pickups
          .map((pickup) => [pickup.position, pickup.kind])
          .toList();
      _paint(world);
      expect(
        world.map.pickups
            .map((pickup) => [pickup.position, pickup.kind])
            .toList(),
        before,
      );
    });

    test('renders mine capture ring at zero progress without mutation', () {
      final world = _world(445);
      final mine = world.mineSystem.mines.first;
      mine.capturerId = 'player';
      mine.captureProgressMs = 0;
      _paint(world);
      expect(mine.captureFraction, 0);
    });

    test('renders mine capture ring at full progress', () {
      final world = _world(449);
      final mine = world.mineSystem.mines.first;
      mine.capturerId = 'player';
      mine.captureProgressMs = mineCaptureDurationMs;
      _paint(world);
      expect(mine.captureFraction, 1);
    });

    test('renders rival ownership tint with active capture ring', () {
      final world = _world(451);
      final mine = world.mineSystem.mines.first;
      mine.ownerId = 'rival_2';
      mine.capturerId = 'player';
      mine.captureProgressMs = mineCaptureDurationMs * 0.8;
      _paint(world);
      expect(mine.owns('rival_2'), isTrue);
      expect(mine.captureFraction, closeTo(0.8, 0.001));
    });

    test('painting mines preserves every mine ground position', () {
      final world = _world(457);
      final before = world.mineSystem.mines.map((mine) => mine.position).toList();
      _paint(world);
      expect(world.mineSystem.mines.map((mine) => mine.position).toList(), before);
    });

    test('painting mines preserves mine size and radius', () {
      final world = _world(461);
      final before = world.mineSystem.mines
          .map((mine) => [mine.size, mine.radius])
          .toList();
      _paint(world);
      expect(
        world.mineSystem.mines
            .map((mine) => [mine.size, mine.radius])
            .toList(),
        before,
      );
    });

    test('empty mine collection does not break actor painting', () {
      final world = _world(463);
      world.mineSystem.mines.clear();
      _paint(world);
      expect(world.mineSystem.mines, isEmpty);
    });

    test('mine capture state can be painted in any actor order', () {
      final world = _world(467);
      for (var i = 0; i < world.mineSystem.mines.length; i++) {
        final mine = world.mineSystem.mines[i];
        mine.capturerId = i.isEven ? 'player' : 'rival_1';
        mine.captureProgressMs = mineCaptureDurationMs * ((i % 4) / 4);
      }
      _paint(world);
      expect(
        world.mineSystem.mines.every((mine) => mine.captureFraction >= 0),
        isTrue,
      );
    });

    test('neutral mine remains neutral after rendering', () {
      final world = _world(479);
      final mine = world.mineSystem.mines.first;
      mine.ownerId = null;
      _paint(world);
      expect(mine.isNeutral, isTrue);
    });

    test('resource pickup age and amount are unchanged by rendering', () {
      final world = _world(487);
      final before = world.mineSystem.pickups
          .map((pickup) => [pickup.amount, pickup.bornAtMs, pickup.fromMine])
          .toList();
      _paint(world);
      expect(
        world.mineSystem.pickups
            .map((pickup) => [pickup.amount, pickup.bornAtMs, pickup.fromMine])
            .toList(),
        before,
      );
    });

    test('chest and resource pickup depth passes are repeatable', () {
      final world = _world(491);
      _paint(world);
      _paint(world);
      expect(
        world.map.pickups.where((pickup) => pickup.kind == PickupKind.chest),
        isNotEmpty,
      );
    });

    test('renders quarter mine capture progress', () {
      final world = _world(493);
      final mine = world.mineSystem.mines.first;
      mine.capturerId = 'player';
      mine.captureProgressMs = mineCaptureDurationMs * 0.25;
      _paint(world);
      expect(mine.captureFraction, closeTo(0.25, 0.001));
    });

    test('renders three-quarter mine capture progress', () {
      final world = _world(497);
      final mine = world.mineSystem.mines.first;
      mine.capturerId = 'player';
      mine.captureProgressMs = mineCaptureDurationMs * 0.75;
      _paint(world);
      expect(mine.captureFraction, closeTo(0.75, 0.001));
    });

    test('mine ownership and capture state remain independent per mine', () {
      final world = _world(499);
      final first = world.mineSystem.mines[0];
      final second = world.mineSystem.mines[1];
      first.ownerId = 'player';
      second.ownerId = 'rival_1';
      first.capturerId = 'player';
      second.capturerId = 'rival_2';
      _paint(world);
      expect(first.ownerId, 'player');
      expect(second.ownerId, 'rival_1');
      expect(first.capturerId, 'player');
      expect(second.capturerId, 'rival_2');
    });

    test('chest pickups still render when all mines are absent', () {
      final world = _world(503);
      world.mineSystem.mines.clear();
      expect(
        world.map.pickups.where((pickup) => pickup.kind == PickupKind.chest),
        isNotEmpty,
      );
      _paint(world);
    });

    test('mine rendering still works when map chests are absent', () {
      final world = _world(509);
      world.map.pickups.clear();
      expect(world.mineSystem.mines, isNotEmpty);
      _paint(world);
    });

    test('resource rendering remains safe when loose piles are absent', () {
      final world = _world(521);
      world.mineSystem.pickups.clear();
      _paint(world);
      expect(world.mineSystem.pickups, isEmpty);
    });

    test('multiple resource pickups retain independent positions', () {
      final world = _world(523);
      final before = world.mineSystem.pickups.map((item) => item.position).toList();
      _paint(world);
      expect(world.mineSystem.pickups.map((item) => item.position).toList(), before);
    });

    test('all mine ownership tints can coexist in one render pass', () {
      final world = _world(541);
      for (var i = 0; i < world.mineSystem.mines.length; i++) {
        world.mineSystem.mines[i].ownerId = switch (i % 3) {
          0 => null,
          1 => 'player',
          _ => 'rival_1',
        };
      }
      _paint(world);
      expect(world.mineSystem.mines, isNotEmpty);
    });

    test('mine and chest painter paths coexist without removing either entity', () {
      final world = _world(547);
      final mineCount = world.mineSystem.mines.length;
      final chestCount = world.map.pickups
          .where((pickup) => pickup.kind == PickupKind.chest)
          .length;
      _paint(world);
      expect(world.mineSystem.mines, hasLength(mineCount));
      expect(
        world.map.pickups.where((pickup) => pickup.kind == PickupKind.chest),
        hasLength(chestCount),
      );
    });

    test('projected mine pass remains stable at steep camera yaw', () {
      final world = _world(557);
      final painter = ArenaPainter(
        world: world,
        projection: const ArenaWorldProjection(
          yawRadians: -0.58,
          groundScaleY: 0.69,
          scale: 0.92,
        ),
        presentation: ArenaPresentation(
          kit: rangerNewKit,
          theme: ThemeData(brightness: Brightness.dark),
          sheet: null,
          frameId: null,
          pivotX: 0.5,
          pivotY: 0.85,
          frameWidth: 192,
          frameHeight: 192,
          labels: const [],
          timeMs: world.nowMs,
          comboText: null,
        ),
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(1280, 720));
      final image = recorder.endRecording().toImageSync(1280, 720);
      expect(image.width, 1280);
      image.dispose();
    });

    test('repeated paint keeps mine count and state stable', () {
      final world = _world(439);
      final count = world.mineSystem.mines.length;
      _paint(world);
      _paint(world);
      expect(world.mineSystem.mines, hasLength(count));
    });

    test('mine depth pass keeps pickups in their existing separate pass', () {
      final world = _world(443);
      expect(world.mineSystem.pickups, isNotEmpty);
      final pickups = world.mineSystem.pickups.length;
      _paint(world);
      expect(world.mineSystem.pickups, hasLength(pickups));
    });
  });
}
