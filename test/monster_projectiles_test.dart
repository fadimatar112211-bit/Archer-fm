import 'package:flutter_test/flutter_test.dart';
import 'package:archero_fm/monsters/monster_army.dart';
import 'package:archero_fm/monsters/monster_combat_resolver.dart';
import 'package:archero_fm/monsters/monster_models.dart';
import 'package:archero_fm/monsters/monster_projectiles.dart';
import 'package:archero_fm/monsters/monster_projectile_manager.dart';
import 'package:archero_fm/monsters/monster_ranged_attack_handler.dart';
import 'package:archero_fm/monsters/monster_combat.dart';

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
          throwsArgumentError);
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
