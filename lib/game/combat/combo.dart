/// Tracks the five-hit normal-attack chain of one hero.
///
/// Rules implemented here (mirroring the production brief):
/// - Chaining within [windowMs] steps to the next hit (1→2→…→5).
/// - After the fifth hit the chain wraps back to the first hit, as long as the
///   next press still lands inside the combo window.
/// - Letting the window expire restarts the chain at the first hit.
/// - Each press counts exactly once, so one press can never register two hits.
library;

class ComboTracker {
  ComboTracker({required this.windowMs});

  /// Chain window in milliseconds between consecutive hits.
  final int windowMs;

  /// Current hit index, 1-based (1..5). Always valid.
  int hitIndex = 1;

  /// Timestamp of the last registered hit; `null` before the first hit.
  int? lastHitAtMs;

  /// Total hits registered since the chain last restarted (for UI streaks).
  int chainLength = 0;

  /// Registers a new attack press and returns the combo hit (1..5) it counts
  /// as. [nowMs] is the world time of the press.
  int advance(int nowMs) {
    final last = lastHitAtMs;
    final expired = last != null && nowMs - last > windowMs;
    if (expired) {
      hitIndex = 1;
      chainLength = 0;
    } else if (chainLength >= 5) {
      // The fifth hit was already registered: wrap back to the first.
      hitIndex = 1;
      chainLength = 0;
    }
    final registered = hitIndex;
    chainLength++;
    if (chainLength < 5) {
      hitIndex = registered + 1;
    }
    lastHitAtMs = nowMs;
    return registered;
  }

  /// Force-restarts the chain (used on death, dodge-cancel or long pauses).
  void reset() {
    hitIndex = 1;
    lastHitAtMs = null;
    chainLength = 0;
  }
}
