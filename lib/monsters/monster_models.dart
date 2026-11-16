enum MonsterType { runner, tank, stalker, ranged }

enum MonsterTargetKind { hero, monster, crystal }

enum MonsterOrder { advance, defend }

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
       assert(attackCooldown != Duration.zero),
       assert(purchaseCost >= 0);

  final double maxHealth;
  final double damage;
  final double moveSpeed;
  final double attackRange;
  final Duration attackCooldown;
  final int purchaseCost;

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
    return MonsterStats(
      maxHealth: maxHealth * (1 + steps * healthPerLevel),
      damage: damage * (1 + steps * damagePerLevel),
      moveSpeed: moveSpeed * (1 + steps * speedPerLevel),
      attackRange: attackRange,
      attackCooldown: attackCooldown,
      purchaseCost: purchaseCost,
    );
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
    double? health,
  }) : health = health ?? stats.maxHealth {
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
    if (maxDistance < 0 || maxDistance.isNaN) {
      throw ArgumentError.value(maxDistance, 'maxDistance');
    }
    MonsterTarget? best;
    var bestDistanceSquared = maxDistance * maxDistance;
    for (final candidate in candidates) {
      if (!candidate.isAlive || candidate.ownerId == ownerId) continue;
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

  MonsterTarget? defensiveTarget({
    required String ownerId,
    required double fromX,
    required double fromY,
    required Iterable<MonsterTarget> candidates,
  }) {
    MonsterTarget? nearest;
    var nearestDistance = double.infinity;
    for (final target in candidates) {
      if (target.kind != MonsterTargetKind.crystal ||
          target.ownerId != ownerId ||
          !target.isAlive) continue;
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
}
