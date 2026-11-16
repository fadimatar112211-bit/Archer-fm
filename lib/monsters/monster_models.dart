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
       assert(attackCooldown > 0),
       assert(purchaseCost >= 0);

  final double maxHealth;
  final double damage;
  final double moveSpeed;
  final double attackRange;
  final Duration attackCooldown;
  final int purchaseCost;

  MonsterStats scaledForLevel(int level) {
    final safeLevel = level.clamp(1, 40);
    final multiplier = 1 + (safeLevel - 1) * 0.025;
    return MonsterStats(
      maxHealth: maxHealth * multiplier,
      damage: damage * multiplier,
      moveSpeed: moveSpeed * (1 + (safeLevel - 1) * 0.008),
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
  bool get isAlive => health > 0;

  bool applyDamage(double amount) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    if (!isAlive) return true;
    health = (health - amount).clamp(0, stats.maxHealth).toDouble();
    return !isAlive;
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
    MonsterTarget? best;
    var bestDistanceSquared = maxDistance * maxDistance;
    for (final candidate in candidates) {
      if (!candidate.isAlive || candidate.ownerId == ownerId) continue;
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
    final threats = candidates.where(
      (target) => target.kind == MonsterTargetKind.crystal &&
          target.ownerId == ownerId &&
          target.isAlive,
    );
    MonsterTarget? nearestThreat;
    var nearestDistance = double.infinity;
    for (final threat in threats) {
      final dx = threat.x - fromX;
      final dy = threat.y - fromY;
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestThreat = threat;
      }
    }
    return nearestThreat;
  }
}
