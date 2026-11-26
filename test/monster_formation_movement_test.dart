import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_formation_movement.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_combat.dart';

MonsterUnit _unit(String id, double x, double y) => MonsterUnit(
  id: id,
  ownerId: 'p1',
  type: MonsterType.werewolf,
  positionX: x,
  positionY: y,
  stats: const MonsterStats(
    maxHealth: 100,
    damage: 10,
    moveSpeed: 5,
    attackRange: 10,
    attackCooldown: Duration(seconds: 1),
    purchaseCost: 1,
  ),
);

void main() {
  const movement = MonsterFormationMovement();

  group('Monster formation movement', () {
    test('moves a group toward its destination within each unit speed', () {
      final units = [_unit('a', 0, 0), _unit('b', 0, 20), _unit('c', 20, 0)];
      final before = units.map((u) => (u.positionX, u.positionY)).toList();
      movement.moveGroup(
        units: units,
        targetX: 100,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
      );
      for (var i = 0; i < units.length; i++) {
        final dx = units[i].positionX - before[i].$1;
        final dy = units[i].positionY - before[i].$2;
        expect(dx * dx + dy * dy, lessThanOrEqualTo(25.000001));
      }
      expect(units.first.positionX, greaterThan(0));
    });

    test('separates overlapping allies instead of stacking them', () {
      final unit = _unit('a', 0, 0);
      final ally = _unit('b', 0, 0);
      final moved = movement.moveUnitToward(
        unit: unit,
        allies: [unit, ally],
        targetX: 100,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
      );
      expect(moved, isTrue);
      expect(unit.positionX.abs() + unit.positionY.abs(), greaterThan(0));
    });

    test('steers a unit away from an obstacle occupying its path', () {
      final unit = _unit('a', 0, 0);
      movement.moveUnitToward(
        unit: unit,
        allies: [unit],
        targetX: 100,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
        obstacles: const [
          MonsterMovementObstacle(x: 2, y: 0, radius: 10),
        ],
      );
      expect(unit.positionX, lessThan(0));
    });

    test('ignores dead units and does not move on zero elapsed time', () {
      final unit = _unit('a', 0, 0);
      unit.applyDamage(100);
      movement.moveGroup(
        units: [unit],
        targetX: 10,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
      );
      expect(unit.positionX, 0);
      final living = _unit('b', 0, 0);
      movement.moveGroup(
        units: [living],
        targetX: 10,
        targetY: 0,
        elapsed: Duration.zero,
      );
      expect(living.positionX, 0);
    });

    test('rejects invalid obstacle geometry and negative elapsed', () {
      expect(() => movement.moveGroup(
        units: [_unit('a', 0, 0)],
        targetX: 10,
        targetY: 0,
        elapsed: const Duration(milliseconds: -1),
      ), throwsArgumentError);
      expect(() => movement.moveGroup(
        units: [_unit('a', 0, 0)],
        targetX: 10,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
        obstacles: const [
          MonsterMovementObstacle(x: 0, y: 0, radius: -1),
        ],
      ), throwsArgumentError);
    });

    test('assigns stable, evenly distributed attack slots', () {
      final units = [_unit('a', 0, 0), _unit('b', 1, 0), _unit('c', 2, 0), _unit('d', 3, 0)];
      final slots = movement.assignAttackSlots(
        units: units,
        targetX: 50,
        targetY: 50,
        attackRange: 10,
      );
      expect(slots, hasLength(4));
      expect(slots.toSet(), hasLength(4));
      expect(slots.first.$1, closeTo(50, 0.0001));
      expect(slots.first.$2, lessThan(50));
    });

    test('attack slots reject invalid target geometry', () {
      expect(() => movement.assignAttackSlots(
        units: [_unit('a', 0, 0)],
        targetX: double.nan,
        targetY: 0,
        attackRange: 10,
      ), throwsArgumentError);
    });

    test('combat pursuit uses ally separation and obstacle steering', () {
      final unit = _unit('a', 0, 0);
      final ally = _unit('b', 0, 0);
      const controller = MonsterCombatController();
      controller.updateUnit(
        unit: unit,
        candidates: const [
          MonsterTarget(
            id: 'enemy', ownerId: 'p2', kind: MonsterTargetKind.hero,
            x: 100, y: 0, isAlive: true,
          ),
        ],
        now: DateTime.utc(2026, 1, 1),
        elapsed: const Duration(seconds: 1),
        allies: [unit, ally],
        obstacles: const [
          MonsterMovementObstacle(x: 1, y: 0, radius: 10),
        ],
      );
      expect(unit.positionY.abs(), greaterThan(0));
    });

    test('movement remains deterministic for identical snapshots', () {
      final first = [_unit('a', 0, 0), _unit('b', 0, 20)];
      final second = [_unit('a', 0, 0), _unit('b', 0, 20)];
      for (final group in [first, second]) {
        movement.moveGroup(
          units: group,
          targetX: 100,
          targetY: 30,
          elapsed: const Duration(milliseconds: 250),
        );
      }
      for (var i = 0; i < first.length; i++) {
        expect(first[i].positionX, second[i].positionX);
        expect(first[i].positionY, second[i].positionY);
      }
    });

    test('rejects non-finite movement tuning and corrupted unit positions', () {
      expect(
        () => MonsterFormationMovement(separationWeight: double.nan),
        throwsAssertionError,
      );

      final corrupted = _unit('bad', 0, 0)..positionX = double.infinity;
      expect(() => movement.moveGroup(
        units: [corrupted],
        targetX: 10,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
      ), throwsArgumentError);
    });

    test('rejects non-finite destination coordinates', () {
      expect(() => movement.moveGroup(
        units: [_unit('a', 0, 0)],
        targetX: double.infinity,
        targetY: 0,
        elapsed: const Duration(seconds: 1),
      ), throwsArgumentError);
    });
  });
}
