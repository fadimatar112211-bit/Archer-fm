import 'package:flutter_test/flutter_test.dart';
import 'package:archero_fm/monsters/monster_army.dart';
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

void main() {
  group('Monster army', () {
    test('creates exactly twenty units from the selected composition', () {
      final army = MonsterArmy(
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

      expect(army.units, hasLength(20));
      expect(army.aliveCount, 20);
      expect(army.countOf(MonsterType.runner), 8);
      expect(army.countOf(MonsterType.ranged), 3);
      expect(army.units.every((unit) => unit.ownerId == 'p1'), isTrue);
    });

    test('rejects a starting army that is not exactly twenty', () {
      expect(
        () => InitialArmySelection({MonsterType.runner: 19}),
        throwsArgumentError,
      );
    });

    test('purchase checks funds and creates a unit', () {
      final army = MonsterArmy(
        ownerId: 'p1',
        catalog: catalog(),
        selection: InitialArmySelection({
          MonsterType.runner: 20,
        }),
        castleX: 0,
        castleY: 0,
      );

      expect(
        army.purchase(type: MonsterType.tank, currentResources: 10),
        isFalse,
      );
      expect(army.units, hasLength(20));
      expect(
        army.purchase(type: MonsterType.tank, currentResources: 11),
        isTrue,
      );
      expect(army.units, hasLength(21));
      expect(army.countOf(MonsterType.tank), 1);
    });

    test('dead units are removed permanently and not respawned', () {
      final army = MonsterArmy(
        ownerId: 'p1',
        catalog: catalog(),
        selection: InitialArmySelection({MonsterType.runner: 20}),
        castleX: 0,
        castleY: 0,
      );
      final unit = army.units.first;
      expect(unit.applyDamage(100), isTrue);
      expect(army.removeDefeated(unit.id), isTrue);
      expect(army.units, hasLength(19));
      expect(army.removeDefeated(unit.id), isFalse);
    });

    test('damage rejects negative and non-finite values', () {
      final unit = MonsterUnit(
        id: 'm1',
        ownerId: 'p1',
        type: MonsterType.tank,
        positionX: 0,
        positionY: 0,
        stats: catalog()[MonsterType.tank].baseStats,
      );
      expect(() => unit.applyDamage(-1), throwsArgumentError);
      expect(() => unit.applyDamage(double.nan), throwsArgumentError);
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
      final target = targeting.nearestEnemy(
        ownerId: 'p1',
        fromX: 0,
        fromY: 0,
        candidates: targets,
      );
      expect(target?.id, 'enemy-near');
    });

    test('respects maximum target distance', () {
      final target = targeting.nearestEnemy(
        ownerId: 'p1',
        fromX: 0,
        fromY: 0,
        candidates: targets,
        maxDistance: 2,
      );
      expect(target, isNull);
    });

    test('defensive target is the nearest owned crystal', () {
      final target = targeting.defensiveTarget(
        ownerId: 'p1',
        fromX: 0,
        fromY: 0,
        candidates: [
          const MonsterTarget(
            id: 'own-crystal-far', ownerId: 'p1',
            kind: MonsterTargetKind.crystal, x: 10, y: 0, isAlive: true,
          ),
          const MonsterTarget(
            id: 'own-crystal-near', ownerId: 'p1',
            kind: MonsterTargetKind.crystal, x: 3, y: 0, isAlive: true,
          ),
          const MonsterTarget(
            id: 'enemy-crystal', ownerId: 'p2',
            kind: MonsterTargetKind.crystal, x: 1, y: 0, isAlive: true,
          ),
        ],
      );
      expect(target?.id, 'own-crystal-near');
    });
  });
}
