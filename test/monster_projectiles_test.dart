import 'package:flutter_test/flutter_test.dart';
import 'package:archero_fm/monsters/monster_army.dart';
import 'package:archero_fm/monsters/monster_combat_resolver.dart';
import 'package:archero_fm/monsters/monster_models.dart';
import 'package:archero_fm/monsters/monster_projectiles.dart';

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
  selection: const InitialArmySelection({
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
        id: 'bolt-1', source: _ranged(), targetId: target.id,
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
        id: 'bolt', source: source, targetId: 'enemy',
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
        id: 'bolt', source: _ranged(), targetId: 'enemy',
        positionX: 0, positionY: 0,
      );
      expect(projectile.update(
        elapsed: const Duration(milliseconds: -1),
        target: _Target('enemy', 'p2', 10, 0),
      ), MonsterProjectileResult.invalidElapsed);
      final runner = MonsterArmy(
        ownerId: 'p1', catalog: _catalog(),
        selection: const InitialArmySelection({
          MonsterType.runner: 20, MonsterType.tank: 0,
          MonsterType.stalker: 0, MonsterType.ranged: 0,
        }),
        castleX: 0, castleY: 0,
      ).units.first;
      expect(() => MonsterProjectile(
        id: 'bad', source: runner, targetId: 'enemy',
        positionX: 0, positionY: 0,
      ), throwsArgumentError);
    });
  });
}
