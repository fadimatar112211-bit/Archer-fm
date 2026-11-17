import 'dart:math' as math;

import 'monster_models.dart';

/// Per-tick spatial hash used to find nearby allied monsters without scanning
/// the entire army for every unit.
class MonsterSpatialIndex {
  MonsterSpatialIndex({
    required Iterable<MonsterUnit> units,
    required this.cellSize,
  }) {
    if (!cellSize.isFinite || cellSize <= 0) {
      throw ArgumentError.value(cellSize, 'cellSize');
    }
    for (final unit in units) {
      if (unit.isAlive) _insert(unit);
    }
  }

  final double cellSize;
  final Map<(int, int), List<MonsterUnit>> _buckets = {};
  final Map<String, (int, int)> _cellByUnitId = {};
  final Map<String, MonsterUnit> _unitsById = {};

  int get unitCount => _unitsById.length;

  /// Updates an entry after a unit moves or dies during the current tick.
  void update(MonsterUnit unit) {
    _remove(unit.id);
    if (unit.isAlive) _insert(unit);
  }

  /// Returns living allies within [radius], excluding [source] itself.
  List<MonsterUnit> nearbyUnits(
    MonsterUnit source, {
    required double radius,
  }) {
    if (!radius.isFinite || radius < 0 ||
        !source.positionX.isFinite || !source.positionY.isFinite) {
      throw ArgumentError('Invalid spatial query.');
    }
    final centerCell = _cell(source.positionX, source.positionY);
    final range = (radius / cellSize).ceil();
    final radiusSquared = radius * radius;
    final result = <MonsterUnit>[];

    if (range > 64) {
      for (final candidate in _unitsById.values) {
        _addIfNearby(result, candidate, source, radiusSquared);
      }
      return List.unmodifiable(result);
    }

    for (var y = centerCell.$2 - range; y <= centerCell.$2 + range; y++) {
      for (var x = centerCell.$1 - range; x <= centerCell.$1 + range; x++) {
        final bucket = _buckets[(x, y)];
        if (bucket == null) continue;
        for (final candidate in bucket) {
          _addIfNearby(result, candidate, source, radiusSquared);
        }
      }
    }
    return List.unmodifiable(result);
  }

  void _addIfNearby(
    List<MonsterUnit> result,
    MonsterUnit candidate,
    MonsterUnit source,
    double radiusSquared,
  ) {
    if (!candidate.isAlive ||
        candidate.id == source.id ||
        candidate.ownerId != source.ownerId) {
      return;
    }
    final dx = candidate.positionX - source.positionX;
    final dy = candidate.positionY - source.positionY;
    if (dx * dx + dy * dy <= radiusSquared) result.add(candidate);
  }

  void _insert(MonsterUnit unit) {
    if (!unit.positionX.isFinite || !unit.positionY.isFinite) {
      throw ArgumentError('Spatial-index unit positions must be finite.');
    }
    final cell = _cell(unit.positionX, unit.positionY);
    _buckets.putIfAbsent(cell, () => []).add(unit);
    _cellByUnitId[unit.id] = cell;
    _unitsById[unit.id] = unit;
  }

  void _remove(String unitId) {
    final previousCell = _cellByUnitId.remove(unitId);
    _unitsById.remove(unitId);
    if (previousCell == null) return;
    final bucket = _buckets[previousCell];
    bucket?.removeWhere((unit) => unit.id == unitId);
    if (bucket != null && bucket.isEmpty) _buckets.remove(previousCell);
  }

  (int, int) _cell(double x, double y) =>
      ((x / cellSize).floor(), (y / cellSize).floor());
}
