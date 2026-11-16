import 'dart:math' as math;

import 'monster_models.dart';

/// A circular, impassable map obstacle in world coordinates.
class MonsterMovementObstacle {
  const MonsterMovementObstacle({
    required this.x,
    required this.y,
    required this.radius,
  });

  final double x;
  final double y;
  final double radius;
}

/// Steering layer for coherent army movement. It combines destination seeking,
/// formation cohesion, local separation and obstacle repulsion. It is
/// deterministic and engine-agnostic; the match/map layer supplies obstacles.
class MonsterFormationMovement {
  const MonsterFormationMovement({
    this.desiredSpacing = 18,
    this.separationRadius = 24,
    this.obstacleClearance = 8,
    this.cohesionWeight = 0.22,
    this.separationWeight = 1.4,
    this.obstacleWeight = 2.2,
  }) : assert(desiredSpacing > 0),
       assert(separationRadius > 0),
       assert(obstacleClearance >= 0),
       assert(cohesionWeight >= 0),
       assert(separationWeight >= 0),
       assert(obstacleWeight >= 0);

  final double desiredSpacing;
  final double separationRadius;
  final double obstacleClearance;
  final double cohesionWeight;
  final double separationWeight;
  final double obstacleWeight;

  /// Returns stable ring slots around a target, suitable for melee approach.
  /// Slot ordering follows the supplied unit order and is deterministic.
  List<(double, double)> assignAttackSlots({
    required Iterable<MonsterUnit> units,
    required double targetX,
    required double targetY,
    required double attackRange,
  }) {
    if (!targetX.isFinite || !targetY.isFinite ||
        !attackRange.isFinite || attackRange < 0) {
      throw ArgumentError('Invalid attack formation geometry.');
    }
    final living = units.where((unit) => unit.isAlive).toList(growable: false);
    if (living.isEmpty) return const [];
    final radius = math.max(desiredSpacing, attackRange * 0.8);
    return List.generate(living.length, (index) {
      final angle = -math.pi / 2 + 2 * math.pi * index / living.length;
      return (targetX + math.cos(angle) * radius,
          targetY + math.sin(angle) * radius);
    }, growable: false);
  }


  /// Moves a group toward a destination while preserving its relative shape.
  /// Each unit remains speed-limited by its own movement stat.
  void moveGroup({
    required Iterable<MonsterUnit> units,
    required double targetX,
    required double targetY,
    required Duration elapsed,
    Iterable<MonsterMovementObstacle> obstacles = const [],
  }) {
    _validate(targetX, targetY, elapsed, obstacles);
    if (elapsed == Duration.zero) return;
    final living = units.where((u) => u.isAlive).toList(growable: false);
    _validateUnitPositions(living);
    if (living.isEmpty) return;
    final center = _center(living);
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final snapshots = living.map((u) => (u.positionX, u.positionY)).toList();

    for (var i = 0; i < living.length; i++) {
      final unit = living[i];
      final x = snapshots[i].$1;
      final y = snapshots[i].$2;
      final gx = targetX + (x - center.$1) * cohesionWeight;
      final gy = targetY + (y - center.$2) * cohesionWeight;
      final steer = _steering(
        x, y, gx, gy, i, snapshots, obstacles,
      );
      _advance(unit, steer.$1, steer.$2, seconds);
    }
  }

  /// Moves one unit toward its independently selected target while avoiding
  /// nearby allies and obstacles. Returns false for a dead unit or no movement.
  bool moveUnitToward({
    required MonsterUnit unit,
    required Iterable<MonsterUnit> allies,
    required double targetX,
    required double targetY,
    required Duration elapsed,
    Iterable<MonsterMovementObstacle> obstacles = const [],
  }) {
    _validate(targetX, targetY, elapsed, obstacles);
    if (!unit.isAlive || elapsed == Duration.zero) return false;
    if (!unit.positionX.isFinite || !unit.positionY.isFinite) {
      throw ArgumentError('Unit position must be finite.');
    }
    final others = allies.where((u) => u.isAlive && u.id != unit.id).toList();
    _validateUnitPositions(others);
    final snapshots = <(double, double)>[
      (unit.positionX, unit.positionY),
      ...others.map((u) => (u.positionX, u.positionY)),
    ];
    final steer = _steering(
      unit.positionX, unit.positionY, targetX, targetY, 0, snapshots, obstacles,
    );
    if (steer.$1 == 0 && steer.$2 == 0) return false;
    final beforeX = unit.positionX;
    final beforeY = unit.positionY;
    _advance(
      unit, steer.$1, steer.$2,
      elapsed.inMicroseconds / Duration.microsecondsPerSecond,
    );
    return unit.positionX != beforeX || unit.positionY != beforeY;
  }

  void _validate(double x, double y, Duration elapsed,
      Iterable<MonsterMovementObstacle> obstacles) {
    if (!x.isFinite || !y.isFinite || elapsed.isNegative) {
      throw ArgumentError('Invalid movement input.');
    }
    if (!desiredSpacing.isFinite || desiredSpacing <= 0 ||
        !separationRadius.isFinite || separationRadius <= 0 ||
        !obstacleClearance.isFinite || obstacleClearance < 0 ||
        !cohesionWeight.isFinite || cohesionWeight < 0 ||
        !separationWeight.isFinite || separationWeight < 0 ||
        !obstacleWeight.isFinite || obstacleWeight < 0) {
      throw ArgumentError('Movement tuning values must be finite and non-negative.');
    }
    for (final obstacle in obstacles) {
      if (!obstacle.x.isFinite || !obstacle.y.isFinite ||
          !obstacle.radius.isFinite || obstacle.radius <= 0) {
        throw ArgumentError('Obstacle geometry must be finite and positive.');
      }
    }
  }

  void _validateUnitPositions(Iterable<MonsterUnit> units) {
    for (final unit in units) {
      if (!unit.positionX.isFinite || !unit.positionY.isFinite) {
        throw ArgumentError('Unit position must be finite.');
      }
    }
  }

  (double, double) _center(List<MonsterUnit> units) => (
    units.fold<double>(0, (s, u) => s + u.positionX) / units.length,
    units.fold<double>(0, (s, u) => s + u.positionY) / units.length,
  );

  (double, double) _steering(
    double x, double y, double goalX, double goalY, int selfIndex,
    List<(double, double)> units,
    Iterable<MonsterMovementObstacle> obstacles,
  ) {
    var vx = goalX - x;
    var vy = goalY - y;
    final goalLength = math.sqrt(vx * vx + vy * vy);
    if (goalLength > 0) { vx /= goalLength; vy /= goalLength; }

    for (var i = 0; i < units.length; i++) {
      if (i == selfIndex) continue;
      final dx = x - units[i].$1;
      final dy = y - units[i].$2;
      final d2 = dx * dx + dy * dy;
      final radius = math.max(separationRadius, desiredSpacing);
      if (d2 > 0 && d2 < radius * radius) {
        final d = math.sqrt(d2);
        final strength = (radius - d) / radius;
        vx += dx / d * strength * separationWeight;
        vy += dy / d * strength * separationWeight;
      } else if (d2 == 0) {
        // Stable tie-break prevents coincident units from remaining stacked.
        final angle = (selfIndex + 1) * 2.399963229728653;
        vx += math.cos(angle) * separationWeight;
        vy += math.sin(angle) * separationWeight;
      }
    }

    for (final obstacle in obstacles) {
      final dx = x - obstacle.x;
      final dy = y - obstacle.y;
      final d = math.sqrt(dx * dx + dy * dy);
      final safeRadius = obstacle.radius + obstacleClearance;
      if (d < safeRadius) {
        final angle = (selfIndex + 1) * 2.399963229728653;
        final nx = d > 0 ? dx / d : math.cos(angle);
        final ny = d > 0 ? dy / d : math.sin(angle);
        final strength = (safeRadius - d) / safeRadius;
        vx += nx * strength * obstacleWeight;
        vy += ny * strength * obstacleWeight;
      }
    }

    final length = math.sqrt(vx * vx + vy * vy);
    if (length == 0 || !length.isFinite) return (0, 0);
    return (vx / length, vy / length);
  }

  void _advance(MonsterUnit unit, double dx, double dy, double seconds) {
    if (!dx.isFinite || !dy.isFinite || !seconds.isFinite || seconds <= 0 ||
        !unit.stats.moveSpeed.isFinite || unit.stats.moveSpeed <= 0) return;
    final step = unit.stats.moveSpeed * seconds;
    if (step <= 0 || !step.isFinite) return;
    unit.positionX += dx * step;
    unit.positionY += dy * step;
  }
}
