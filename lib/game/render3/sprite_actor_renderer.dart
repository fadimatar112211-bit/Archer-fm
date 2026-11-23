import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared camera-facing sprite/billboard drawing used by heroes and, once
/// their approved packs exist, the four monster roles.
///
/// The actor's [groundAnchor] is the gameplay ground point. Pivot coordinates
/// are normalized within the source frame so art dimensions never alter
/// collision radii, navigation or combat ranges.
class SpriteActorRenderer {
  const SpriteActorRenderer._();

  static Rect destinationRect({
    required Offset groundAnchor,
    required Size frameSize,
    required double pivotX,
    required double pivotY,
    required double targetHeight,
  }) {
    if (frameSize.width <= 0 ||
        frameSize.height <= 0 ||
        targetHeight <= 0 ||
        pivotX < 0 ||
        pivotX > 1 ||
        pivotY < 0 ||
        pivotY > 1) {
      throw ArgumentError('Invalid sprite frame geometry or normalized pivot');
    }
    final width = targetHeight * frameSize.width / frameSize.height;
    return Rect.fromLTWH(
      groundAnchor.dx - width * pivotX,
      groundAnchor.dy - targetHeight * pivotY,
      width,
      targetHeight,
    );
  }

  static void paint(
    Canvas canvas, {
    required ui.Image image,
    required Rect sourceRect,
    required Offset groundAnchor,
    required Size frameSize,
    required double pivotX,
    required double pivotY,
    required double targetHeight,
    double opacity = 1,
    Color? tint,
    FilterQuality filterQuality = FilterQuality.medium,
  }) {
    final destination = destinationRect(
      groundAnchor: groundAnchor,
      frameSize: frameSize,
      pivotX: pivotX,
      pivotY: pivotY,
      targetHeight: targetHeight,
    );
    final alpha = opacity.clamp(0.0, 1.0).toDouble();
    final color = tint?.withValues(alpha: alpha) ??
        Color.fromRGBO(255, 255, 255, alpha);
    canvas.drawImageRect(
      image,
      sourceRect,
      destination,
      Paint()
        ..filterQuality = filterQuality
        ..color = color,
    );
  }
}
