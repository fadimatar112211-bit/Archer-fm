import 'monster_combat.dart';
import 'monster_combat_resolver.dart';
import 'monster_models.dart';
import 'monster_projectile_manager.dart';
import 'monster_projectiles.dart';
import 'monster_ranged_attack_handler.dart';
import 'monster_formation_movement.dart';
import 'monster_navigation.dart';
import 'monster_attack_slots.dart';

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
    this.navigationGrid,
    MonsterPathfinder? pathfinder,
    MonsterAttackSlotCoordinator? attackSlots,
  })  : pathfinder = pathfinder ?? MonsterPathfinder(),
        attackSlots = attackSlots ?? MonsterAttackSlotCoordinator() {
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
  final MonsterNavigationGrid? navigationGrid;
  final MonsterPathfinder pathfinder;
  final MonsterAttackSlotCoordinator attackSlots;

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

    final unitSnapshot = units.toList(growable: false);

    // Advance only projectiles that existed at the beginning of this tick.
    // Projectiles launched below must not receive travel time retroactively.
    final projectileResults = projectiles.update(
      elapsed: elapsed,
      resolveTarget: resolvePositionedTarget,
    );

    final candidatesByUnit = <String, List<MonsterTarget>>{};
    final targetsByUnit = <String, MonsterTarget?>{};
    final unitsByTarget = <String, List<MonsterUnit>>{};
    final targetById = <String, MonsterTarget>{};

    // Select all targets first so the whole army can reserve approach slots
    // before any unit moves during this tick.
    for (final unit in unitSnapshot) {
      if (!unit.isAlive) {
        pathfinder.release(unit.id);
        continue;
      }
      final candidates = candidatesFor(unit).toList(growable: false);
      candidatesByUnit[unit.id] = candidates;
      final target = combat.selectTarget(unit: unit, candidates: candidates);
      targetsByUnit[unit.id] = target;
      if (target != null) {
        unitsByTarget.putIfAbsent(target.id, () => []).add(unit);
        targetById[target.id] = target;
      }
    }

    final approachSlots = attackSlots.assignForTargets(
      unitsByTarget: unitsByTarget,
      targetsById: targetById,
    );

    var meleeApplied = 0;
    var rangedCreated = 0;
    var rejected = 0;

    for (final unit in unitSnapshot) {
      if (!unit.isAlive) continue;
      final intent = combat.updateUnit(
        unit: unit,
        candidates: candidatesByUnit[unit.id] ?? const [],
        selectedTarget: targetsByUnit[unit.id],
        selectedTargetProvided: true,
        approachPoint: approachSlots[unit.id],
        now: now,
        elapsed: elapsed,
        allies: alliesFor(unit),
        obstacles: obstaclesFor(unit),
        navigationGrid: navigationGrid,
        pathfinder: pathfinder,
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

    return MonsterMatchTickResult(
      meleeHitsApplied: meleeApplied,
      rangedProjectilesCreated: rangedCreated,
      rejectedAttacks: rejected,
      projectileResults: projectileResults,
    );
  }

  /// Clears all per-match transient state when a match ends or is restarted.
  void clear() {
    projectiles.clear();
    pathfinder.clear();
    attackSlots.clear();
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
