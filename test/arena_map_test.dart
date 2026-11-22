import 'dart:math' as math;

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/minimap.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/progress/progression.dart';
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
            expect(bridge.angle.isFinite, isTrue);
            // A point near each end of the cross-river deck must remain
            // walkable after the deck is rotated with its local river tangent.
            final crossDeckPoint = bridge.center +
                Offset(math.cos(bridge.angle), math.sin(bridge.angle)) *
                    (bridge.width / 2 - 3);
            expect(bridge.contains(crossDeckPoint), isTrue);
            expect(map.isBridge(crossDeckPoint), isTrue);
            expect(map.isWater(crossDeckPoint), isFalse);
            final alongDeck = Offset(
              -math.sin(bridge.angle),
              math.cos(bridge.angle),
            );
            expect(
              bridge.contains(
                bridge.center + alongDeck * (bridge.depth / 2 + 2),
              ),
              isFalse,
              reason: 'rotated deck must not claim dry ground past its end',
            );
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

    test('full cross-river movement over every bridge stays full speed', () {
      for (var seed = 0; seed < 40; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (final river in map.rivers) {
          for (final bridge in river.bridges) {
            final across = Offset(
              math.cos(bridge.angle),
              math.sin(bridge.angle),
            );
            final from = bridge.center -
                across * (bridge.width / 2 + 20);
            final displacement = across * (bridge.width + 40);
            expect(
              map.movementFactorAlong(from, displacement),
              1.0,
              reason: 'bridge crossing must remain full speed for seed $seed',
            );
            for (var step = 0; step <= 16; step++) {
              final point = from + displacement * (step / 16);
              expect(
                map.isWater(point),
                isFalse,
                reason: 'crossing path must be dry for seed $seed',
              );
            }
          }
        }
      }
    });

    test('bridge decks stay dry across their full walkable footprint', () {
      for (var seed = 0; seed < 40; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (final river in map.rivers) {
          for (final bridge in river.bridges) {
            // Probe the actual oriented deck, not the corners of its
            // axis-aligned bounding box (which can lie outside a rotated deck).
            final across = Offset(
              math.cos(bridge.angle),
              math.sin(bridge.angle),
            );
            final along = Offset(-math.sin(bridge.angle), math.cos(bridge.angle));
            final samples = <Offset>[
              bridge.center,
              bridge.center + across * (bridge.width / 2 - 1),
              bridge.center - across * (bridge.width / 2 - 1),
              bridge.center + along * (bridge.depth / 2 - 1),
              bridge.center - along * (bridge.depth / 2 - 1),
              bridge.center + across * (bridge.width * 0.30) +
                  along * (bridge.depth * 0.30),
            ];
            for (final point in samples) {
              expect(bridge.contains(point), isTrue,
                  reason: 'sample must lie on oriented deck for seed $seed');
              expect(map.isBridge(point), isTrue,
                  reason: 'bridge surface must remain walkable for seed $seed');
              expect(map.isWater(point), isFalse,
                  reason: 'bridge surface must be dry for seed $seed');
              expect(map.movementFactorAt(point), 1.0,
                  reason: 'bridge surface must not slow movement for seed $seed');
            }
            final beyondDeckEnd =
                bridge.center + along * (bridge.depth / 2 + 2);
            expect(bridge.contains(beyondDeckEnd), isFalse,
                reason: 'deck must reject points beyond its oriented end');
            expect(map.isWater(beyondDeckEnd), isTrue,
                reason: 'river water must remain exposed beyond the deck');
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

    test('biome centres and uncontested edges keep their assigned terrain', () {
      for (var seed = 0; seed < 32; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (final patch in map.biomes) {
          expect(
            map.biomeAt(patch.center)?.kind,
            patch.kind,
            reason: 'biome centre for seed $seed',
          );
          final edge = patch.center + Offset(patch.radius * 0.82, 0);
          final owners = map.biomes.where((other) => other.contains(edge)).toList();
          if (owners.length == 1) {
            expect(
              map.biomeAt(edge)?.kind,
              patch.kind,
              reason: 'uncontested biome edge for seed $seed',
            );
          }
        }
      }
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

    test('biome interiors stay assigned to their own terrain across seeds', () {
      var checkedCrossings = 0;
      for (var seed = 0; seed < 24; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (final patch in map.biomes) {
          expect(map.biomeAt(patch.center)?.kind, patch.kind,
              reason: 'biome centre ownership for seed $seed');
          final edgePoint = patch.center + Offset(patch.radius * 0.82, 0);
          final owners = map.biomes.where((other) => other.contains(edgePoint)).toList();
          if (owners.length == 1) {
            expect(map.biomeAt(edgePoint)?.kind, patch.kind,
                reason: 'uncontested biome edge for seed $seed');
          }
        }
      }
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

    test('pickups and scenery keep their generated clearance across seeds', () {
      for (var seed = 50; seed < 90; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        for (var i = 0; i < map.pickups.length; i++) {
          final pickup = map.pickups[i];
          expect(pickup.position.dx, inInclusiveRange(0, map.size.width));
          expect(pickup.position.dy, inInclusiveRange(0, map.size.height));
          for (var j = i + 1; j < map.pickups.length; j++) {
            expect(
              (pickup.position - map.pickups[j].position).distance,
              greaterThanOrEqualTo(120),
              reason: 'pickup spacing seed=$seed',
            );
          }
          for (final obstacle in map.obstacles) {
            expect(
              (pickup.position - obstacle.position).distance,
              greaterThanOrEqualTo(obstacle.radius + 24),
              reason: 'pickup/scenery clearance seed=$seed',
            );
          }
        }
        for (var i = 0; i < map.obstacles.length; i++) {
          final obstacle = map.obstacles[i];
          for (var j = i + 1; j < map.obstacles.length; j++) {
            final other = map.obstacles[j];
            expect(
              (obstacle.position - other.position).distance,
              greaterThanOrEqualTo(obstacle.radius + other.radius + 18),
              reason: 'scenery overlap seed=$seed',
            );
          }
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

    test('movement factor samples the full path across water and bridges', () {
      for (var seed = 0; seed < 24; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        final river = map.rivers.first;
        final a = river.points[1];
        final b = river.points[2];
        final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        // Probe perpendicular to the channel so the segment includes both
        // dry banks and unbridged water, rather than checking only its start.
        final tangent = b - a;
        final length = tangent.distance;
        final normal = Offset(-tangent.dy / length, tangent.dx / length);
        final from = midpoint - normal * (river.halfWidth + 36);
        final displacement = normal * (river.halfWidth * 2 + 72);
        if (map.isBridge(midpoint)) continue;
        final factor = map.movementFactorAlong(from, displacement);
        expect(factor, lessThan(1.0),
            reason: 'crossing water must slow the whole movement step, seed $seed');
        expect(factor, greaterThanOrEqualTo(waterSpeedFactor));
        checkedCrossings++;
      }
      expect(checkedCrossings, greaterThan(0),
          reason: 'the seeded river samples must include a non-bridge crossing');
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

  group('movement sampling', () {
    test('movement segments crossing river water cannot remain fully dry', () {
      for (var seed = 1; seed <= 40; seed++) {
        final map = ArenaMap.generate(math.Random(seed));
        var checked = false;
        for (final river in map.rivers) {
          for (var i = 0; i < river.points.length - 1; i++) {
            final a = river.points[i];
            final b = river.points[i + 1];
            final segment = b - a;
            if (segment.distance < 1) continue;
            final tangent = segment / segment.distance;
            final normal = Offset(-tangent.dy, tangent.dx);
            final midpoint = Offset.lerp(a, b, 0.5)!;
            if (!map.isWater(midpoint)) continue;
            final halfSpan = river.width * 0.85;
            final from = midpoint - normal * halfSpan;
            final displacement = normal * (halfSpan * 2);
            final factor = map.movementFactorAlong(from, displacement);
            expect(
              factor,
              lessThan(1.0),
              reason: 'seed=$seed river=$i should account for water on path',
            );
            expect(factor, greaterThanOrEqualTo(waterSpeedFactor));
            checked = true;
            break;
          }
          if (checked) break;
        }
        expect(checked, isTrue, reason: 'seed=$seed must test a river segment');
      }
    });

    test('zero-length movement remains at normal speed', () {
      final map = ArenaMap.generate(math.Random(19));
      expect(map.movementFactorAlong(map.center, Offset.zero), 1.0);
    });
  });

  group('monster economy integration', () {
    test('purchases spend only the matching resource and respect army cap', () {
      final world = makeWorld(seed: 31);
      final startingCount = world.army.length;
      world.resources = MonsterCatalog.def(MonsterType.runner).price - 1;
      final poorBalance = world.resources;
      expect(world.canBuyMonster(MonsterType.runner), isFalse);
      expect(world.buyMonster(MonsterType.runner), isFalse);
      expect(world.resources, poorBalance);
      expect(world.army, hasLength(startingCount));

      world.resources++;
      expect(world.canBuyMonster(MonsterType.runner), isTrue);
      expect(world.buyMonster(MonsterType.runner), isTrue);
      expect(world.resources, 0);
      expect(world.army, hasLength(startingCount + 1));
      expect(world.army.last.type, MonsterType.runner);
      expect(world.army.last.team, MonsterTeam.player);
    });

    test('monster upgrade requires both essence and monster materials', () {
      final world = makeWorld(seed: 32);
      world.essence = 20;
      world.materials[ProgressionMaterial.monster] = 0;
      expect(world.upgradeMonster(MonsterType.tank), isFalse);
      expect(world.essence, 20);
      expect(world.upgrades.levelOf(MonsterType.tank), 1);

      world.materials[ProgressionMaterial.monster] = 1;
      world.essence = 19;
      expect(world.upgradeMonster(MonsterType.tank), isFalse);
      expect(world.essence, 19);
      expect(world.materials[ProgressionMaterial.monster], 1);

      world.essence = 20;
      expect(world.upgradeMonster(MonsterType.tank), isTrue);
      expect(world.essence, 0);
      expect(world.materials[ProgressionMaterial.monster], 0);
      expect(world.upgrades.levelOf(MonsterType.tank), 2);
    });

    test('purchase availability matches each monster price boundary', () {
      for (final type in MonsterType.values) {
        final world = makeWorld(seed: 40 + type.index);
        final price = MonsterCatalog.def(type).price;
        world.resources = price - 1;
        expect(world.canBuyMonster(type), isFalse, reason: type.name);
        world.resources = price;
        expect(world.canBuyMonster(type), isTrue, reason: type.name);
        expect(world.buyMonster(type), isTrue, reason: type.name);
        expect(world.resources, 0, reason: type.name);
        expect(world.army.last.type, type, reason: type.name);
      }
    });

    test('monster upgrades affect future recruits without rewriting survivors', () {
      final world = makeWorld(seed: 44);
      final original = world.army.firstWhere(
        (monster) => monster.type == MonsterType.tank,
      );
      final oldHp = original.maxHp;
      final oldDamage = original.contactDamage;
      world.resources = 100000;
      world.essence = world.upgrades.upgradeCost(MonsterType.tank);
      world.materials[ProgressionMaterial.monster] = 1;

      expect(world.upgradeMonster(MonsterType.tank), isTrue);
      expect(world.upgrades.levelOf(MonsterType.tank), 2);
      expect(original.level, 1);
      expect(original.maxHp, oldHp);
      expect(original.contactDamage, oldDamage);

      expect(world.buyMonster(MonsterType.tank), isTrue);
      final recruit = world.army.last;
      final levelTwo = MonsterStats.of(MonsterType.tank, 2);
      expect(recruit.level, 2);
      expect(recruit.maxHp, levelTwo.maxHp);
      expect(recruit.contactDamage, levelTwo.damage);
      expect(recruit.speed, levelTwo.speed);
    });

    test('max-level monster upgrade is rejected without spending resources', () {
      final world = makeWorld(seed: 45);
      world.upgrades.loadFromMap({'tank': monsterMaxLevel});
      world.essence = 100000;
      world.materials[ProgressionMaterial.monster] = 100;
      final essenceBefore = world.essence;
      final materialsBefore = world.materials[ProgressionMaterial.monster];

      expect(world.upgradeMonster(MonsterType.tank), isFalse);
      expect(world.upgrades.levelOf(MonsterType.tank), monsterMaxLevel);
      expect(world.essence, essenceBefore);
      expect(world.materials[ProgressionMaterial.monster], materialsBefore);
    });

    test('army purchase cap rejects without charging resources', () {
      final world = makeWorld(seed: 33);
      world.resources = 100000;
      for (var i = world.army.length; i < maxArmySize; i++) {
        expect(world.buyMonster(MonsterType.runner), isTrue);
      }
      final balance = world.resources;
      final count = world.army.length;
      expect(world.canBuyMonster(MonsterType.tank), isFalse);
      expect(world.buyMonster(MonsterType.tank), isFalse);
      expect(world.resources, balance);
      expect(world.army, hasLength(count));
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

    test('hostile monsters damage a nearby home crystal when hero is absent', () {
      final world = makeWorld(seed: 61);
      world.player.dead = true;
      world.army.clear();
      world.enemies.clear();
      final crystal = world.castleSystem.playerCastle.alive.first;
      final stats = MonsterStats.of(MonsterType.tank, 1);
      final attacker = EnemyState(
        id: 'crystal_attacker',
        kind: MonsterType.tank.name,
        type: MonsterType.tank,
        team: MonsterTeam.enemy,
        level: 1,
        position: crystal.position + const Offset(40, 0),
        maxHp: stats.maxHp,
        speed: stats.speed,
        contactDamage: stats.damage,
        xpValue: stats.xpValue,
        radius: stats.radius,
      );
      world.enemies.add(attacker);
      final hpBefore = crystal.hp;

      world.update(16);
      expect(crystal.hp, hpBefore - stats.damage);
      expect(attacker.attackCooldownUntilMs, greaterThan(world.nowMs));

      world.update(16);
      expect(crystal.hp, hpBefore - stats.damage,
          reason: 'crystal damage must respect the monster attack cooldown');
    });

    test('hostile monsters do not hit home crystals while hero distracts them', () {
      final world = makeWorld(seed: 62);
      world.army.clear();
      world.enemies.clear();
      final crystal = world.castleSystem.playerCastle.alive.first;
      final stats = MonsterStats.of(MonsterType.tank, 1);
      final attacker = EnemyState(
        id: 'distracted_crystal_attacker',
        kind: MonsterType.tank.name,
        type: MonsterType.tank,
        team: MonsterTeam.enemy,
        level: 1,
        position: crystal.position + const Offset(40, 0),
        maxHp: stats.maxHp,
        speed: stats.speed,
        contactDamage: stats.damage,
        xpValue: stats.xpValue,
        radius: stats.radius,
      );
      world.player.position = attacker.position + const Offset(40, 0);
      world.enemies.add(attacker);
      final hpBefore = crystal.hp;

      world.update(16);

      expect(crystal.hp, hpBefore,
          reason: 'the nearby hero must distract the hostile monster');
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
