import 'package:flutter/services.dart';

/// Session-scoped feedback preferences. Durable storage is owned by Phase 5.
class GameFeedbackPreferences {
  GameFeedbackPreferences._();

  static bool hapticsEnabled = true;
  static double movementSensitivity = 1.0;

  static void setMovementSensitivity(double value) {
    movementSensitivity = value.clamp(0.5, 1.5).toDouble();
  }

  static Future<void> selectionClick() {
    if (!hapticsEnabled) return Future<void>.value();
    return HapticFeedback.selectionClick();
  }
}
