import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'world/game_world.dart';

/// One authoritative mapping between arena widget pixels and map-world units.
///
/// The same instance data drives canvas painting and pointer-to-world input,
/// preventing camera smoothing, letterboxing, or viewport sizing from making
/// taps land somewhere other than the point shown on screen.
class ArenaCameraTransform {
  const ArenaCameraTransform({
    required this.scale,
    required this.viewportOrigin,
    required this.cameraOrigin,
  });

  factory ArenaCameraTransform.forViewport(Size size, GameWorld world) {
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
    );
  }

  /// Logical arena-to-widget scale after aspect-ratio letterboxing.
  final double scale;

  /// Top-left of the logical arena inside the widget (letterbox offset).
  final Offset viewportOrigin;

  /// Smoothed top-left world coordinate currently rendered by the camera.
  final Offset cameraOrigin;

  /// Converts a widget-local point to its exact map-world coordinate.
  Offset localToWorld(Offset local) =>
      (local - viewportOrigin) / scale + cameraOrigin;

  /// Converts a map-world coordinate to its exact widget-local screen point.
  Offset worldToLocal(Offset world) =>
      (world - cameraOrigin) * scale + viewportOrigin;

  /// Visible map-space rectangle for culling, minimap indicators and hit tests.
  Rect get visibleWorldRect => Rect.fromLTWH(
        cameraOrigin.dx,
        cameraOrigin.dy,
        arenaWidth,
        arenaHeight,
      );
}
