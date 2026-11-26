import 'dart:math' as math;
import 'dart:ui' show Offset;

/// World-space direction convention shared by movement and sprite animation.
/// Positive Y points down-screen, so the octants run clockwise from east.
class GameWorld {
  const GameWorld._();

  static const List<String> octantNames = <String>[
    'e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne',
  ];

  static int octantIndexOf(Offset facing) {
    if (facing == Offset.zero) return 2;
    final angle = math.atan2(facing.dy, facing.dx);
    final octant = (angle / (math.pi / 4)).round();
    return octant % 8 < 0 ? octant % 8 + 8 : octant % 8;
  }
}
