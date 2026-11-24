import 'monster_army.dart';
import 'monster_battle_layer.dart';
import 'monster_match_combat_loop.dart';
import 'monster_match_world.dart';
import 'monster_models.dart';
import 'monster_navigation.dart';
import 'monster_projectile_manager.dart';
import 'monster_projectiles.dart';

/// Coordinates armies, one authoritative combat tick, projectiles, and the
/// visual-only lifetime of defeated units. The match host supplies external
/// hero/crystal adapters, the current map grid, and the camera transform.
class MonsterMatchRuntime {
  MonsterMatchRuntime({
    required Iterable<MonsterArmy> armies,
    required this.combatLoop,
  }) : armies = List<MonsterArmy>.unmodifiable(armies) {
    if (this.armies.isEmpty) {
      throw ArgumentError.value(armies, 'armies', 'At least one army is required.');
    }
    final unitIds = <String>{};
    for (final unit in liveUnits) {
      if (!unitIds.add(unit.id)) {
        throw ArgumentError('Duplicate monster unit ID: ' + unit.id);
      }
    }
  }

  final List<MonsterArmy> armies;
  final MonsterMatchCombatLoop combatLoop;
  final List<MonsterUnit> _dyingUnits = [];
  Set<String> _attackingUnitIds = const {};
  MonsterMatchTickResult? _lastResult;
  int _simulationTick = 0;

  MonsterProjectileManager get projectileManager => combatLoop.projectiles;
  int get simulationTick => _simulationTick;
  MonsterMatchTickResult? get lastResult => _lastResult;

  List<MonsterUnit> get liveUnits => List.unmodifiable(
        armies.expand((army) => army.units),
      );

  List<MonsterUnit> get dyingUnits => List.unmodifiable(_dyingUnits);

  /// Advances all armies against one fresh authoritative world snapshot.
  MonsterMatchTickResult tick({
    Iterable<MonsterPositionedDamageTarget> externalEntities = const [],
    required DateTime now,
    required Duration elapsed,
    MonsterNavigationGrid? navigationGrid,
  }) {
    final world = MonsterMatchWorldSnapshot(
      units: liveUnits,
      externalEntities: externalEntities,
    );
    final result = world.step(
      loop: combatLoop,
      now: now,
      elapsed: elapsed,
      navigationGrid: navigationGrid,
    );

    // Dead units leave the simulation immediately, but stay in the separate
    // presentation list until the battle layer reports their death animation.
    for (final army in armies) {
      final defeated = army.units.where((unit) => !unit.isAlive).toList();
      for (final unit in defeated) {
        if (army.removeDefeated(unit.id)) _dyingUnits.add(unit);
      }
    }

    _attackingUnitIds = result.attackingUnitIds;
    _lastResult = result;
    _simulationTick++;
    return result;
  }

  /// Called by MonsterBattleLayer after the visual death animation completes.
  bool completeDeathAnimation(String unitId) {
    final previousLength = _dyingUnits.length;
    _dyingUnits.removeWhere((unit) => unit.id == unitId);
    return _dyingUnits.length != previousLength;
  }

  /// Builds the presentation layer from the latest authoritative runtime state.
  MonsterBattleLayer buildBattleLayer({
    required MonsterWorldToScreen worldToScreen,
    double unitSize = 64,
    double projectileSize = 9,
  }) =>
      MonsterBattleLayer(
        units: liveUnits,
        dyingUnits: dyingUnits,
        projectiles: projectileManager.active,
        worldToScreen: worldToScreen,
        simulationTick: _simulationTick,
        attackingUnitIds: _attackingUnitIds,
        unitSize: unitSize,
        projectileSize: projectileSize,
        onDeathAnimationComplete: completeDeathAnimation,
      );
}
