import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_army.dart';
import 'package:archer_fm/monsters/monster_combat.dart';
import 'package:archer_fm/monsters/monster_combat_resolver.dart';
import 'package:archer_fm/monsters/monster_match_combat_loop.dart';
import 'package:archer_fm/monsters/monster_projectile_manager.dart';
import 'package:archer_fm/monsters/monster_ranged_attack_handler.dart';
import 'package:archer_fm/monsters/monster_attack_slots.dart';
import 'package:archer_fm/monsters/monster_formation_movement.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_navigation.dart';

MonsterStats _stats({double attackRange = 20, double moveSpeed = 100}) =>
    MonsterStats(
      maxHealth: 100,
      damage: 10,
      moveSpeed: moveSpeed,
      attackRange: attackRange,
      attackCooldown: const Duration(seconds: 1),
      purchaseCost: 10,
    );

MonsterUnit _unit(
  String id, {
  String ownerId = 'p1',
  double x = 0,
  double y = 0,
  double attackRange = 20,
  double moveSpeed = 100,
  MonsterOrder order = MonsterOrder.auto,
}) =>
    MonsterUnit(
      id: id,
      ownerId: ownerId,
      type: MonsterType.runner,
      positionX: x,
      positionY: y,
      stats: _stats(attackRange: attackRange, moveSpeed: moveSpeed),
      order: order,
    );

MonsterCatalog _catalog() => MonsterCatalog({
      for (final type in MonsterType.values)
        type: MonsterDefinition(type: type, baseStats: _stats()),
    });

void main() {
  group('Monster A* navigation', () {
    test('routes around a wall instead of crossing blocked cells', () {
      final grid = MonsterNavigationGrid(
        columns: 7,
        rows: 5,
        cellSize: 10,
        blocked: {
          for (var y = 0; y < 4; y++) MonsterGridCell(3, y),
        },
      );
      final path = MonsterPathfinder().findPath(
        grid: grid,
        startX: 15,
        startY: 15,
        goalX: 55,
        goalY: 15,
      );

      expect(path, isNotNull);
      expect(path!.first, const MonsterGridCell(1, 1));
      expect(path.last, const MonsterGridCell(5, 1));
      expect(path.any((cell) => cell.y == 4), isTrue);
      expect(path.any((cell) => grid.blockedCells.contains(cell)), isFalse);
    });

    test('does not cut diagonally between two blocked corners', () {
      final grid = MonsterNavigationGrid(
        columns: 2,
        rows: 2,
        cellSize: 10,
        blocked: {
          const MonsterGridCell(1, 0),
          const MonsterGridCell(0, 1),
        },
      );
      expect(
        MonsterPathfinder().findPath(
          grid: grid,
          startX: 5,
          startY: 5,
          goalX: 15,
          goalY: 15,
        ),
        isNull,
      );
    });

    test('cached routes are invalidated when map revision changes', () {
      final unit = _unit('path-unit', x: 5, y: 5);
      final planner = MonsterPathfinder();
      final openGrid = MonsterNavigationGrid(
        columns: 8,
        rows: 4,
        cellSize: 10,
        revision: 1,
      );
      expect(
        planner.nextWaypoint(
          unit: unit,
          grid: openGrid,
          targetX: 65,
          targetY: 5,
        ),
        isNotNull,
      );
      expect(planner.cachedRouteCount, 1);

      final blockedGrid = MonsterNavigationGrid(
        columns: 8,
        rows: 4,
        cellSize: 10,
        revision: 2,
        blocked: {
          for (var y = 0; y < 4; y++) MonsterGridCell(3, y),
        },
      );
      expect(
        planner.nextWaypoint(
          unit: unit,
          grid: blockedGrid,
          targetX: 65,
          targetY: 5,
        ),
        isNull,
      );
      expect(planner.cachedRouteCount, 0);
    });

    test('uses world-space coordinates when the grid has a non-zero origin',
        () {
      final unit = _unit('origin-unit', x: 105, y: 55);
      final grid = MonsterNavigationGrid(
        columns: 3,
        rows: 2,
        cellSize: 10,
        originX: 100,
        originY: 50,
      );
      final waypoint = MonsterPathfinder().nextWaypoint(
        unit: unit,
        grid: grid,
        targetX: 125,
        targetY: 55,
      );

      expect(waypoint, (115.0, 55.0));
    });

    test('replans when a unit is displaced away from its cached route', () {
      final unit = _unit('displaced-unit', x: 5, y: 5);
      final grid = MonsterNavigationGrid(
        columns: 8,
        rows: 4,
        cellSize: 10,
      );
      final planner = MonsterPathfinder();
      final first = planner.nextWaypoint(
        unit: unit,
        grid: grid,
        targetX: 65,
        targetY: 5,
      );
      expect(first, (15.0, 5.0));

      unit.positionY = 35;
      final recovered = planner.nextWaypoint(
        unit: unit,
        grid: grid,
        targetX: 65,
        targetY: 5,
      );

      expect(recovered, isNotNull);
      expect(recovered!.$2, greaterThan(5));
    });

    test('respects the configured A* expansion budget', () {
      final grid = MonsterNavigationGrid(
        columns: 30,
        rows: 30,
        cellSize: 10,
      );
      final path = MonsterPathfinder(maxExpandedNodes: 1).findPath(
        grid: grid,
        startX: 5,
        startY: 5,
        goalX: 285,
        goalY: 285,
      );
      expect(path, isNull);
    });

    test('rejects invalid grid and pathfinder settings', () {
      expect(
        () => MonsterNavigationGrid(columns: 0, rows: 2, cellSize: 10),
        throwsArgumentError,
      );
      expect(() => MonsterPathfinder(maxExpandedNodes: 0), throwsArgumentError);
      expect(
        () => MonsterPathfinder().findPath(
          grid: MonsterNavigationGrid(columns: 2, rows: 2, cellSize: 10),
          startX: double.nan,
          startY: 0,
          goalX: 10,
          goalY: 10,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Automatic attack slot reservations', () {
    test('assigns stable unique approach points and prunes dead units', () {
      final units = List.generate(20, (index) => _unit('u-$index', attackRange: 100));
      final target = const MonsterTarget(
        id: 'crystal-enemy',
        ownerId: 'p2',
        kind: MonsterTargetKind.crystal,
        x: 200,
        y: 100,
        isAlive: true,
      );
      final coordinator = MonsterAttackSlotCoordinator();
      Map<String, (double, double)> assign(List<MonsterUnit> current) =>
          coordinator.assignForTargets(
            unitsByTarget: {'crystal-enemy': current},
            targetsById: {'crystal-enemy': target},
          );

      final first = assign(units);
      final second = assign(units);
      expect(first.length, 20);
      expect(first.values.toSet().length, 20);
      expect(second, first);
      expect(coordinator.activeReservationCount, 20);

      final remaining = units.sublist(1);
      final third = assign(remaining);
      expect(third.length, 19);
      expect(coordinator.activeReservationCount, 19);
    });

    test('releases reservations when a unit changes target', () {
      final unit = _unit('switcher', attackRange: 50);
      final firstTarget = const MonsterTarget(
        id: 'first',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: 50,
        y: 0,
        isAlive: true,
      );
      final secondTarget = const MonsterTarget(
        id: 'second',
        ownerId: 'p3',
        kind: MonsterTargetKind.hero,
        x: 100,
        y: 0,
        isAlive: true,
      );
      final coordinator = MonsterAttackSlotCoordinator();
      coordinator.assignForTargets(
        unitsByTarget: {'first': [unit]},
        targetsById: {'first': firstTarget},
      );
      expect(coordinator.activeReservationCount, 1);

      coordinator.assignForTargets(
        unitsByTarget: {'second': [unit]},
        targetsById: {'second': secondTarget},
      );
      expect(coordinator.activeReservationCount, 1);
    });
  });

  group('Automatic crystal defense', () {
    test('auto order prioritizes an enemy threatening an owned crystal', () {
      final unit = _unit('defender', x: 0, y: 0);
      const friendlyCrystal = MonsterTarget(
        id: 'home-crystal',
        ownerId: 'p1',
        kind: MonsterTargetKind.crystal,
        x: 0,
        y: 100,
        isAlive: true,
      );
      const nearestEnemy = MonsterTarget(
        id: 'nearest',
        ownerId: 'p3',
        kind: MonsterTargetKind.hero,
        x: 20,
        y: 0,
        isAlive: true,
      );
      const crystalThreat = MonsterTarget(
        id: 'threat',
        ownerId: 'p2',
        kind: MonsterTargetKind.monster,
        x: 0,
        y: 80,
        isAlive: true,
      );

      expect(
        const MonsterTargeting().selectCombatTarget(
          unit: unit,
          candidates: [friendlyCrystal, nearestEnemy, crystalThreat],
        )?.id,
        'threat',
      );
      unit.order = MonsterOrder.advance;
      expect(
        const MonsterTargeting().selectCombatTarget(
          unit: unit,
          candidates: [friendlyCrystal, nearestEnemy, crystalThreat],
        )?.id,
        'nearest',
      );
    });

    test('auto defense reacts to threats when a unit is already guarding home', () {
      final unit = _unit('home-guard', x: 0, y: 10, attackRange: 20);
      const home = MonsterTarget(
        id: 'home',
        ownerId: 'p1',
        kind: MonsterTargetKind.crystal,
        x: 0,
        y: 0,
        isAlive: true,
      );
      const nearestButSafe = MonsterTarget(
        id: 'safe-nearest',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: 0,
        y: 25,
        isAlive: true,
      );
      const homeThreat = MonsterTarget(
        id: 'home-threat',
        ownerId: 'p3',
        kind: MonsterTargetKind.monster,
        x: 0,
        y: -15,
        isAlive: true,
      );

      expect(
        const MonsterTargeting().selectCombatTarget(
          unit: unit,
          candidates: [home, nearestButSafe, homeThreat],
        )?.id,
        'home-threat',
      );
    });

    test('defend order returns to its owned crystal after a threat clears', () {
      final unit = _unit(
        'returning-guard',
        x: 200,
        y: 0,
        order: MonsterOrder.defend,
        moveSpeed: 10,
      );
      const home = MonsterTarget(
        id: 'home-crystal',
        ownerId: 'p1',
        kind: MonsterTargetKind.crystal,
        x: 0,
        y: 0,
        isAlive: true,
      );
      const distantEnemy = MonsterTarget(
        id: 'distant-enemy',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: 1000,
        y: 0,
        isAlive: true,
      );

      const MonsterCombatController().updateUnit(
        unit: unit,
        candidates: [home, distantEnemy],
        now: DateTime.utc(2026, 11, 17),
        elapsed: Duration(seconds: 1),
      );

      expect(unit.targetId, isNull);
      expect(unit.positionX, lessThan(200));
    });

    test('defend order stays home when there is no active threat', () {
      final unit = _unit('guard', order: MonsterOrder.defend);
      const crystal = MonsterTarget(
        id: 'home',
        ownerId: 'p1',
        kind: MonsterTargetKind.crystal,
        x: 0,
        y: 20,
        isAlive: true,
      );
      const distantEnemy = MonsterTarget(
        id: 'enemy',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: 200,
        y: 0,
        isAlive: true,
      );
      expect(
        const MonsterTargeting().selectCombatTarget(
          unit: unit,
          candidates: [crystal, distantEnemy],
        ),
        isNull,
      );
    });
  });

  group('Hard movement collision resolution', () {
    test('a large movement step cannot tunnel through a circular obstacle', () {
      final unit = _unit('collision', x: 0, y: 0, moveSpeed: 100);
      const obstacle = MonsterMovementObstacle(x: 50, y: 0, radius: 10);
      const movement = MonsterFormationMovement(obstacleClearance: 8);
      movement.moveUnitToward(
        unit: unit,
        allies: const [],
        targetX: 100,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
        obstacles: const [obstacle],
      );

      final dx = unit.positionX - obstacle.x;
      final dy = unit.positionY - obstacle.y;
      expect(math.sqrt(dx * dx + dy * dy), greaterThanOrEqualTo(18 - 1e-6));
      expect(unit.positionX, lessThan(100));
    });
  });

  group('Terrain-aware movement speed', () {
    test('surface multiplier scales per-unit travel without changing base stats',
        () {
      final unit = _unit('slow-surface', x: 0, y: 0, attackRange: 0, moveSpeed: 100);
      const movement = MonsterFormationMovement();

      movement.moveUnitToward(
        unit: unit,
        allies: const [],
        targetX: 100,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
        speedMultiplier: 0.5,
      );

      expect(unit.positionX, closeTo(50, 1e-9));
      expect(unit.stats.moveSpeed, 100);
      expect(
        () => movement.moveUnitToward(
          unit: unit,
          allies: const [],
          targetX: 100,
          targetY: 0,
          elapsed: const Duration(seconds: 1),
          speedMultiplier: 0,
        ),
        throwsArgumentError,
      );
    });

    test('match host can apply a terrain multiplier per monster', () {
      final unit = _unit('water-unit', x: 0, y: 0, attackRange: 0, moveSpeed: 100);
      const target = MonsterTarget(
        id: 'far-enemy',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: 100,
        y: 0,
        isAlive: true,
      );
      final loop = MonsterMatchCombatLoop(
        combat: const MonsterCombatController(),
        resolver: const MonsterCombatResolver(),
        rangedHandler: const MonsterRangedAttackHandler(),
        projectiles: MonsterProjectileManager(maxActiveProjectiles: 2),
        projectileSpeed: 10,
        projectileId: (_) => 'unused',
        movementSpeedMultiplierFor: (_) => 0.25,
      );

      loop.update(
        units: [unit],
        candidatesFor: (_) => [target],
        resolveDamageTarget: (_) => null,
        resolvePositionedTarget: (_) => null,
        now: DateTime.utc(2026, 11, 17),
        elapsed: const Duration(seconds: 1),
      );

      expect(unit.positionX, closeTo(25, 1e-9));
    });
  });

  group('Monster match navigation integration', () {
    test('combat follows A* waypoints around blocked map cells', () {
      final unit = _unit(
        'route-unit',
        x: 5,
        y: 15,
        attackRange: 0,
        moveSpeed: 10,
      );
      final target = const MonsterTarget(
        id: 'enemy-crystal',
        ownerId: 'p2',
        kind: MonsterTargetKind.crystal,
        x: 55,
        y: 15,
        isAlive: true,
      );
      final grid = MonsterNavigationGrid(
        columns: 7,
        rows: 5,
        cellSize: 10,
        blocked: {
          for (var y = 0; y < 4; y++) MonsterGridCell(3, y),
        },
      );
      final loop = MonsterMatchCombatLoop(
        combat: const MonsterCombatController(),
        resolver: const MonsterCombatResolver(),
        rangedHandler: const MonsterRangedAttackHandler(),
        projectiles: MonsterProjectileManager(maxActiveProjectiles: 4),
        projectileSpeed: 10,
        projectileId: (_) => 'unused-projectile',
        navigationGrid: grid,
      );

      var maxYReached = unit.positionY;
      for (var tick = 0; tick < 12; tick++) {
        loop.update(
          units: [unit],
          candidatesFor: (_) => [target],
          resolveDamageTarget: (_) => null,
          resolvePositionedTarget: (_) => null,
          now: DateTime.utc(2026, 11, 17).add(Duration(seconds: tick)),
          elapsed: const Duration(seconds: 1),
        );
        final currentCell = grid.worldToCell(unit.positionX, unit.positionY);
        expect(grid.isWalkable(currentCell), isTrue);
        maxYReached = math.max(maxYReached, unit.positionY).toDouble();
      }

      expect(loop.pathfinder.cachedRouteCount, 1);
      expect(unit.targetId, 'enemy-crystal');
      expect(maxYReached, greaterThan(15));
    });
  });

  group('Owner-group cohesion', () {
    test('match loop keeps units cohesive while they pursue separate targets', () {
      final first = _unit('cohesive-a', x: 0, y: 0, attackRange: 0, moveSpeed: 10);
      final second = _unit('cohesive-b', x: 0, y: 60, attackRange: 0, moveSpeed: 10);
      const firstTarget = MonsterTarget(
        id: 'target-a',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: 100,
        y: 0,
        isAlive: true,
      );
      const secondTarget = MonsterTarget(
        id: 'target-b',
        ownerId: 'p3',
        kind: MonsterTargetKind.hero,
        x: 100,
        y: 60,
        isAlive: true,
      );
      final loop = MonsterMatchCombatLoop(
        combat: const MonsterCombatController(),
        resolver: const MonsterCombatResolver(),
        rangedHandler: const MonsterRangedAttackHandler(),
        projectiles: MonsterProjectileManager(maxActiveProjectiles: 4),
        projectileSpeed: 10,
        projectileId: (_) => 'unused-projectile',
      );

      loop.update(
        units: [first, second],
        candidatesFor: (source) =>
            source.id == first.id ? [firstTarget] : [secondTarget],
        resolveDamageTarget: (_) => null,
        resolvePositionedTarget: (_) => null,
        now: DateTime.utc(2026, 11, 17),
        elapsed: const Duration(seconds: 1),
      );

      expect(first.targetId, 'target-a');
      expect(second.targetId, 'target-b');
      expect(first.positionY, greaterThan(0));
      expect(second.positionY, lessThan(60));
    });

  });

  group('Runtime army safety budget', () {
    test('optional technical capacity blocks purchases without debiting', () {
      final counts = {for (final type in MonsterType.values) type: 0};
      counts[MonsterType.runner] = 20;
      final army = MonsterArmy(
        ownerId: 'p1',
        catalog: _catalog(),
        selection: InitialArmySelection(counts),
        castleX: 0,
        castleY: 0,
        maxUnits: 20,
      );
      var debitCalled = false;
      expect(army.canPurchase, isFalse);
      expect(
        army.purchase(type: MonsterType.tank, currentResources: 100),
        isNull,
      );
      expect(
        army.purchaseAtomically(
          type: MonsterType.tank,
          currentResources: 100,
          tryDebit: (_) {
            debitCalled = true;
            return true;
          },
          refund: (_) {},
        ),
        isNull,
      );
      expect(debitCalled, isFalse);

      army.units.first.applyDamage(100);
      expect(army.removeDefeated(army.units.first.id), isTrue);
      expect(army.canPurchase, isTrue);
      expect(
        army.purchase(type: MonsterType.tank, currentResources: 100),
        isNotNull,
      );
    });
  });
}
