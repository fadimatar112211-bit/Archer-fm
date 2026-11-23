import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../hero/hero_manifest.dart';

/// Converts a world-facing vector into the eight-direction naming convention
/// used by the hero sprite manifests. Positive Y points south on the game plane.
class SpriteActorClipResolver {
  const SpriteActorClipResolver._();

  static const List<String> directions = [
    'e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne',
  ];

  static String directionFor(Offset facing) {
    if (facing == Offset.zero) return 's';
    final angle = math.atan2(facing.dy, facing.dx);
    final octant = (angle / (math.pi / 4)).round();
    final index = (octant % directions.length + directions.length) %
        directions.length;
    return directions[index];
  }

  static String clipName(String state, Offset facing) =>
      '${state}_${directionFor(facing)}';

  static AnimationClip? clipFor(
    HeroManifest manifest,
    String state,
    Offset facing,
  ) =>
      manifest.clipFor(state, directionFor(facing));
}
