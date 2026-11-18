import 'dart:math' as math;

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/minimap.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/game/world/mine_system.dart';
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

MineController makeController({int seed = 7}) {
  final map = ArenaMap.generate(math.Random(seed));
  return MineController(map: map, random: math.Random(seed));
}

void runFor(GameWorld world, int ms) {
  for (var t = 0; t < ms; t += 16) {
    world.update(16);
  }
}

void main() {
  group('mine capture', () {
    test('starts with eight neutral mines owned by nobody', () {
      final world = makeWorld();
      expect(world.mineSystem.mines, hasLength(mapMineCount));
      expect(world.mineSystem.mines.every((mine) => mine.isNeutral), isTrue);
      expect(world.ownedMineCount, 0);
      expect(
        world.mineSystem.mines.where((m) => m.size == MineSize.small).length,
        3,
      );
      expect(
        world.mineSystem.mines.where((m) => m.size == MineSize.medium).length,
        3,
      );
      expect(
        world.mineSystem.mines.where((m) => m.size == MineSize.large).length,
        2,
      );
    });

    test('needs ten uninterrupted seconds inside the mine area', () {
      final world = makeWorld();
      final mine = world.mineSystem.mines.first;
      world.player.position = mine.position;

      runFor(world, mineCaptureDurationMs - 16);
      expect(mine.isNeutral, isTrue);
      expect(mine.captureProgressMs, greaterThan(0));

      world.update(16);
      expect(mine.owns(MineController.localPlayerId), isTrue);
      expect(world.ownedMineCount, 1);
    });

    test('leaving the area resets progress', () {
      final controller = makeController();
      final mine = controller.mines.first;

      controller.update(
        deltaMs: 5000,
        nowMs: 5000,
        players: {MineController.localPlayerId: mine.position},
      );
      expect(mine.captureProgressMs, 5000);

      controller.update(
        deltaMs: 16,
        nowMs: 5016,
        players: {MineController.localPlayerId: const Offset(0, 0)},
      );
      expect(mine.captureProgressMs, 0);
      expect(mine.isNeutral, isTrue);
    });

    test('several players inside pause the capture until one remains', () {
      final controller = makeController();
      final mine = controller.mines.first;

      controller.update(
        deltaMs: 4000,
        nowMs: 4000,
        players: {'a': mine.position},
      );
      controller.update(
        deltaMs: 3000,
        nowMs: 7000,
        players: {'a': mine.position, 'b': mine.position},
      );
      expect(mine.captureProgressMs, 4000);
      expect(mine.isNeutral, isTrue);

      controller.update(
        deltaMs: 6000,
        nowMs: 13000,
        players: {'a': mine.position},
      );
      expect(mine.owns('a'), isTrue);
    });

    test('an opponent can take an owned mine with the same capture', () {
      final controller = makeController();
      final mine = controller.mines.first;
      mine.ownerId = 'enemy';

      controller.update(
        deltaMs: mineCaptureDurationMs,
        nowMs: mineCaptureDurationMs,
        players: {MineController.localPlayerId: mine.position},
      );
      expect(mine.owns(MineController.localPlayerId), isTrue);
    });

    test('the owner standing in their own mine does not reset ownership', () {
      final controller = makeController();
      final mine = controller.mines.first;
      mine.ownerId = MineController.localPlayerId;

      controller.update(
        deltaMs: 5000,
        nowMs: 5000,
        players: {MineController.localPlayerId: mine.position},
      );
      expect(mine.owns(MineController.localPlayerId), isTrue);
      expect(mine.captureProgressMs, 0);
    });

    test('a player may control several mines at once', () {
      final world = makeWorld();
      for (final mine in world.mineSystem.mines.take(3)) {
        mine.ownerId = MineController.localPlayerId;
      }
      expect(world.ownedMineCount, 3);
      // Ownership does not depend on the hero standing in the mine.
      world.player.position = world.map.castleAnchors.first;
      runFor(world, 1000);
      expect(world.ownedMineCount, 3);
    });

    test('capture emits one event per ownership change', () {
      final world = makeWorld();
      final mine = world.mineSystem.mines.first;
      world.player.position = mine.position;
      world.update(mineCaptureDurationMs);
      world.drainEvents();
      world.update(16);
      expect(
        world.drainEvents().whereType<MineCapturedEvent>().toList(),
        isEmpty,
      );
    });
  });

  group('mine production and pickups', () {
    test('owned mines keep producing while the owner is elsewhere', () {
      final controller = makeController();
      final mine = controller.mines.firstWhere(
        (mine) => mine.size == MineSize.small,
      );
      mine.ownerId = MineController.localPlayerId;
      final far = const Offset(0, 0);

      controller.update(
        deltaMs: 8000,
        nowMs: 8000,
        players: {MineController.localPlayerId: far},
      );
      final produced = controller.pickups.where((p) => p.fromMine).toList();
      expect(produced, hasLength(2));
      expect(produced.every((p) => p.amount == MineSize.small.pickupAmount),
          isTrue);
      for (final pickup in produced) {
        expect((pickup.position - mine.position).distance,
            lessThanOrEqualTo(mine.radius + 1));
      }
    });

    test('each size produces its own interval and amount', () {
      for (final size in MineSize.values) {
        final controller = makeController();
        final mine = controller.mines.firstWhere((mine) => mine.size == size);
        mine.ownerId = MineController.localPlayerId;
        controller.update(
          deltaMs: size.productionIntervalMs,
          nowMs: size.productionIntervalMs,
          players: {MineController.localPlayerId: const Offset(0, 0)},
        );
        final produced = controller.pickups.where((p) => p.fromMine).toList();
        expect(produced, hasLength(1), reason: '$size');
        expect(produced.single.amount, size.pickupAmount);
      }
    });

    test('neutral mines produce nothing', () {
      final controller = makeController();
      controller.update(
        deltaMs: 20000,
        nowMs: 20000,
        players: {MineController.localPlayerId: const Offset(0, 0)},
      );
      expect(controller.pickups.where((p) => p.fromMine), isEmpty);
    });

    test('mines of an opponent produce for that opponent', () {
      final controller = makeController();
      final mine = controller.mines.first;
      mine.ownerId = 'enemy';
      controller.update(
        deltaMs: mine.size.productionIntervalMs,
        nowMs: mine.size.productionIntervalMs,
        players: {MineController.localPlayerId: const Offset(0, 0)},
      );
      expect(controller.pickups.where((p) => p.fromMine), hasLength(1));
    });

    test('pickups must be walked over, never credited automatically', () {
      final world = makeWorld();
      final mine = world.mineSystem.mines.first;
      mine.ownerId = MineController.localPlayerId;
      world.player.position = world.map.castleAnchors.first;
      world.resources = 0;

      runFor(world, mine.size.productionIntervalMs + 32);
      final pickup = world.mineSystem.pickups.firstWhere((p) => p.fromMine);
      expect(world.resources, 0);

      world.player.position = pickup.position;
      world.update(16);
      expect(world.resources, pickup.amount);
      expect(world.mineSystem.pickups.contains(pickup), isFalse);
    });

    test('collection stops at the confirmed starting carry capacity', () {
      final world = makeWorld();
      final mine = world.mineSystem.mines.first;
      mine.ownerId = MineController.localPlayerId;
      world.player.position = world.map.castleAnchors.first;
      runFor(world, mine.size.productionIntervalMs + 32);
      final pickup = world.mineSystem.pickups.firstWhere((p) => p.fromMine);

      world.resources = startingCarryCapacity;
      world.player.position = pickup.position;
      world.update(16);
      expect(world.resources, startingCarryCapacity);
      expect(world.mineSystem.pickups.contains(pickup), isTrue);

      // Exactly enough free room: the pickup is collected in full.
      world.resources = startingCarryCapacity - pickup.amount;
      world.update(16);
      expect(world.resources, startingCarryCapacity);
      expect(world.mineSystem.pickups.contains(pickup), isFalse);
    });

    test('uncollected pickups expire after their lifetime', () {
      final controller = makeController();
      final mine = controller.mines.first;
      mine.ownerId = MineController.localPlayerId;
      controller.update(
        deltaMs: mine.size.productionIntervalMs,
        nowMs: mine.size.productionIntervalMs,
        players: {MineController.localPlayerId: const Offset(0, 0)},
      );
      expect(controller.pickups.where((p) => p.fromMine), hasLength(1));

      controller.update(
        deltaMs: 0,
        nowMs: mine.size.productionIntervalMs + minePickupLifetimeMs + 1,
        players: {MineController.localPlayerId: const Offset(0, 0)},
      );
      expect(controller.pickups.where((p) => p.fromMine), isEmpty);
    });

    test('the map loose resources are collectable and chests are not', () {
      final world = makeWorld();
      final loose =
          world.mineSystem.pickups.where((p) => !p.fromMine).toList();
      expect(loose, hasLength(mapResourcePickupCount));
      final chestCount = world.map.pickups
          .where((pickup) => pickup.kind == PickupKind.chest)
          .length;
      expect(chestCount, mapChestPickupCount);

      world.resources = 0;
      world.player.position = loose.first.position;
      world.update(16);
      expect(world.resources, mapResourcePickupAmount);
      expect(world.mineSystem.pickups.contains(loose.first), isFalse);
    });
  });

  group('world integration and UI data', () {
    test('current mine drives the HUD and reports its capture state', () {
      final world = makeWorld();
      final mine = world.mineSystem.mines.first;
      world.player.position = mine.position;
      world.update(16);
      expect(world.currentMine, same(mine));
      expect(mine.capturerId, MineController.localPlayerId);
      expect(mine.captureFraction, greaterThan(0));

      world.player.position = world.map.castleAnchors.first;
      world.update(16);
      expect(world.currentMine, isNull);
    });

    test('minimap keeps every mine visible and reports ownership', () {
      final world = makeWorld();
      final mine = world.mineSystem.mines.first;
      mine.ownerId = MineController.localPlayerId;

      final markers = minimapMarkers(world);
      final mineMarkers = markers
          .where((marker) => marker.kind == MinimapMarkerKind.mine)
          .toList();
      expect(mineMarkers, hasLength(mapMineCount));
      expect(
        mineMarkers.where((m) => m.ownerId == MineController.localPlayerId),
        hasLength(1),
      );
      expect(mineMarkers.where((m) => m.ownerId == null),
          hasLength(mapMineCount - 1));
    });

    test('the mine wallet is the same match resource used for purchases', () {
      final world = makeWorld();
      final mine = world.mineSystem.mines.first;
      mine.ownerId = MineController.localPlayerId;
      world.player.position = world.map.castleAnchors.first;
      world.resources = 100;

      runFor(world, mine.size.productionIntervalMs + 32);
      final pickup = world.mineSystem.pickups.firstWhere((p) => p.fromMine);
      world.player.position = pickup.position;
      world.update(16);
      expect(world.resources, 100 + pickup.amount);

      final price = MonsterCatalog.def(MonsterType.runner).price;
      expect(world.buyMonster(MonsterType.runner), isTrue);
      expect(world.resources, 100 + pickup.amount - price);
    });
  });
}
