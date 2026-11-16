import 'dart:math' as math;

import 'monster_combat_resolver.dart';
import 'monster_models.dart';

enum MonsterProjectileResult {
  travelling,
  hit,
  targetMissing,
  friendlyTarget,
  deadTarget,
  invalidElapsed,
  alreadyResolved,
}

/// Server-authoritative homing projectile emitted by a ranged monster.
/// The caller must provide a fresh authoritative target on every update.
class MonsterProjectile {
  MonsterProjectile({
    required this.id,
    required MonsterUnit source,
    required this.targetId,
    required double projectileSpeed,
    required this.positionX,
    required this.positionY,
  })  : ownerId = source.ownerId,
        sourceMonsterId = source.id,
        speed = projectileSpeed,
        damage = source.stats.damage {
    if (id.isEmpty || targetId.isEmpty || !source.isAlive ||
        source.type != MonsterType.ranged ||
        !positionX.isFinite || !positionY.isFinite ||
        !speed.isFinite || speed <= 0 ||
        !damage.isFinite || damage <= 0) {
      throw ArgumentError('Invalid ranged projectile source or parameters.');
    }
  }

  final String id;
  final String ownerId;
  final String sourceMonsterId;
  final String targetId;
  final double speed;
  final double damage;
  double positionX;
  double positionY;
  bool _resolved = false;

  bool get isResolved => _resolved;

  MonsterProjectileResult update({
    required Duration elapsed,
    required MonsterDamageTarget? target,
  }) {
    if (_resolved) return MonsterProjectileResult.alreadyResolved;
    if (elapsed.isNegative) return MonsterProjectileResult.invalidElapsed;
    if (target == null || target.id != targetId) {
      _resolved = true;
      return MonsterProjectileResult.targetMissing;
    }
    if (target.ownerId == ownerId) {
      _resolved = true;
      return MonsterProjectileResult.friendlyTarget;
    }
    if (!target.isAlive) {
      _resolved = true;
      return MonsterProjectileResult.deadTarget;
    }

    final dx = _targetX(target) - positionX;
    final dy = _targetY(target) - positionY;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (!distance.isFinite) {
      _resolved = true;
      return MonsterProjectileResult.targetMissing;
    }
    if (distance == 0) {
      target.applyDamage(damage);
      _resolved = true;
      return MonsterProjectileResult.hit;
    }

    final step = speed * elapsed.inMicroseconds /
        Duration.microsecondsPerSecond;
    if (step >= distance) {
      positionX = _targetX(target);
      positionY = _targetY(target);
      target.applyDamage(damage);
      _resolved = true;
      return MonsterProjectileResult.hit;
    }
    if (step > 0) {
      positionX += dx / distance * step;
      positionY += dy / distance * step;
    }
    return MonsterProjectileResult.travelling;
  }

  double _targetX(MonsterDamageTarget target) =>
      target is MonsterPositionedDamageTarget ? target.positionX : double.nan;
  double _targetY(MonsterDamageTarget target) =>
      target is MonsterPositionedDamageTarget ? target.positionY : double.nan;
}

/// Position extension required by homing projectile targets. Match entities
/// should implement this alongside MonsterDamageTarget.
abstract interface class MonsterPositionedDamageTarget
    implements MonsterDamageTarget {
  double get positionX;
  double get positionY;
}
