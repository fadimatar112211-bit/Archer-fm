import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_animation.dart';
import 'package:archer_fm/monsters/monster_army.dart';
import 'package:archer_fm/monsters/monster_battle_layer.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_projectiles.dart';
import 'package:archer_fm/monsters/monster_sprite_view.dart';

MonsterCatalog _catalog() => MonsterCatalog({
      for (final type in MonsterType.values)
        type: MonsterDefinition(
          type: type,
          baseStats: const MonsterStats(
            maxHealth: 100,
            damage: 12,
            moveSpeed: 10,
            attackRange: 20,
            attackCooldown: Duration(seconds: 1),
            purchaseCost: 10,
          ),
        ),
    });

MonsterUnit _unit({
  required String idPrefix,
  required MonsterType type,
  double x = 10,
  double y = 10,
}) {
  final counts = {for (final value in MonsterType.values) value: 0};
  counts[type] = 20;
  final army = MonsterArmy(
    ownerId: 'p1',
    idPrefix: idPrefix,
    catalog: _catalog(),
    selection: InitialArmySelection(counts),
    castleX: x - 34,
    castleY: y,
  );
  final unit = army.units.first;
  unit.positionX = x;
  unit.positionY = y;
  return unit;
}

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 320, height: 240, child: child),
    );

void main() {
  group('Monster battle layer', () {
    testWidgets('renders live monsters and active projectile positions',
        (tester) async {
      final runner = _unit(idPrefix: 'runner', type: MonsterType.runner);
      final ranged = _unit(
        idPrefix: 'ranged',
        type: MonsterType.ranged,
        x: 40,
        y: 30,
      );
      final projectile = MonsterProjectile(
        id: 'bolt-1',
        source: ranged,
        targetId: 'enemy',
        projectileSpeed: 10,
        positionX: 55,
        positionY: 35,
      );

      await tester.pumpWidget(_host(MonsterBattleLayer(
        units: [runner, ranged],
        projectiles: [projectile],
        worldToScreen: (x, y) => Offset(x + 50, y + 50),
        simulationTick: 1,
        attackingUnitIds: {runner.id},
      )));

      expect(find.byType(MonsterSpriteView), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('monster-layer-projectile-bolt-1')),
        findsOneWidget,
      );
      final sprites = tester.widgetList<MonsterSpriteView>(
        find.byType(MonsterSpriteView),
      );
      expect(sprites.any((sprite) => sprite.attacking), isTrue);
      expect(sprites.every((sprite) => sprite.healthFraction == 1), isTrue);
      final runnerSprite = sprites.firstWhere(
        (sprite) => sprite.animation.type == MonsterType.runner,
      );
      expect(runnerSprite.animation.state, MonsterAnimationState.attack);

      await tester.pumpWidget(_host(MonsterBattleLayer(
        units: [runner, ranged],
        projectiles: [projectile],
        worldToScreen: (x, y) => Offset(x + 50, y + 50),
        simulationTick: 2,
      )));
      expect(runnerSprite.animation.state, MonsterAnimationState.attack);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(_host(MonsterBattleLayer(
        units: [runner, ranged],
        projectiles: [projectile],
        worldToScreen: (x, y) => Offset(x + 50, y + 50),
        simulationTick: 3,
      )));
      expect(runnerSprite.animation.state, MonsterAnimationState.idle);
    });

    testWidgets('detects movement only when the simulation tick advances',
        (tester) async {
      final runner = _unit(idPrefix: 'moving', type: MonsterType.runner);
      Widget layer(int tick) => _host(MonsterBattleLayer(
            units: [runner],
            projectiles: const <MonsterProjectile>[],
            worldToScreen: (x, y) => Offset(x, y),
            simulationTick: tick,
          ));

      await tester.pumpWidget(layer(1));
      var sprite = tester.widget<MonsterSpriteView>(
        find.byType(MonsterSpriteView),
      );
      expect(sprite.moving, isFalse);

      runner.positionX += 12;
      await tester.pumpWidget(layer(2));
      sprite = tester.widget<MonsterSpriteView>(
        find.byType(MonsterSpriteView),
      );
      expect(sprite.moving, isTrue);

      await tester.pumpWidget(layer(2));
      sprite = tester.widget<MonsterSpriteView>(
        find.byType(MonsterSpriteView),
      );
      expect(sprite.moving, isTrue);

      await tester.pumpWidget(layer(3));
      sprite = tester.widget<MonsterSpriteView>(
        find.byType(MonsterSpriteView),
      );
      expect(sprite.moving, isFalse);
    });

    testWidgets('dead monsters remain rendered for their death animation',
        (tester) async {
      final runner = _unit(idPrefix: 'dead', type: MonsterType.runner);
      runner.applyDamage(100);

      await tester.pumpWidget(_host(MonsterBattleLayer(
        units: [runner],
        projectiles: const <MonsterProjectile>[],
        worldToScreen: (x, y) => Offset(x, y),
        simulationTick: 1,
      )));

      final sprite = tester.widget<MonsterSpriteView>(
        find.byType(MonsterSpriteView),
      );
      expect(sprite.alive, isFalse);
    });
  });
}
