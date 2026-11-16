import 'package:flutter_test/flutter_test.dart';
import 'package:archero_fm/monsters/monster_formation_movement.dart';
import 'package:archero_fm/monsters/monster_models.dart';

MonsterUnit _unit(String id, double x, double y) => MonsterUnit(
  id: id,
  ownerId: 'p1',
  type: MonsterType.runner,
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
  });
}
