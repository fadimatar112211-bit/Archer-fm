import 'dart:math' as math;

import '../monsters/monster_navigation.dart';
import 'arena_map.dart';

/// Bridges the packaged, north-up arena map into the monster A* grid.
///
/// The monster system stores grid rows top-to-bottom, while the arena map uses
/// world +Y north. This adapter owns that conversion in one place:
///   world -> cell: col = floor(x + 48), row = floor(48 - y)
///   cell -> world: (col - 47.5, 47.5 - row)
///
/// It also exposes authored terrain costs through [neighbors], so roads are
/// cheaper than grass and rocky ground, and reuses the monster pathfinder's
/// corner-cutting rule.
class ArenaMonsterNavigationGrid extends MonsterNavigationGrid {
  ArenaMonsterNavigationGrid(this.map)
      : super(
          columns: ArenaMap.size,
          rows: ArenaMap.size,
          cellSize: ArenaMap.cellSize,
          originX: -ArenaMap.halfExtent,
          originY: -ArenaMap.halfExtent,
          blocked: map.blockedCells
              .map((cell) => MonsterGridCell(cell.col, cell.row))
              .toSet(),
          revision: map.revision,
        );

  final ArenaMap map;

  @override
  MonsterGridCell worldToCell(double x, double y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('World coordinates must be finite.');
    }
    return MonsterGridCell(
      (x + ArenaMap.halfExtent).floor(),
      (ArenaMap.halfExtent - y).floor(),
    );
  }

  @override
  (double, double) cellCenter(MonsterGridCell cell) => (
        cell.x - ArenaMap.halfExtent + 0.5,
        ArenaMap.halfExtent - cell.y - 0.5,
      );

  @override
  bool isWalkable(MonsterGridCell cell) =>
      contains(cell) && map.walkableCell(ArenaCell(cell.x, cell.y));

  @override
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
          continue;
        }
        final terrain = map.movementCost(ArenaCell(next.x, next.y));
        yield (next, (dx != 0 && dy != 0 ? math.sqrt2 : 1.0) * terrain);
      }
    }
  }
}
