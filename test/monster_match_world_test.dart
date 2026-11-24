import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_army.dart';
import 'package:archer_fm/monsters/monster_combat.dart';
import 'package:archer_fm/monsters/monster_combat_resolver.dart';
import 'package:archer_fm/monsters/monster_external_entity_adapter.dart';
import 'package:archer_fm/monsters/monster_match_combat_loop.dart';
import 'package:archer_fm/monsters/monster_match_world.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_projectile_manager.dart';
import 'package:archer_fm/monsters/monster_projectiles.dart';
import 'package:archer_fm/monsters/monster_ranged_attack_handler.dart';

MonsterCatalog _catalog() => MonsterCatalog({
      for (final type in MonsterType.values)
        type: MonsterDefinition(
          type: type,
          baseStats: MonsterStats(
            maxHealth: 100,
            damage: 12,
            moveSpeed: 10,
            attackRange: 100,
            attackCooldown: const Duration(seconds: 1),
            purchaseCost: 10,
          ),
        ),
    });

MonsterUnit _unit({
  required String ownerId,
  required String idPrefix,
  required MonsterType type,
}) {
  final counts = {for (final monsterType in MonsterType.values) monsterType: 0};
  counts[type] = 20;
  return MonsterArmy(
    ownerId: ownerId,
    idPrefix: idPrefix,
    catalog: _catalog(),
    selection: InitialArmySelection(counts),
    castleX: 0,
    castleY: 0,
  ).units.first;
}

MonsterMatchCombatLoop _loop(MonsterProjectileManager projectiles) =>
    MonsterMatchCombatLoop(
      combat: const MonsterCombatController(),
      resolver: const MonsterCombatResolver(),
      rangedHandler: const MonsterRangedAttackHandler(),
      projectiles: projectiles,
      projectileSpeed: 10,
      projectileId: (_) => 'world-bolt',
    );

void main() {
  group('Monster match world adapter', () {
    test('builds candidates and resolves melee damage against live entities',
        () {
      final attacker = _unit(
        ownerId: 'p1',
        idPrefix: 'p1-army',
        type: MonsterType.runner,
      );
      var heroHealth = 50.0;
      final hero = MonsterExternalEntityAdapter(
        id: 'p2-hero',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        isAlive: true,
        positionX: 1,
        positionY: 0,
        applyDamage: (amount) {
          heroHealth -= amount;
          return heroHealth <= 0;
        },
      );
      final world = MonsterMatchWorldSnapshot(
        units: [attacker],
        externalEntities: [hero],
      );

      expect(
        world.candidatesFor(attacker).map((target) => target.id),
        contains('p2-hero'),
      );
      final result = world.step(
        loop: _loop(MonsterProjectileManager(maxActiveProjectiles: 4)),
        now: DateTime.utc(2026, 11, 17),
        elapsed: const Duration(seconds: 1),
      );

      expect(result.meleeHitsApplied, 1);
      expect(result.attackingUnitIds, contains(attacker.id));
      expect(heroHealth, 38);
    });

    test('resolves damage between enemy monster units through the same world index',
        () {
      final attacker = _unit(
        ownerId: 'p1',
        idPrefix: 'p1-army',
        type: MonsterType.runner,
      );
      final defender = _unit(
        ownerId: 'p2',
        idPrefix: 'p2-army',
        type: MonsterType.tank,
      );
      final world = MonsterMatchWorldSnapshot(
        units: [attacker, defender],
      );

      final result = world.step(
        loop: _loop(MonsterProjectileManager(maxActiveProjectiles: 4)),
        now: DateTime.utc(2026, 11, 17),
        elapsed: const Duration(seconds: 1),
      );

      expect(result.meleeHitsApplied, 2);
      expect(attacker.health, 88);
      expect(defender.health, 88);
    });

    test('live health prevents later attackers from overkilling a defeated target',
        () {
      final army = MonsterArmy(
        ownerId: 'p1',
        idPrefix: 'p1-army',
        catalog: _catalog(),
        selection: InitialArmySelection({
          for (final type in MonsterType.values)
            type: type == MonsterType.runner ? 20 : 0,
        }),
        castleX: 0,
        castleY: 0,
      );
      final attackers = army.units.take(2).toList(growable: false);
      var heroHealth = 10.0;
      final hero = MonsterExternalEntityAdapter(
        id: 'p2-fragile-hero',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        isAlive: true,
        positionX: 1,
        positionY: 0,
        isAliveNow: () => heroHealth > 0,
        applyDamage: (amount) {
          heroHealth -= amount;
          return heroHealth <= 0;
        },
      );
      final world = MonsterMatchWorldSnapshot(
        units: attackers,
        externalEntities: [hero],
      );

      final result = world.step(
        loop: _loop(MonsterProjectileManager(maxActiveProjectiles: 4)),
        now: DateTime.utc(2026, 11, 17),
        elapsed: const Duration(seconds: 1),
      );

      expect(result.meleeHitsApplied, 1);
      expect(result.rejectedAttacks, 1);
      expect(heroHealth, -2);
    });

    test('resolves homing ranged projectiles against fresh world snapshots',
        () {
      final ranged = _unit(
        ownerId: 'p1',
        idPrefix: 'p1-ranged',
        type: MonsterType.ranged,
      );
      var heroHealth = 50.0;
      var heroX = ranged.positionX + 5;
      MonsterExternalEntityAdapter hero() => MonsterExternalEntityAdapter(
            id: 'p2-moving-hero',
            ownerId: 'p2',
            kind: MonsterTargetKind.hero,
            isAlive: true,
            positionX: heroX,
            positionY: ranged.positionY,
            applyDamage: (amount) {
              heroHealth -= amount;
              return heroHealth <= 0;
            },
          );
      final manager = MonsterProjectileManager(maxActiveProjectiles: 4);
      final loop = _loop(manager);
      final firstWorld = MonsterMatchWorldSnapshot(
        units: [ranged],
        externalEntities: [hero()],
      );
      final first = firstWorld.step(
        loop: loop,
        now: DateTime.utc(2026, 11, 17),
        elapsed: Duration.zero,
      );
      expect(first.rangedProjectilesCreated, 1);
      expect(first.attackingUnitIds, contains(ranged.id));
      expect(heroHealth, 50);

      heroX = ranged.positionX + 10;
      final secondWorld = MonsterMatchWorldSnapshot(
        units: [ranged],
        externalEntities: [hero()],
      );
      final second = secondWorld.step(
        loop: loop,
        now: DateTime.utc(2026, 11, 17).add(const Duration(milliseconds: 500)),
        elapsed: const Duration(seconds: 1),
      );

      expect(second.projectileResults.values, contains(MonsterProjectileResult.hit));
      expect(heroHealth, 38);
      expect(manager.activeCount, 0);
    });

    test('includes allied crystals for defense but excludes the source itself',
        () {
      final unit = _unit(
        ownerId: 'p1',
        idPrefix: 'p1-army',
        type: MonsterType.runner,
      );
      final crystal = MonsterExternalEntityAdapter(
        id: 'p1-crystal',
        ownerId: 'p1',
        kind: MonsterTargetKind.crystal,
        isAlive: true,
        positionX: 0,
        positionY: 5,
        applyDamage: (_) => false,
      );
      final world = MonsterMatchWorldSnapshot(
        units: [unit],
        externalEntities: [crystal],
      );
      final candidates = world.candidatesFor(unit);

      expect(candidates.map((target) => target.id), contains('p1-crystal'));
      expect(candidates.map((target) => target.id), isNot(contains(unit.id)));
    });

    test('rejects duplicate IDs and invalid external coordinates', () {
      final unit = _unit(
        ownerId: 'p1',
        idPrefix: 'p1-army',
        type: MonsterType.runner,
      );
      final duplicate = MonsterExternalEntityAdapter(
        id: unit.id,
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        isAlive: true,
        positionX: 1,
        positionY: 1,
        applyDamage: (_) => false,
      );
      expect(
        () => MonsterMatchWorldSnapshot(
          units: [unit],
          externalEntities: [duplicate],
        ),
        throwsArgumentError,
      );
      final invalid = MonsterExternalEntityAdapter(
        id: 'invalid',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        isAlive: true,
        positionX: double.nan,
        positionY: 0,
        applyDamage: (_) => false,
      );
      expect(
        () => MonsterMatchWorldSnapshot(
          units: [unit],
          externalEntities: [invalid],
        ),
        throwsArgumentError,
      );
    });
  });
}
