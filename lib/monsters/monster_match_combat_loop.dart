import 'monster_combat.dart';
import 'monster_combat_resolver.dart';
import 'monster_models.dart';
import 'monster_projectile_manager.dart';
import 'monster_projectiles.dart';
import 'monster_ranged_attack_handler.dart';
import 'monster_formation_movement.dart';

typedef MonsterTargetCandidates = Iterable<MonsterTarget> Function(
  MonsterUnit source,
);
typedef MonsterDamageLookup = MonsterDamageTarget? Function(String targetId);
typedef MonsterPositionedLookup =
    MonsterPositionedDamageTarget? Function(String targetId);
typedef MonsterProjectileIdFactory = String Function(MonsterUnit source);
typedef MonsterAlliesLookup = Iterable<MonsterUnit> Function(MonsterUnit source);
typedef MonsterObstaclesLookup = Iterable<MonsterMovementObstacle> Function(MonsterUnit source);

/// One authoritative simulation step for monster AI, melee damage and ranged
/// projectile lifecycle. Call only from the match authority/server tick.
/// Hero/crystal systems plug in through target lookup adapters; no hero code
/// is imported or mutated here.
class MonsterMatchCombatLoop {
  MonsterMatchCombatLoop({
    required this.combat,
    required this.resolver,
    required this.rangedHandler,
    required this.projectiles,
    required this.projectileSpeed,
    required this.projectileId,
    this.alliesFor = _noAllies,
    this.obstaclesFor = _noObstacles,
  }) {
    if (!projectileSpeed.isFinite || projectileSpeed <= 0) {
      throw ArgumentError.value(projectileSpeed, 'projectileSpeed');
    }
  }

  final MonsterCombatController combat;
  final MonsterCombatResolver resolver;
  final MonsterRangedAttackHandler rangedHandler;
  final MonsterProjectileManager projectiles;
  final double projectileSpeed;
  final MonsterProjectileIdFactory projectileId;
  final MonsterAlliesLookup alliesFor;
  final MonsterObstaclesLookup obstaclesFor;

  static Iterable<MonsterUnit> _noAllies(MonsterUnit _) => const [];
  static Iterable<MonsterMovementObstacle> _noObstacles(MonsterUnit _) => const [];

  MonsterMatchTickResult update({
    required Iterable<MonsterUnit> units,
    required MonsterTargetCandidates candidatesFor,
    required MonsterDamageLookup resolveDamageTarget,
    required MonsterPositionedLookup resolvePositionedTarget,
    required DateTime now,
    required Duration elapsed,
  }) {
    if (elapsed.isNegative) throw ArgumentError.value(elapsed, 'elapsed');

    var meleeApplied = 0;
    var rangedCreated = 0;
    var rejected = 0;

    for (final unit in units) {
      if (!unit.isAlive) continue;
      final intent = combat.updateUnit(
        unit: unit,
        candidates: candidatesFor(unit),
        now: now,
        elapsed: elapsed,
        allies: alliesFor(unit),
        obstacles: obstaclesFor(unit),
      );
      if (intent == null) continue;

      if (unit.type == MonsterType.ranged) {
        final projectile = rangedHandler.tryCreate(
          intent: intent,
          source: unit,
          target: resolvePositionedTarget(intent.targetId),
          projectileId: projectileId(unit),
          projectileSpeed: projectileSpeed,
        );
        if (projectile == null || !projectiles.add(projectile)) {
          rejected++;
        } else {
          rangedCreated++;
        }
      } else {
        final result = resolver.resolve(
          intent: intent,
          attackerOwnerId: unit.ownerId,
          target: resolveDamageTarget(intent.targetId),
        );
        if (result == MonsterDamageResult.applied) {
          meleeApplied++;
        } else {
          rejected++;
        }
      }
    }

    final projectileResults = projectiles.update(
      elapsed: elapsed,
      resolveTarget: resolveDamageTarget,
    );
    return MonsterMatchTickResult(
      meleeHitsApplied: meleeApplied,
      rangedProjectilesCreated: rangedCreated,
      rejectedAttacks: rejected,
      projectileResults: projectileResults,
    );
  }
}

class MonsterMatchTickResult {
  const MonsterMatchTickResult({
    required this.meleeHitsApplied,
    required this.rangedProjectilesCreated,
    required this.rejectedAttacks,
    required this.projectileResults,
  });

  final int meleeHitsApplied;
  final int rangedProjectilesCreated;
  final int rejectedAttacks;
  final Map<String, MonsterProjectileResult> projectileResults;
}
