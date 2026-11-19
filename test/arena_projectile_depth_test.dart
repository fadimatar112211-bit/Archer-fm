import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArenaPainter projectile depth pass', () {
    test('renders a moving projectile through the shared actor depth queue', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(211),
        spawnWaves: false,
      );
      world.projectiles.add(ProjectileState(
        id: 'depth-test-projectile',
        position: const Offset(470, 280),
        velocity: const Offset(8, 3),
        damage: 10,
        pierceLeft: 0,
        maxTravel: 500,
        tint: 0xFF66CCFF,
        big: false,
      ));
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
      expect(image.height, 540);
      image.dispose();
    });

    test('zero-velocity projectile does not divide by zero during paint', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(223),
        spawnWaves: false,
      );
      world.projectiles.add(ProjectileState(
        id: 'stationary-test-projectile',
        position: const Offset(520, 300),
        velocity: Offset.zero,
        damage: 10,
        pierceLeft: 0,
        maxTravel: 500,
        tint: 0xFFFFAA44,
        big: true,
      ));
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
    });
  });
}
