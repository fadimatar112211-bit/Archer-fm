import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_spatial_index.dart';

MonsterUnit _unit(
  String id, {
  String ownerId = 'p1',
  double x = 0,
  double y = 0,
}) =>
    MonsterUnit(
      id: id,
      ownerId: ownerId,
      type: MonsterType.runner,
      positionX: x,
      positionY: y,
      stats: const MonsterStats(
        maxHealth: 100,
        damage: 10,
        moveSpeed: 10,
        attackRange: 20,
        attackCooldown: Duration(seconds: 1),
        purchaseCost: 10,
      ),
    );

void main() {
  group('MonsterSpatialIndex', () {
    test('returns nearby living allies but excludes enemies and source', () {
      final source = _unit('source');
      final ally = _unit('ally', x: 12, y: 0);
      final enemy = _unit('enemy', ownerId: 'p2', x: 5, y: 0);
      final distant = _unit('distant', x: 500, y: 500);
      final index = MonsterSpatialIndex(
        units: [source, ally, enemy, distant],
        cellSize: 48,
      );

      expect(
        index.nearbyUnits(source, radius: 24).map((unit) => unit.id),
        ['ally'],
      );
      expect(index.unitCount, 4);
    });

    test('updates buckets after movement and removes dead units', () {
      final source = _unit('source');
      final ally = _unit('ally', x: 10, y: 0);
      final index = MonsterSpatialIndex(
        units: [source, ally],
        cellSize: 48,
      );
      expect(index.nearbyUnits(source, radius: 20), hasLength(1));

      ally.positionX = 300;
      ally.positionY = 300;
      index.update(ally);
      expect(index.nearbyUnits(source, radius: 20), isEmpty);

      ally.applyDamage(100);
      index.update(ally);
      expect(index.unitCount, 1);
    });

    test('rejects invalid geometry and duplicate identities', () {
      final unit = _unit('same');
      expect(
        () => MonsterSpatialIndex(units: [unit], cellSize: 0),
        throwsArgumentError,
      );
      expect(
        () => MonsterSpatialIndex(units: [unit, _unit('same', x: 2)], cellSize: 48),
        throwsArgumentError,
      );
    });
  });
}
