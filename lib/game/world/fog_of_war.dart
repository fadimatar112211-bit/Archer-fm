import 'dart:math' as math;
import 'dart:ui';

import 'arena_map.dart';

/// Permanent exploration memory for the match map.
///
/// Areas start hidden, get revealed while the hero is near them, and stay
/// revealed afterwards. Enemy visibility is a separate, distance-based rule.
class FogOfWar {
  FogOfWar({
    required this.worldWidth,
    required this.worldHeight,
    this.cell = fogCellSize,
  })  : cols = (worldWidth / cell).ceil(),
        rows = (worldHeight / cell).ceil(),
        _revealed = List<bool>.filled(
          (worldWidth / cell).ceil() * (worldHeight / cell).ceil(),
          false,
        );

  final double worldWidth;
  final double worldHeight;
  final double cell;
  final int cols;
  final int rows;
  final List<bool> _revealed;

  bool cellRevealed(int col, int row) {
    if (col < 0 || row < 0 || col >= cols || row >= rows) return false;
    return _revealed[row * cols + col];
  }

  /// Reveals every cell whose center falls inside [radius] of [center].
  void reveal(Offset center, double radius) {
    if (radius <= 0) return;
    final minCol = ((center.dx - radius) / cell).floor().clamp(0, cols - 1);
    final maxCol = ((center.dx + radius) / cell).ceil().clamp(0, cols - 1);
    final minRow = ((center.dy - radius) / cell).floor().clamp(0, rows - 1);
    final maxRow = ((center.dy + radius) / cell).ceil().clamp(0, rows - 1);
    final radiusSquared = radius * radius;
    for (var row = minRow; row <= maxRow; row++) {
      for (var col = minCol; col <= maxCol; col++) {
        final cellCenter = Offset(
          (col + 0.5) * cell,
          (row + 0.5) * cell,
        );
        if ((cellCenter - center).distanceSquared <= radiusSquared) {
          _revealed[row * cols + col] = true;
        }
      }
    }
  }

  bool isRevealed(Offset point) {
    final col = (point.dx / cell).floor();
    final row = (point.dy / cell).floor();
    return cellRevealed(col, row);
  }

  int get revealedCellCount =>
      _revealed.where((revealed) => revealed).length;

  double get revealedFraction {
    if (_revealed.isEmpty) return 0;
    return revealedCellCount / _revealed.length;
  }

  /// Bounding rectangle of one cell in world coordinates.
  Rect cellRect(int col, int row) =>
      Rect.fromLTWH(col * cell, row * cell, cell, cell);

  /// Cells that intersect [view] and are still hidden — used by the painter so
  /// it only walks the visible slice of a large map.
  Iterable<Rect> hiddenCellsIn(Rect view) sync* {
    final minCol = math.max(0, (view.left / cell).floor());
    final maxCol =
        math.min(cols - 1, ((view.right - 0.01) / cell).floor());
    final minRow = math.max(0, (view.top / cell).floor());
    final maxRow =
        math.min(rows - 1, ((view.bottom - 0.01) / cell).floor());
    for (var row = minRow; row <= maxRow; row++) {
      for (var col = minCol; col <= maxCol; col++) {
        if (!cellRevealed(col, row)) yield cellRect(col, row);
      }
    }
  }
}
