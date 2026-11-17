import 'dart:math' as math;

import 'monster_models.dart';
import 'monster_formation_movement.dart';

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

  MonsterCombatIntent? updateUnit({
    required MonsterUnit unit,
    required Iterable<MonsterTarget> candidates,
    required DateTime now,
    required Duration elapsed,
    Iterable<MonsterUnit> allies = const [],
    Iterable<MonsterMovementObstacle> obstacles = const [],
  }) {
    if (!unit.isAlive) return null;
    if (elapsed.isNegative) throw ArgumentError.value(elapsed, 'elapsed');
    final target = targeting.nearestEnemy(
      ownerId: unit.ownerId,
      fromX: unit.positionX,
      fromY: unit.positionY,
      candidates: candidates,
    );
    if (target == null) {
      unit.targetId = null;
      unit.targetKind = null;
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
    movement.moveUnitToward(
      unit: unit,
      allies: allies,
      targetX: target.x,
      targetY: target.y,
      elapsed: elapsed,
      obstacles: obstacles,
    );
    return null;
  }
}
