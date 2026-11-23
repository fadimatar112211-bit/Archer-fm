import 'dart:ui' show Offset;

import '../../hero/hero_manifest.dart';
import '../world/game_world.dart';

/// Shared state/direction lookup for camera-facing hero and monster sprites.
/// Gameplay facing remains in world space; GameWorld owns the established
/// screen/world octant convention, so art packs cannot invent a second one.
class SpriteActorClipResolver {
  const SpriteActorClipResolver._();

  static String directionFor(Offset facing) =>
      GameWorld.octantNames[GameWorld.octantIndexOf(facing)];

  static String clipName(String state, Offset facing) =>
      '${state}_${directionFor(facing)}';

  static AnimationClip? clipFor(
    HeroManifest manifest,
    String state,
    Offset facing,
  ) =>
      manifest.clipFor(state, directionFor(facing));
}
