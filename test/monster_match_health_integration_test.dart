import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_army.dart';
import 'package:archer_fm/monsters/monster_combat.dart';
import 'package:archer_fm/monsters/monster_combat_resolver.dart';
import 'package:archer_fm/monsters/monster_external_entity_adapter.dart';
import 'package:archer_fm/monsters/monster_match_combat_loop.dart';
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

MonsterUnit _unit(MonsterType type, {String ownerId = 'p1'}) {
  final counts = {for (final value in MonsterType.values) value: 0};
  counts[type] = 20;
  return MonsterArmy(
    ownerId: ownerId,
    catalog: _catalog(),
    selection: InitialArmySelection(counts),
    castleX: 0,
    castleY: 0,
  ).units.first;
}

class _HealthEntity {
  _HealthEntity({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.x,
    required this.y,
    this.health = 50,
  });

  final String id;
  final String ownerId;
  final MonsterTargetKind kind;
  double x;
  double y;
  double health;

  MonsterExternalEntityAdapter adapter() => MonsterExternalEntityAdapter(
        id: id,
        ownerId: ownerId,
        kind: kind,
        isAlive: health > 0,
        positionX: x,
        positionY: y,
        applyDamage: (amount) {
          health = (health - amount).clamp(0, double.infinity).toDouble();
          return health <= 0;
        },
      );

  MonsterTarget candidate() => MonsterTarget(
        id: id,
        ownerId: ownerId,
        kind: kind,
        x: x,
        y: y,
        isAlive: health > 0,
      );
}

MonsterMatchCombatLoop _loop() => MonsterMatchCombatLoop(
      combat: const MonsterCombatController(),
      resolver: const MonsterCombatResolver(),
      rangedHandler: const MonsterRangedAttackHandler(),
      projectiles: MonsterProjectileManager(maxActiveProjectiles: 16),
      projectileSpeed: 10,
      projectileId: (unit) => 'bolt-${unit.id}',
    );

void main() {
  group('Monster combat health integration contracts', () {
    test('melee attack applies damage to an enemy hero health adapter', () {
      final attacker = _unit(MonsterType.runner);
      final hero = _HealthEntity(
        id: 'hero-p2',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: attacker.positionX + 1,
        y: attacker.positionY,
      );
      final result = _loop().update(
        units: [attacker],
        candidatesFor: (_) => [hero.candidate()],
        resolveDamageTarget: (_) => hero.adapter(),
        resolvePositionedTarget: (_) => hero.adapter(),
        now: DateTime.utc(2026, 11, 17),
        elapsed: Duration.zero,
      );

      expect(result.meleeHitsApplied, 1);
      expect(hero.health, 38);
    });

    test('melee attack applies damage to an enemy crystal health adapter', () {
      final attacker = _unit(MonsterType.tank);
      final crystal = _HealthEntity(
        id: 'crystal-p2',
        ownerId: 'p2',
        kind: MonsterTargetKind.crystal,
        x: attacker.positionX + 1,
        y: attacker.positionY,
      );
      final result = _loop().update(
        units: [attacker],
        candidatesFor: (_) => [crystal.candidate()],
        resolveDamageTarget: (_) => crystal.adapter(),
        resolvePositionedTarget: (_) => crystal.adapter(),
        now: DateTime.utc(2026, 11, 17),
        elapsed: Duration.zero,
      );

      expect(result.meleeHitsApplied, 1);
      expect(crystal.health, 38);
    });

    test('melee attack damages an enemy monster unit directly', () {
      final attacker = _unit(MonsterType.stalker);
      final defender = _unit(MonsterType.tank, ownerId: 'p2');
      defender.health = 10;
      final result = _loop().update(
        units: [attacker],
        candidatesFor: (_) => [
          MonsterTarget(
            id: defender.id,
            ownerId: defender.ownerId,
            kind: MonsterTargetKind.monster,
            x: attacker.positionX + 1,
            y: attacker.positionY,
            isAlive: defender.isAlive,
          ),
        ],
        resolveDamageTarget: (id) =>
            id == defender.id ? MonsterUnitDamageTarget(defender) : null,
        resolvePositionedTarget: (_) => null,
        now: DateTime.utc(2026, 11, 17),
        elapsed: Duration.zero,
      );

      expect(result.meleeHitsApplied, 1);
      expect(defender.health, 0);
      expect(defender.isAlive, isFalse);
    });

    test('lethal hero damage is reflected by fresh lookups and cannot repeat', () {
      final attacker = _unit(MonsterType.runner);
      final hero = _HealthEntity(
        id: 'hero-low-health',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: attacker.positionX + 1,
        y: attacker.positionY,
        health: 12,
      );
      final loop = _loop();
      final first = loop.update(
        units: [attacker],
        candidatesFor: (_) => [hero.candidate()],
        resolveDamageTarget: (_) => hero.adapter(),
        resolvePositionedTarget: (_) => hero.adapter(),
        now: DateTime.utc(2026, 11, 17),
        elapsed: Duration.zero,
      );
      final second = loop.update(
        units: [attacker],
        candidatesFor: (_) => [hero.candidate()],
        resolveDamageTarget: (_) => hero.adapter(),
        resolvePositionedTarget: (_) => hero.adapter(),
        now: DateTime.utc(2026, 11, 17).add(const Duration(seconds: 1)),
        elapsed: const Duration(seconds: 1),
      );

      expect(first.meleeHitsApplied, 1);
      expect(hero.health, 0);
      expect(second.meleeHitsApplied, 0);
      expect(second.rejectedAttacks, 1);
      expect(hero.health, 0);
    });

    test('ranged projectile applies damage to an enemy hero', () {
      final attacker = _unit(MonsterType.ranged);
      final hero = _HealthEntity(
        id: 'ranged-hero-p2',
        ownerId: 'p2',
        kind: MonsterTargetKind.hero,
        x: attacker.positionX + 1,
        y: attacker.positionY,
      );
      final loop = _loop();
      final first = loop.update(
        units: [attacker],
        candidatesFor: (_) => [hero.candidate()],
        resolveDamageTarget: (_) => hero.adapter(),
        resolvePositionedTarget: (_) => hero.adapter(),
        now: DateTime.utc(2026, 11, 17),
        elapsed: Duration.zero,
      );
      final second = loop.update(
        units: [attacker],
        candidatesFor: (_) => const [],
        resolveDamageTarget: (_) => hero.adapter(),
        resolvePositionedTarget: (_) => hero.adapter(),
        now: DateTime.utc(2026, 11, 17).add(const Duration(seconds: 1)),
        elapsed: const Duration(seconds: 1),
      );

      expect(first.rangedProjectilesCreated, 1);
      expect(hero.health, 38);
      expect(second.projectileResults.values, contains(MonsterProjectileResult.hit));
    });

    test('ranged projectile applies lethal damage to an enemy crystal', () {
      final attacker = _unit(MonsterType.ranged);
      final crystal = _HealthEntity(
        id: 'ranged-crystal-p2',
        ownerId: 'p2',
        kind: MonsterTargetKind.crystal,
        x: attacker.positionX + 1,
        y: attacker.positionY,
        health: 12,
      );
      final loop = _loop();
      final first = loop.update(
        units: [attacker],
        candidatesFor: (_) => [crystal.candidate()],
        resolveDamageTarget: (_) => crystal.adapter(),
        resolvePositionedTarget: (_) => crystal.adapter(),
        now: DateTime.utc(2026, 11, 17),
        elapsed: Duration.zero,
      );
      final second = loop.update(
        units: [attacker],
        candidatesFor: (_) => const [],
        resolveDamageTarget: (_) => crystal.adapter(),
        resolvePositionedTarget: (_) => crystal.adapter(),
        now: DateTime.utc(2026, 11, 17).add(const Duration(seconds: 1)),
        elapsed: const Duration(seconds: 1),
      );

      expect(first.rangedProjectilesCreated, 1);
      expect(second.projectileResults.values, contains(MonsterProjectileResult.hit));
      expect(crystal.health, 0);
      expect(second.projectileResults.values, isNot(contains(MonsterProjectileResult.travelling)));
    });
  });
}
