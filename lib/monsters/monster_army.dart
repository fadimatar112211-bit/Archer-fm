import 'dart:math' as math;\n\nimport 'monster_models.dart';

class InitialArmySelection {
  InitialArmySelection(Map<MonsterType, int> counts)
      : counts = Map.unmodifiable(counts) {
    if (MonsterType.values.any((type) => (this.counts[type] ?? 0) < 0)) {
      throw ArgumentError('Initial army counts cannot be negative.');
    }
    final total = MonsterType.values.fold<int>(
      0,
      (sum, type) => sum + (this.counts[type] ?? 0),
    );
    if (total != 20) {
      throw ArgumentError('Initial army must contain exactly 20 monsters; got $total.');
    }
  }

  final Map<MonsterType, int> counts;
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
    var index = 0;
    for (final type in MonsterType.values) {
      final count = selection.counts[type] ?? 0;
      for (var i = 0; i < count; i++) {
        _units.add(_createUnit(type, index++));
      }
    }
    _nextId = index;
  }

  final String ownerId;
  final MonsterCatalog catalog;
  final InitialArmySelection selection;
  final double castleX;
  final double castleY;
  final List<MonsterUnit> _units = [];
  int _nextId = 0;
  int _formationCursor = 0;

  List<MonsterUnit> get units => List.unmodifiable(_units);
  int get aliveCount => _units.where((unit) => unit.isAlive).length;
  int countOf(MonsterType type) =>
      _units.where((unit) => unit.type == type && unit.isAlive).length;

  MonsterUnit _createUnit(MonsterType type, int index) {
    // Compact deterministic ring around the castle; the world layer may
    // resolve collisions against terrain after receiving these spawn points.
    final slot = index % 20;
    final ring = slot ~/ 8;
    final angle = slot * 0.7853981633974483;
    final radius = 34.0 + ring * 24.0;
    final stats = catalog[type].baseStats;
    return MonsterUnit(
      id: '$ownerId-monster-${_nextId++}',
      ownerId: ownerId,
      type: type,
      positionX: castleX + radius * _cos(angle),
      positionY: castleY + radius * _sin(angle),
      stats: stats,
    );
  }

  bool purchase({
    required MonsterType type,
    required int currentResources,
  }) {
    if (currentResources < 0) {
      throw ArgumentError.value(currentResources, 'currentResources');
    }
    final cost = catalog[type].baseStats.purchaseCost;
    if (currentResources < cost) return false;
    _units.add(_createUnit(type, _formationCursor++));
    return true;
  }

  /// Removes defeated units permanently; they are never auto-respawned.
  bool removeDefeated(String unitId) {
    final index = _units.indexWhere((unit) => unit.id == unitId);
    if (index < 0 || _units[index].isAlive) return false;
    _units.removeAt(index);
    return true;
  }

  static double _sin(double value) {
    // Small deterministic approximation is replaced by dart:math below.
    return _Trig.sin(value);
  }

  static double _cos(double value) => _Trig.cos(value);
}

class _Trig {
  static double sin(double value) => _sinImpl(value);
  static double cos(double value) => _cosImpl(value);
}
