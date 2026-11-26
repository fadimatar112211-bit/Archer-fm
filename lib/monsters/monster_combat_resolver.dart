import 'monster_combat.dart';
import 'monster_models.dart';

/// A narrow adapter over an authoritative match entity.
///
/// Hero and crystal systems can implement this contract without importing or
/// changing monster internals. The match authority must supply a fresh target
/// instance/state for every resolution attempt.
abstract interface class MonsterDamageTarget {
  String get id;
  String get ownerId;
  MonsterTargetKind get kind;
  bool get isAlive;

  /// Applies damage to the authoritative entity and returns true if defeated.
  bool applyDamage(double amount);
}

enum MonsterDamageResult {
  applied,
  missingTarget,
  selfTarget,
  friendlyTarget,
  deadTarget,
  invalidIntent,
}

/// Resolves an AI intent against a fresh authoritative target.
///
/// This class deliberately does not look up entities or mutate match state
/// itself. The caller owns lookup, network authority, and transaction ordering.
class MonsterCombatResolver {
  const MonsterCombatResolver();

  MonsterDamageResult resolve({
    required MonsterCombatIntent intent,
    required String attackerOwnerId,
    required MonsterDamageTarget? target,
  }) {
    if (attackerOwnerId.isEmpty ||
        intent.monsterId.isEmpty ||
        intent.targetId.isEmpty ||
        !intent.damage.isFinite ||
        intent.damage <= 0) {
      return MonsterDamageResult.invalidIntent;
    }
    if (intent.targetId == intent.monsterId) {
      return MonsterDamageResult.selfTarget;
    }
    if (target == null) return MonsterDamageResult.missingTarget;
    if (target.id == intent.monsterId) return MonsterDamageResult.selfTarget;
    if (target.id != intent.targetId) return MonsterDamageResult.missingTarget;
    if (target.id.isEmpty || target.ownerId.isEmpty) {
      return MonsterDamageResult.invalidIntent;
    }
    if (target.ownerId == attackerOwnerId) {
      return MonsterDamageResult.friendlyTarget;
    }
    if (!target.isAlive) return MonsterDamageResult.deadTarget;

    target.applyDamage(intent.damage);
    return MonsterDamageResult.applied;
  }
}

/// In-memory adapter for monster units. Hero and crystal implementations
/// belong to their respective systems and should implement
/// [MonsterDamageTarget] at their integration boundary.
class MonsterUnitDamageTarget implements MonsterDamageTarget {
  MonsterUnitDamageTarget(this.unit);

  final MonsterUnit unit;

  @override
  String get id => unit.id;

  @override
  String get ownerId => unit.ownerId;

  @override
  MonsterTargetKind get kind => MonsterTargetKind.monster;

  @override
  bool get isAlive => unit.isAlive;

  @override
  bool applyDamage(double amount) => unit.applyDamage(amount);
}
