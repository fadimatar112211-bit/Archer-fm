// Archer FM arena map: production loader for the packaged 96x96 map.
//
// Source of truth (kept in assets/maps/source/ and assets/maps/arena/):
//   data/archer_fm_map.json, data/nav_grid.txt, data/height_map.csv
//
// World space: 1 unit = 1 metre = 1 navigation cell, +X east, +Y north.
// Cell space: col = floor(x + 48), row = floor(48 - y).
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// A walkable grid cell in arena (column/row) space.
class ArenaCell {
  const ArenaCell(this.col, this.row);

  final int col;
  final int row;

  ArenaCell offset(int dc, int dr) => ArenaCell(col + dc, row + dr);

  @override
  bool operator ==(Object other) =>
      other is ArenaCell && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => 'ArenaCell($col, $row)';
}

/// Axis-aligned footprint in world metres: [left, bottom, right, top].
class ArenaRect {
  const ArenaRect(this.left, this.bottom, this.right, this.top);

  factory ArenaRect.fromJson(Object? value) {
    final list = value as List<dynamic>;
    if (list.length != 4) {
      throw const FormatException('Arena rectangle must have four values.');
    }
    final n = list.cast<num>().map((v) => v.toDouble()).toList(growable: false);
    return ArenaRect(n[0], n[1], n[2], n[3]);
  }

  final double left;
  final double bottom;
  final double right;
  final double top;

  double get width => right - left;
  double get height => top - bottom;
  double get centerX => (left + right) / 2;
  double get centerY => (bottom + top) / 2;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= bottom && y <= top;
}

/// One of the seven crystals owned by each of the four players.
class ArenaCrystal {
  ArenaCrystal({
    required this.id,
    required this.ownerId,
    required this.tier,
    required this.x,
    required this.y,
    required this.footprint,
    required this.maxHealth,
  }) : health = maxHealth;

  final String id;
  final String ownerId;

  /// heart, inner, mid, outer as authored by the map package.
  final String tier;
  final double x;
  final double y;
  final ArenaRect footprint;
  final double maxHealth;

  double health;
  bool destroyed = false;

  bool get isAlive => !destroyed && health > 0;
  double get healthFraction =>
      maxHealth <= 0 ? 0 : (health / maxHealth).clamp(0.0, 1.0).toDouble();

  /// Applies damage and reports true only when this hit destroys the crystal.
  bool applyDamage(double amount) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    if (!isAlive) return false;
    health = math.max(0, health - amount);
    if (health > 0) return false;
    destroyed = true;
    return true;
  }
}

class ArenaTower {
  const ArenaTower({
    required this.id,
    required this.ownerId,
    required this.rect,
    required this.range,
  });

  final String id;
  final String ownerId;
  final ArenaRect rect;
  final double range;
}

class ArenaObstacle {
  const ArenaObstacle({required this.id, required this.ownerId, required this.rect});

  final String id;
  final String ownerId;
  final ArenaRect rect;
}

enum ArenaCampType { goblin, wolf, golem, crystalDrake }

ArenaCampType _parseCampType(String value) {
  switch (value) {
    case 'goblin':
      return ArenaCampType.goblin;
    case 'wolf':
      return ArenaCampType.wolf;
    case 'golem':
      return ArenaCampType.golem;
    case 'crystal_drake':
      return ArenaCampType.crystalDrake;
    default:
      throw FormatException('Unknown arena camp type: $value');
  }
}

String arenaCampTypeName(ArenaCampType type) {
  switch (type) {
    case ArenaCampType.goblin:
      return 'goblin';
    case ArenaCampType.wolf:
      return 'wolf';
    case ArenaCampType.golem:
      return 'golem';
    case ArenaCampType.crystalDrake:
      return 'crystal_drake';
  }
}

class ArenaCamp {
  const ArenaCamp({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.count,
    required this.leash,
    required this.spawnSeconds,
    required this.respawnSeconds,
  });

  final String id;
  final ArenaCampType type;
  final double x;
  final double y;
  final int count;
  final double leash;
  final double spawnSeconds;
  final double respawnSeconds;
}

class ArenaControlPoint {
  const ArenaControlPoint({
    required this.id,
    required this.x,
    required this.y,
    required this.captureRadius,
  });

  final String id;
  final double x;
  final double y;
  final double captureRadius;
}

class ArenaBridge {
  const ArenaBridge({
    required this.id,
    required this.centerX,
    required this.centerY,
    required this.width,
  });

  final String id;
  final double centerX;
  final double centerY;
  final double width;
}

class ArenaRiver {
  const ArenaRiver({
    required this.centerRadius,
    required this.width,
    required this.waterZ,
  });

  final String centerRadius;
  final double width;
  final double waterZ;
}

class ArenaPlayer {
  const ArenaPlayer({
    required this.id,
    required this.side,
    required this.colorValue,
    required this.castle,
    required this.spawnX,
    required this.spawnY,
    required this.cameraYawDeg,
  });

  final String id;
  final String side;

  /// 0xAARRGGBB value; the UI converts it to a Flutter Color.
  final int colorValue;
  final ArenaRect castle;
  final double spawnX;
  final double spawnY;
  final int cameraYawDeg;
}

/// Immutable parsed arena map plus the mutable navigation/height grid.
///
/// Call [destroyCrystal] when authoritative crystal health reaches zero; it
/// opens the crystal footprint and bumps [revision] so cached paths invalidate.
class ArenaMap {
  ArenaMap._({
    required this.name,
    required this.raw,
    required this.grid,
    required this.heights,
    required this.players,
    required this.crystals,
    required this.towers,
    required this.walls,
    required this.rocks,
    required this.camps,
    required this.controlPoints,
    required this.bridges,
    required this.river,
  });

  static const int size = 96;
  static const double cellSize = 1;
  static const double halfExtent = 48;

  static const Set<String> walkableChars = {'=', 'B', 'b', '.', ':'};
  static const Map<String, double> movementCosts = {
    '=': 1.0,
    'B': 1.0,
    'b': 1.0,
    '.': 1.25,
    ':': 1.6,
  };
  static const Set<String> shotBlockingChars = {'#', 'R', 'C', 'T'};

  final String name;
  final Map<String, dynamic> raw;
  final List<List<String>> grid;
  final List<List<double>> heights;
  final List<ArenaPlayer> players;
  final List<ArenaCrystal> crystals;
  final List<ArenaTower> towers;
  final List<ArenaObstacle> walls;
  final List<ArenaObstacle> rocks;
  final List<ArenaCamp> camps;
  final List<ArenaControlPoint> controlPoints;
  final List<ArenaBridge> bridges;
  final ArenaRiver? river;

  int _revision = 0;
  int get revision => _revision;

  /// Loads the runtime copy of the packaged map from Flutter assets.
  static Future<ArenaMap> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final results = await Future.wait([
      assets.loadString('assets/maps/arena/archer_fm_map.json'),
      assets.loadString('assets/maps/arena/nav_grid.txt'),
      assets.loadString('assets/maps/arena/height_map.csv'),
    ]);
    return ArenaMap.parse(
      jsonText: results[0],
      navGridText: results[1],
      heightMapCsv: results[2],
    );
  }

  /// Parses the three original package files without Flutter asset access.
  static ArenaMap parse({
    required String jsonText,
    required String navGridText,
    required String heightMapCsv,
  }) {
    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    final declared = (data['size'] as List).cast<num>();
    if (declared.length != 2 || declared[0].toInt() != size || declared[1].toInt() != size) {
      throw FormatException('Arena map size must be 96x96; got $declared.');
    }

    final gridRows = const LineSplitter()
        .convert(navGridText.trimRight())
        .map((line) => line.split(''))
        .toList(growable: false);
    if (gridRows.length != size) {
      throw FormatException('nav_grid.txt has ${gridRows.length} rows, expected $size.');
    }
    for (var row = 0; row < size; row++) {
      if (gridRows[row].length != size) {
        throw FormatException(
          'nav_grid.txt row $row has ${gridRows[row].length} columns, expected $size.',
        );
      }
    }

    final heightRows = const LineSplitter()
        .convert(heightMapCsv.trim())
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.split(',').map((v) => double.parse(v.trim())).toList(growable: false))
        .toList(growable: false);
    if (heightRows.length != size) {
      throw FormatException('height_map.csv has ${heightRows.length} rows, expected $size.');
    }
    for (var row = 0; row < size; row++) {
      if (heightRows[row].length != size) {
        throw FormatException(
          'height_map.csv row $row has ${heightRows[row].length} columns, expected $size.',
        );
      }
    }

    final players = <ArenaPlayer>[];
    final crystals = <ArenaCrystal>[];
    final towers = <ArenaTower>[];
    for (final rawPlayer in (data['players'] as List).cast<Map<String, dynamic>>()) {
      final id = rawPlayer['id'] as String;
      final spawn = (rawPlayer['spawn'] as List).cast<num>();
      players.add(ArenaPlayer(
        id: id,
        side: rawPlayer['side'] as String,
        colorValue: _parseColor(rawPlayer['color'] as String),
        castle: ArenaRect.fromJson(rawPlayer['castle']),
        spawnX: spawn[0].toDouble(),
        spawnY: spawn[1].toDouble(),
        cameraYawDeg: (rawPlayer['cameraYawDeg'] as num).toInt(),
      ));
      for (final rawCrystal in (rawPlayer['crystals'] as List).cast<Map<String, dynamic>>()) {
        crystals.add(ArenaCrystal(
          id: rawCrystal['id'] as String,
          ownerId: id,
          tier: rawCrystal['tier'] as String,
          x: (rawCrystal['x'] as num).toDouble(),
          y: (rawCrystal['y'] as num).toDouble(),
          footprint: ArenaRect.fromJson(rawCrystal['footprint']),
          maxHealth: (rawCrystal['hp'] as num).toDouble(),
        ));
      }
      for (final rawTower in (rawPlayer['towers'] as List).cast<Map<String, dynamic>>()) {
        towers.add(ArenaTower(
          id: rawTower['id'] as String,
          ownerId: id,
          rect: ArenaRect.fromJson(rawTower['rect']),
          range: (rawTower['range'] as num).toDouble(),
        ));
      }
    }

    List<ArenaObstacle> obstacles(String key, String ownerId) =>
        (data[key] as List).cast<Map<String, dynamic>>().map((item) {
          return ArenaObstacle(
            id: item['id'] as String,
            ownerId: ownerId,
            rect: ArenaRect.fromJson(item['rect']),
          );
        }).toList(growable: false);

    final camps = (data['camps'] as List).cast<Map<String, dynamic>>().map((item) {
      return ArenaCamp(
        id: item['id'] as String,
        type: _parseCampType(item['type'] as String),
        x: (item['x'] as num).toDouble(),
        y: (item['y'] as num).toDouble(),
        count: (item['count'] as num).toInt(),
        leash: (item['leash'] as num).toDouble(),
        spawnSeconds: (item['spawnSec'] as num).toDouble(),
        respawnSeconds: (item['respawnSec'] as num).toDouble(),
      );
    }).toList(growable: false);

    final points = (data['points'] as List).cast<Map<String, dynamic>>().map((item) {
      return ArenaControlPoint(
        id: item['id'] as String,
        x: (item['x'] as num).toDouble(),
        y: (item['y'] as num).toDouble(),
        captureRadius: (item['captureRadius'] as num).toDouble(),
      );
    }).toList(growable: false);

    final bridges = (data['bridges'] as List).cast<Map<String, dynamic>>().map((item) {
      final center = (item['center'] as List).cast<num>();
      return ArenaBridge(
        id: item['id'] as String,
        centerX: center[0].toDouble(),
        centerY: center[1].toDouble(),
        width: (item['width'] as num).toDouble(),
      );
    }).toList(growable: false);

    final rawRiver = data['river'] as Map<String, dynamic>?;
    final river = rawRiver == null
        ? null
        : ArenaRiver(
            centerRadius: rawRiver['centerRadius'] as String,
            width: (rawRiver['width'] as num).toDouble(),
            waterZ: (rawRiver['waterZ'] as num).toDouble(),
          );

    return ArenaMap._(
      name: data['name'] as String? ?? 'Archer FM Arena',
      raw: data,
      grid: gridRows,
      heights: heightRows,
      players: List.unmodifiable(players),
      crystals: crystals,
      towers: List.unmodifiable(towers),
      walls: List.unmodifiable(obstacles('walls', 'neutral')),
      rocks: List.unmodifiable(obstacles('rocks', 'neutral')),
      camps: List.unmodifiable(camps),
      controlPoints: List.unmodifiable(points),
      bridges: List.unmodifiable(bridges),
      river: river,
    );
  }

  static int _parseColor(String value) {
    final hex = value.replaceFirst('#', '');
    if (hex.length != 6) throw FormatException('Invalid arena color: $value');
    return 0xFF000000 | int.parse(hex, radix: 16);
  }

  bool inside(int col, int row) =>
      col >= 0 && row >= 0 && col < size && row < size;

  bool insideCell(ArenaCell cell) => inside(cell.col, cell.row);

  String charAt(int col, int row) => grid[row][col];

  bool walkableCell(ArenaCell cell) =>
      insideCell(cell) && walkableChars.contains(charAt(cell.col, cell.row));

  bool walkableAt(double x, double y) => walkableCell(worldToCell(x, y));

  double movementCost(ArenaCell cell) =>
      movementCosts[charAt(cell.col, cell.row)] ?? double.infinity;

  bool blocksShot(ArenaCell cell) =>
      !insideCell(cell) || shotBlockingChars.contains(charAt(cell.col, cell.row));

  bool blocksShotAt(double x, double y) => blocksShot(worldToCell(x, y));

  ArenaCell worldToCell(double x, double y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Arena world coordinates must be finite.');
    }
    return ArenaCell((x + halfExtent).floor(), (halfExtent - y).floor());
  }

  (double, double) cellCenter(ArenaCell cell) => (
        cell.col - halfExtent + 0.5,
        halfExtent - cell.row - 0.5,
      );

  (double, double) cellCorner(int col, int row, {bool right = false, bool top = false}) {
    // Cell (col,row) covers x in [col-48, col-47], y in [47-row, 48-row].
    final x = col - halfExtent + (right ? 1.0 : 0.0);
    final y = halfExtent - row - (top ? 0.0 : 1.0);
    return (x, y);
  }

  double heightAtCell(ArenaCell cell) {
    if (!insideCell(cell)) return 0;
    return heights[cell.row][cell.col];
  }

  double heightAtWorld(double x, double y) {
    final cell = worldToCell(x, y);
    return heightAtCell(cell);
  }

  ArenaCrystal? crystalById(String id) {
    for (final crystal in crystals) {
      if (crystal.id == id) return crystal;
    }
    return null;
  }

  Iterable<ArenaCrystal> crystalsOf(String ownerId) =>
      crystals.where((crystal) => crystal.ownerId == ownerId);

  Iterable<ArenaCell> footprintCells(ArenaRect rect) sync* {
    final left = worldToCell(rect.left + .5, rect.top - .5);
    final right = worldToCell(rect.right - .5, rect.bottom + .5);
    final firstCol = math.min(left.col, right.col);
    final lastCol = math.max(left.col, right.col);
    final firstRow = math.min(left.row, right.row);
    final lastRow = math.max(left.row, right.row);
    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        if (inside(col, row)) yield ArenaCell(col, row);
      }
    }
  }

  /// A* over the map's authored per-cell movement costs.
  ///
  /// Eight directions are allowed, diagonal corner cutting is forbidden, and
  /// blocked cells (water, walls, rocks, castles, towers, intact crystals) are
  /// never entered. The returned list includes both start and goal cells.
  List<ArenaCell> findPath(ArenaCell start, ArenaCell goal, {int maxExpanded = 20000}) {
    if (!walkableCell(start) || !walkableCell(goal)) return const [];

    double heuristic(ArenaCell cell) {
      final dx = (cell.col - goal.col).abs().toDouble();
      final dy = (cell.row - goal.row).abs().toDouble();
      final diagonal = math.min(dx, dy);
      final straight = math.max(dx, dy) - diagonal;
      return straight + diagonal * math.sqrt2;
    }

    final open = SplayTreeSet<ArenaPathNode>((a, b) {
      final byCost = a.priority.compareTo(b.priority);
      return byCost != 0 ? byCost : a.cell.row * size + a.cell.col - (b.cell.row * size + b.cell.col);
    });
    final costs = <ArenaCell, double>{start: 0};
    final cameFrom = <ArenaCell, ArenaCell>{};
    final closed = <ArenaCell>{};
    open.add(ArenaPathNode(start, 0, heuristic(start)));

    var expanded = 0;
    while (open.isNotEmpty && expanded < maxExpanded) {
      final current = open.first;
      open.remove(current);
      if (!closed.add(current.cell)) continue;
      expanded++;
      if (current.cell == goal) {
        final reversed = <ArenaCell>[goal];
        var cursor = goal;
        while (cursor != start) {
          final previous = cameFrom[cursor];
          if (previous == null) return const [];
          cursor = previous;
          reversed.add(cursor);
        }
        return reversed.reversed.toList(growable: false);
      }
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dc == 0 && dr == 0) continue;
          final next = ArenaCell(current.cell.col + dc, current.cell.row + dr);
          if (!walkableCell(next) || closed.contains(next)) continue;
          // A diagonal step may not cut through either orthogonal corner.
          if (dc != 0 &&
              dr != 0 &&
              (!walkableCell(ArenaCell(current.cell.col + dc, current.cell.row)) ||
                  !walkableCell(ArenaCell(current.cell.col, current.cell.row + dr)))) {
            continue;
          }
          final step = (dc != 0 && dr != 0 ? math.sqrt2 : 1.0) * movementCost(next);
          final tentative = current.cost + step;
          final previous = costs[next];
          if (previous != null && tentative >= previous) continue;
          costs[next] = tentative;
          cameFrom[next] = current.cell;
          open.add(ArenaPathNode(next, tentative, tentative + heuristic(next)));
        }
      }
    }
    return const [];
  }

  /// Converts a grid path to world waypoints, dropping points that a clear
  /// line of sight can skip. Keeps the final goal exactly.
  List<(double, double)> worldPath(List<ArenaCell> cells) {
    if (cells.length < 2) {
      return cells.map(cellCenter).toList(growable: false);
    }
    final points = <(double, double)>[cellCenter(cells.first)];
    var anchor = cells.first;
    for (var i = 1; i < cells.length; i++) {
      final candidate = cells[i];
      final isLast = i == cells.length - 1;
      if (!isLast && _clearCellLine(anchor, candidate)) continue;
      points.add(cellCenter(candidate));
      anchor = candidate;
    }
    return points;
  }

  bool _clearCellLine(ArenaCell a, ArenaCell b) {
    final ax = a.col.toDouble();
    final ay = a.row.toDouble();
    final bx = b.col.toDouble();
    final by = b.row.toDouble();
    final distance = math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2));
    final steps = math.max(1, (distance * 3).ceil());
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      final cell = ArenaCell(
        (ax + (bx - ax) * t).round(),
        (ay + (by - ay) * t).round(),
      );
      if (!walkableCell(cell)) return false;
    }
    return true;
  }

  /// Samples the map for line of sight. Water does not block arrows; walls,
  /// rocks, castles and towers do. Intact crystal cells block as well ('K' is
  /// not in [shotBlockingChars], matching the package's obstacle intent).
  bool lineOfSight(double x1, double y1, double x2, double y2) {
    final distance = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
    final steps = math.max(1, (distance * 4).ceil());
    final startCell = worldToCell(x1, y1);
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      final cell = worldToCell(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
      // A unit may stand on/next to the obstacle that owns its own cell.
      if (cell == startCell) continue;
      if (blocksShot(cell)) return false;
    }
    return true;
  }

  ArenaCell nearestWalkable(ArenaCell cell, {int radius = 4}) {
    if (walkableCell(cell)) return cell;
    for (var r = 1; r <= radius; r++) {
      for (var dr = -r; dr <= r; dr++) {
        for (var dc = -r; dc <= r; dc++) {
          if (dc.abs() != r && dr.abs() != r) continue;
          final candidate = ArenaCell(cell.col + dc, cell.row + dr);
          if (walkableCell(candidate)) return candidate;
        }
      }
    }
    return cell;
  }

  /// Opens a destroyed crystal's footprint. Returns true if the grid changed.
  bool destroyCrystal(String id) {
    final crystal = crystalById(id);
    if (crystal == null) return false;
    crystal.health = 0;
    crystal.destroyed = true;
    var changed = false;
    for (final cell in footprintCells(crystal.footprint)) {
      if (grid[cell.row][cell.col] != '.') {
        grid[cell.row][cell.col] = '.';
        changed = true;
      }
    }
    if (changed) _revision++;
    return changed;
  }

  Set<ArenaCell> get blockedCells {
    final blocked = <ArenaCell>{};
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (!walkableChars.contains(grid[row][col])) {
          blocked.add(ArenaCell(col, row));
        }
      }
    }
    return blocked;
  }
}

class ArenaPathNode {
  const ArenaPathNode(this.cell, this.cost, this.estimate);

  final ArenaCell cell;
  final double cost;
  final double estimate;

  double get priority => cost + estimate;
}
