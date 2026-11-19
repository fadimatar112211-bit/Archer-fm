import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/render3/glb.dart';
import 'package:archer_fm/game/render3/hero3d_controller.dart';
import 'package:archer_fm/game/render3/hero3d_painter.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures real GLB-vs-obstacle depth cases through the production arena
/// painter. These images are review evidence, not an automated pixel-quality
/// assertion; they deliberately cover both depth orders and several layouts.
void main() {
  test(
    'captures real Ranger GLB against foreground and background obstacles',
    () async {
      final bytes = File('assets/heroes/ranger_new/ranger_animated.glb')
          .readAsBytesSync();
      final model = await GlbModel.load(Uint8List.fromList(bytes));
      final hero = Hero3DController(Hero3DModel(model));
      hero.model.calibrate();

      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(83),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.army.clear();
      world.corpses.clear();
      final base = world.player.position;
      world.player.facing = const Offset(1, 0);
      world.fog.reveal(base, 900);

      hero.playClip(
        'idle',
        loop: true,
        pace: 1,
        nowMs: world.nowMs,
        events: const [],
      );
      hero.advance(world.nowMs, onEvent: (_) {});

      ui.Image render(Size size) {
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
            hero3d: hero,
          ),
        );
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), size);
        return recorder.endRecording().toImageSync(
          size.width.toInt(),
          size.height.toInt(),
        );
      }

      Future<void> save(String name, ui.Image image) async {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('/tmp/opencode/merge/captures');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File('${dir.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      }

      // Baseline with the real GLB hero and no obstacle. Review this beside
      // the overlap captures to distinguish model visibility from occlusion.
      world.map.obstacles.clear();
      await save('73_glb_hero_no_obstacle_baseline', render(const Size(1920, 1080)));

      // Foreground tree: its ground anchor is deeper than the hero's.
      world.map.obstacles
        ..clear()
        ..add(MapObstacle(
          position: base + const Offset(0, 72),
          radius: 58,
          kind: ObstacleKind.tree,
        ));
      await save('74_glb_tree_foreground_16x9', render(const Size(1920, 1080)));
      await save('75_glb_tree_foreground_wide', render(const Size(2400, 1080)));

      // Background tree: hero should now be painted in front of it.
      world.map.obstacles[0] = MapObstacle(
        position: base - const Offset(0, 72),
        radius: 58,
        kind: ObstacleKind.tree,
      );
      await save('76_glb_tree_background_narrow', render(const Size(1280, 720)));

      // Split-depth tree: the trunk anchor is in front of the hero while
      // the canopy anchor (20.3 world units farther back) is behind it.
      // This is the critical partial-occlusion case for the split painter.
      world.map.obstacles[0] = MapObstacle(
        position: base + const Offset(0, 20),
        radius: 58,
        kind: ObstacleKind.tree,
      );
      await save(
        '78_glb_tree_split_canopy_trunk_16x9',
        render(const Size(1920, 1080)),
      );

      // Foreground rock exercises the non-tree obstacle path.
      world.map.obstacles[0] = MapObstacle(
        position: base + const Offset(0, 42),
        radius: 38,
        kind: ObstacleKind.rock,
      );
      await save('77_glb_rock_foreground_16x9', render(const Size(1920, 1080)));

      expect(model.jointNames, isNotEmpty);
      expect(model.clips.keys, contains('idle'));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
