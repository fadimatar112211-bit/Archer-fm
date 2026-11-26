import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/match_status_effects.dart';

void main() {
  group('Match status-effect runtime', () {
    test('burn and poison apply deterministic periodic damage until expiry', () {
      final effects = MatchStatusEffectRuntime()
        ..apply(
          sourcePlayerId: 'p1',
          spec: const MatchStatusEffectSpec(
            type: MatchStatusEffectType.burn,
            duration: Duration(seconds: 3),
            tickInterval: Duration(seconds: 1),
            damagePerTick: 7,
          ),
        )
        ..apply(
          sourcePlayerId: 'p2',
          spec: const MatchStatusEffectSpec(
            type: MatchStatusEffectType.poison,
            duration: Duration(seconds: 2),
            tickInterval: Duration(seconds: 1),
            damagePerTick: 5,
          ),
        );

      final first = effects.advance(const Duration(seconds: 1));
      expect(first.map((item) => item.amount), [7, 5]);
      expect(first.map((item) => item.sourcePlayerId), ['p1', 'p2']);
      final second = effects.advance(const Duration(seconds: 1));
      expect(second.map((item) => item.amount), [7, 5]);
      final third = effects.advance(const Duration(seconds: 1));
      expect(third.map((item) => item.amount), [7]);
      expect(effects.isEmpty, isTrue);
    });

    test('slow uses the strongest active movement reduction', () {
      final effects = MatchStatusEffectRuntime()
        ..apply(
          sourcePlayerId: 'p1',
          spec: const MatchStatusEffectSpec(
            type: MatchStatusEffectType.slow,
            duration: Duration(seconds: 2),
            movementMultiplier: 0.7,
          ),
        )
        ..apply(
          sourcePlayerId: 'p2',
          spec: const MatchStatusEffectSpec(
            type: MatchStatusEffectType.slow,
            duration: Duration(seconds: 3),
            movementMultiplier: 0.4,
          ),
        );
      expect(effects.movementMultiplier, 0.4);
      effects.advance(const Duration(seconds: 2));
      expect(effects.movementMultiplier, 0.4);
      effects.advance(const Duration(seconds: 1));
      expect(effects.movementMultiplier, 1);
    });

    test('freeze and stun disable actions and expire deterministically', () {
      final effects = MatchStatusEffectRuntime()
        ..apply(
          sourcePlayerId: 'p1',
          spec: const MatchStatusEffectSpec(
            type: MatchStatusEffectType.freeze,
            duration: Duration(milliseconds: 500),
          ),
        );
      expect(effects.isActionDisabled, isTrue);
      expect(effects.movementMultiplier, 0.05);
      effects.advance(const Duration(milliseconds: 500));
      expect(effects.isActionDisabled, isFalse);
      expect(effects.movementMultiplier, 1);
      effects.apply(
        sourcePlayerId: 'p2',
        spec: const MatchStatusEffectSpec(
          type: MatchStatusEffectType.stun,
          duration: Duration(milliseconds: 250),
        ),
      );
      expect(effects.isActionDisabled, isTrue);
      effects.advance(const Duration(milliseconds: 250));
      expect(effects.isActionDisabled, isFalse);
    });

    test('refreshes duration without allowing weaker slow to overwrite stronger slow', () {
      final effects = MatchStatusEffectRuntime()
        ..apply(
          sourcePlayerId: 'p1',
          spec: const MatchStatusEffectSpec(
            type: MatchStatusEffectType.slow,
            duration: Duration(seconds: 2),
            movementMultiplier: 0.5,
          ),
        )
        ..advance(const Duration(seconds: 1))
        ..apply(
          sourcePlayerId: 'p2',
          spec: const MatchStatusEffectSpec(
            type: MatchStatusEffectType.slow,
            duration: Duration(seconds: 2),
            movementMultiplier: 0.8,
          ),
        );
      expect(effects.movementMultiplier, 0.5);
      effects.advance(const Duration(milliseconds: 1500));
      expect(effects.movementMultiplier, 0.5);
      effects.advance(const Duration(milliseconds: 500));
      expect(effects.movementMultiplier, 1);
    });

    test('rejects malformed effect specifications and negative elapsed time', () {
      final effects = MatchStatusEffectRuntime();
      expect(
        () => effects.apply(
          sourcePlayerId: 'p1',
          spec: const MatchStatusEffectSpec(
            type: MatchStatusEffectType.poison,
            duration: Duration(seconds: 2),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => effects.advance(const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
    });
  });
}
