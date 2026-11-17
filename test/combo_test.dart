import 'package:archer_fm/game/combat/combo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('five-hit combo chain', () {
    test('hits escalate 100/110/120/135/155%', () {
      final kitMultipliers = const <double>[
        1.00,
        1.10,
        1.20,
        1.35,
        1.55,
      ];
      final combo = ComboTracker(windowMs: 1800);
      final hits = [
        combo.advance(0),
        combo.advance(500),
        combo.advance(1000),
        combo.advance(1500),
        combo.advance(2000),
      ];
      expect(hits, [1, 2, 3, 4, 5]);
      expect(
        hits.map((h) => kitMultipliers[h - 1]),
        [1.00, 1.10, 1.20, 1.35, 1.55],
      );
    });

    test('each press registers exactly one hit (no double counting)', () {
      final combo = ComboTracker(windowMs: 1800);
      var calls = 0;
      final registered = <int>[];
      // Simulate a spammy player pressing far more times than the cooldown
      // allows: only accepted presses call advance().
      for (var t = 0; t < 10000; t += 250) {
        final accepted = t % 1000 == 0; // one attack per ~cycle
        if (accepted) {
          calls++;
          registered.add(combo.advance(t));
        }
      }
      expect(registered.length, calls);
      expect(registered.take(10), [1, 2, 3, 4, 5, 1, 2, 3, 4, 5]);
    });

    test('wraps back to hit 1 after the fifth hit inside the window', () {
      final combo = ComboTracker(windowMs: 1800);
      combo.advance(0);
      combo.advance(400);
      combo.advance(800);
      combo.advance(1200);
      combo.advance(1600); // fifth
      expect(combo.advance(2000), 1);
    });

    test('window expiry restarts the chain at hit 1', () {
      final combo = ComboTracker(windowMs: 1800);
      combo.advance(0);
      combo.advance(500);
      combo.advance(1000);
      // Long pause past the 1800 ms window.
      expect(combo.advance(1000 + 1801), 1);
    });

    test('reset() starts the chain from hit 1', () {
      final combo = ComboTracker(windowMs: 1800);
      combo.advance(0);
      combo.advance(400);
      combo.reset();
      expect(combo.advance(800), 1);
    });
  });
}
