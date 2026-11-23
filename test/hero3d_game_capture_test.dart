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
/// presentation; PNGs land in build/arena-captures as gameplay proof.
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
        final dir = Directory('build/arena-captures');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File('${dir.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      }

      // 1 — deliberate three-quarter face-readability capture; the eight-direction suite
      // still verifies all gameplay facings; this dedicated frame avoids judging
      // face readability from a back-facing run pose.
      stepTo(600);
      world.player.facing = const Offset(1, -1);
      pose('idle');
      await save('70_game_3d_hero_face_3quarter_idle', capture());

      // 2 — idle battle frame with enemies at the sides.
      world.player.facing = const Offset(1, 0);
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

  test(
    'all four 3D heroes render from all eight gameplay camera directions',
    () async {
      final heroes = [
        [
          'assets/heroes/ranger_new/ranger_animated.glb',
          'ranger_new',
          'ranger',
        ],
        [
          'assets/heroes/flame/model/flame_animated.glb',
          'flame',
          'flame',
        ],
        [
          'assets/heroes/shadow/model/shadow_animated.glb',
          'shadow',
          'shadow',
        ],
        [
          'assets/heroes/storm/model/storm_animated.glb',
          'storm',
          'storm',
        ],
      ];
      const facings = <Offset>[
        Offset(0, -1), // north
        Offset(1, -1),  // north-east
        Offset(1, 0),   // east
        Offset(1, 1),   // south-east
        Offset(0, 1),   // south
        Offset(-1, 1),  // south-west
        Offset(-1, 0),  // west
        Offset(-1, -1), // north-west
      ];
      const directionNames = [
        'n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw',
      ];

      for (final entry in heroes) {
        final bytes = File(entry[0]).readAsBytesSync();
        final model = await GlbModel.load(Uint8List.fromList(bytes));
        final hero3d = Hero3DController(Hero3DModel(model, heroId: entry[1] as String));
        hero3d.model.calibrate();
        expect(model.jointNames.length, greaterThan(0), reason: entry[1]);
        expect(model.clips.keys, containsAll([
          'idle', 'walk', 'run', 'attack', 'skill', 'dodge', 'hit', 'death',
        ]), reason: entry[1]);

        final kit = kitForHero(entry[2]);
        final world = GameWorld(
          kit: kit,
          random: math.Random(7),
          spawnWaves: false,
        );
        world.enemies.clear();
        world.enemies.add(
          EnemyState(
            id: 'dummy',
            kind: 'slime',
            position: world.player.position + const Offset(150, 10),
            maxHp: 500,
            speed: 0,
            contactDamage: 8,
            xpValue: 10,
          ),
        );

        // A dedicated front/three-quarter idle frame is required for
        // every production hero. Triangle-count-only directional captures
        // cannot prove that the face, eyes, weapon and silhouette are readable.
        world.player.facing = const Offset(1, 1);
        hero3d.playClip(
          'idle',
          loop: true,
          pace: 1.0,
          nowMs: world.nowMs,
          events: const [],
        );
        hero3d.advance(world.nowMs + 180, onEvent: (_) {});
        final facePainter = ArenaPainter(
          world: world,
          presentation: ArenaPresentation(
            kit: kit,
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
        final faceRecorder = ui.PictureRecorder();
        facePainter.paint(Canvas(faceRecorder), const Size(800, 450));
        expect(
          hero3d.model.drawnTriangles,
          greaterThan(0),
          reason: '${entry[1]} front/three-quarter idle face capture',
        );
        final faceImage = faceRecorder.endRecording().toImageSync(800, 450);
        final faceData = await faceImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        final captureDir = Directory('build/arena-captures');
        if (!captureDir.existsSync()) captureDir.createSync(recursive: true);
        File('${captureDir.path}/hero_${entry[1]}_face_idle.png')
            .writeAsBytesSync(faceData!.buffer.asUint8List());
        faceImage.dispose();

        // Every authored state is now exercised through the runtime GLB
        // controller and arena painter for each of the four heroes. This
        // catches clips that exist in metadata but fail to produce visible
        // skinned geometry, and leaves a full review strip in CI artifacts.
        const heroStates = [
          'idle', 'walk', 'run', 'attack', 'skill', 'dodge', 'hit', 'death',
        ];
        for (final state in heroStates) {
          hero3d.playClip(
            state,
            loop: state == 'idle' || state == 'walk' || state == 'run',
            pace: 1.0,
            nowMs: world.nowMs,
            events: const [],
          );
          hero3d.advance(world.nowMs + 480, onEvent: (_) {});
          final statePainter = ArenaPainter(
            world: world,
            presentation: ArenaPresentation(
              kit: kit,
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
          final stateRecorder = ui.PictureRecorder();
          statePainter.paint(Canvas(stateRecorder), const Size(800, 450));
          expect(
            hero3d.model.drawnTriangles,
            greaterThan(0),
            reason: '${entry[1]} state $state must produce visible geometry',
          );
          final stateImage =
              stateRecorder.endRecording().toImageSync(800, 450);
          final stateData = await stateImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final stateDir = Directory('build/arena-captures');
          if (!stateDir.existsSync()) stateDir.createSync(recursive: true);
          File('${stateDir.path}/hero_${entry[1]}_state_$state.png')
              .writeAsBytesSync(stateData!.buffer.asUint8List());
          stateImage.dispose();
        }

        // Isolated close-ups use the exact runtime Hero3DController painter,
        // but remove the arena camera/map scale from the review. Eight yaw
        // samples let reviewers identify the actual face-forward convention
        // instead of assuming a 2D facing vector is the model's front.
        final closeupViews = <List<Object>>[
          ['yaw_0', const Offset(0, 1)],
          ['yaw_45', const Offset(1, 1)],
          ['yaw_90', const Offset(1, 0)],
          ['yaw_135', const Offset(1, -1)],
          ['yaw_180', const Offset(0, -1)],
          ['yaw_225', const Offset(-1, -1)],
          ['yaw_270', const Offset(-1, 0)],
          ['yaw_315', const Offset(-1, 1)],
        ];
        for (final view in closeupViews) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 800, 800),
            Paint()..color = const Color(0xFF30343A),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(400, 680),
              width: 310,
              height: 58,
            ),
            Paint()..color = const Color(0x55000000),
          );
          hero3d.paint(
            canvas,
            anchor: const Offset(400, 660),
            facing: view[1] as Offset,
            scale: hero3d.scaleForPixelHeight(700),
          );
          final bounds = hero3d.model.drawnBounds;
          final drawnHeight = bounds[3] - bounds[1];
          expect(
            drawnHeight,
            greaterThan(300),
            reason: '${entry[1]} isolated close-up ${view[0]} must be large enough to inspect',
          );
          expect(
            drawnHeight,
            lessThan(700),
            reason: '${entry[1]} isolated close-up ${view[0]} must remain inside its review frame',
          );
          final image = recorder.endRecording().toImageSync(800, 800);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final captureDir = Directory('build/arena-captures');
          if (!captureDir.existsSync()) captureDir.createSync(recursive: true);
          File('${captureDir.path}/hero_${entry[1]}_${view[0]}_closeup.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        }

        for (var i = 0; i < facings.length; i++) {
          world.player.facing = facings[i];
          hero3d.playClip(
            'attack',
            loop: false,
            pace: 1.0,
            nowMs: world.nowMs,
            events: const [],
          );
          hero3d.advance(world.nowMs + 1200, onEvent: (_) {});
          final painter = ArenaPainter(
            world: world,
            presentation: ArenaPresentation(
              kit: kit,
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
          expect(
            hero3d.model.drawnTriangles,
            greaterThan(0),
            reason: '${entry[1]} facing ${directionNames[i]}',
          );
          final image = recorder.endRecording().toImageSync(800, 450);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('build/arena-captures');
          if (!dir.existsSync()) dir.createSync(recursive: true);
          File('${dir.path}/hero_${entry[1]}_${directionNames[i]}.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
