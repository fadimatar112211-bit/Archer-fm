/// Deterministic, server-owned status effects shared by heroes and monsters.
enum MatchStatusEffectType { burn, poison, slow, freeze, stun }

class MatchStatusEffectSpec {
  const MatchStatusEffectSpec({
    required this.type,
    required this.duration,
    this.tickInterval = Duration.zero,
    this.damagePerTick = 0,
    this.movementMultiplier = 1,
  });

  final MatchStatusEffectType type;
  final Duration duration;
  final Duration tickInterval;
  final double damagePerTick;
  final double movementMultiplier;

  void validate() {
    if (duration <= Duration.zero ||
        tickInterval.isNegative ||
        !damagePerTick.isFinite ||
        damagePerTick < 0 ||
        !movementMultiplier.isFinite ||
        movementMultiplier <= 0 ||
        movementMultiplier > 1) {
      throw ArgumentError('Invalid match status-effect specification.');
    }
    final damageOverTime =
        type == MatchStatusEffectType.burn ||
        type == MatchStatusEffectType.poison;
    if (damageOverTime) {
      if (tickInterval <= Duration.zero || damagePerTick <= 0) {
        throw ArgumentError('Burn and poison require positive tick damage and interval.');
      }
    } else if (damagePerTick != 0 || tickInterval != Duration.zero) {
      throw ArgumentError('Control effects cannot deal periodic damage.');
    }
    if ((type == MatchStatusEffectType.freeze ||
            type == MatchStatusEffectType.stun) &&
        movementMultiplier != 1) {
      throw ArgumentError('Freeze and stun disable actions; movement multiplier must remain 1.');
    }
  }
}

class MatchStatusEffectDamage {
  const MatchStatusEffectDamage({
    required this.sourcePlayerId,
    required this.type,
    required this.amount,
  });

  final String sourcePlayerId;
  final MatchStatusEffectType type;
  final double amount;
}

class MatchStatusEffectRuntime {
  final Map<MatchStatusEffectType, _ActiveMatchStatusEffect> _active = {};

  bool get isEmpty => _active.isEmpty;
  bool get isActionDisabled =>
      _active.containsKey(MatchStatusEffectType.freeze) ||
      _active.containsKey(MatchStatusEffectType.stun);

  double get movementMultiplier {
    if (isActionDisabled) return 0.05;
    var multiplier = 1.0;
    for (final effect in _active.values) {
      if (effect.spec.type == MatchStatusEffectType.slow &&
          effect.spec.movementMultiplier < multiplier) {
        multiplier = effect.spec.movementMultiplier;
      }
    }
    return multiplier;
  }

  Set<MatchStatusEffectType> get activeTypes =>
      Set.unmodifiable(_active.keys);

  void apply({
    required String sourcePlayerId,
    required MatchStatusEffectSpec spec,
  }) {
    if (sourcePlayerId.isEmpty) {
      throw ArgumentError.value(sourcePlayerId, 'sourcePlayerId');
    }
    spec.validate();
    final existing = _active[spec.type];
    if (existing == null) {
      _active[spec.type] = _ActiveMatchStatusEffect(
        sourcePlayerId: sourcePlayerId,
        spec: spec,
      );
      return;
    }
    if (spec.duration > existing.remaining) existing.remaining = spec.duration;
    if (spec.damagePerTick > existing.spec.damagePerTick ||
        spec.movementMultiplier < existing.spec.movementMultiplier) {
      existing.spec = MatchStatusEffectSpec(
        type: spec.type,
        duration: existing.remaining,
        tickInterval: spec.tickInterval == Duration.zero
            ? existing.spec.tickInterval
            : spec.tickInterval,
        damagePerTick: spec.damagePerTick > existing.spec.damagePerTick
            ? spec.damagePerTick
            : existing.spec.damagePerTick,
        movementMultiplier: spec.movementMultiplier <
                existing.spec.movementMultiplier
            ? spec.movementMultiplier
            : existing.spec.movementMultiplier,
      );
    }
    existing.sourcePlayerId = sourcePlayerId;
    if (spec.type == MatchStatusEffectType.burn ||
        spec.type == MatchStatusEffectType.poison) {
      if (existing.untilNextTick > spec.tickInterval ||
          existing.untilNextTick == Duration.zero) {
        existing.untilNextTick = spec.tickInterval;
      }
    }
  }

  List<MatchStatusEffectDamage> advance(Duration elapsed) {
    if (elapsed.isNegative) throw ArgumentError.value(elapsed, 'elapsed');
    if (elapsed == Duration.zero || _active.isEmpty) return const [];
    final damage = <MatchStatusEffectDamage>[];
    for (final entry in _active.entries.toList(growable: false)) {
      final active = entry.value;
      final consumed = elapsed < active.remaining ? elapsed : active.remaining;
      active.remaining -= consumed;
      if (active.spec.damagePerTick > 0) {
        active.untilNextTick -= consumed;
        while (active.untilNextTick <= Duration.zero) {
          damage.add(MatchStatusEffectDamage(
            sourcePlayerId: active.sourcePlayerId,
            type: active.spec.type,
            amount: active.spec.damagePerTick,
          ));
          active.untilNextTick += active.spec.tickInterval;
        }
      }
      if (active.remaining == Duration.zero) _active.remove(entry.key);
    }
    return List.unmodifiable(damage);
  }

  void clear() => _active.clear();
}

class _ActiveMatchStatusEffect {
  _ActiveMatchStatusEffect({
    required this.sourcePlayerId,
    required this.spec,
  })  : remaining = spec.duration,
        untilNextTick = spec.tickInterval;

  String sourcePlayerId;
  MatchStatusEffectSpec spec;
  Duration remaining;
  Duration untilNextTick;
}
