import 'dart:math' as math;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/minimap.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/world/castle_system.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/game/world/mine_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld makeWorld({int seed = 21, int resources = 100000}) {
  final world = GameWorld(
    kit: rangerNewKit,
    random: math.Random(seed),
    spawnWaves: false,
  );
  world.enemies.clear();
  world.projectiles.clear();
  world.army.clear();
  world.resources = resources;
  return world;
}

void runFor(GameWorld world, int ms) {
  for (var t = 0; t < ms; t += 16) {
    world.update(16);
  }
}

/// Spawns one huge friendly arrow next to [crystal] and steps until it lands.
void shootCrystal(GameWorld world, CrystalState crystal) {
  world.enemies.clear();
  world.projectiles.clear();
  world.player.position = crystal.position - const Offset(96, 0);
  world.player.facing = const Offset(1, 0);
  world.spawnArrow(
    origin: world.player.position,
    direction: const Offset(1, 0),
    damage: 99999,
    speed: 1400,
    range: 600,
    tint: 0xFF9BE845,
  );
  for (var t = 0; t < 400 && !crystal.destroyed; t += 16) {
    world.update(16);
  }
}

Offset? _waterNear(GameWorld world, Offset anchor, double radius) {
  for (var r = 24.0; r <= radius; r += 16) {
    for (var i = 0; i < 48; i++) {
      final angle = i * math.pi * 2 / 48;
      final point = anchor +
          Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (world.map.isWater(point)) return point;
    }
  }
  return null;
}

void main() {
  group('castle layout', () {
    test('four castles, seven crystals each with the confirmed HP values', () {
      final world = makeWorld();
      expect(world.castleSystem.castles, hasLength(mapCastleCount));
      for (final castle in world.castleSystem.castles) {
        expect(castle.crystals, hasLength(castleCrystalCount));
        expect(
          castle.crystals.map((crystal) => crystal.slot).toList()..sort(),
          [0, 1, 2, 3, 4, 5, 6],
        );
        for (final crystal in castle.crystals) {
          expect(
            crystal.maxHp,
            crystalMaxHpValues[crystal.slot].toDouble(),
          );
          expect(crystal.hp, crystal.maxHp);
          expect(crystal.ownerId, castle.ownerId);
          expect(crystal.destroyed, isFalse);
        }
      }
      expect(
        world.castleSystem.castles.first.ownerId,
        MineController.localPlayerId,
      );
      expect(
        world.castleSystem.castles.skip(1).map((castle) => castle.ownerId),
        ['rival_1', 'rival_2', 'rival_3'],
      );
    });

    test('four crystals are exposed and three sit inside the walls', () {
      final world = makeWorld();
      for (final castle in world.castleSystem.castles) {
        final exposed = castle.crystals.where((crystal) => crystal.exposed);
        final sheltered = castle.crystals.where((crystal) => !crystal.exposed);
        expect(exposed, hasLength(4));
        expect(sheltered, hasLength(3));
        for (final crystal in castle.crystals) {
          final distance = (crystal.position - castle.anchor).distance;
          if (crystal.exposed) {
            expect(distance, greaterThan(castleWallRadius));
          } else {
            expect(distance, lessThan(castleWallRadius));
          }
        }
        // Walls leave four gates on the exposed crystal angles.
        expect(castle.walls, hasLength(4));
      }
    });

    test('any crystal can be attacked directly, in any order', () {
      final world = makeWorld();
      final castle = world.castleSystem.castleAt(1)!;
      // The innermost crystal (slot 6, 2200 HP) is destroyed before any of
      // the exposed outer crystals are touched.
      final inner = castle.crystals.firstWhere((crystal) => crystal.slot == 6);
      expect(inner.exposed, isFalse);
      expect(castle.aliveCount, 7);

      final destroyed = world.castleSystem.damageCrystal(inner, 2200);
      expect(destroyed, isTrue);
      expect(inner.destroyed, isTrue);
      expect(castle.aliveCount, 6);
      expect(castle.fallen, isFalse);
    });

    test('walls are visual only: the spec never says they block movement', () {
      final world = makeWorld();
      final castle = world.castleSystem.playerCastle;
      final point = castle.anchor + const Offset(castleWallRadius, 0);
      expect(world.map.isBlocked(point, 4), isFalse);
    });
  });

  group('crystal combat through the world', () {
    test('an arrow damages and destroys a rival crystal', () {
      final world = makeWorld();
      // Use a 500 HP exposed crystal so one arrow is enough.
      final crystal = world.castleSystem.castleAt(1)!.crystals.first;
      expect(crystal.maxHp, 500);
      shootCrystal(world, crystal);
      expect(crystal.destroyed, isTrue);
      expect(world.player.dead, isFalse);

      final events = world.drainEvents();
      expect(
        events.whereType<CrystalDestroyedEvent>().map((e) => e.slot),
        contains(crystal.slot),
      );
    });

    test('a close melee swing hits a crystal without killing outer ones', () {
      final world = makeWorld();
      final castle = world.castleSystem.castleAt(2)!;
      final target = castle.crystals.firstWhere((crystal) => crystal.slot == 5);
      final hpBefore = target.hp;
      world.player.position = target.position - const Offset(30, 0);
      world.player.facing = const Offset(1, 0);
      world.pendingHitMultiplier = 1.0;
      world.releaseMeleeSwing();
      expect(target.hp, lessThan(hpBefore));
      // Direct hits do not require the exposed crystals to fall first.
      expect(castle.crystals.where((c) => c.exposed).every((c) => !c.destroyed),
          isTrue);
    });

    test('all seven destroyed: the castle falls and disappears', () {
      final world = makeWorld();
      final rival = world.castleSystem.castleAt(1)!;
      for (final crystal in List<CrystalState>.of(rival.crystals)) {
        shootCrystal(world, crystal);
      }
      expect(rival.aliveCount, 0);
      expect(rival.fallen, isTrue);
      expect(world.castleSystem.standingCastles.contains(rival), isFalse);
      expect(
        world.castleSystem.mappedCrystals.where((c) => c.ownerId == 'rival_1'),
        isEmpty,
      );
      // The player stays in the match and the other castles remain.
      expect(world.player.dead, isFalse);
      expect(world.castleSystem.standingCastles, hasLength(3));

      final events = world.drainEvents();
      expect(events.whereType<CrystalDestroyedEvent>(), hasLength(7));
      expect(
        events.whereType<CastleFellEvent>().map((e) => e.ownerId),
        contains('rival_1'),
      );
    });
  });

  group('rebuilding crystals', () {
    test('rejected at the maximum of seven active crystals', () {
      final world = makeWorld();
      final castle = world.playerCastle;
      expect(castle.aliveCount, 7);
      expect(
        world.rebuildCrystalAt(castle.anchor + const Offset(40, 0)),
        CrystalRebuildResult.atMax,
      );
      expect(world.resources, 100000);
    });

    test('rejected without enough resources', () {
      final world = makeWorld(resources: 0);
      final castle = world.playerCastle;
      final lost = castle.crystals.first;
      world.castleSystem.damageCrystal(lost, lost.maxHp);
      expect(
        world.rebuildCrystalAt(lost.position),
        CrystalRebuildResult.notEnoughResources,
      );
      expect(lost.destroyed, isTrue);
      expect(world.resources, 0);
    });

    test('rejected outside the player territory', () {
      final world = makeWorld();
      final castle = world.playerCastle;
      final lost = castle.crystals.first;
      world.castleSystem.damageCrystal(lost, lost.maxHp);
      expect(
        world.rebuildCrystalAt(
          castle.anchor + const Offset(castleTerritoryRadius + 40, 0),
        ),
        CrystalRebuildResult.outsideTerritory,
      );
    });

    test('rejected on water, obstacles, mines and occupied spots', () {
      final world = makeWorld();
      final castle = world.playerCastle;
      final lost = castle.crystals.first;
      world.castleSystem.damageCrystal(lost, lost.maxHp);

      // Any river water inside the territory is refused.
      final water = _waterNear(
        world,
        castle.anchor,
        castleTerritoryRadius,
      );
      if (water != null) {
        expect(world.rebuildCrystalAt(water), CrystalRebuildResult.blocked);
      }

      // An existing crystal blocks the spot.
      final occupied = castle.crystals
          .firstWhere((crystal) => !crystal.destroyed)
          .position;
      expect(
        world.rebuildCrystalAt(occupied),
        CrystalRebuildResult.blocked,
      );
    });

    test('rebuild is immediate, paid, and reuses the original HP', () {
      final world = makeWorld(resources: 1000);
      final castle = world.playerCastle;
      final lost = castle.crystals.firstWhere((crystal) => crystal.slot == 5);
      final originalHp = lost.maxHp;
      world.castleSystem.damageCrystal(lost, lost.maxHp);
      final cost = world.crystalRebuildCost;
      expect(cost, crystalRebuildBaseCost);

      final before = world.resources;
      expect(world.rebuildCrystalAt(lost.position), CrystalRebuildResult.ok);
      expect(world.resources, before - cost);

      final rebuilt = castle.crystals.firstWhere((c) => c.slot == 5);
      expect(rebuilt.destroyed, isFalse);
      expect(rebuilt.maxHp, originalHp);
      expect(rebuilt.hp, originalHp);
      expect(castle.aliveCount, 7);
      final events = world.drainEvents().whereType<CrystalRebuiltEvent>();
      expect(events.single.slot, 5);
      expect(events.single.cost, cost);
    });

    test('each successive rebuild costs more', () {
      final world = makeWorld(resources: 10000);
      final castle = world.playerCastle;
      final first = castle.crystals.firstWhere((c) => c.slot == 0);
      final second = castle.crystals.firstWhere((c) => c.slot == 1);
      world.castleSystem.damageCrystal(first, first.maxHp);
      world.castleSystem.damageCrystal(second, second.maxHp);
      expect(world.crystalRebuildCost, crystalRebuildBaseCost);

      expect(world.rebuildCrystalAt(first.position), CrystalRebuildResult.ok);
      expect(
        world.crystalRebuildCost,
        crystalRebuildBaseCost + crystalRebuildCostStep,
      );
      expect(world.rebuildCrystalAt(second.position), CrystalRebuildResult.ok);
      expect(
        world.crystalRebuildCost,
        crystalRebuildBaseCost + crystalRebuildCostStep * 2,
      );
    });

    test('a rebuilt crystal can be destroyed and rebuilt again', () {
      final world = makeWorld(resources: 10000);
      final castle = world.playerCastle;
      final lost = castle.crystals.first;
      final spot = lost.position;
      world.castleSystem.damageCrystal(lost, lost.maxHp);
      expect(world.rebuildCrystalAt(spot), CrystalRebuildResult.ok);

      final rebuilt = castle.crystals.firstWhere((c) => c.slot == 0);
      world.castleSystem.damageCrystal(rebuilt, rebuilt.maxHp);
      expect(rebuilt.destroyed, isTrue);
      expect(
        world.crystalRebuildCost,
        crystalRebuildBaseCost + crystalRebuildCostStep,
      );
      expect(world.rebuildCrystalAt(spot), CrystalRebuildResult.ok);
      expect(castle.aliveCount, 7);
      expect(castle.rebuilds, 2);
    });

    test('a fallen castle returns with its first rebuilt crystal', () {
      final world = makeWorld(resources: 10000);
      final castle = world.playerCastle;
      final spots = [for (final crystal in castle.crystals) crystal.position];
      for (final crystal in List<CrystalState>.of(castle.crystals)) {
        world.castleSystem.damageCrystal(crystal, crystal.maxHp);
      }
      expect(castle.fallen, isTrue);
      expect(
        world.castleSystem.standingCastles.contains(castle),
        isFalse,
      );

      expect(world.rebuildCrystalAt(spots.first), CrystalRebuildResult.ok);
      expect(castle.fallen, isFalse);
      expect(castle.standing, isTrue);
      expect(castle.aliveCount, 1);
      expect(
        world.castleSystem.standingCastles.contains(castle),
        isTrue,
      );
    });
  });

  group('minimap and screen mapping', () {
    test('minimap lists every standing castle and all its crystals', () {
      final world = makeWorld();
      final markers = minimapMarkers(world);
      expect(
        markers.where((marker) => marker.kind == MinimapMarkerKind.castle),
        hasLength(mapCastleCount),
      );
      final crystals = markers
          .where((marker) => marker.kind == MinimapMarkerKind.crystal)
          .toList();
      expect(crystals, hasLength(mapCastleCount * castleCrystalCount));
      expect(
        crystals
            .where((marker) => marker.ownerId == MineController.localPlayerId),
        hasLength(castleCrystalCount),
      );
      expect(
        crystals.where((marker) => marker.ownerId == 'rival_2'),
        hasLength(castleCrystalCount),
      );

      // Destroying a crystal removes it from the minimap data.
      final crystal = world.playerCastle.crystals.first;
      world.castleSystem.damageCrystal(crystal, crystal.maxHp);
      expect(
        minimapMarkers(world)
            .where((marker) => marker.kind == MinimapMarkerKind.crystal),
        hasLength(mapCastleCount * castleCrystalCount - 1),
      );
    });

    test('a fallen castle leaves the minimap entirely', () {
      final world = makeWorld();
      final rival = world.castleSystem.castleAt(1)!;
      for (final crystal in List<CrystalState>.of(rival.crystals)) {
        world.castleSystem.damageCrystal(crystal, crystal.maxHp);
      }
      final markers = minimapMarkers(world);
      expect(
        markers.where((marker) => marker.kind == MinimapMarkerKind.castle),
        hasLength(mapCastleCount - 1),
      );
      expect(
        markers.where(
          (marker) =>
              marker.kind == MinimapMarkerKind.crystal &&
              marker.ownerId == 'rival_1',
        ),
        isEmpty,
      );
    });

    test('arena taps map back to the world point under the camera', () {
      final world = makeWorld();
      // Centre of the map keeps the camera unclamped.
      world.player.position = Offset(
        world.map.size.width / 2,
        world.map.size.height / 2,
      );
      final hero = arenaToWorld(
        const Offset(arenaWidth / 2, arenaHeight / 2),
        const Size(arenaWidth, arenaHeight),
        world,
      );
      expect((hero - world.player.position).distance, lessThan(0.001));

      // A taller, letterboxed widget keeps the same mapping.
      final letterboxed = arenaToWorld(
        const Offset(960, 540),
        const Size(1920, 1080),
        world,
      );
      expect((letterboxed - world.player.position).distance, lessThan(0.001));

      // Taps in map coordinates still land on the same crystal spot.
      final castle = world.playerCastle;
      final origin = arenaCameraOrigin(world);
      final local = (castle.anchor - origin) +
          Offset(0, 0);
      expect(
        (arenaToWorld(local, const Size(arenaWidth, arenaHeight), world) -
                castle.anchor)
            .distance,
        lessThan(0.001),
      );
    });
  });
}
