enum MonsterType { bogMonster, werewolf, stoneGolem, blindStalker }

enum MonsterTargetKind { hero, monster, crystal }

/// Automatic is the normal match order. Advance ignores home-crystal threats;
/// defend stays near the owner's territory until a threat appears.
enum MonsterOrder { auto, advance, defend }

class MonsterStats {
  const MonsterStats({
    required this.maxHealth,
    required this.damage,
    required this.moveSpeed,
    required this.attackRange,
    required this.attackCooldown,
    required this.purchaseCost,
  }) : assert(maxHealth > 0),
       assert(damage > 0),
       assert(moveSpeed > 0),
       assert(attackRange >= 0),
       assert(purchaseCost >= 0);

  final double maxHealth;
  final double damage;
  final double moveSpeed;
  final double attackRange;
  final Duration attackCooldown;
  final int purchaseCost;

  void validate() {
    if (!maxHealth.isFinite || maxHealth <= 0 ||
        !damage.isFinite || damage <= 0 ||
        !moveSpeed.isFinite || moveSpeed <= 0 ||
        !attackRange.isFinite || attackRange < 0 ||
        attackCooldown.isNegative || attackCooldown == Duration.zero ||
        purchaseCost < 0) {
      throw ArgumentError('Monster stats must be finite and within valid ranges.');
    }
  }

  MonsterStats scaledForLevel(
    int level, {
    required double healthPerLevel,
    required double damagePerLevel,
    required double speedPerLevel,
  }) {
    if (level < 1 || level > 40) {
      throw RangeError.range(level, 1, 40, 'level');
    }
    for (final value in [healthPerLevel, damagePerLevel, speedPerLevel]) {
      if (!value.isFinite || value < 0) {
        throw ArgumentError('Upgrade growth values must be finite and non-negative.');
      }
    }
    final steps = level - 1;
    final scaled = MonsterStats(
      maxHealth: maxHealth * (1 + steps * healthPerLevel),
      damage: damage * (1 + steps * damagePerLevel),
      moveSpeed: moveSpeed * (1 + steps * speedPerLevel),
      attackRange: attackRange,
      attackCooldown: attackCooldown,
      purchaseCost: purchaseCost,
    );
    scaled.validate();
    return scaled;
  }
}

class MonsterDefinition {
  const MonsterDefinition({required this.type, required this.baseStats});
  final MonsterType type;
  final MonsterStats baseStats;
}

class MonsterCatalog {
  MonsterCatalog(Map<MonsterType, MonsterDefinition> definitions)
      : _definitions = Map.unmodifiable(definitions) {
    if (_definitions.length != MonsterType.values.length ||
        MonsterType.values.any((type) => !_definitions.containsKey(type))) {
      throw ArgumentError('Catalog must define exactly the four launch monsters.');
    }
    for (final type in MonsterType.values) {
      _definitions[type]!.baseStats.validate();
      if (_definitions[type]!.type != type) {
        throw ArgumentError('Catalog key and monster definition type must match.');
      }
    }
  }

  final Map<MonsterType, MonsterDefinition> _definitions;
  MonsterDefinition operator [](MonsterType type) => _definitions[type]!;
  Iterable<MonsterDefinition> get all => _definitions.values;
}

class MonsterUnit {
  MonsterUnit({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.positionX,
    required this.positionY,
    required this.stats,
    this.order = MonsterOrder.auto,
    double? health,
  }) : health = health ?? stats.maxHealth {
    stats.validate();
    if (id.isEmpty || ownerId.isEmpty) {
      throw ArgumentError('Monster id and owner id cannot be empty.');
    }
    if (!this.health.isFinite || this.health <= 0 || this.health > stats.maxHealth) {
      throw ArgumentError.value(health, 'health');
    }
    if (!positionX.isFinite || !positionY.isFinite) {
      throw ArgumentError('Monster position must be finite.');
    }
  }

  final String id;
  final String ownerId;
  final MonsterType type;
  final MonsterStats stats;
  double positionX;
  double positionY;
  double health;
  MonsterOrder order;
  String? targetId;
  MonsterTargetKind? targetKind;
  DateTime? lastAttackAt;
  bool get isAlive => health > 0;

  bool applyDamage(double amount) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    if (!isAlive) return true;
    health = (health - amount).clamp(0, stats.maxHealth).toDouble();
    return !isAlive;
  }

  bool canAttackAt(DateTime now) {
    final previous = lastAttackAt;
    return previous == null ||
        !now.isBefore(previous.add(stats.attackCooldown));
  }

  void recordAttack(DateTime now) {
    if (!canAttackAt(now)) {
      throw StateError('Monster attack is still on cooldown.');
    }
    lastAttackAt = now;
  }
}

class MonsterTarget {
  const MonsterTarget({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.x,
    required this.y,
    required this.isAlive,
  });

  final String id;
  final String ownerId;
  final MonsterTargetKind kind;
  final double x;
  final double y;
  final bool isAlive;
}

class MonsterTargeting {
  const MonsterTargeting();

  MonsterTarget? nearestEnemy({
    required String ownerId,
    required double fromX,
    required double fromY,
    required Iterable<MonsterTarget> candidates,
    double maxDistance = double.infinity,
  }) {
    if (ownerId.isEmpty || !fromX.isFinite || !fromY.isFinite ||
        maxDistance < 0 || maxDistance.isNaN) {
      throw ArgumentError.value(maxDistance, 'maxDistance');
    }
    MonsterTarget? best;
    var bestDistanceSquared = maxDistance * maxDistance;
    for (final candidate in candidates) {
      if (!candidate.isAlive || candidate.id.isEmpty ||
          candidate.ownerId.isEmpty || candidate.ownerId == ownerId) continue;
      if (!candidate.x.isFinite || !candidate.y.isFinite) continue;
      // Castles are deliberately not a target kind: crystals gate castle damage.
      final dx = candidate.x - fromX;
      final dy = candidate.y - fromY;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared < bestDistanceSquared) {
        best = candidate;
        bestDistanceSquared = distanceSquared;
      }
    }
    return best;
  }

  /// Selects a nearby enemy that is closer to an owned crystal than this unit
  /// is before falling back to the normal nearest-enemy behavior. This creates
  /// automatic local defense without inventing a fixed defense-radius value.
  MonsterTarget? selectCombatTarget({
    required MonsterUnit unit,
    required Iterable<MonsterTarget> candidates,
  }) {
    final snapshot = candidates.toList(growable: false);
    final nearest = nearestEnemy(
      ownerId: unit.ownerId,
      fromX: unit.positionX,
      fromY: unit.positionY,
      candidates: snapshot,
    );
    if (unit.order == MonsterOrder.advance) return nearest;

    final crystals = snapshot.where((target) =>
        target.kind == MonsterTargetKind.crystal &&
        target.ownerId == unit.ownerId &&
        target.id.isNotEmpty &&
        target.isAlive &&
        target.x.isFinite &&
        target.y.isFinite).toList(growable: false);
    if (crystals.isEmpty) {
      return unit.order == MonsterOrder.defend ? null : nearest;
    }

    final enemies = snapshot.where((target) =>
        target.kind != MonsterTargetKind.crystal &&
        target.ownerId.isNotEmpty &&
        target.ownerId != unit.ownerId &&
        target.id.isNotEmpty &&
        target.isAlive &&
        target.x.isFinite &&
        target.y.isFinite).toList(growable: false);

    MonsterTarget? threat;
    var bestPressure = double.infinity;
    var bestUnitDistance = double.infinity;
    for (final enemy in enemies) {
      for (final crystal in crystals) {
        final enemyDistance = _distanceSquared(
          enemy.x, enemy.y, crystal.x, crystal.y,
        );
        final unitDistance = _distanceSquared(
          unit.positionX, unit.positionY, crystal.x, crystal.y,
        );
        // A defender already standing on the crystal still reacts when an
        // enemy enters its own attack radius around that crystal.
        final defenseThreshold = mathMax(
          unitDistance,
          unit.stats.attackRange * unit.stats.attackRange,
        );
        if (enemyDistance >= defenseThreshold) continue;
        final pressure = enemyDistance / mathMax(defenseThreshold, 1);
        final unitToEnemy = _distanceSquared(
          unit.positionX, unit.positionY, enemy.x, enemy.y,
        );
        if (pressure < bestPressure ||
            (pressure == bestPressure && unitToEnemy < bestUnitDistance)) {
          threat = enemy;
          bestPressure = pressure;
          bestUnitDistance = unitToEnemy;
        }
      }
    }
    if (threat != null) return threat;
    return unit.order == MonsterOrder.defend ? null : nearest;
  }

  MonsterTarget? defensiveTarget({
    required String ownerId,
    required double fromX,
    required double fromY,
    required Iterable<MonsterTarget> candidates,
  }) {
    if (ownerId.isEmpty || !fromX.isFinite || !fromY.isFinite) {
      throw ArgumentError('Defensive targeting requires a valid owner and position.');
    }
    MonsterTarget? nearest;
    var nearestDistance = double.infinity;
    for (final target in candidates) {
      if (target.kind != MonsterTargetKind.crystal ||
          target.id.isEmpty || target.ownerId != ownerId ||
          !target.isAlive || !target.x.isFinite || !target.y.isFinite) continue;
      final dx = target.x - fromX;
      final dy = target.y - fromY;
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = target;
      }
    }
    return nearest;
  }

  static double _distanceSquared(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return dx * dx + dy * dy;
  }

  static double mathMax(double a, double b) => a > b ? a : b;
}
