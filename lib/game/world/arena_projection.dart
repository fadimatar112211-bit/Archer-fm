import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// A reversible oblique projection for points on the arena ground plane.
///
/// Simulation and collision continue to use map-world coordinates. This
/// object only maps those coordinates to projected ground coordinates; it is
/// intentionally independent of Flutter widgets and GameWorld. The same
/// projection instance is injected into the live arena painter and camera
/// input transform so rendering and pointer mapping share one basis.
///
/// `yawRadians` rotates the ground plane around the camera. `groundScaleY`
/// compresses the camera-depth axis to create an oblique top-down view.
/// `scale` controls projected units per world unit. A default instance is
/// identity-compatible with the existing top-down renderer.
class ArenaWorldProjection {
  const ArenaWorldProjection({
    this.yawRadians = 0,
    this.groundScaleY = 1,
    this.scale = 1,
    this.focus = Offset.zero,
  })  : assert(groundScaleY > 0),
        assert(scale > 0);

  final double yawRadians;
  final double groundScaleY;
  final double scale;

  /// World-space point that maps to projected origin.
  final Offset focus;

  double get _cosYaw => math.cos(yawRadians);
  double get _sinYaw => math.sin(yawRadians);

  /// Project a map-world point onto the ground plane.
  Offset projectGround(Offset worldPoint) {
    final dx = worldPoint.dx - focus.dx;
    final dy = worldPoint.dy - focus.dy;
    final cameraRight = dx * _cosYaw - dy * _sinYaw;
    final cameraDepth = dx * _sinYaw + dy * _cosYaw;
    return Offset(
      cameraRight * scale,
      cameraDepth * groundScaleY * scale,
    );
  }

  /// Inverse of [projectGround], used by pointer input and world hit tests.
  Offset unprojectGround(Offset projectedPoint) {
    final cameraRight = projectedPoint.dx / scale;
    final cameraDepth = projectedPoint.dy / (groundScaleY * scale);
    final dx = cameraRight * _cosYaw + cameraDepth * _sinYaw;
    final dy = -cameraRight * _sinYaw + cameraDepth * _cosYaw;
    return focus + Offset(dx, dy);
  }

  /// Camera-depth coordinate used as the stable ground-plane sort key.
  double depthOf(Offset worldPoint) {
    final dx = worldPoint.dx - focus.dx;
    final dy = worldPoint.dy - focus.dy;
    return dx * _sinYaw + dy * _cosYaw;
  }

  /// Project an elevated point while keeping its ground anchor consistent.
  ///
  /// [worldHeight] is measured in the same world units as the ground plane.
  /// Positive height moves upward on screen.
  Offset projectHeight(Offset worldPoint, double worldHeight) =>
      projectGround(worldPoint) + Offset(0, -worldHeight * scale);

  /// Convert a world-space circular footprint to its projected radius.
  double projectRadius(double worldRadius) => worldRadius * scale;

  /// Conservative world-space AABB containing the inverse-projected viewport.
  ///
  /// A rotated viewport maps to a quadrilateral, so this returns the AABB of
  /// its four inverse-projected corners. It is suitable for conservative
  /// culling, not for precise point-in-viewport tests.
  Rect visibleWorldBounds(Rect projectedViewport) {
    final corners = [
      unprojectGround(projectedViewport.topLeft),
      unprojectGround(projectedViewport.topRight),
      unprojectGround(projectedViewport.bottomLeft),
      unprojectGround(projectedViewport.bottomRight),
    ];
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final point in corners) {
      minX = math.min(minX, point.dx).toDouble();
      minY = math.min(minY, point.dy).toDouble();
      maxX = math.max(maxX, point.dx).toDouble();
      maxY = math.max(maxY, point.dy).toDouble();
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// Single default projection shared by the arena renderer and input mapping.
const ArenaWorldProjection defaultArenaWorldProjection =
    ArenaWorldProjection(groundScaleY: 0.82, scale: 1.15);
