import 'dart:math' as math;

import 'monster_models.dart';

/// Integer coordinate of a walkable cell in a [MonsterNavigationGrid].
class MonsterGridCell {
  const MonsterGridCell(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is MonsterGridCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'MonsterGridCell($x, $y)';
}

/// Immutable navigation snapshot supplied by the map/match layer.
///
/// Increment [revision] whenever obstacle geometry changes. Cached routes are
/// invalidated automatically when the revision changes.
class MonsterNavigationGrid {
  MonsterNavigationGrid({
    required this.columns,
    required this.rows,
    required this.cellSize,
    this.originX = 0,
    this.originY = 0,
    Set<MonsterGridCell> blocked = const {},
    this.revision = 0,
  }) : blockedCells = Set.unmodifiable(blocked) {
    if (columns <= 0 ||
        rows <= 0 ||
        !cellSize.isFinite ||
        cellSize <= 0 ||
        !originX.isFinite ||
        !originY.isFinite ||
        revision < 0) {
      throw ArgumentError('Invalid monster navigation grid geometry.');
    }
  }

  final int columns;
  final int rows;
  final double cellSize;
  final double originX;
  final double originY;
  final int revision;
  final Set<MonsterGridCell> blockedCells;

  bool contains(MonsterGridCell cell) =>
      cell.x >= 0 && cell.y >= 0 && cell.x < columns && cell.y < rows;

  bool isWalkable(MonsterGridCell cell) =>
      contains(cell) && !blockedCells.contains(cell);

  MonsterGridCell worldToCell(double x, double y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('World coordinates must be finite.');
    }
    return MonsterGridCell(
      ((x - originX) / cellSize).floor(),
      ((y - originY) / cellSize).floor(),
    );
  }

  (double, double) cellCenter(MonsterGridCell cell) => (
        originX + (cell.x + 0.5) * cellSize,
        originY + (cell.y + 0.5) * cellSize,
      );

  Iterable<(MonsterGridCell, double)> neighbors(
    MonsterGridCell cell, {
    bool allowDiagonal = true,
  }) sync* {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        if (!allowDiagonal && dx != 0 && dy != 0) continue;
        final next = MonsterGridCell(cell.x + dx, cell.y + dy);
        if (!isWalkable(next)) continue;
        if (dx != 0 &&
            dy != 0 &&
            (!isWalkable(MonsterGridCell(cell.x + dx, cell.y)) ||
                !isWalkable(MonsterGridCell(cell.x, cell.y + dy)))) {
          // Do not cut diagonally through the corner of two blocked cells.
          continue;
        }
        yield (next, dx == 0 || dy == 0 ? 1.0 : math.sqrt2);
      }
    }
  }
}

/// A* path planner with per-unit route caching and bounded search work.
///
/// It returns the next world-space waypoint rather than exposing movement
/// integration. The combat/movement systems remain responsible for speed,
/// collision handling, and deciding when a target is in attack range.
class MonsterPathfinder {
  MonsterPathfinder({
    this.maxExpandedNodes = 12000,
    this.waypointTolerance = 0.3,
  }) {
    if (maxExpandedNodes <= 0 ||
        !waypointTolerance.isFinite ||
        waypointTolerance <= 0) {
      throw ArgumentError('Invalid pathfinder limits.');
    }
  }

  final int maxExpandedNodes;
  final double waypointTolerance;
  final Map<String, _CachedMonsterPath> _routes = {};

  int get cachedRouteCount => _routes.length;

  /// Returns a full cell path including the start and goal cells, or null
  /// when the goal is unreachable or the expansion budget is exhausted.
  List<MonsterGridCell>? findPath({
    required MonsterNavigationGrid grid,
    required double startX,
    required double startY,
    required double goalX,
    required double goalY,
    double goalRange = 0,
  }) {
    if (!startX.isFinite ||
        !startY.isFinite ||
        !goalX.isFinite ||
        !goalY.isFinite ||
        !goalRange.isFinite ||
        goalRange < 0) {
      throw ArgumentError('Invalid pathfinding coordinates or goal range.');
    }

    final start = grid.worldToCell(startX, startY);
    final goal = grid.worldToCell(goalX, goalY);
    if (!grid.isWalkable(start)) return null;

    final open = _PathMinHeap();
    final cameFrom = <MonsterGridCell, MonsterGridCell>{};
    final scores = <MonsterGridCell, double>{start: 0};
    final closed = <MonsterGridCell>{};
    var sequence = 0;
    open.add(_PathNode(
      cell: start,
      cost: 0,
      estimate: _heuristic(
        start,
        goal,
        grid.cellSize,
        grid.originX,
        grid.originY,
        goalX,
        goalY,
        goalRange,
      ),
      sequence: sequence++,
    ));

    var expanded = 0;
    while (open.isNotEmpty && expanded < maxExpandedNodes) {
      final current = open.removeFirst();
      final bestKnown = scores[current.cell];
      if (bestKnown == null || current.cost > bestKnown || !closed.add(current.cell)) {
        continue;
      }
      expanded++;

      final center = grid.cellCenter(current.cell);
      final dx = center.$1 - goalX;
      final dy = center.$2 - goalY;
      if ((current.cell == goal && grid.isWalkable(goal)) ||
          dx * dx + dy * dy <= goalRange * goalRange) {
        return _reconstruct(cameFrom, start, current.cell);
      }

      for (final edge in grid.neighbors(current.cell)) {
        final next = edge.$1;
        if (closed.contains(next)) continue;
        final tentative = current.cost + edge.$2;
        final previous = scores[next];
        if (previous != null && tentative >= previous) continue;
        cameFrom[next] = current.cell;
        scores[next] = tentative;
        open.add(_PathNode(
          cell: next,
          cost: tentative,
          estimate: _heuristic(
                next,
                goal,
                grid.cellSize,
                grid.originX,
                grid.originY,
                goalX,
                goalY,
                goalRange,
              ),
          sequence: sequence++,
        ));
      }
    }
    return null;
  }

  /// Returns the next cached waypoint for [unit], replanning when its target
  /// cell or map revision changes. [goalRange] is normally the unit's range.
  (double, double)? nextWaypoint({
    required MonsterUnit unit,
    required MonsterNavigationGrid grid,
    required double targetX,
    required double targetY,
    double goalRange = 0,
  }) {
    if (!unit.isAlive) {
      release(unit.id);
      return null;
    }
    if (!unit.positionX.isFinite ||
        !unit.positionY.isFinite ||
        !targetX.isFinite ||
        !targetY.isFinite ||
        !goalRange.isFinite ||
        goalRange < 0) {
      throw ArgumentError('Invalid live navigation state.');
    }

    final startCell = grid.worldToCell(unit.positionX, unit.positionY);
    final targetCell = grid.worldToCell(targetX, targetY);
    var route = _routes[unit.id];
    final targetMoved = route != null &&
        _distanceSquared(route.targetX, route.targetY, targetX, targetY) >
            grid.cellSize * grid.cellSize * 0.25;
    final deviated = route != null &&
        startCell != route.lastObservedCell &&
        !route.path.contains(startCell);
    if (route == null ||
        route.targetCell != targetCell ||
        route.gridRevision != grid.revision ||
        route.goalRange != goalRange ||
        targetMoved ||
        deviated) {
      final path = findPath(
        grid: grid,
        startX: unit.positionX,
        startY: unit.positionY,
        goalX: targetX,
        goalY: targetY,
        goalRange: goalRange,
      );
      if (path == null) {
        _routes.remove(unit.id);
        return null;
      }
      route = _CachedMonsterPath(
        path: path.length > 1 ? path.sublist(1) : const [],
        targetCell: targetCell,
        gridRevision: grid.revision,
        targetX: targetX,
        targetY: targetY,
        goalRange: goalRange,
        lastObservedCell: startCell,
      );
      _routes[unit.id] = route;
    } else {
      route.lastObservedCell = startCell;
      final routeCellIndex = route.path.indexOf(startCell);
      if (routeCellIndex >= route.nextIndex) {
        route.nextIndex = routeCellIndex + 1;
      }
    }

    final tolerance = grid.cellSize * waypointTolerance;
    while (route.nextIndex < route.path.length) {
      final point = grid.cellCenter(route.path[route.nextIndex]);
      if (_distanceSquared(unit.positionX, unit.positionY, point.$1, point.$2) >
          tolerance * tolerance) {
        return point;
      }
      route.nextIndex++;
    }

    // The unit has reached the final cell. A direct final approach is safe:
    // MonsterFormationMovement performs hard obstacle collision resolution.
    return (targetX, targetY);
  }

  void release(String unitId) => _routes.remove(unitId);

  void clear() => _routes.clear();

  static List<MonsterGridCell> _reconstruct(
    Map<MonsterGridCell, MonsterGridCell> cameFrom,
    MonsterGridCell start,
    MonsterGridCell goal,
  ) {
    final reversed = <MonsterGridCell>[goal];
    var current = goal;
    while (current != start) {
      final previous = cameFrom[current];
      if (previous == null) return const [];
      current = previous;
      reversed.add(current);
    }
    return reversed.reversed.toList(growable: false);
  }

  static double _heuristic(
    MonsterGridCell cell,
    MonsterGridCell goal,
    double cellSize,
    double originX,
    double originY,
    double goalX,
    double goalY,
    double goalRange,
  ) {
    final dx = (cell.x - goal.x).abs().toDouble();
    final dy = (cell.y - goal.y).abs().toDouble();
    final diagonal = math.min(dx, dy);
    final straight = math.max(dx, dy) - diagonal;
    final cellDistance = (straight + diagonal * math.sqrt2) * cellSize;
    final center = (
      originX + (cell.x + 0.5) * cellSize,
      originY + (cell.y + 0.5) * cellSize,
    );
    final worldDistance = math.sqrt(
      _distanceSquared(center.$1, center.$2, goalX, goalY),
    );
    return math.max(0, math.min(cellDistance, worldDistance) - goalRange).toDouble();
  }

  static double _distanceSquared(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return dx * dx + dy * dy;
  }
}

class _CachedMonsterPath {
  _CachedMonsterPath({
    required this.path,
    required this.targetCell,
    required this.gridRevision,
    required this.targetX,
    required this.targetY,
    required this.goalRange,
    required this.lastObservedCell,
  });

  final List<MonsterGridCell> path;
  final MonsterGridCell targetCell;
  final int gridRevision;
  final double targetX;
  final double targetY;
  final double goalRange;
  MonsterGridCell lastObservedCell;
  int nextIndex = 0;
}

class _PathNode {
  const _PathNode({
    required this.cell,
    required this.cost,
    required this.estimate,
    required this.sequence,
  });

  final MonsterGridCell cell;
  final double cost;
  final double estimate;
  final int sequence;

  double get priority => cost + estimate;
}

class _PathMinHeap {
  final List<_PathNode> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void add(_PathNode value) {
    _items.add(value);
    var index = _items.length - 1;
    while (index > 0) {
      final parent = (index - 1) ~/ 2;
      if (!_less(_items[index], _items[parent])) break;
      final swap = _items[index];
      _items[index] = _items[parent];
      _items[parent] = swap;
      index = parent;
    }
  }

  _PathNode removeFirst() {
    if (_items.isEmpty) throw StateError('Path queue is empty.');
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isEmpty) return first;
    _items[0] = last;
    var index = 0;
    while (true) {
      final left = index * 2 + 1;
      final right = left + 1;
      var smallest = index;
      if (left < _items.length && _less(_items[left], _items[smallest])) {
        smallest = left;
      }
      if (right < _items.length && _less(_items[right], _items[smallest])) {
        smallest = right;
      }
      if (smallest == index) break;
      final swap = _items[index];
      _items[index] = _items[smallest];
      _items[smallest] = swap;
      index = smallest;
    }
    return first;
  }

  bool _less(_PathNode a, _PathNode b) {
    if (a.priority != b.priority) return a.priority < b.priority;
    if (a.estimate != b.estimate) return a.estimate < b.estimate;
    return a.sequence < b.sequence;
  }
}
