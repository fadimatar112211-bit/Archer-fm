import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_army.dart';
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
