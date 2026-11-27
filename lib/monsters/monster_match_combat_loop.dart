import 'monster_combat.dart';
import 'monster_combat_resolver.dart';
import 'monster_models.dart';
import 'monster_projectile_manager.dart';
import 'monster_projectiles.dart';
import 'monster_ranged_attack_handler.dart';
import 'monster_formation_movement.dart';
import 'monster_navigation.dart';
import 'monster_attack_slots.dart';
import 'monster_spatial_index.dart';

typedef MonsterTargetCandidates = Iterable<MonsterTarget> Function(
  MonsterUnit source,
);
typedef MonsterDamageLookup = MonsterDamageTarget? Function(String targetId);
typedef MonsterPositionedLookup =
    MonsterPositionedDamageTarget? Function(String targetId);
typedef MonsterProjectileIdFactory = String Function(MonsterUnit source);
typedef MonsterAlliesLookup = Iterable<MonsterUnit> Function(MonsterUnit source);
typedef MonsterObstaclesLookup = Iterable<MonsterMovementObstacle> Function(MonsterUnit source);
typedef MonsterMovementSpeedMultiplier = double Function(MonsterUnit source);

double _normalMonsterMovementSpeed(MonsterUnit _) => 1;

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
    this.alliesFor,
    this.obstaclesFor = _noObstacles,
    this.movementSpeedMultiplierFor = _normalMonsterMovementSpeed,
    this.onProjectileKill,
    this.canActFor,
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
  final MonsterAlliesLookup? alliesFor;
  final MonsterObstaclesLookup obstaclesFor;
  /// Map hosts can lower movement on water or other slow surfaces.
  final MonsterMovementSpeedMultiplier movementSpeedMultiplierFor;
  /// Called only when a projectile changes a live target into a defeated one.
  final MonsterKillCallback? onProjectileKill;
  /// Allows the match host to pause stunned/frozen units without removing them
  /// from targeting or presentation.
  final bool Function(MonsterUnit unit)? canActFor;
  final MonsterNavigationGrid? navigationGrid;
  final MonsterPathfinder pathfinder;
  final MonsterAttackSlotCoordinator attackSlots;

  static Iterable<MonsterMovementObstacle> _noObstacles(MonsterUnit _) => const [];

  MonsterMatchTickResult update({
    required Iterable<MonsterUnit> units,
    required MonsterTargetCandidates candidatesFor,
    required MonsterDamageLookup resolveDamageTarget,
    required MonsterPositionedLookup resolvePositionedTarget,
    required DateTime now,
    required Duration elapsed,
    MonsterNavigationGrid? navigationGrid,
  }) {
    if (elapsed.isNegative) throw ArgumentError.value(elapsed, 'elapsed');
    final activeNavigationGrid = navigationGrid ?? this.navigationGrid;

    final unitSnapshot = units.toList(growable: false);
    final unitsByOwner = <String, List<MonsterUnit>>{};
    for (final unit in unitSnapshot) {
      if (unit.isAlive) {
        unitsByOwner.putIfAbsent(unit.ownerId, () => []).add(unit);
      }
    }
    final cohesionAnchors = <String, (double, double)>{};
    for (final entry in unitsByOwner.entries) {
      final group = entry.value;
      cohesionAnchors[entry.key] = (
        group.fold<double>(0, (sum, unit) => sum + unit.positionX) / group.length,
        group.fold<double>(0, (sum, unit) => sum + unit.positionY) / group.length,
      );
    }
    final spatialIndex = alliesFor == null
        ? MonsterSpatialIndex(
            units: unitSnapshot,
            cellSize: combat.movement.separationRadius * 2,
          )
        : null;

    // Advance only projectiles that existed at the beginning of this tick.
    // Projectiles launched below must not receive travel time retroactively.
    final projectileResults = projectiles.update(
      elapsed: elapsed,
      resolveTarget: resolvePositionedTarget,
      onKill: onProjectileKill,
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
    final attackingUnitIds = <String>{};

    for (final unit in unitSnapshot) {
      if (!unit.isAlive) {
        spatialIndex?.update(unit);
        continue;
      }
      final nearbyAllies = alliesFor?.call(unit) ??
          spatialIndex!.nearbyUnits(
            unit,
            radius: combat.movement.separationRadius,
          );
      final intent = combat.updateUnit(
        unit: unit,
        candidates: candidatesByUnit[unit.id] ?? const [],
        selectedTarget: targetsByUnit[unit.id],
        selectedTargetProvided: true,
        approachPoint: approachSlots[unit.id],
        now: now,
        elapsed: elapsed,
        allies: nearbyAllies,
        obstacles: obstaclesFor(unit),
        navigationGrid: activeNavigationGrid,
        pathfinder: pathfinder,
        cohesionAnchor: cohesionAnchors[unit.ownerId],
        movementSpeedMultiplier: movementSpeedMultiplierFor(unit),
      );
      spatialIndex?.update(unit);
      if (intent == null) continue;

      if (unit.type == MonsterType.bogMonster) {
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
          attackingUnitIds.add(intent.monsterId);
        }
      } else {
        final result = resolver.resolve(
          intent: intent,
          attackerOwnerId: unit.ownerId,
          target: resolveDamageTarget(intent.targetId),
        );
        if (result == MonsterDamageResult.applied) {
          meleeApplied++;
          attackingUnitIds.add(intent.monsterId);
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
      attackingUnitIds: Set.unmodifiable(attackingUnitIds),
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
    this.attackingUnitIds = const {},
  });

  final int meleeHitsApplied;
  final int rangedProjectilesCreated;
  final int rejectedAttacks;
  final Map<String, MonsterProjectileResult> projectileResults;
  final Set<String> attackingUnitIds;
}
