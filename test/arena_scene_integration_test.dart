import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/render3/glb.dart';
import 'package:archer_fm/game/render3/hero3d_controller.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One end-to-end visual capture of the real arena composition.
///
/// This intentionally uses the production ArenaPainter and Ranger GLB while
/// the same GameWorld owns terrain, the four castles, their 28 crystals,
/// friendly units, hostile units, mines, river/bridges, fog and pickups.
/// The PNG is review evidence; it is not by itself visual approval on a phone.
void main() {
  test(
    'renders hero, both armies, map and crystal castles in one arena scene',
    () async {
      final bytes = File('assets/heroes/ranger_new/ranger_animated.glb')
          .readAsBytesSync();
      final model = await GlbModel.load(Uint8List.fromList(bytes));
      final hero3d = Hero3DController(Hero3DModel(model));
      hero3d.model.calibrate();

      final army = <MonsterType, int>{
        for (final type in MonsterType.values) type: 5,
      };
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(73),
        spawnWaves: false,
        startingArmy: army,
      );

      // Keep the local castle and its crystals near the camera focus.
      final localCastle = world.castleSystem.playerCastle;
      world.player.position = world.map.playerSpawn;
      world.player.facing = const Offset(1, -1);
      world.fog.reveal(world.player.position, 900);
      world.fog.reveal(localCastle.anchor, 900);

      // Four hostile roles are placed inside the explored combat area.
      for (final entry in MonsterType.values.indexed) {
        final type = entry.$1;
        final index = entry.$2;
        final stats = MonsterStats.of(type, 1);
        final enemy = EnemyState(
          id: 'scene_enemy_${type.name}',
          kind: type.name,
          type: type,
          team: MonsterTeam.enemy,
          level: 1,
          position: world.player.position +
              Offset(180 + (index % 2) * 46, -100 + index * 52),
          maxHp: stats.maxHp,
          speed: 0,
          contactDamage: stats.damage,
          xpValue: stats.xpValue,
          radius: stats.radius,
        );
        enemy.hp = stats.maxHp * (1 - index * 0.12);
        enemy.moving = index.isOdd;
        enemy.attackAnimUntilMs = index == 0 ? world.nowMs + 180 : 0;
        world.enemies.add(enemy);
      }

      // Confirm the simulation contains all intended layers before painting.
      expect(world.castleSystem.castles, hasLength(4));
      expect(
        world.castleSystem.castles.fold<int>(
          0,
          (sum, castle) => sum + castle.aliveCount,
        ),
        28,
      );
      expect(world.army, hasLength(GameWorld.startingArmySize));
      expect(world.enemies.map((enemy) => enemy.type).toSet(),
          containsAll(MonsterType.values));
      expect(world.map.rivers, isNotEmpty);
      expect(world.map.obstacles, isNotEmpty);

      hero3d.playClip(
        'idle',
        loop: true,
        pace: 1,
        nowMs: world.nowMs,
        events: const [],
      );
      hero3d.advance(world.nowMs + 180, onEvent: (_) {});

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

      const captureSize = Size(1280, 720);
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), captureSize);
      final image = recorder.endRecording().toImageSync(
            captureSize.width.toInt(),
            captureSize.height.toInt(),
          );

      expect(hero3d.model.drawnTriangles, greaterThan(0));
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(png, isNotNull);
      expect(png!.lengthInBytes, greaterThan(10000));

      final captureDir = Directory('build/arena-captures');
      if (!captureDir.existsSync()) captureDir.createSync(recursive: true);
      File('${captureDir.path}/unified_arena_scene.png')
          .writeAsBytesSync(png.buffer.asUint8List());

      image.dispose();
      hero3d.dispose();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
