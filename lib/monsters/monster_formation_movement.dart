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

/// Deterministic steering plus hard collision resolution for coherent armies.
/// Global route planning is supplied separately by MonsterPathfinder.
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
    final radius = attackRange * 0.82;
    return List.generate(living.length, (index) {
      final angle = -math.pi / 2 + 2 * math.pi * index / living.length;
      return (targetX + math.cos(angle) * radius,
          targetY + math.sin(angle) * radius);
    }, growable: false);
  }

  /// Moves a group toward a shared destination while retaining local spacing.
  /// Each unit remains speed-limited by its own movement stat.
  void moveGroup({
    required Iterable<MonsterUnit> units,
    required double targetX,
    required double targetY,
    required Duration elapsed,
    Iterable<MonsterMovementObstacle> obstacles = const [],
  }) {
    final obstacleList = _validate(targetX, targetY, elapsed, obstacles);
    if (elapsed == Duration.zero) return;
    final living = units.where((unit) => unit.isAlive).toList(growable: false);
    _validateUnitPositions(living);
    if (living.isEmpty) return;
    final center = _center(living);
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final snapshots = living.map((unit) => (unit.positionX, unit.positionY)).toList();

    for (var i = 0; i < living.length; i++) {
      final unit = living[i];
      final x = snapshots[i].$1;
      final y = snapshots[i].$2;
      final goalX = targetX + (x - center.$1) * cohesionWeight;
      final goalY = targetY + (y - center.$2) * cohesionWeight;
      final steer = _steering(
        x, y, goalX, goalY, i, snapshots, obstacleList,
      );
      final allies = <(double, double)>[
        for (var j = 0; j < snapshots.length; j++)
          if (j != i) snapshots[j],
      ];
      _advance(
        unit,
        steer.$1,
        steer.$2,
        seconds,
        obstacles: obstacleList,
        allies: allies,
        tieBreaker: i,
      );
    }
  }

  /// Moves one unit toward its independently selected target while avoiding
  /// nearby allies and resolving obstacle intersections before committing.
  bool moveUnitToward({
    required MonsterUnit unit,
    required Iterable<MonsterUnit> allies,
    required double targetX,
    required double targetY,
    required Duration elapsed,
    Iterable<MonsterMovementObstacle> obstacles = const [],
  }) {
    final obstacleList = _validate(targetX, targetY, elapsed, obstacles);
    if (!unit.isAlive || elapsed == Duration.zero) return false;
    if (!unit.positionX.isFinite || !unit.positionY.isFinite) {
      throw ArgumentError('Unit position must be finite.');
    }
    final others = allies.where((other) =>
        other.isAlive && other.id != unit.id).toList(growable: false);
    _validateUnitPositions(others);
    final snapshots = <(double, double)>[
      (unit.positionX, unit.positionY),
      ...others.map((other) => (other.positionX, other.positionY)),
    ];
    final steer = _steering(
      unit.positionX,
      unit.positionY,
      targetX,
      targetY,
      0,
      snapshots,
      obstacleList,
    );
    if (steer.$1 == 0 && steer.$2 == 0) return false;
    final beforeX = unit.positionX;
    final beforeY = unit.positionY;
    _advance(
      unit,
      steer.$1,
      steer.$2,
      elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      obstacles: obstacleList,
      allies: snapshots.skip(1).toList(growable: false),
      tieBreaker: 0,
    );
    return unit.positionX != beforeX || unit.positionY != beforeY;
  }

  List<MonsterMovementObstacle> _validate(
    double x,
    double y,
    Duration elapsed,
    Iterable<MonsterMovementObstacle> obstacles,
  ) {
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
    final snapshot = obstacles.toList(growable: false);
    for (final obstacle in snapshot) {
      if (!obstacle.x.isFinite || !obstacle.y.isFinite ||
          !obstacle.radius.isFinite || obstacle.radius <= 0) {
        throw ArgumentError('Obstacle geometry must be finite and positive.');
      }
    }
    return snapshot;
  }

  void _validateUnitPositions(Iterable<MonsterUnit> units) {
    for (final unit in units) {
      if (!unit.positionX.isFinite || !unit.positionY.isFinite) {
        throw ArgumentError('Unit position must be finite.');
      }
    }
  }

  (double, double) _center(List<MonsterUnit> units) => (
        units.fold<double>(0, (sum, unit) => sum + unit.positionX) / units.length,
        units.fold<double>(0, (sum, unit) => sum + unit.positionY) / units.length,
      );

  (double, double) _steering(
    double x,
    double y,
    double goalX,
    double goalY,
    int selfIndex,
    List<(double, double)> units,
    List<MonsterMovementObstacle> obstacles,
  ) {
    var vx = goalX - x;
    var vy = goalY - y;
    final goalLength = math.sqrt(vx * vx + vy * vy);
    if (goalLength > 0) {
      vx /= goalLength;
      vy /= goalLength;
    }

    for (var i = 0; i < units.length; i++) {
      if (i == selfIndex) continue;
      final dx = x - units[i].$1;
      final dy = y - units[i].$2;
      final distanceSquared = dx * dx + dy * dy;
      final radius = math.max(separationRadius, desiredSpacing);
      if (distanceSquared > 0 && distanceSquared < radius * radius) {
        final distance = math.sqrt(distanceSquared);
        final strength = (radius - distance) / radius;
        vx += dx / distance * strength * separationWeight;
        vy += dy / distance * strength * separationWeight;
      } else if (distanceSquared == 0) {
        final angle = (selfIndex + 1) * 2.399963229728653;
        vx += math.cos(angle) * separationWeight;
        vy += math.sin(angle) * separationWeight;
      }
    }

    for (final obstacle in obstacles) {
      final dx = x - obstacle.x;
      final dy = y - obstacle.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      final safeRadius = obstacle.radius + obstacleClearance;
      if (distance < safeRadius) {
        final angle = (selfIndex + 1) * 2.399963229728653;
        final nx = distance > 0 ? dx / distance : math.cos(angle);
        final ny = distance > 0 ? dy / distance : math.sin(angle);
        final strength = (safeRadius - distance) / safeRadius;
        vx += nx * strength * obstacleWeight;
        vy += ny * strength * obstacleWeight;
      }
    }

    final length = math.sqrt(vx * vx + vy * vy);
    if (length == 0 || !length.isFinite) return (0, 0);
    return (vx / length, vy / length);
  }

  void _advance(
    MonsterUnit unit,
    double dx,
    double dy,
    double seconds, {
    required List<MonsterMovementObstacle> obstacles,
    required List<(double, double)> allies,
    required int tieBreaker,
  }) {
    if (!dx.isFinite || !dy.isFinite || !seconds.isFinite || seconds <= 0 ||
        !unit.stats.moveSpeed.isFinite || unit.stats.moveSpeed <= 0) {
      return;
    }
    final step = unit.stats.moveSpeed * seconds;
    if (step <= 0 || !step.isFinite) return;
    final startX = unit.positionX;
    final startY = unit.positionY;
    var endX = startX + dx * step;
    var endY = startY + dy * step;
    final minimumAllySpacing = math.max(1, desiredSpacing * 0.55);

    // Multiple passes handle cases where resolving one collision exposes
    // another nearby obstacle or ally. All geometry is resolved before commit.
    for (var pass = 0; pass < 3; pass++) {
      for (final obstacle in obstacles) {
        final resolved = _slideAroundCircle(
          startX,
          startY,
          endX,
          endY,
          obstacle,
          tieBreaker,
        );
        endX = resolved.$1;
        endY = resolved.$2;
      }
      for (var i = 0; i < allies.length; i++) {
        final resolved = _separateFromPoint(
          endX,
          endY,
          allies[i].$1,
          allies[i].$2,
          minimumAllySpacing,
          tieBreaker + i,
        );
        endX = resolved.$1;
        endY = resolved.$2;
      }
    }

    // Never commit a position that still intersects an impassable obstacle.
    for (final obstacle in obstacles) {
      final safeRadius = obstacle.radius + obstacleClearance;
      final ox = endX - obstacle.x;
      final oy = endY - obstacle.y;
      if (ox * ox + oy * oy < safeRadius * safeRadius) {
        endX = startX;
        endY = startY;
        break;
      }
    }
    unit.positionX = endX;
    unit.positionY = endY;
  }

  (double, double) _slideAroundCircle(
    double startX,
    double startY,
    double endX,
    double endY,
    MonsterMovementObstacle obstacle,
    int tieBreaker,
  ) {
    final radius = obstacle.radius + obstacleClearance;
    final startDx = startX - obstacle.x;
    final startDy = startY - obstacle.y;
    final startDistance = math.sqrt(startDx * startDx + startDy * startDy);

    if (startDistance < radius) {
      final endDx = endX - obstacle.x;
      final endDy = endY - obstacle.y;
      final endDistance = math.sqrt(endDx * endDx + endDy * endDy);
      final angle = (tieBreaker + 1) * 2.399963229728653;
      final nx = endDistance > 1e-9 ? endDx / endDistance : math.cos(angle);
      final ny = endDistance > 1e-9 ? endDy / endDistance : math.sin(angle);
      return (obstacle.x + nx * radius, obstacle.y + ny * radius);
    }

    final moveX = endX - startX;
    final moveY = endY - startY;
    final lengthSquared = moveX * moveX + moveY * moveY;
    if (lengthSquared == 0) return (endX, endY);
    final toCenterX = obstacle.x - startX;
    final toCenterY = obstacle.y - startY;
    final closestT = ((toCenterX * moveX + toCenterY * moveY) /
            lengthSquared)
        .clamp(0.0, 1.0);
    final closestX = startX + moveX * closestT;
    final closestY = startY + moveY * closestT;
    final closestDx = closestX - obstacle.x;
    final closestDy = closestY - obstacle.y;
    if (closestDx * closestDx + closestDy * closestDy >= radius * radius) {
      return (endX, endY);
    }

    final b = -2 * (toCenterX * moveX + toCenterY * moveY);
    final c = toCenterX * toCenterX + toCenterY * toCenterY - radius * radius;
    final discriminant = b * b - 4 * lengthSquared * c;
    if (discriminant < 0) return (startX, startY);
    final hitT = ((-b - math.sqrt(discriminant)) / (2 * lengthSquared))
        .clamp(0.0, 1.0);
    final contactX = startX + moveX * hitT;
    final contactY = startY + moveY * hitT;
    var normalX = contactX - obstacle.x;
    var normalY = contactY - obstacle.y;
    final normalLength = math.sqrt(normalX * normalX + normalY * normalY);
    if (normalLength <= 1e-9) {
      final angle = (tieBreaker + 1) * 2.399963229728653;
      normalX = math.cos(angle);
      normalY = math.sin(angle);
    } else {
      normalX /= normalLength;
      normalY /= normalLength;
    }
    final remainingX = endX - contactX;
    final remainingY = endY - contactY;
    final tangentX = -normalY;
    final tangentY = normalX;
    final slide = remainingX * tangentX + remainingY * tangentY;
    return (
      contactX + tangentX * slide,
      contactY + tangentY * slide,
    );
  }

  (double, double) _separateFromPoint(
    double x,
    double y,
    double otherX,
    double otherY,
    double minimumDistance,
    int tieBreaker,
  ) {
    final dx = x - otherX;
    final dy = y - otherY;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance >= minimumDistance) return (x, y);
    final angle = (tieBreaker + 1) * 2.399963229728653;
    final nx = distance > 1e-9 ? dx / distance : math.cos(angle);
    final ny = distance > 1e-9 ? dy / distance : math.sin(angle);
    return (
      otherX + nx * minimumDistance,
      otherY + ny * minimumDistance,
    );
  }
}
