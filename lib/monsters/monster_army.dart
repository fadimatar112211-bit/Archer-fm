import 'dart:math' as math;

import 'monster_models.dart';
import 'monster_formation_movement.dart';

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
    this.maxUnits,
  }) {
    if (ownerId.isEmpty) throw ArgumentError.value(ownerId, 'ownerId');
    if (!castleX.isFinite || !castleY.isFinite) {
      throw ArgumentError('Castle position must be finite.');
    }
    if (maxUnits != null && maxUnits! < 20) {
      throw ArgumentError.value(maxUnits, 'maxUnits', 'Must allow the 20-unit starting army.');
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

  /// Optional device/runtime safety budget, not a game-design army limit.
  /// Leave unset until the target device profile has been measured.
  final int? maxUnits;

  final List<MonsterUnit> _units = [];
  int _nextId = 0;
  int _spawnCursor = 0;

  List<MonsterUnit> get units => List.unmodifiable(_units);
  int get aliveCount => _units.where((unit) => unit.isAlive).length;
  int countOf(MonsterType type) =>
      _units.where((unit) => unit.type == type && unit.isAlive).length;
  bool get canPurchase => maxUnits == null || aliveCount < maxUnits!;

  MonsterUnit _createUnit(MonsterType type, int index) {
    final slot = index % 8;
    final ring = index ~/ 8;
    final angle = slot * (math.pi / 4);
    final radius = 34.0 + ring * 24.0;
    final stats = catalog[type].baseStats;
    return MonsterUnit(
      id: '$ownerId-monster-${_nextId++}',
      ownerId: ownerId,
      type: type,
      positionX: castleX + radius * math.cos(angle),
      positionY: castleY + radius * math.sin(angle),
      stats: stats,
    );
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
    if (!canPurchase) return null;
    final cost = catalog[type].baseStats.purchaseCost;
    if (currentResources < cost) return null;
    final unit = _createUnit(type, _spawnCursor++);
    _units.add(unit);
    return MonsterPurchase(unit: unit, cost: cost);
  }

  /// Debits authoritative resources before spawning and refunds on any failure.
  /// [tryDebit] must be an atomic compare-and-debit operation on match state.
  MonsterPurchase? purchaseAtomically({
    required MonsterType type,
    required int currentResources,
    required bool Function(int amount) tryDebit,
    required void Function(int amount) refund,
  }) {
    if (currentResources < 0) {
      throw ArgumentError.value(currentResources, 'currentResources');
    }
    if (!canPurchase) return null;
    final cost = catalog[type].baseStats.purchaseCost;
    if (currentResources < cost || !tryDebit(cost)) return null;
    try {
      final result = purchase(
        type: type,
        currentResources: currentResources,
      );
      if (result == null) {
        refund(cost);
        return null;
      }
      return result;
    } catch (_) {
      refund(cost);
      rethrow;
    }
  }

  /// Moves the army toward a shared destination while retaining local spacing.
  /// Individual units retain independent positions and target decisions.
  void moveGroupToward({
    required double targetX,
    required double targetY,
    required Duration elapsed,
    double cohesion = 0.35,
    Iterable<MonsterMovementObstacle> obstacles = const [],
  }) {
    if (!cohesion.isFinite || cohesion < 0 || cohesion > 1) {
      throw ArgumentError.value(cohesion, 'cohesion');
    }
    MonsterFormationMovement(cohesionWeight: cohesion).moveGroup(
      units: _units,
      targetX: targetX,
      targetY: targetY,
      elapsed: elapsed,
      obstacles: obstacles,
    );
  }

  /// Removes defeated units permanently; they are never auto-respawned.
  bool removeDefeated(String unitId) {
    final index = _units.indexWhere((unit) => unit.id == unitId);
    if (index < 0 || _units[index].isAlive) return false;
    _units.removeAt(index);
    return true;
  }
}
