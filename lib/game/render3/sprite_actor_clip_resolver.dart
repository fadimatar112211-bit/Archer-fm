import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Shared direction lookup for camera-facing actors.
/// Gameplay facing remains in world space; this keeps the established
/// eight-way screen/world convention in one place.
class SpriteActorClipResolver {
  const SpriteActorClipResolver._();

  static const List<String> octantNames = [
    'e',
    'se',
    's',
    'sw',
    'w',
    'nw',
    'n',
    'ne',
  ];

  static int octantIndexOf(Offset facing) {
    if (facing.dx == 0 && facing.dy == 0) return 2; // south
    // atan2 returns -pi..pi, 0 along +x. Convert to 0=e,1=se,...
    final angle = math.atan2(facing.dy, facing.dx);
    final octant = ((angle / (math.pi / 4)).round() + 8) % 8;
    return octant;
  }

  static String directionFor(Offset facing) => octantNames[octantIndexOf(facing)];

  static String clipName(String state, Offset facing) =>
      '${state}_${directionFor(facing)}';
}
