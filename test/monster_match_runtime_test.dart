import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_army.dart';
import 'package:archer_fm/monsters/monster_combat.dart';
import 'package:archer_fm/monsters/monster_combat_resolver.dart';
import 'package:archer_fm/monsters/monster_match_combat_loop.dart';
import 'package:archer_fm/monsters/monster_match_runtime.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_projectile_manager.dart';
import 'package:archer_fm/monsters/monster_ranged_attack_handler.dart';

MonsterCatalog _catalog({double damage = 100}) => MonsterCatalog({
      for (final type in MonsterType.values)
        type: MonsterDefinition(
          type: type,
          baseStats: MonsterStats(
            maxHealth: 100,
            damage: damage,
            moveSpeed: 10,
            attackRange: 100,
            attackCooldown: const Duration(seconds: 1),
            purchaseCost: 10,
          ),
        ),
    });

MonsterArmy _army(String ownerId, String idPrefix, MonsterType type) {
  final counts = {for (final value in MonsterType.values) value: 0};
  counts[type] = 20;
  final army = MonsterArmy(
    ownerId: ownerId,
    idPrefix: idPrefix,
    catalog: _catalog(),
    selection: InitialArmySelection(counts),
    castleX: 0,
    castleY: 0,
  );
  for (final unit in army.units.skip(1).toList()) {
    unit.applyDamage(unit.health);
    army.removeDefeated(unit.id);
  }
  return army;
}

MonsterMatchCombatLoop _loop(MonsterProjectileManager manager) =>
    MonsterMatchCombatLoop(
      combat: const MonsterCombatController(),
      resolver: const MonsterCombatResolver(),
      rangedHandler: const MonsterRangedAttackHandler(),
      projectiles: manager,
      projectileSpeed: 10,
      projectileId: (_) => 'runtime-projectile',
    );

void main() {
  group('MonsterMatchRuntime', () {
    test('owns live armies, removes defeated units, and retains death visuals',
        () {
      final runnerArmy = _army('p1', 'p1-army', MonsterType.runner);
      final tankArmy = _army('p2', 'p2-army', MonsterType.tank);
      final runner = runnerArmy.units.single;
      final tank = tankArmy.units.single;
      tank.positionX = runner.positionX + 10;
      final manager = MonsterProjectileManager(maxActiveProjectiles: 4);
      final runtime = MonsterMatchRuntime(
        armies: [runnerArmy, tankArmy],
        combatLoop: _loop(manager),
      );

      final result = runtime.tick(
        now: DateTime.utc(2026, 11, 17),
        elapsed: const Duration(seconds: 1),
      );

      expect(result.meleeHitsApplied, 1);
      expect(result.attackingUnitIds, contains(runner.id));
      expect(tankArmy.units, isEmpty);
      expect(runtime.liveUnits, [runner]);
      expect(runtime.dyingUnits, [tank]);
      expect(runtime.simulationTick, 1);

      final layer = runtime.buildBattleLayer(
        worldToScreen: (x, y) => Offset(x, y),
      );
      expect(layer.units, [runner]);
      expect(layer.dyingUnits, [tank]);
      expect(layer.attackingUnitIds, contains(runner.id));
      expect(layer.projectiles, isEmpty);

      expect(runtime.completeDeathAnimation(tank.id), isTrue);
      expect(runtime.dyingUnits, isEmpty);
      expect(runtime.completeDeathAnimation(tank.id), isFalse);
    });

    test('rejects duplicate unit IDs across armies', () {
      final first = _army('p1', 'shared-prefix', MonsterType.runner);
      final second = _army('p2', 'shared-prefix', MonsterType.tank);

      expect(
        () => MonsterMatchRuntime(
          armies: [first, second],
          combatLoop: _loop(MonsterProjectileManager(maxActiveProjectiles: 4)),
        ),
        throwsArgumentError,
      );
    });

    test('requires at least one army', () {
      expect(
        () => MonsterMatchRuntime(
          armies: const [],
          combatLoop: _loop(MonsterProjectileManager(maxActiveProjectiles: 4)),
        ),
        throwsArgumentError,
      );
    });
  });
}
