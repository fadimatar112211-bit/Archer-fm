import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_army.dart';
import 'package:archer_fm/monsters/monster_combat_resolver.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_projectiles.dart';
import 'package:archer_fm/monsters/monster_projectile_manager.dart';
import 'package:archer_fm/monsters/monster_ranged_attack_handler.dart';
import 'package:archer_fm/monsters/monster_combat.dart';
import 'package:archer_fm/monsters/monster_match_combat_loop.dart';
import 'package:archer_fm/monsters/monster_external_entity_adapter.dart';

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

MonsterUnit _ranged() => MonsterArmy(
  ownerId: 'p1',
  catalog: _catalog(),
  selection: InitialArmySelection({
    MonsterType.runner: 0,
    MonsterType.tank: 0,
    MonsterType.stalker: 0,
    MonsterType.ranged: 20,
  }),
  castleX: 0,
  castleY: 0,
).units.first;

class _Target implements MonsterPositionedDamageTarget {
  _Target(this.id, this.ownerId, this.positionX, this.positionY,
      {this.health = 50});
  @override
  final String id;
  @override
  final String ownerId;
  @override
  final double positionX;
  @override
  final double positionY;
  double health;
  @override
  MonsterTargetKind get kind => MonsterTargetKind.hero;
  @override
  bool get isAlive => health > 0;
  @override
  bool applyDamage(double amount) {
    health = (health - amount).clamp(0, double.infinity).toDouble();
    return !isAlive;
  }

}

void main() {
  group('Ranged monster projectiles', () {
    test('travels toward a live enemy and applies damage on arrival', () {
      final target = _Target('enemy', 'p2', 15, 0);
      final projectile = MonsterProjectile(
        id: 'bolt-1', source: _ranged(), targetId: target.id, projectileSpeed: 10,
        positionX: 0, positionY: 0,
      );
      expect(projectile.update(
        elapsed: const Duration(seconds: 1), target: target,
      ), MonsterProjectileResult.travelling);
      expect(projectile.positionX, 10);
      expect(target.health, 50);
      expect(projectile.update(
        elapsed: const Duration(seconds: 1), target: target,
      ), MonsterProjectileResult.hit);
      expect(target.health, 38);
      expect(projectile.isResolved, isTrue);
      expect(projectile.update(
        elapsed: const Duration(seconds: 1), target: target,
      ), MonsterProjectileResult.alreadyResolved);
    });

    test('cancels when target disappears, dies, or becomes friendly', () {
      final source = _ranged();
      MonsterProjectile make() => MonsterProjectile(
        id: 'bolt', source: source, targetId: 'enemy', projectileSpeed: 10,
        positionX: 0, positionY: 0,
      );
      expect(make().update(
        elapsed: Duration.zero, target: null,
      ), MonsterProjectileResult.targetMissing);
      expect(make().update(
        elapsed: Duration.zero,
        target: _Target('enemy', 'p2', 10, 0, health: 0),
      ), MonsterProjectileResult.deadTarget);
      expect(make().update(
        elapsed: Duration.zero,
        target: _Target('enemy', 'p1', 10, 0),
      ), MonsterProjectileResult.friendlyTarget);
    });

    test('cancels a projectile when target identity is malformed', () {
      final projectile = MonsterProjectile(
        id: 'bolt-invalid-target',
        source: _ranged(),
        targetId: 'enemy',
        projectileSpeed: 10,
        positionX: 0,
        positionY: 0,
      );
      expect(projectile.update(
        elapsed: Duration.zero,
        target: _Target('enemy', '', 10, 0),
      ), MonsterProjectileResult.targetMissing);
      expect(projectile.isResolved, isTrue);
    });

    test('cancels when a positioned target has non-finite coordinates', () {
      final projectile = MonsterProjectile(
        id: 'bolt-invalid-position',
        source: _ranged(),
        targetId: 'enemy',
        projectileSpeed: 10,
        positionX: 0,
        positionY: 0,
      );
      expect(projectile.update(
        elapsed: const Duration(milliseconds: 10),
        target: _Target('enemy', 'p2', double.nan, 0),
      ), MonsterProjectileResult.targetMissing);
      expect(projectile.isResolved, isTrue);
    });

    test('cancels targets with infinite coordinates before moving', () {
      final projectile = MonsterProjectile(
        id: 'bolt-infinite-position',
        source: _ranged(),
        targetId: 'enemy',
        projectileSpeed: 10,
        positionX: 3,
        positionY: 4,
      );
      expect(projectile.update(
        elapsed: const Duration(seconds: 1),
        target: _Target('enemy', 'p2', double.infinity, 0),
      ), MonsterProjectileResult.targetMissing);
      expect(projectile.positionX, 3);
      expect(projectile.positionY, 4);
      expect(projectile.isResolved, isTrue);
    });

    test('rejects negative elapsed and requires a ranged living source', () {
      final projectile = MonsterProjectile(
        id: 'bolt', source: _ranged(), targetId: 'enemy', projectileSpeed: 10,
        positionX: 0, positionY: 0,
      );
      expect(projectile.update(
        elapsed: const Duration(milliseconds: -1),
        target: _Target('enemy', 'p2', 10, 0),
      ), MonsterProjectileResult.invalidElapsed);
      final runner = MonsterArmy(
        ownerId: 'p1', catalog: _catalog(),
        selection: InitialArmySelection({
          MonsterType.runner: 20, MonsterType.tank: 0,
          MonsterType.stalker: 0, MonsterType.ranged: 0,
        }),
        castleX: 0, castleY: 0,
      ).units.first;
      expect(() => MonsterProjectile(
        id: 'bad', source: runner, targetId: 'enemy', projectileSpeed: 10,
        positionX: 0, positionY: 0,
      ), throwsArgumentError);
    });
  });




  group('External match entity adapter', () {
    test('exposes authoritative position and delegates damage', () {
      var health = 40.0;
      final adapter = MonsterExternalEntityAdapter(
        id: 'crystal-1',
        ownerId: 'p2',
        kind: MonsterTargetKind.crystal,
        isAlive: true,
        positionX: 12,
        positionY: 18,
        applyDamage: (amount) {
          health = (health - amount).clamp(0, 100).toDouble();
          return health <= 0;
        },
      );
      expect(adapter.positionX, 12);
      expect(adapter.positionY, 18);
      expect(adapter.applyDamage(15), isFalse);
      expect(health, 25);
    });
  });

  group('Authoritative monster match combat loop', () {
    test('routes melee damage and ranged attacks through the projectile manager', () {
      final ranged = _ranged();
      final melee = MonsterArmy(
        ownerId: 'p1-melee',
        catalog: _catalog(),
        selection: InitialArmySelection({
          MonsterType.runner: 20, MonsterType.tank: 0,
          MonsterType.stalker: 0, MonsterType.ranged: 0,
        }),
        castleX: 0, castleY: 0,
      ).units.first;
      final rangedTarget = _Target(
        'ranged-enemy', 'p2', ranged.positionX + 1, ranged.positionY,
      );
      final meleeTarget = _Target(
        'melee-enemy', 'p2', melee.positionX + 1, melee.positionY,
      );
      final targets = <String, _Target>{
        rangedTarget.id: rangedTarget,
        meleeTarget.id: meleeTarget,
      };
      final manager = MonsterProjectileManager(maxActiveProjectiles: 8);
      var sequence = 0;
      final loop = MonsterMatchCombatLoop(
        combat: const MonsterCombatController(),
        resolver: const MonsterCombatResolver(),
        rangedHandler: const MonsterRangedAttackHandler(),
        projectiles: manager,
        projectileSpeed: 10,
        projectileId: (_) => 'tick-bolt-${sequence++}',
      );

      final first = loop.update(
        units: [ranged, melee],
        candidatesFor: (unit) => [
          MonsterTarget(
            id: unit.type == MonsterType.ranged
                ? rangedTarget.id : meleeTarget.id,
            ownerId: 'p2',
            kind: MonsterTargetKind.hero,
            x: unit.type == MonsterType.ranged
                ? rangedTarget.positionX : meleeTarget.positionX,
            y: unit.type == MonsterType.ranged
                ? rangedTarget.positionY : meleeTarget.positionY,
            isAlive: true,
          ),
        ],
        resolveDamageTarget: (id) => targets[id],
        resolvePositionedTarget: (id) => targets[id],
        now: DateTime.utc(2026, 3, 1),
        elapsed: Duration.zero,
      );

      expect(first.meleeHitsApplied, 1);
      expect(first.rangedProjectilesCreated, 1);
      expect(first.rejectedAttacks, 0);
      expect(manager.activeCount, 1);
      expect(meleeTarget.health, 38);
      expect(rangedTarget.health, 50);

      final second = loop.update(
        units: [ranged, melee],
        candidatesFor: (_) => const [],
        resolveDamageTarget: (id) => targets[id],
        resolvePositionedTarget: (id) => targets[id],
        now: DateTime.utc(2026, 3, 1).add(const Duration(seconds: 1)),
        elapsed: const Duration(seconds: 1),
      );
      expect(second.projectileResults.values, contains(MonsterProjectileResult.hit));
      expect(manager.activeCount, 0);
      expect(rangedTarget.health, 38);
    });

    test('rejects negative tick duration without advancing projectiles', () {
      final manager = MonsterProjectileManager(maxActiveProjectiles: 2);
      final loop = MonsterMatchCombatLoop(
        combat: const MonsterCombatController(),
        resolver: const MonsterCombatResolver(),
        rangedHandler: const MonsterRangedAttackHandler(),
        projectiles: manager,
        projectileSpeed: 10,
        projectileId: (_) => 'unused',
      );
      expect(() => loop.update(
        units: const [],
        candidatesFor: (_) => const [],
        resolveDamageTarget: (_) => null,
        resolvePositionedTarget: (_) => null,
        now: DateTime.utc(2026, 3, 1),
        elapsed: const Duration(milliseconds: -1),
      ), throwsArgumentError);
    });
  });

  group('Ranged attack intent integration', () {
    const handler = MonsterRangedAttackHandler();

    test('turns a valid ranged intent into a projectile at source position', () {
      final source = _ranged();
      source.positionX = 4;
      source.positionY = 7;
      final target = _Target('enemy', 'p2', 30, 40);
      final projectile = handler.tryCreate(
        intent: MonsterCombatIntent(
          monsterId: source.id, targetId: target.id, damage: source.stats.damage,
        ),
        source: source,
        target: target,
        projectileId: 'bolt-valid',
        projectileSpeed: 15,
      );
      expect(projectile, isNotNull);
      expect(projectile!.ownerId, 'p1');
      expect(projectile.sourceMonsterId, source.id);
      expect(projectile.positionX, 4);
      expect(projectile.positionY, 7);
      expect(projectile.targetId, 'enemy');
      expect(projectile.speed, 15);
    });

    test('rejects mismatched source, owner intent, and invalid targets', () {
      final source = _ranged();
      final target = _Target('enemy', 'p2', 10, 0);
      MonsterCombatIntent intent(String monsterId, String targetId) =>
          MonsterCombatIntent(
            monsterId: monsterId, targetId: targetId,
            damage: source.stats.damage,
          );
      MonsterProjectile? create({
        MonsterCombatIntent? attack,
        MonsterPositionedDamageTarget? victim,
      }) => handler.tryCreate(
        intent: attack ?? intent(source.id, 'enemy'),
        source: source,
        target: victim ?? target,
        projectileId: 'bolt',
        projectileSpeed: 10,
      );

      expect(create(attack: intent('other-monster', 'enemy')), isNull);
      expect(create(attack: intent(source.id, 'other-target')), isNull);
      expect(create(victim: _Target('enemy', 'p1', 10, 0)), isNull);
      expect(create(victim: _Target('enemy', 'p2', 10, 0, health: 0)), isNull);
      expect(create(victim: _Target('enemy', '', 10, 0)), isNull);
      expect(handler.tryCreate(
        intent: intent(source.id, 'enemy'),
        source: source,
        target: null,
        projectileId: 'missing-target',
        projectileSpeed: 10,
      ), isNull);
      expect(handler.tryCreate(
        intent: intent(source.id, 'enemy'),
        source: source,
        target: target,
        projectileId: 'bad-speed',
        projectileSpeed: double.nan,
      ), isNull);
    });

    test('rejects ranged sources with non-finite launch coordinates', () {
      final source = _ranged();
      final target = _Target('enemy', 'p2', 10, 0);
      final intent = MonsterCombatIntent(
        monsterId: source.id, targetId: target.id, damage: source.stats.damage,
      );
      source.positionX = double.nan;
      expect(handler.tryCreate(
        intent: intent, source: source, target: target,
        projectileId: 'invalid-launch-x', projectileSpeed: 10,
      ), isNull);
      source.positionX = 0;
      source.positionY = double.infinity;
      expect(handler.tryCreate(
        intent: intent, source: source, target: target,
        projectileId: 'invalid-launch-y', projectileSpeed: 10,
      ), isNull);
    });

    test('rejects non-ranged and defeated sources', () {
      final source = MonsterArmy(
        ownerId: 'p1', catalog: _catalog(),
        selection: InitialArmySelection({
          MonsterType.runner: 20, MonsterType.tank: 0,
          MonsterType.stalker: 0, MonsterType.ranged: 0,
        }),
        castleX: 0, castleY: 0,
      ).units.first;
      final target = _Target('enemy', 'p2', 10, 0);
      final intent = MonsterCombatIntent(
        monsterId: source.id, targetId: 'enemy', damage: source.stats.damage,
      );
      expect(handler.tryCreate(
        intent: intent, source: source, target: target,
        projectileId: 'bad-source', projectileSpeed: 10,
      ), isNull);
    });
  });

  group('Monster projectile manager', () {
    MonsterProjectile projectile(String id) => MonsterProjectile(
      id: id, source: _ranged(), targetId: 'enemy',
      projectileSpeed: 10, positionX: 0, positionY: 0,
    );

    test('enforces configured capacity and unique IDs', () {
      final manager = MonsterProjectileManager(maxActiveProjectiles: 2);
      expect(manager.add(projectile('a')), isTrue);
      expect(manager.add(projectile('a')), isFalse);
      expect(manager.add(projectile('b')), isTrue);
      expect(manager.add(projectile('c')), isFalse);
      expect(manager.activeCount, 2);
    });

    test('removes resolved projectiles and supports clearing', () {
      final manager = MonsterProjectileManager(maxActiveProjectiles: 3);
      manager.add(projectile('a'));
      manager.add(projectile('b'));
      final target = _Target('enemy', 'p2', 0, 0);
      final result = manager.update(
        elapsed: Duration.zero,
        resolveTarget: (id) => id == target.id ? target : null,
      );
      expect(result['a'], MonsterProjectileResult.hit);
      expect(result['b'], MonsterProjectileResult.hit);
      expect(manager.activeCount, 0);
      manager.add(projectile('c'));
      manager.clear();
      expect(manager.activeCount, 0);
    });

    test('retains travelling projectiles and rejects invalid capacity', () {
      expect(() => MonsterProjectileManager(maxActiveProjectiles: 0),
          throwsAssertionError);
      final manager = MonsterProjectileManager(maxActiveProjectiles: 1);
      manager.add(projectile('a'));
      final result = manager.update(
        elapsed: const Duration(milliseconds: 100),
        resolveTarget: (_) => _Target('enemy', 'p2', 100, 0),
      );
      expect(result['a'], MonsterProjectileResult.travelling);
      expect(manager.activeCount, 1);
    });
  });

}
