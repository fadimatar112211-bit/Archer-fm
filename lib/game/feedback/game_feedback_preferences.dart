import 'package:flutter/services.dart';

/// Session-scoped feedback preferences. Durable storage is owned by Phase 5.
class GameFeedbackPreferences {
  GameFeedbackPreferences._();

  static bool hapticsEnabled = true;

  static Future<void> selectionClick() {
    if (!hapticsEnabled) return Future<void>.value();
    return HapticFeedback.selectionClick();
  }
}
