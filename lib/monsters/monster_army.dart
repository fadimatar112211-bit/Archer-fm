import 'dart:math' as math;

import 'monster_models.dart';

class InitialArmySelection {
  InitialArmySelection(Map<MonsterType, int> counts)
      : counts = Map.unmodifiable(counts) {
    if (MonsterType.values.any((type) => (this.counts[type] ?? 0) < 0)) {
      throw ArgumentError('Initial army counts cannot be negative.');
    }
    if (counts.keys.any((type) => !MonsterType.values.contains(type))) {
      throw ArgumentError('Initial army contains an unknown monster type.');
    }
    final total = MonsterType.values.fold<int>(
      0, (sum, type) => sum + (this.counts[type] ?? 0),
    );
    if (total != 20) {
      throw ArgumentError('Initial army must contain exactly 20 monsters; got $total.');
    }
  }

  final Map<MonsterType, int> counts;
}

class MonsterPurchase {
  const MonsterPurchase({required this.unit, required this.cost});
  final MonsterUnit unit;
  final int cost;
}

class MonsterArmy {
  MonsterArmy({
    required this.ownerId,
    required this.catalog,
    required this.selection,
    required this.castleX,
    required this.castleY,
  }) {
    if (ownerId.isEmpty) throw ArgumentError.value(ownerId, 'ownerId');
    if (!castleX.isFinite || !castleY.isFinite) {
      throw ArgumentError('Castle position must be finite.');
    }
    for (final type in MonsterType.values) {
      final count = selection.counts[type] ?? 0;
      for (var i = 0; i < count; i++) {
        _units.add(_createUnit(type, _nextId));
      }
    }
    _spawnCursor = _nextId;
  }

  final String ownerId;
  final MonsterCatalog catalog;
  final InitialArmySelection selection;
  final double castleX;
  final double castleY;
  final List<MonsterUnit> _units = [];
  int _nextId = 0;
  int _spawnCursor = 0;

  List<MonsterUnit> get units => List.unmodifiable(_units);
  int get aliveCount => _units.where((unit) => unit.isAlive).length;
  int countOf(MonsterType type) =>
      _units.where((unit) => unit.type == type && unit.isAlive).length;

  MonsterUnit _createUnit(MonsterType type, int index) {
    final slot = index % 8;
    final ring = index ~/ 8;
    final angle = slot * (math.pi / 4);
    final radius = 34.0 + ring * 24.0;
    final stats = catalog[type].baseStats;
    final unit = MonsterUnit(
      id: '$ownerId-monster-${_nextId++}',
      ownerId: ownerId,
      type: type,
      positionX: castleX + radius * math.cos(angle),
      positionY: castleY + radius * math.sin(angle),
      stats: stats,
    );
    return unit;
  }

  /// Returns the exact cost with the spawned unit; the economy must debit this
  /// amount atomically before accepting the purchase in the match state.
  MonsterPurchase? purchase({
    required MonsterType type,
    required int currentResources,
  }) {
    if (currentResources < 0) {
      throw ArgumentError.value(currentResources, 'currentResources');
    }
    final cost = catalog[type].baseStats.purchaseCost;
    if (currentResources < cost) return null;
    final unit = _createUnit(type, _spawnCursor++);
    _units.add(unit);
    return MonsterPurchase(unit: unit, cost: cost);
  }

  /// Moves the army toward a shared destination while retaining local spacing.
  /// Individual units retain independent positions and target decisions.
  void moveGroupToward({
    required double targetX,
    required double targetY,
    required Duration elapsed,
    double cohesion = 0.35,
  }) {
    if (!targetX.isFinite || !targetY.isFinite ||
        !cohesion.isFinite || cohesion < 0 || cohesion > 1 ||
        elapsed.isNegative) {
      throw ArgumentError('Invalid group movement input.');
    }
    if (elapsed == Duration.zero) return;
    final living = _units.where((unit) => unit.isAlive).toList();
    if (living.isEmpty) return;
    final centerX = living.fold<double>(0, (sum, unit) => sum + unit.positionX) / living.length;
    final centerY = living.fold<double>(0, (sum, unit) => sum + unit.positionY) / living.length;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;

    for (final unit in living) {
      final desiredX = targetX + (unit.positionX - centerX) * cohesion;
      final desiredY = targetY + (unit.positionY - centerY) * cohesion;
      final dx = desiredX - unit.positionX;
      final dy = desiredY - unit.positionY;
      final distance = math.sqrt(dx * dx + dy * dy);
      final step = unit.stats.moveSpeed * seconds;
      if (distance <= step || distance == 0) {
        unit.positionX = desiredX;
        unit.positionY = desiredY;
      } else {
        unit.positionX += dx / distance * step;
        unit.positionY += dy / distance * step;
      }
    }
  }

  /// Removes defeated units permanently; they are never auto-respawned.
  bool removeDefeated(String unitId) {
    final index = _units.indexWhere((unit) => unit.id == unitId);
    if (index < 0 || _units[index].isAlive) return false;
    _units.removeAt(index);
    return true;
  }
}
