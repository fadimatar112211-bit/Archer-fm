import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Orthographic 2.5D camera for the 96x96 arena map.
///
/// World coordinates are metres (+X east, +Y north). The map picture is
/// recorded once in base-scale projected coordinates; this camera only applies
/// zoom, pan and screen centering, so changing zoom never rebuilds terrain.
class ArenaCamera {
  ArenaCamera({this.zoom = 16, this.targetX = 0, this.targetY = 0});

  /// Pixels per metre in the final view.
  double zoom;

  /// World point that is kept at the centre of the viewport.
  double targetX;
  double targetY;

  static const double baseScale = 10;
  static const double yaw = math.pi / 4;
  static const double tiltDegrees = 48;
  static double get _tilt => tiltDegrees * math.pi / 180;

  static Offset project(double x, double y, double z) {
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final sinT = math.sin(_tilt);
    final cosT = math.cos(_tilt);
    final sx = (x * cosY - y * sinY) * baseScale;
    final sy = -(x * sinY + y * cosY) * baseScale * sinT - z * baseScale * cosT;
    return Offset(sx, sy);
  }

  Offset worldToScreen(double x, double y, double z, Size viewport) {
    final point = project(x, y, z);
    final target = project(targetX, targetY, 0);
    final scale = zoom / baseScale;
    return Offset(
      (point.dx - target.dx) * scale + viewport.width / 2,
      (point.dy - target.dy) * scale + viewport.height / 2,
    );
  }

  (double, double) screenToWorld(Offset screen, Size viewport, {double z = 0}) {
    final target = project(targetX, targetY, 0);
    final scale = zoom / baseScale;
    final sx = (screen.dx - viewport.width / 2) / scale + target.dx;
    final sy = (screen.dy - viewport.height / 2) / scale + target.dy;
    final a = sx / baseScale;
    final b = (sy + z * baseScale * math.cos(_tilt)) / baseScale;
    final u = a;
    final v = -b / math.sin(_tilt);
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final x = u * cosY + v * sinY;
    final y = -u * sinY + v * cosY;
    return (x, y);
  }

  void clampZoom() {
    zoom = zoom.clamp(8.0, 28.0).toDouble();
  }
}
