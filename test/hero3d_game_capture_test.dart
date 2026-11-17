import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/render3/glb.dart';
import 'package:archer_fm/game/render3/hero3d_controller.dart';
import 'package:archer_fm/game/render3/hero3d_painter.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual capture of the REAL in-game 3D hero through the REAL arena painter,
/// following `game_capture_test.dart`'s plain-test pattern (fast under the
/// qemu software rasterizer). Scripted GameWorld states drive
/// `ArenaPainter.paint` with the real ranger GLB controller in the
/// presentation; PNGs land in /tmp/opencode/merge/captures as gameplay proof.
void main() {
  test(
    'in-game 3D hero battle scenes render through ArenaPainter',
    () async {
      final bytes = File('assets/heroes/ranger_new/ranger_animated.glb')
          .readAsBytesSync();
      final model = await GlbModel.load(Uint8List.fromList(bytes));
      final hero3d = Hero3DController(Hero3DModel(model));
      hero3d.model.calibrate();

      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(7),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.enemies.addAll([
        EnemyState(
          id: 'd1',
          kind: 'slime',
          position: world.player.position + const Offset(160, 10),
          maxHp: 500,
          speed: 0,
          contactDamage: 8,
          xpValue: 10,
        ),
        EnemyState(
          id: 'd2',
          kind: 'archer',
          position: world.player.position + const Offset(-180, -50),
          maxHp: 40,
          speed: 0,
          contactDamage: 6,
          xpValue: 14,
          ranged: true,
        ),
      ]);
      world.player.facing = const Offset(1, 0);

      // Advance the world then pose the 3D hero exactly like the game
      // screen's _updateSprite 3D branch does.
      void pose(String state, {bool loop = true, double pace = 1.0}) {
        hero3d.playClip(
          state,
          loop: loop,
          pace: pace,
          nowMs: world.nowMs,
          events: const [],
        );
        hero3d.advance(world.nowMs, onEvent: (_) {});
      }

      void stepTo(int targetMs) {
        while (world.nowMs < targetMs) {
          world.update(16);
        }
      }

      ui.Image capture() {
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
            hero3d: hero3d,
          ),
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(800, 450));
        return recorder.endRecording().toImageSync(800, 450);
      }

      Future<void> save(String name, ui.Image image) async {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('/tmp/opencode/merge/captures');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File('${dir.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      }

      // 1 — idle in the arena with both dummies around.
      stepTo(600);
      pose('idle');
      await save('71_game_3d_hero_idle', capture());

      // 2 — attack: arrow mid-flight toward the slime, hero facing east.
      world.requestAttack();
      pose('attack', loop: false);
      world.releaseArrow();
      stepTo(world.nowMs + 300);
      await save('72_game_3d_hero_attack', capture());

      // 3 — running north: hero back to the camera, model yaw follows facing.
      world.player.facing = const Offset(0, -1);
      pose('run');
      stepTo(world.nowMs + 500);
      await save('73_game_3d_hero_run', capture());

      // Real combat happened across the scripted scene.
      expect(world.totalDamageDealt, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
