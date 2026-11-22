import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monster progression and army balance', () {
    test('all archetypes scale monotonically and stop at level 40', () {
      for (final type in MonsterType.values) {
        final level1 = MonsterStats.of(type, 1);
        final level20 = MonsterStats.of(type, 20);
        final level40 = MonsterStats.of(type, 40);
        final overCap = MonsterStats.of(type, 99);
        expect(level20.maxHp, greaterThan(level1.maxHp));
        expect(level20.damage, greaterThan(level1.damage));
        expect(level20.speed, greaterThan(level1.speed));
        expect(level40.level, 40);
        expect(overCap.level, 40);
        expect(overCap.maxHp, level40.maxHp);
        expect(overCap.damage, level40.damage);
        expect(overCap.speed, level40.speed);
      }
    });

    test('starting army is exactly twenty with every role represented', () {
      final army = MonsterCatalog.defaultStartingArmy;
      expect(army.values.fold<int>(0, (sum, count) => sum + count), 20);
      expect(army.keys.toSet(), MonsterType.values.toSet());
      expect(army.values.every((count) => count > 0), isTrue);
    });

    test('upgrade costs rise, unaffordable upgrades do not mutate levels', () {
      final upgrades = MonsterUpgrades();
      for (final type in MonsterType.values) {
        expect(upgrades.levelOf(type), 1);
        expect(upgrades.upgradeCost(type), 20);
        expect(upgrades.canUpgrade(type, 19), isFalse);
        expect(upgrades.upgrade(type, essence: 19), 1);
        expect(upgrades.levelOf(type), 1);
        expect(upgrades.upgrade(type, essence: 20), 2);
        expect(upgrades.levelOf(type), 2);
        expect(upgrades.upgradeCost(type), 32);
      }
    });

    test('saved upgrade levels are clamped and restored independently', () {
      final upgrades = MonsterUpgrades({
        MonsterType.runner: 7,
        MonsterType.tank: 40,
      });
      final serialized = upgrades.toMap();
      final restored = MonsterUpgrades();
      restored.loadFromMap(serialized);
      expect(restored.levelOf(MonsterType.runner), 7);
      expect(restored.levelOf(MonsterType.tank), 40);
      expect(restored.levelOf(MonsterType.stalker), 1);
      restored.loadFromMap({'runner': 99, 'tank': 0});
      expect(restored.levelOf(MonsterType.runner), 40);
      expect(restored.levelOf(MonsterType.tank), 0.clamp(1, 40));
    });

    test('formation positions stay finite and do not stack on one point', () {
      for (final total in [1, 4, 8, 12, 20, 32]) {
        final positions = [
          for (var slot = 0; slot < total; slot++)
            armyFormationOffset(slot, total),
        ];
        expect(positions.toSet(), hasLength(total), reason: 'total=$total');
        for (final point in positions) {
          expect(point.dx.isFinite && point.dy.isFinite, isTrue);
          expect(point.distance, greaterThan(0));
        }
      }
    });
  });
}
