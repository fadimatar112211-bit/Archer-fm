import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/minimap.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/game/world/mine_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual evidence for the match map step: the large generated world, the fog
/// of war with the distance-based enemy rule, and the minimap.
void main() {
  test('paints the generated world and the fog of war', () async {
    final world = GameWorld(
      kit: rangerNewKit,
      random: math.Random(11),
      spawnWaves: false,
    );
    world.enemies.clear();
    world.army.clear();

    // Stand next to a river crossing so the water, banks and bridge are visible.
    final river = world.map.rivers.first;
    final bridge = river.bridges.first;
    world.player.position = bridge.center + const Offset(-140, 60);
    world.player.facing = const Offset(1, 0);
    world.fog.reveal(world.player.position, fogRevealRadius);

    // A few allies and one nearby enemy so scale reads against the terrain.
    final base = world.player.position;
    for (var i = 0; i < 4; i++) {
      world.army.add(
        _monster(
          id: 'ally_$i',
          type: MonsterType.runner,
          team: MonsterTeam.player,
          position: base + Offset(-40.0 + i * 26, 44),
        ),
      );
    }
    world.enemies.add(
      _monster(
        id: 'near_enemy',
        type: MonsterType.tank,
        team: MonsterTeam.enemy,
        position: base + const Offset(180, -90),
      ),
    );

    await _save('30_map_world.png', _paint(world));

    // Explore a trail, then jump far away: the explored trail stays visible
    // while everything the hero has not reached is still hidden.
    for (var step = 0; step < 14; step++) {
      world.fog.reveal(base + Offset(step * 60.0, 0), fogRevealRadius);
    }
    world.player.position = base + const Offset(900, 260);
    world.fog.reveal(world.player.position, fogRevealRadius);

    await _save('31_map_fog.png', _paint(world));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('captures the minimap markers', () async {
    final world = GameWorld(
      kit: rangerNewKit,
      random: math.Random(11),
      spawnWaves: false,
    );
    world.enemies.clear();
    world.army.clear();
    // Show all three mine states: neutral, owned by the hero, enemy-owned.
    world.mineSystem.mines[0].ownerId = MineController.localPlayerId;
    world.mineSystem.mines[1].ownerId = 'enemy';
    // Explore a little so revealed terrain, rivers and markers all render.
    for (var step = 0; step < 10; step++) {
      world.fog.reveal(
        world.map.castleAnchors.first + Offset(step * 70.0, 40),
        fogRevealRadius,
      );
    }

    const captureSize = Size(384, 226);
    final recorder = ui.PictureRecorder();
    MinimapPainter(world: world).paint(Canvas(recorder), captureSize);
    final image = recorder.endRecording().toImageSync(
      captureSize.width.toInt(),
      captureSize.height.toInt(),
    );
    await _save('32_map_minimap.png', image);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('paints owned, neutral and contested mines with pickups', () async {
    final world = GameWorld(
      kit: rangerNewKit,
      random: math.Random(11),
      spawnWaves: false,
    );
    world.enemies.clear();
    world.army.clear();

    final target = world.mineSystem.mines.firstWhere(
      (mine) => mine.size == MineSize.large,
    );
    // Own one mine, let it produce, and stand in a neutral one mid-capture.
    world.mineSystem.mines.first.ownerId = MineController.localPlayerId;
    target.ownerId = null;
    world.player.position =
        target.position + Offset(0, target.radius * 0.2);
    world.fog.reveal(world.player.position, fogRevealRadius);
    world.mineSystem.update(
      deltaMs: 5400,
      nowMs: 5400,
      players: {MineController.localPlayerId: world.player.position},
    );
    world.mineSystem.mines.last.ownerId = 'enemy';

    // Put a few produced pickups next to the owned mine.
    final owned = world.mineSystem.mines.first;
    for (var i = 0; i < 3; i++) {
      world.mineSystem.pickups.add(
        ResourcePickup(
          id: 'shot_$i',
          position: owned.position + Offset(-20.0 + i * 20, owned.radius * 0.75),
          amount: owned.size.pickupAmount,
          bornAtMs: world.nowMs,
        ),
      );
    }

    await _save('33_mines.png', _paint(world));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

ui.Image _paint(GameWorld world) {
  final painter = ArenaPainter(
    world: world,
    presentation: ArenaPresentation(
      kit: rangerNewKit,
      theme: ThemeData(brightness: Brightness.dark),
      sheet: null,
      frameId: null,
      pivotX: 0.5,
      pivotY: 0.5,
      frameWidth: 64,
      frameHeight: 64,
      labels: const [],
      timeMs: world.nowMs,
      comboText: null,
    ),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, const Size(960, 540));
  return recorder.endRecording().toImageSync(960, 540);
}

EnemyState _monster({
  required String id,
  required MonsterType type,
  required MonsterTeam team,
  required Offset position,
}) {
  final stats = MonsterStats.of(type, 1);
  return EnemyState(
    id: id,
    kind: type.name,
    type: type,
    team: team,
    level: 1,
    position: position,
    maxHp: stats.maxHp,
    speed: stats.speed,
    contactDamage: stats.damage,
    xpValue: stats.xpValue,
  );
}

Future<void> _save(String name, ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('/tmp/opencode/merge/captures');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(data!.buffer.asUint8List());
  image.dispose();
}
