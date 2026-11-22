import 'dart:math' as math;

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/minimap.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/world/castle_system.dart';
import 'package:archer_fm/game/world/fog_of_war.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld makeWorld({int seed = 7}) {
  final world = GameWorld(
    kit: rangerNewKit,
    random: math.Random(seed),
    spawnWaves: false,
  );
  world.enemies.clear();
  world.projectiles.clear();
  return world;
}

void main() {
  group('map generation', () {
    test('is large, randomized, and bigger than the camera window', () {
      final maps = [
        for (final seed in const [1, 2, 3, 4, 5])
          ArenaMap.generate(math.Random(seed)),
      ];
      for (final map in maps) {
        expect(
          map.size.width,
          inInclusiveRange(arenaMapMinWidth, arenaMapMaxWidth),
        );
        expect(
          map.size.height,
          inInclusiveRange(arenaMapMinHeight, arenaMapMaxHeight),
        );
        expect(map.size.width, greaterThan(arenaWidth));
        expect(map.size.height, greaterThan(arenaHeight));
      }
      final sizes = maps.map((map) => '${map.size.width}x${map.size.height}');
      expect(sizes.toSet().length, greaterThan(1));
    });

    test('always has four castles inside the map and far apart', () {
      for (var seed = 0; seed < 20; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        expect(map.castleAnchors, hasLength(mapCastleCount));
        for (final castle in map.castleAnchors) {
          expect(castle.dx, greaterThan(100));
          expect(castle.dy, greaterThan(100));
          expect(castle.dx, lessThan(map.size.width - 100));
          expect(castle.dy, lessThan(map.size.height - 100));
          expect(map.isWater(castle), isFalse);
        }
        for (var i = 0; i < map.castleAnchors.length; i++) {
          for (var j = i + 1; j < map.castleAnchors.length; j++) {
            expect(
              (map.castleAnchors[i] - map.castleAnchors[j]).distance,
              greaterThan(300),
            );
          }
        }
      }
    });

    test('has eight mines using the three confirmed sizes', () {
      for (var seed = 0; seed < 10; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        expect(map.mines, hasLength(mapMineCount));
        expect(
          map.mines.where((mine) => mine.size == MineSize.small).length,
          3,
        );
        expect(
          map.mines.where((mine) => mine.size == MineSize.medium).length,
          3,
        );
        expect(
          map.mines.where((mine) => mine.size == MineSize.large).length,
          2,
        );
        for (final mine in map.mines) {
          expect(map.isWater(mine.position), isFalse);
          expect(map.isBlocked(mine.position, mine.radius), isFalse);
        }
      }
    });

    test('adds a river with dry bridges across it', () {
      for (var seed = 0; seed < 10; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        expect(map.rivers, hasLength(greaterThanOrEqualTo(2)));
        // The side stream joins the main channel and has its own dry bridge.
        expect(map.rivers.every((river) => river.points.length > 2), isTrue);
        expect(map.rivers.every((river) => river.bridges.isNotEmpty), isTrue);
        final river = map.rivers.first;
        expect(river.points.length, greaterThan(2));
        expect(river.bridges.length, greaterThanOrEqualTo(2));
        for (final channel in map.rivers) {
          for (final bridge in channel.bridges) {
            // Every crossing belongs to its channel and is dry to walk on.
            expect(channel.contains(bridge.center), isTrue);
            expect(map.isBridge(bridge.center), isTrue);
            expect(map.isWater(bridge.center), isFalse);
            expect(map.movementFactorAt(bridge.center), 1.0);
          }
        }
        // The tributary itself is water away from its bridge deck.
        final tributary = map.rivers[1];
        final tributaryWater = tributary.points[1];
        expect(map.isWater(tributaryWater), isTrue);
        expect(map.movementFactorAt(tributaryWater), waterSpeedFactor);
      }
    });

    test('river channels slow movement everywhere outside bridge decks', () {
      for (var seed = 0; seed < 20; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (final river in map.rivers) {
          var checkedWater = 0;
          for (var i = 0; i < river.points.length - 1; i++) {
            final a = river.points[i];
            final b = river.points[i + 1];
            for (final t in const [0.2, 0.5, 0.8]) {
              final point = Offset(
                a.dx + (b.dx - a.dx) * t,
                a.dy + (b.dy - a.dy) * t,
              );
              if (!river.contains(point) || map.isBridge(point)) continue;
              expect(map.isWater(point), isTrue,
                  reason: 'unbridged river sample should be water, seed $seed');
              expect(map.movementFactorAt(point), waterSpeedFactor,
                  reason: 'unbridged river should slow movement, seed $seed');
              checkedWater++;
            }
          }
          expect(checkedWater, greaterThan(0),
              reason: 'each river must expose testable water, seed $seed');
        }
      }
    });

    test('bridge decks stay dry across their full walkable footprint', () {
      for (var seed = 0; seed < 20; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (final river in map.rivers) {
          for (final bridge in river.bridges) {
            final samples = <Offset>[
              bridge.center,
              Offset(bridge.rect.left + 1, bridge.center.dy),
              Offset(bridge.rect.right - 1, bridge.center.dy),
              Offset(bridge.center.dx, bridge.rect.top + 1),
              Offset(bridge.center.dx, bridge.rect.bottom - 1),
            ];
            for (final point in samples) {
              expect(map.isBridge(point), isTrue,
                  reason: 'bridge edge must remain walkable for seed $seed');
              expect(map.isWater(point), isFalse,
                  reason: 'bridge edge must be dry for seed $seed');
              expect(map.movementFactorAt(point), 1.0,
                  reason: 'bridge edge must not slow movement for seed $seed');
            }
          }
        }
      }
    });

    test('slideMove preserves lateral movement along an obstacle', () {
      final map = ArenaMap.generate(math.Random(73));
      final obstacle = map.obstacles.first;
      final radius = 5.0;
      final from = obstacle.position +
          Offset(-obstacle.radius - radius - 2, 0);
      expect(map.isBlocked(from, radius), isFalse);
      final step = Offset(12, 9);
      expect(map.isBlocked(from + step, radius), isTrue,
          reason: 'diagonal target must intersect the obstacle');
      expect(map.isBlocked(Offset(from.dx, from.dy + step.dy), radius), isFalse,
          reason: 'lateral slide path must remain clear');
      final moved = map.slideMove(from, step, radius);
      expect(map.isBlocked(moved, radius), isFalse);
      expect(moved.dx, closeTo(from.dx, 1e-9),
          reason: 'blocked diagonal should resolve to the clear axis');
      expect(moved.dy, greaterThan(from.dy));
      expect((moved - from).distance, lessThanOrEqualTo(step.distance));
    });

    test('slideMove never crosses the map boundary', () {
      final map = ArenaMap.generate(math.Random(91));
      const radius = 8.0;
      final from = Offset(radius + 1, map.size.height / 2);
      final moved = map.slideMove(from, const Offset(-40, 12), radius);
      expect(moved.dx, greaterThanOrEqualTo(radius));
      expect(moved.dy, greaterThanOrEqualTo(radius));
      expect(moved.dy, lessThanOrEqualTo(map.size.height - radius));
      expect(map.isBlocked(moved, radius), isFalse);
    });

    test('covers all four castle biomes across randomized maps', () {
      final biomeOrders = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        expect(map.biomes, hasLength(mapBiomeKinds),
            reason: 'biome count for seed $seed');
        expect(
          map.biomes.map((patch) => patch.kind).toSet(),
          TerrainKind.values.toSet(),
          reason: 'all biome types for seed $seed',
        );
        for (final patch in map.biomes) {
          expect(patch.radius, greaterThan(150));
        }
        // Each castle quadrant must remain assigned to a different biome.
        final castleBiomes = map.castleAnchors
            .map((castle) => map.biomeAt(castle)?.kind)
            .toList();
        expect(castleBiomes, everyElement(isNotNull),
            reason: 'castle biome coverage for seed $seed');
        expect(castleBiomes.toSet(), TerrainKind.values.toSet(),
            reason: 'distinct castle biomes for seed $seed');
        biomeOrders.add(castleBiomes.map((kind) => kind!.name).join(','));
      }
      // The biome-to-castle assignment is shuffled between matches, not fixed.
      expect(biomeOrders.length, greaterThan(1));
    });

    test('overlapping biome patches resolve to the nearest centre', () {
      var checkedOverlaps = 0;
      for (var seed = 0; seed < 20; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (var y = 160.0; y < map.size.height; y += 48) {
          for (var x = 160.0; x < map.size.width; x += 48) {
            final point = Offset(x, y);
            final covering = map.biomes
                .where((patch) => patch.contains(point))
                .toList();
            if (covering.length < 2) continue;
            covering.sort((left, right) =>
                (left.center - point).distanceSquared.compareTo(
                    (right.center - point).distanceSquared));
            expect(map.biomeAt(point)?.kind, covering.first.kind);
            checkedOverlaps++;
          }
        }
      }
      expect(checkedOverlaps, greaterThan(0));
    });

    test('returns no biome outside every generated region', () {
      for (var seed = 0; seed < 20; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        expect(map.biomeAt(const Offset(-1000, -1000)), isNull);
        expect(map.biomeAt(Offset(map.size.width + 1000,
            map.size.height + 1000)), isNull);
      }
    });

    test('places indestructible trees and rocks out of the water', () {
      final map = ArenaMap.generate(math.Random(7));
      expect(
        map.obstacles.where((o) => o.kind == ObstacleKind.tree).length,
        greaterThan(30),
      );
      expect(
        map.obstacles.where((o) => o.kind == ObstacleKind.rock).length,
        greaterThan(10),
      );
      for (final obstacle in map.obstacles) {
        expect(obstacle.radius, greaterThan(5));
        expect(map.isWater(obstacle.position), isFalse);
      }
    });

    test('spawns all resources and chests on clear dry ground across seeds', () {
      for (var seed = 0; seed < 20; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        expect(
          map.pickups.where((p) => p.kind == PickupKind.resource).length,
          mapResourcePickupCount,
          reason: 'resource count for seed $seed',
        );
        expect(
          map.pickups.where((p) => p.kind == PickupKind.chest).length,
          mapChestPickupCount,
          reason: 'chest count for seed $seed',
        );
        for (final pickup in map.pickups) {
          expect(map.isWater(pickup.position), isFalse,
              reason: 'pickup in water for seed $seed');
          expect(map.isBlocked(pickup.position, 12), isFalse,
              reason: 'pickup blocked by scenery for seed $seed');
          expect(
            map.obstacles.every((obstacle) =>
                (obstacle.position - pickup.position).distance >=
                    obstacle.radius + 24),
            isTrue,
            reason: 'pickup overlaps tree/rock for seed $seed',
          );
        }
      }
    });

    test('keeps castle clearings free of obstacles and river water', () {
      for (var seed = 0; seed < 10; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (final castle in map.castleAnchors) {
          expect(map.isWater(castle), isFalse);
          expect(
            map.obstacles.every(
              (obstacle) => (obstacle.position - castle).distance >= 240,
            ),
            isTrue,
          );
        }
      }
    });
  });

  group('map movement rules', () {
    test('river network keeps both channels and every bridge dry', () {
      for (var seed = 0; seed < 20; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        expect(map.rivers, hasLength(2),
            reason: 'main river and tributary for seed $seed');
        expect(map.rivers.first.bridges, hasLength(2),
            reason: 'main river crossings for seed $seed');
        expect(map.rivers.last.bridges, hasLength(1),
            reason: 'tributary crossing for seed $seed');
        for (final river in map.rivers) {
          for (final bridge in river.bridges) {
            expect(river.contains(bridge.center), isTrue,
                reason: 'bridge must cross its river for seed $seed');
            expect(map.isBridge(bridge.center), isTrue);
            expect(map.isWater(bridge.center), isFalse,
                reason: 'bridge center must be dry for seed $seed');
            expect(map.movementFactorAt(bridge.center), 1.0,
                reason: 'bridge must not slow movement for seed $seed');
          }
        }
      }
      final map = ArenaMap.generate(math.Random(7));
      expect(map.movementFactorAt(map.castleAnchors.first), 1.0);
    });

    test('river water slows movement away from bridges', () {
      final map = ArenaMap.generate(math.Random(7));
      final river = map.rivers.first;
      final sample = river.points[1];
      if (!map.isBridge(sample)) {
        expect(map.isWater(sample), isTrue);
        expect(map.movementFactorAt(sample), waterSpeedFactor);
      }
    });

    test('obstacles block walking and slide along the free axis', () {
      final map = ArenaMap.generate(math.Random(7));
      var checked = 0;
      for (final obstacle in map.obstacles) {
        final start = obstacle.position -
            Offset(obstacle.radius + 24 + 2, 0);
        if (map.isBlocked(start, 24) || map.isWater(start)) continue;
        final target = map.slideMove(start, const Offset(40, 0), 24);
        expect(map.isBlocked(target, 24), isFalse);
        expect(target.dx, lessThan(obstacle.position.dx - obstacle.radius + 1));
        checked++;
        if (checked == 5) break;
      }
      expect(checked, greaterThan(0));
    });

    test('large movement steps cannot tunnel through obstacles', () {
      final map = ArenaMap.generate(math.Random(73));
      final radius = 8.0;
      var checked = false;
      for (final obstacle in map.obstacles) {
        final offset = obstacle.radius + radius + 24;
        final from = obstacle.position - Offset(offset, 0);
        final to = obstacle.position + Offset(offset, 0);
        if (map.isBlocked(from, radius) ||
            map.isBlocked(to, radius) ||
            map.isWater(from) ||
            map.isWater(to)) {
          continue;
        }
        final moved = map.slideMove(from, to - from, radius);
        expect(map.isBlocked(moved, radius), isFalse);
        expect(
          (moved - obstacle.position).distance,
          greaterThanOrEqualTo(obstacle.radius + radius),
          reason: 'fast movement must not cross the obstacle',
        );
        checked = true;
        break;
      }
      expect(checked, isTrue,
          reason: 'seed 73 should provide a clear obstacle crossing');
    });

    test('movement is clamped inside the generated map', () {
      final map = ArenaMap.generate(math.Random(7));
      final clamped =
          map.slideMove(const Offset(10, 10), const Offset(-500, -500), 24);
      expect(clamped.dx, greaterThanOrEqualTo(24));
      expect(clamped.dy, greaterThanOrEqualTo(24));
      final far = map.slideMove(
        Offset(map.size.width - 30, map.size.height - 30),
        const Offset(5000, 5000),
        24,
      );
      expect(far.dx, lessThanOrEqualTo(map.size.width - 24));
      expect(far.dy, lessThanOrEqualTo(map.size.height - 24));
    });
  });

  group('fog of war', () {
    test('starts hidden, reveals around the hero, and stays revealed', () {
      final fog = FogOfWar(worldWidth: 1920, worldHeight: 1080);
      expect(fog.revealedCellCount, 0);
      const hero = Offset(900, 500);
      fog.reveal(hero, fogRevealRadius);
      expect(fog.revealedCellCount, greaterThan(0));
      expect(fog.isRevealed(hero), isTrue);
      final revealed = fog.revealedCellCount;

      fog.reveal(const Offset(1600, 900), fogRevealRadius);
      expect(fog.isRevealed(hero), isTrue);
      expect(fog.revealedCellCount, greaterThan(revealed));
      expect(fog.revealedFraction, greaterThan(0));
      expect(fog.revealedFraction, lessThan(1));
    });

    test('exposes only hidden cells inside the requested view', () {
      final fog = FogOfWar(worldWidth: 1920, worldHeight: 1080);
      fog.reveal(const Offset(200, 200), 200);
      final view = const Rect.fromLTWH(0, 0, 600, 600);
      final hidden = fog.hiddenCellsIn(view).toList();
      expect(hidden, isNotEmpty);
      for (final cell in hidden) {
        expect(fog.isRevealed(cell.center), isFalse);
        expect(view.overlaps(cell), isTrue);
      }
    });
  });

  group('world integration', () {
    test('hero starts beside their castle on clear dry ground', () {
      final world = makeWorld();
      final spawn = world.player.position;
      final home = world.map.castleAnchors.first;
      expect((spawn - home).distance, greaterThan(castleWallRadius + 24 + 20));
      expect((spawn - home).distance, lessThan(240));
      expect(world.map.isWater(spawn), isFalse);
      expect(world.map.isBlocked(spawn, 24), isFalse);
    });

    test('map and exploration are deterministic per seed', () {
      final a = makeWorld(seed: 21);
      final b = makeWorld(seed: 21);
      expect(a.map.size, b.map.size);
      expect(a.map.castleAnchors.first, b.map.castleAnchors.first);
      expect(a.fog.revealedCellCount, b.fog.revealedCellCount);

      final c = makeWorld(seed: 22);
      final differs = c.map.size != a.map.size ||
          c.map.castleAnchors.first != a.map.castleAnchors.first;
      expect(differs, isTrue);
    });

    test('fog reveals around the hero while walking', () {
      final world = makeWorld();
      final before = world.fog.revealedCellCount;
      world.moveInput = const Offset(1, 0);
      for (var i = 0; i < 120; i++) {
        world.update(16);
      }
      expect(world.fog.revealedCellCount, greaterThanOrEqualTo(before));
      expect(world.fog.isRevealed(world.player.position), isTrue);
    });

    test('enemy monsters are only visible when nearby', () {
      final world = makeWorld();
      final near = EnemyState(
        id: 'near',
        kind: 'runner',
        type: MonsterType.runner,
        team: MonsterTeam.enemy,
        level: 1,
        position: world.player.position + const Offset(120, 0),
        maxHp: 60,
        speed: 100,
        contactDamage: 5,
        xpValue: 4,
        radius: 12,
      );
      final far = EnemyState(
        id: 'far',
        kind: 'runner',
        type: MonsterType.runner,
        team: MonsterTeam.enemy,
        level: 1,
        position: world.player.position +
            const Offset(enemyVisibleRadius + 120, 0),
        maxHp: 60,
        speed: 100,
        contactDamage: 5,
        xpValue: 4,
        radius: 12,
      );
      world.enemies.addAll([near, far]);
      expect(world.isEnemyVisible(near), isTrue);
      expect(world.isEnemyVisible(far), isFalse);
      expect(world.visibleEnemies.toList(), [near]);
    });

    test('minimap always lists the hero, castles, crystals and mines', () {
      final world = makeWorld();
      final markers = minimapMarkers(world);
      expect(
        markers,
        hasLength(
          1 + mapCastleCount + mapMineCount + mapCastleCount * castleCrystalCount,
        ),
      );
      expect(
        markers.where((m) => m.kind == MinimapMarkerKind.crystal).length,
        mapCastleCount * castleCrystalCount,
      );
      expect(
        markers.where((m) => m.kind == MinimapMarkerKind.castle).length,
        mapCastleCount,
      );
      expect(
        markers.where((m) => m.kind == MinimapMarkerKind.mine).length,
        mapMineCount,
      );
      final player = markers.firstWhere(
        (m) => m.kind == MinimapMarkerKind.player,
      );
      expect(player.position, world.player.position);
      // Mines are listed even when they are far outside the camera window.
      final farMine = world.map.mines
          .where((mine) => (mine.position - world.player.position).distance >
              enemyVisibleRadius)
          .toList();
      expect(farMine, isNotEmpty);
    });
  });

  testWidgets('minimap widget renders', (tester) async {
    final world = makeWorld();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: ArenaMinimap(world: world))),
      ),
    );
    expect(find.bySemanticsLabel('الخريطة المصغرة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
