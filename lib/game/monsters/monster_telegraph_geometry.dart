import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Returns the ground-plane warning angle in the monster body's local space.
///
/// The painter mirrors the body for west-facing monsters before drawing the
/// warning, so the horizontal component must be mirrored as well. Keeping this
/// transform pure makes all eight directions independently testable.
double monsterTelegraphAngle(
  Offset facing, {
  required bool mirrored,
}) {
  if (!facing.dx.isFinite ||
      !facing.dy.isFinite ||
      facing.distanceSquared < 1e-8) {
    return 0;
  }
  final localX = mirrored ? -facing.dx : facing.dx;
  return math.atan2(facing.dy, localX);
}
