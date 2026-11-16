import 'package:flutter_test/flutter_test.dart';
import 'package:archero_fm/monsters/monster_army.dart';
import 'package:archero_fm/monsters/monster_combat.dart';
import 'package:archero_fm/monsters/monster_combat_resolver.dart';
import 'package:archero_fm/monsters/monster_models.dart';

MonsterCatalog catalog() => MonsterCatalog({
  for (final type in MonsterType.values)
    type: MonsterDefinition(
      type: type,
      baseStats: MonsterStats(
        maxHealth: 100,
        damage: 10,
        moveSpeed: 2,
        attackRange: type == MonsterType.ranged ? 120 : 24,
        attackCooldown: const Duration(milliseconds: 800),
        purchaseCost: type.index + 10,
      ),
    ),
});

MonsterArmy makeArmy() => MonsterArmy(
  ownerId: 'p1',
  catalog: catalog(),
  selection: InitialArmySelection({
    MonsterType.runner: 8,
    MonsterType.tank: 4,
    MonsterType.stalker: 5,
    MonsterType.ranged: 3,
  }),
  castleX: 100,
  castleY: 200,
);

class _FakeDamageTarget implements MonsterDamageTarget {
  _FakeDamageTarget({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.health,
  });

  @override
  final String id;
  @override
  final String ownerId;
  @override
  final MonsterTargetKind kind;
  double health;

  @override
  bool get isAlive => health > 0;

  @override
  bool applyDamage(double amount) {
    health = (health - amount).clamp(0, double.infinity).toDouble();
    return !isAlive;
  }
}

void main() {
  group('Monster army', () {
    test('creates exactly twenty units from the selected composition', () {
      final army = makeArmy();
      expect(army.units, hasLength(20));
      expect(army.aliveCount, 20);
      expect(army.countOf(MonsterType.runner), 8);
      expect(army.countOf(MonsterType.ranged), 3);
      expect(army.units.every((unit) => unit.ownerId == 'p1'), isTrue);
      expect(army.units.map((unit) => unit.id).toSet(), hasLength(20));
    });

    test('rejects invalid starting compositions', () {
      expect(() => InitialArmySelection({MonsterType.runner: 19}), throwsArgumentError);
      expect(() => InitialArmySelection({MonsterType.runner: -1}), throwsArgumentError);
    });

    test('purchase returns exact debit and spawned unit', () {
      final army = makeArmy();
      expect(army.purchase(type: MonsterType.tank, currentResources: 10), isNull);
      expect(army.units, hasLength(20));
      final purchase = army.purchase(type: MonsterType.tank, currentResources: 11);
      expect(purchase, isNotNull);
      expect(purchase!.cost, 11);
      expect(purchase.unit.type, MonsterType.tank);
      expect(army.units, hasLength(21));
    });

    test('dead units are removed permanently and not respawned', () {
      final army = makeArmy();
      final unit = army.units.first;
      expect(unit.applyDamage(100), isTrue);
      expect(army.removeDefeated(unit.id), isTrue);
      expect(army.units, hasLength(19));
      expect(army.removeDefeated(unit.id), isFalse);
    });

    test('group movement advances units without exceeding individual speed', () {
      final army = makeArmy();
      final before = army.units.map((u) => [u.positionX, u.positionY]).toList();
      army.moveGroupToward(
        targetX: 500,
        targetY: 200,
        elapsed: const Duration(seconds: 1),
      );
      for (var i = 0; i < army.units.length; i++) {
        final dx = army.units[i].positionX - before[i][0];
        final dy = army.units[i].positionY - before[i][1];
        expect(dx * dx + dy * dy, lessThanOrEqualTo(4.000001));
      }
    });

    test('zero elapsed time does not move the group', () {
      final army = makeArmy();
      final before = army.units.first.positionX;
      army.moveGroupToward(
        targetX: 500, targetY: 500, elapsed: Duration.zero,
      );
      expect(army.units.first.positionX, before);
    });
  });

  group('Monster unit combat timing', () {
    test('attack cooldown is enforced', () {
      final unit = makeArmy().units.first;
      final first = DateTime.utc(2026, 1, 1);
      expect(unit.canAttackAt(first), isTrue);
      unit.recordAttack(first);
      expect(unit.canAttackAt(first.add(const Duration(milliseconds: 799))), isFalse);
      expect(unit.canAttackAt(first.add(const Duration(milliseconds: 800))), isTrue);
    });

    test('damage rejects negative and non-finite values', () {
      final unit = makeArmy().units.first;
      expect(() => unit.applyDamage(-1), throwsArgumentError);
      expect(() => unit.applyDamage(double.nan), throwsArgumentError);
    });
  });

  group('Monster combat controller', () {
    const combat = MonsterCombatController();

    test('moves toward nearest enemy, then emits damage inside range', () {
      final unit = makeArmy().units.first;
      final target = const MonsterTarget(
        id: 'enemy', ownerId: 'p2', kind: MonsterTargetKind.hero,
        x: 200, y: 200, isAlive: true,
      );
      final now = DateTime.utc(2026, 2, 1);
      final initialDistance = (target.x - unit.positionX).abs();
      final intent = combat.updateUnit(
        unit: unit,
        candidates: [target],
        now: now,
        elapsed: const Duration(seconds: 1),
      );
      expect(intent, isNull);
      expect((target.x - unit.positionX).abs(), lessThan(initialDistance));
      expect(unit.targetId, 'enemy');

      unit.positionX = target.x - unit.stats.attackRange;
      unit.positionY = target.y;
      final attack = combat.updateUnit(
        unit: unit,
        candidates: [target],
        now: now,
        elapsed: Duration.zero,
      );
      expect(attack?.targetId, 'enemy');
      expect(attack?.damage, unit.stats.damage);
    });

    test('does not attack friendlies or dead targets', () {
      final unit = makeArmy().units.first;
      final result = combat.updateUnit(
        unit: unit,
        candidates: [
          MonsterTarget(
            id: 'friendly', ownerId: unit.ownerId,
            kind: MonsterTargetKind.hero, x: unit.positionX,
            y: unit.positionY, isAlive: true,
          ),
          const MonsterTarget(
            id: 'dead', ownerId: 'p2',
            kind: MonsterTargetKind.hero, x: 0, y: 0, isAlive: false,
          ),
        ],
        now: DateTime.utc(2026, 2, 1),
        elapsed: Duration.zero,
      );
      expect(result, isNull);
      expect(unit.targetId, isNull);
    });

    test('attacks a crystal target but never a castle target', () {
      final unit = makeArmy().units.first;
      unit.positionX = 0;
      unit.positionY = 0;
      final result = combat.updateUnit(
        unit: unit,
        candidates: [
          const MonsterTarget(
            id: 'enemy-crystal', ownerId: 'p2',
            kind: MonsterTargetKind.crystal, x: 1, y: 0, isAlive: true,
          ),
        ],
        now: DateTime.utc(2026, 2, 1),
        elapsed: Duration.zero,
      );
      expect(result?.targetId, 'enemy-crystal');
    });

    test('respects attack cooldown', () {
      final unit = makeArmy().units.first;
      unit.positionX = 0;
      unit.positionY = 0;
      const target = MonsterTarget(
        id: 'enemy', ownerId: 'p2', kind: MonsterTargetKind.monster,
        x: 1, y: 0, isAlive: true,
      );
      final now = DateTime.utc(2026, 2, 1);
      expect(combat.updateUnit(
        unit: unit, candidates: [target], now: now, elapsed: Duration.zero,
      ), isNotNull);
      expect(combat.updateUnit(
        unit: unit, candidates: [target],
        now: now.add(const Duration(milliseconds: 799)),
        elapsed: Duration.zero,
      ), isNull);
    });
  });

  group('Monster targeting', () {
    const targeting = MonsterTargeting();
    final targets = [
      const MonsterTarget(
        id: 'friendly', ownerId: 'p1', kind: MonsterTargetKind.hero,
        x: 1, y: 0, isAlive: true,
      ),
      const MonsterTarget(
        id: 'enemy-far', ownerId: 'p2', kind: MonsterTargetKind.hero,
        x: 20, y: 0, isAlive: true,
      ),
      const MonsterTarget(
        id: 'enemy-near', ownerId: 'p3', kind: MonsterTargetKind.monster,
        x: 4, y: 0, isAlive: true,
      ),
      const MonsterTarget(
        id: 'dead', ownerId: 'p4', kind: MonsterTargetKind.hero,
        x: 0.5, y: 0, isAlive: false,
      ),
    ];

    test('selects nearest living enemy and ignores friendly/dead units', () {
      expect(targeting.nearestEnemy(
        ownerId: 'p1', fromX: 0, fromY: 0, candidates: targets,
      )?.id, 'enemy-near');
    });

    test('respects maximum target distance', () {
      expect(targeting.nearestEnemy(
        ownerId: 'p1', fromX: 0, fromY: 0,
        candidates: targets, maxDistance: 2,
      ), isNull);
    });

    test('defensive target is nearest living owned crystal', () {
      final target = targeting.defensiveTarget(
        ownerId: 'p1', fromX: 0, fromY: 0,
        candidates: [
          const MonsterTarget(
            id: 'far', ownerId: 'p1', kind: MonsterTargetKind.crystal,
            x: 10, y: 0, isAlive: true,
          ),
          const MonsterTarget(
            id: 'near', ownerId: 'p1', kind: MonsterTargetKind.crystal,
            x: 3, y: 0, isAlive: true,
          ),
          const MonsterTarget(
            id: 'enemy', ownerId: 'p2', kind: MonsterTargetKind.crystal,
            x: 1, y: 0, isAlive: true,
          ),
        ],
      );
      expect(target?.id, 'near');
    });
  });
}


  group('Monster combat damage resolver', () {
    const resolver = MonsterCombatResolver();
    const intent = MonsterCombatIntent(
      monsterId: 'attacker',
      targetId: 'target',
      damage: 25,
    );

    test('applies intent to a fresh enemy target adapter', () {
      final target = _FakeDamageTarget(
        id: 'target', ownerId: 'p2',
        kind: MonsterTargetKind.hero, health: 60,
      );
      expect(resolver.resolve(
        intent: intent, attackerOwnerId: 'p1', target: target,
      ), MonsterDamageResult.applied);
      expect(target.health, 35);
    });

    test('rejects friendly, dead, missing and mismatched targets', () {
      _FakeDamageTarget target(String owner, double health) =>
          _FakeDamageTarget(
            id: 'target', ownerId: owner,
            kind: MonsterTargetKind.crystal, health: health,
          );

      expect(resolver.resolve(
        intent: intent, attackerOwnerId: 'p2',
        target: target('p2', 50),
      ), MonsterDamageResult.friendlyTarget);
      expect(resolver.resolve(
        intent: intent, attackerOwnerId: 'p1',
        target: target('p2', 0),
      ), MonsterDamageResult.deadTarget);
      expect(resolver.resolve(
        intent: intent, attackerOwnerId: 'p1', target: null,
      ), MonsterDamageResult.missingTarget);
      expect(resolver.resolve(
        intent: intent, attackerOwnerId: 'p1',
        target: _FakeDamageTarget(
          id: 'wrong', ownerId: 'p2',
          kind: MonsterTargetKind.crystal, health: 50,
        ),
      ), MonsterDamageResult.missingTarget);
    });

    test('rejects malformed damage intents', () {
      final target = _FakeDamageTarget(
        id: 'target', ownerId: 'p2',
        kind: MonsterTargetKind.hero, health: 50,
      );
      expect(resolver.resolve(
        intent: const MonsterCombatIntent(
          monsterId: 'attacker', targetId: 'target', damage: double.nan,
        ),
        attackerOwnerId: 'p1', target: target,
      ), MonsterDamageResult.invalidIntent);
      expect(target.health, 50);
    });
  });
}
