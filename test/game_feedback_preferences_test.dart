import 'package:archer_fm/game/feedback/game_feedback_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    GameFeedbackPreferences.hapticsEnabled = true;
    GameFeedbackPreferences.setMovementSensitivity(1.0);
  });

  test('movement sensitivity is clamped to the supported range', () {
    GameFeedbackPreferences.setMovementSensitivity(0.1);
    expect(GameFeedbackPreferences.movementSensitivity, 0.5);

    GameFeedbackPreferences.setMovementSensitivity(1.25);
    expect(GameFeedbackPreferences.movementSensitivity, 1.25);

    GameFeedbackPreferences.setMovementSensitivity(2.0);
    expect(GameFeedbackPreferences.movementSensitivity, 1.5);
  });

  test('haptics preference can be disabled without changing sensitivity', () {
    GameFeedbackPreferences.setMovementSensitivity(1.2);
    GameFeedbackPreferences.hapticsEnabled = false;

    expect(GameFeedbackPreferences.hapticsEnabled, isFalse);
    expect(GameFeedbackPreferences.movementSensitivity, 1.2);
  });
}
