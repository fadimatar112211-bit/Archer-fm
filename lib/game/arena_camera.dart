import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'world/arena_projection.dart';
import 'world/game_world.dart';

/// Immutable camera settings shared by the arena painter and pointer mapping.
class ArenaCameraConfig {
  const ArenaCameraConfig({this.projection = defaultArenaWorldProjection});

  final ArenaWorldProjection projection;
}

/// Default camera settings for the mobile arena.
const ArenaCameraConfig defaultArenaCameraConfig = ArenaCameraConfig();

/// One authoritative mapping between arena widget pixels and map-world units.
/// Painting and pointer input share the same projection and camera snapshot.
class ArenaCameraTransform {
  const ArenaCameraTransform({
    required this.scale,
    required this.viewportOrigin,
    required this.cameraOrigin,
    this.projection = defaultArenaWorldProjection,
  });

  factory ArenaCameraTransform.forViewport(
    Size size,
    GameWorld world, {
    ArenaCameraConfig config = defaultArenaCameraConfig,
    ArenaWorldProjection? projection,
  }) {
    final effectiveProjection = projection ?? config.projection;
    final scale = math.min(
      size.width / arenaWidth,
      size.height / arenaHeight,
    );
    final viewWidth = arenaWidth * scale;
    final viewHeight = arenaHeight * scale;
    return ArenaCameraTransform(
      scale: scale,
      viewportOrigin: Offset(
        (size.width - viewWidth) / 2,
        (size.height - viewHeight) / 2,
      ),
      cameraOrigin: world.cameraOrigin,
      projection: effectiveProjection,
    );
  }

  final double scale;
  final Offset viewportOrigin;
  final Offset cameraOrigin;
  final ArenaWorldProjection projection;

  Offset get _logicalCenter => const Offset(arenaWidth / 2, arenaHeight / 2);

  /// Converts a widget-local point to its exact map-world coordinate.
  Offset localToWorld(Offset local) {
    final projected = (local - viewportOrigin) / scale - _logicalCenter;
    return cameraOrigin + _logicalCenter + projection.unprojectGround(projected);
  }

  /// Converts a map-world coordinate to its exact widget-local screen point.
  Offset worldToLocal(Offset world) {
    final projected = projection.projectGround(world - cameraOrigin - _logicalCenter);
    return (projected + _logicalCenter) * scale + viewportOrigin;
  }

  /// Conservative world AABB for the inverse-projected viewport.
  Rect get visibleWorldRect => projection.visibleWorldBounds(
        Rect.fromLTRB(
          -_logicalCenter.dx,
          -_logicalCenter.dy,
          _logicalCenter.dx,
          _logicalCenter.dy,
        ),
      ).shift(cameraOrigin + _logicalCenter);
}
