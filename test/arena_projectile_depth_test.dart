import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/game/world/arena_projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld _world(int seed) => GameWorld(
      kit: rangerNewKit,
      random: math.Random(seed),
      spawnWaves: false,
    );

ProjectileState _projectile({
  required String id,
  required Offset position,
  required Offset velocity,
  bool big = false,
  double visualHeight = 0,
}) =>
    ProjectileState(
      id: id,
      position: position,
      velocity: velocity,
      damage: 10,
      pierceLeft: 0,
      maxTravel: 900,
      tint: 0xFF66CCFF,
      big: big,
      visualHeight: visualHeight,
    );

void _paint(
  GameWorld world, {
  ArenaWorldProjection projection = defaultArenaWorldProjection,
}) {
  final painter = ArenaPainter(
    world: world,
    projection: projection,
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
  expect(image.height, 540);
  image.dispose();
}

void main() {
  group('ArenaPainter projectile depth pass', () {
    test('renders with a non-zero yaw using the injected shared projection', () {
      final world = _world(207);
      world.projectiles.add(_projectile(
        id: 'yawed',
        position: const Offset(480, 280),
        velocity: const Offset(8, 3),
        visualHeight: 32,
      ));
      _paint(
        world,
        projection: const ArenaWorldProjection(
          yawRadians: 0.24,
          groundScaleY: 0.82,
        ),
      );
    });

    test('renders each living castle crystal through the shared actor depth queue', () {
      final world = _world(219);
      for (final castle in world.castleSystem.castles) {
        expect(castle.alive, hasLength(7));
        for (final crystal in castle.alive) {
          // Damaged crystals exercise their HP-bar path as well as the
          // independently sorted crystal draw closure.
          crystal.hp = crystal.maxHp * 0.64;
        }
      }
      _paint(world);
      expect(
        world.castleSystem.castles
            .expand((castle) => castle.alive)
            .length,
        28,
      );
    });

    test('renders a moving projectile through the shared actor depth queue', () {
      final world = _world(211);
      world.projectiles.add(_projectile(
        id: 'moving',
        position: const Offset(470, 280),
        velocity: const Offset(8, 3),
      ));
      _paint(world);
    });

    test('zero-velocity projectile does not divide by zero during paint', () {
      final world = _world(223);
      world.projectiles.add(_projectile(
        id: 'stationary',
        position: const Offset(520, 300),
        velocity: Offset.zero,
        big: true,
      ));
      _paint(world);
    });

    test('renders several projectiles in one frame', () {
      final world = _world(227);
      for (var i = 0; i < 8; i++) {
        world.projectiles.add(_projectile(
          id: 'multi-$i',
          position: Offset(300 + i * 42, 180 + i * 24),
          velocity: Offset(5 + i.toDouble(), 2 - i * 0.2),
          big: i.isEven,
        ));
      }
      _paint(world);
      expect(world.projectiles, hasLength(8));
    });

    test('handles a projectile moving left and upward', () {
      final world = _world(229);
      world.projectiles.add(_projectile(
        id: 'negative-vector',
        position: const Offset(600, 380),
        velocity: const Offset(-12, -7),
      ));
      _paint(world);
    });

    test('handles a fast projectile without changing its simulation position', () {
      final world = _world(233);
      final shot = _projectile(
        id: 'fast',
        position: const Offset(740, 420),
        velocity: const Offset(1400, -900),
      );
      world.projectiles.add(shot);
      final before = shot.position;
      _paint(world);
      expect(shot.position, before);
    });

    test('does not remove or mutate projectile state while painting', () {
      final world = _world(239);
      final shot = _projectile(
        id: 'persistent',
        position: const Offset(420, 240),
        velocity: const Offset(6, 2),
      );
      world.projectiles.add(shot);
      final beforePosition = shot.position;
      final beforeVelocity = shot.velocity;
      _paint(world);
      expect(world.projectiles.single, same(shot));
      expect(shot.position, beforePosition);
      expect(shot.velocity, beforeVelocity);
    });

    test('renders projectiles with no monsters or army units', () {
      final world = _world(241);
      world.enemies.clear();
      world.army.clear();
      world.projectiles.add(_projectile(
        id: 'alone',
        position: const Offset(450, 260),
        velocity: const Offset(7, 1),
      ));
      _paint(world);
    });

    test('renders projectiles alongside corpses and obstacles', () {
      final world = _world(251);
      world.projectiles.add(_projectile(
        id: 'crossing',
        position: const Offset(520, 310),
        velocity: const Offset(9, 4),
      ));
      _paint(world);
    });

    test('renders large projectile with full glow and arrow head', () {
      final world = _world(257);
      world.projectiles.add(_projectile(
        id: 'large',
        position: const Offset(500, 290),
        velocity: const Offset(10, 0),
        big: true,
      ));
      _paint(world);
    });

    test('unlifted projectile visual position equals its ground anchor', () {
      final shot = _projectile(
        id: 'grounded',
        position: const Offset(333, 222),
        velocity: const Offset(4, 1),
      );
      expect(shot.visualHeight, 0);
      expect(shot.visualPosition, shot.position);
    });

    test('lifted projectile visual position offsets upward only', () {
      final shot = _projectile(
        id: 'elevated',
        position: const Offset(333, 222),
        velocity: const Offset(4, 1),
        visualHeight: 48,
      );
      expect(shot.visualPosition, const Offset(333, 174));
      expect(shot.position, const Offset(333, 222));
    });

    test('negative projectile visual height is rejected', () {
      expect(
        () => ProjectileState(
          id: 'below-ground',
          position: Offset.zero,
          velocity: const Offset(1, 0),
          damage: 1,
          pierceLeft: 0,
          maxTravel: 10,
          tint: 0xFFFFFFFF,
          big: false,
          visualHeight: -1,
        ),
        throwsAssertionError,
      );
    });

    test('visual lift renders separately while ground depth anchor stays fixed', () {
      final world = _world(269);
      final shot = _projectile(
        id: 'lifted',
        position: const Offset(540, 320),
        velocity: const Offset(8, 2),
        visualHeight: 64,
      );
      world.projectiles.add(shot);
      final groundAnchor = shot.position;
      _paint(world);
      expect(shot.position, groundAnchor);
      expect(shot.visualHeight, 64);
    });

    test('repeated paint calls remain deterministic for unchanged projectiles', () {
      final world = _world(263);
      final shot = _projectile(
        id: 'repeat',
        position: const Offset(560, 330),
        velocity: const Offset(8, -3),
      );
      world.projectiles.add(shot);
      final position = shot.position;
      _paint(world);
      _paint(world);
      expect(shot.position, position);
      expect(world.projectiles, hasLength(1));
    });
  });
}
