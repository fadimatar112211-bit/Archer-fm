import 'dart:math' as math;

import 'monster_models.dart';
import 'monster_formation_movement.dart';
import 'monster_navigation.dart';

class MonsterCombatIntent {
  const MonsterCombatIntent({
    required this.monsterId,
    required this.targetId,
    required this.damage,
  });

  final String monsterId;
  final String targetId;
  final double damage;
}

/// Deterministic per-unit AI. The match authority applies returned damage to
/// the authoritative target; this class never mutates another player's state.
class MonsterCombatController {
  const MonsterCombatController({
    this.targeting = const MonsterTargeting(),
    this.movement = const MonsterFormationMovement(),
  });

  final MonsterTargeting targeting;
  final MonsterFormationMovement movement;

  MonsterTarget? selectTarget({
    required MonsterUnit unit,
    required Iterable<MonsterTarget> candidates,
  }) {
    if (!unit.isAlive) return null;
    return targeting.selectCombatTarget(unit: unit, candidates: candidates);
  }

  MonsterCombatIntent? updateUnit({
    required MonsterUnit unit,
    required Iterable<MonsterTarget> candidates,
    required DateTime now,
    required Duration elapsed,
    Iterable<MonsterUnit> allies = const [],
    Iterable<MonsterMovementObstacle> obstacles = const [],
    MonsterTarget? selectedTarget,
    bool selectedTargetProvided = false,
    (double, double)? approachPoint,
    MonsterNavigationGrid? navigationGrid,
    MonsterPathfinder? pathfinder,
    (double, double)? cohesionAnchor,
    double movementSpeedMultiplier = 1,
  }) {
    if (!unit.isAlive) return null;
    if (elapsed.isNegative) throw ArgumentError.value(elapsed, 'elapsed');
    if (!movementSpeedMultiplier.isFinite || movementSpeedMultiplier <= 0) {
      throw ArgumentError.value(movementSpeedMultiplier, 'movementSpeedMultiplier');
    }
    final target = selectedTargetProvided
        ? selectedTarget
        : selectTarget(unit: unit, candidates: candidates);
    if (target == null) {
      unit.targetId = null;
      unit.targetKind = null;
      pathfinder?.release(unit.id);
      return null;
    }

    unit.targetId = target.id;
    unit.targetKind = target.kind;
    final dx = target.x - unit.positionX;
    final dy = target.y - unit.positionY;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= unit.stats.attackRange) {
      if (!unit.canAttackAt(now)) return null;
      unit.recordAttack(now);
      return MonsterCombatIntent(
        monsterId: unit.id,
        targetId: target.id,
        damage: unit.stats.damage,
      );
    }

    if (elapsed == Duration.zero || distance == 0) return null;
    final destination = approachPoint ?? (target.x, target.y);
    var moveX = destination.$1;
    var moveY = destination.$2;
    if (navigationGrid != null) {
      final routePlanner = pathfinder;
      if (routePlanner == null) {
        throw ArgumentError('A pathfinder is required when a navigation grid is supplied.');
      }
      final waypoint = routePlanner.nextWaypoint(
        unit: unit,
        grid: navigationGrid,
        targetX: moveX,
        targetY: moveY,
        goalRange: navigationGrid.cellSize * 0.2,
      );
      if (waypoint == null) return null;
      moveX = waypoint.$1;
      moveY = waypoint.$2;
    }

    movement.moveUnitToward(
      unit: unit,
      allies: allies,
      targetX: moveX,
      targetY: moveY,
      elapsed: elapsed,
      obstacles: obstacles,
      cohesionAnchor: cohesionAnchor,
      speedMultiplier: movementSpeedMultiplier,
    );
    return null;
  }
}
