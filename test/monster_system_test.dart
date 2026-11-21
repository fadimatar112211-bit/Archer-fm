import 'dart:math' as math;

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/progress/progression.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld makeMonsterWorld({
  int seed = 3,
  Map<MonsterType, int>? army,
  int resources = 500,
  int essence = 0,
}) {
  final world = GameWorld(
    kit: rangerNewKit,
    random: math.Random(seed),
    spawnWaves: false,
    startingArmy: army ?? MonsterCatalog.defaultStartingArmy,
  );
  world.enemies.clear();
  world.projectiles.clear();
  world.resources = resources;
  world.essence = essence;
  return world;
}

void runFor(GameWorld world, int ms) {
  for (var t = 0; t < ms; t += 16) {
    world.update(16);
  }
}

EnemyState addEnemy(
  GameWorld world, {
  MonsterType type = MonsterType.runner,
  required Offset position,
  double hp = 500,
}) {
  final stats = MonsterStats.of(type, 1);
  final enemy = EnemyState(
    id: 'enemy_test_${world.enemies.length}',
    kind: type.name,
    type: type,
    position: position,
    maxHp: hp,
    speed: 0,
    contactDamage: stats.damage,
    xpValue: stats.xpValue,
  );
  world.enemies.add(enemy);
  return enemy;
}

void main() {
  group('monster catalog', () {
    test('ships exactly the four approved legacy types', () {
      expect(MonsterType.values.length, 4);
      final names = MonsterCatalog.all.map((def) => def.nameAr).toSet();
      expect(names.length, 4);
      for (final def in MonsterCatalog.all) {
        expect(def.baseHp, greaterThan(0));
        expect(def.baseSpeed, greaterThan(0));
        expect(def.baseDamage, greaterThan(0));
        expect(def.price, greaterThan(0));
        expect(def.radius, greaterThan(0));
      }
    });

    test('reference palette keeps the four monster silhouettes distinct', () {
      expect(MonsterCatalog.def(MonsterType.runner).color, 0xFF4D9848);
      expect(MonsterCatalog.def(MonsterType.tank).color, 0xFF596474);
      expect(MonsterCatalog.def(MonsterType.stalker).color, 0xFFE5D9BD);
      expect(MonsterCatalog.def(MonsterType.ranged).color, 0xFF57358F);
      expect(MonsterCatalog.def(MonsterType.runner).accent, 0xFFC5E99B);
      expect(MonsterCatalog.def(MonsterType.ranged).accent, 0xFFBE83FF);
      // The purple blade silhouette must not change the existing ranged role.
      expect(MonsterStats.of(MonsterType.ranged, 1).attackRange, 210);
      expect(MonsterCatalog.def(MonsterType.ranged).isRanged, isTrue);
    });

    test('the roles stay distinct: runner fastest, tank toughest', () {
      final runner = MonsterStats.of(MonsterType.runner, 1);
      final tank = MonsterStats.of(MonsterType.tank, 1);
      final ranged = MonsterStats.of(MonsterType.ranged, 1);
      for (final type in MonsterType.values) {
        final stats = MonsterStats.of(type, 1);
        if (type != MonsterType.runner) {
          expect(stats.speed, lessThan(runner.speed));
        }
        if (type != MonsterType.tank) {
          expect(stats.maxHp, lessThan(tank.maxHp));
        }
      }
      expect(ranged.attackRange, greaterThan(tank.attackRange));
      expect(MonsterCatalog.def(MonsterType.ranged).isRanged, isTrue);
    });

    test('levels scale HP, damage and speed up to level 40', () {
      for (final type in MonsterType.values) {
        final first = MonsterStats.of(type, 1);
        final top = MonsterStats.of(type, monsterMaxLevel);
        expect(top.maxHp, greaterThan(first.maxHp * 3));
        expect(top.damage, greaterThan(first.damage * 2.5));
        expect(top.speed, greaterThan(first.speed));
        expect(MonsterStats.of(type, 500).level, monsterMaxLevel);
      }
    });

    test('upgrades stop at 40 and get more expensive', () {
      final upgrades = MonsterUpgrades();
      expect(upgrades.levelOf(MonsterType.runner), 1);
      final cost1 = upgrades.upgradeCost(MonsterType.runner);
      expect(upgrades.canUpgrade(MonsterType.runner, cost1 - 1), isFalse);
      expect(upgrades.canUpgrade(MonsterType.runner, cost1), isTrue);

      var essence = 1000000;
      while (upgrades.levelOf(MonsterType.runner) < 40) {
        final cost = upgrades.upgradeCost(MonsterType.runner);
        expect(cost, greaterThanOrEqualTo(cost1));
        final before = upgrades.levelOf(MonsterType.runner);
        expect(
          upgrades.upgrade(MonsterType.runner, essence: essence),
          greaterThan(before),
        );
        essence -= cost;
      }
      expect(upgrades.levelOf(MonsterType.runner), 40);
      expect(upgrades.upgradeCost(MonsterType.runner), 0);
      expect(upgrades.upgrade(MonsterType.runner, essence: essence), 40);
      expect(upgrades.canUpgrade(MonsterType.runner, 999999), isFalse);
    });

    test('the default starting army is free, balanced and exactly 20', () {
      expect(
        MonsterCatalog.defaultStartingArmy.values
            .fold<int>(0, (sum, value) => sum + value),
        GameWorld.startingArmySize,
      );
      for (final type in MonsterType.values) {
        expect(MonsterCatalog.defaultStartingArmy[type], greaterThan(0));
      }
    });
  });

  group('monster compatibility and lifecycle edges', () {
    test('legacy names map only to the four approved production types', () {
      expect(monsterTypeFromName('slime'), MonsterType.runner);
      expect(monsterTypeFromName('runner'), MonsterType.runner);
      expect(monsterTypeFromName('brute'), MonsterType.tank);
      expect(monsterTypeFromName('tank'), MonsterType.tank);
      expect(monsterTypeFromName('stalker'), MonsterType.stalker);
      expect(monsterTypeFromName('archer'), MonsterType.ranged);
      expect(monsterTypeFromName('ranged'), MonsterType.ranged);
      expect(monsterTypeFromName('unrecognized'), MonsterType.runner);
      expect(MonsterType.values, hasLength(4));
    });

    test('level inputs clamp safely at both ends for every monster type', () {
      for (final type in MonsterType.values) {
        expect(MonsterStats.of(type, -20).level, 1);
        expect(MonsterStats.of(type, 0).level, 1);
        expect(MonsterStats.of(type, 999).level, monsterMaxLevel);
      }
    });

    test('formation offsets are finite and separate successive slots', () {
      for (var total = 1; total <= GameWorld.startingArmySize; total++) {
        final offsets = [
          for (var slot = 0; slot < total; slot++)
            armyFormationOffset(slot, total),
        ];
        for (final offset in offsets) {
          expect(offset.dx.isFinite, isTrue);
          expect(offset.dy.isFinite, isTrue);
        }
        for (var i = 0; i < offsets.length; i++) {
          for (var j = i + 1; j < offsets.length; j++) {
            expect((offsets[i] - offsets[j]).distance, greaterThan(0.1));
          }
        }
      }
    });

    test('corpse animation has bounded progress and a fixed death state', () {
      final corpse = MonsterCorpse(
        type: MonsterType.stalker,
        team: MonsterTeam.enemy,
        position: const Offset(200, 300),
        facing: const Offset(1, 0),
        bornAtMs: 1000,
      );
      expect(corpse.stateAt(1000), MonsterAnimState.death);
      expect(corpse.progressAt(900), 0);
      expect(corpse.progressAt(1000), 0);
      expect(corpse.progressAt(1350), closeTo(0.5, 1e-9));
      expect(corpse.progressAt(1700), 1);
      expect(corpse.progressAt(3000), 1);
    });
  });

  group('army roster', () {
    test('a match starts with the full 20-monster free army', () {
      final world = makeMonsterWorld();
      expect(world.army.length, GameWorld.startingArmySize);
      for (final type in MonsterType.values) {
        final count = world.army.where((m) => m.type == type).length;
        expect(count, MonsterCatalog.defaultStartingArmy[type]);
      }
      for (final monster in world.army) {
        expect(monster.team, MonsterTeam.player);
        expect(monster.hp, monster.maxHp);
        expect((monster.position - world.player.position).distance,
            lessThan(260));
      }
    });

    test('buying a monster spends resources and spawns it beside the castle', () {
      final world = makeMonsterWorld(resources: 500);
      final before = world.army.length;
      final price = MonsterCatalog.def(MonsterType.tank).price;
      expect(world.buyMonster(MonsterType.tank), isTrue);
      expect(world.army.length, before + 1);
      expect(world.resources, 500 - price);
      final bought = world.army.last;
      expect(bought.type, MonsterType.tank);
      // Spec §3:60: reinforcements spawn beside the owner's castle.
      expect((bought.position - world.castleSystem.playerCastle.anchor).distance,
          lessThan(320));
    });

    test('purchase is refused without resources and at the army cap', () {
      final world = makeMonsterWorld(resources: 0);
      expect(world.canBuyMonster(MonsterType.runner), isFalse);
      expect(world.buyMonster(MonsterType.runner), isFalse);
      expect(world.army.length, GameWorld.startingArmySize);

      final rich = makeMonsterWorld(resources: 100000);
      for (var i = 0; i < 30; i++) {
        rich.buyMonster(MonsterType.runner);
      }
      expect(rich.army.length, GameWorld.maxArmySize);
      expect(rich.buyMonster(MonsterType.runner), isFalse);
    });

    test('dead army monsters are permanently lost, not respawned', () {
      final world = makeMonsterWorld();
      final ally = world.army.first;
      world.spawnArrow(
        origin: ally.position - const Offset(30, 0),
        direction: const Offset(1, 0),
        damage: 9999,
        speed: 600,
        range: 120,
        tint: 0xFFFF7A5A,
        hostile: true,
      );
      runFor(world, 200);
      expect(world.army.length, GameWorld.startingArmySize - 1);
      expect(world.army.contains(ally), isFalse);
      expect(
        world.drainEvents().whereType<ArmyMonsterLostEvent>(),
        isNotEmpty,
      );
      expect(world.corpses, isNotEmpty);
      runFor(world, 900);
      expect(world.army.length, GameWorld.startingArmySize - 1);
      expect(world.corpses, isEmpty);
    });

    test('a hostile arrow is spent on the first army monster it hits', () {
      final world = makeMonsterWorld();
      world.army.clear();
      final front = EnemyState(
        id: 'front',
        kind: 'tank',
        type: MonsterType.tank,
        team: MonsterTeam.player,
        position: const Offset(480, 300),
        maxHp: 300,
        speed: 0,
        contactDamage: 10,
        xpValue: 0,
      );
      final back = EnemyState(
        id: 'back',
        kind: 'tank',
        type: MonsterType.tank,
        team: MonsterTeam.player,
        position: const Offset(512, 300),
        maxHp: 300,
        speed: 0,
        contactDamage: 10,
        xpValue: 0,
      );
      world.army.addAll([front, back]);
      world.spawnArrow(
        origin: const Offset(420, 300),
        direction: const Offset(1, 0),
        damage: 12,
        speed: 300,
        range: 200,
        tint: 0xFFFF7A5A,
        hostile: true,
      );
      runFor(world, 400);
      expect(front.hp, lessThan(front.maxHp));
      expect(back.hp, back.maxHp);
      expect(world.projectiles.where((p) => p.hostile), isEmpty);
    });

    test('upgraded types keep their level when purchased', () {
      final world = makeMonsterWorld(essence: 100000);
      // Every upgrade category needs its own material, not currency alone.
      expect(world.upgradeMonster(MonsterType.tank), isFalse);
      world.materials[ProgressionMaterial.monster] = 1;
      expect(world.upgradeMonster(MonsterType.tank), isTrue);
      expect(world.upgrades.levelOf(MonsterType.tank), 2);
      expect(world.materials[ProgressionMaterial.monster], 0);
      expect(world.essence, lessThan(100000));
      expect(world.buyMonster(MonsterType.tank), isTrue);
      final bought = world.army.last;
      expect(bought.level, 2);
      expect(bought.maxHp,
          greaterThan(MonsterStats.of(MonsterType.tank, 1).maxHp));
    });
  });

  group('monster behaviour and animation', () {
    test('the army walks with an advancing gait cycle', () {
      final world = makeMonsterWorld();
      // Pull the hero so the formation has to re-group, forcing movement.
      world.player.position = const Offset(140, 460);
      runFor(world, 300);
      final moving = world.army.where((m) => m.walkPhase > 0).toList();
      expect(moving, isNotEmpty);
      expect(
        moving.any((m) => m.animStateAt(world.nowMs) == MonsterAnimState.walk),
        isTrue,
      );
    });

    test('idle monsters stay on the idle animation', () {
      final world = makeMonsterWorld();
      // Let the formation settle first.
      runFor(world, 2500);
      final idle = world.army.first;
      idle.walkPhase = 0;
      idle.moving = false;
      expect(idle.animStateAt(world.nowMs), MonsterAnimState.idle);
    });

    test('packs separate instead of stacking on one point', () {
      final world = makeMonsterWorld(
        army: {MonsterType.runner: 20},
      );
      runFor(world, 1500);
      for (var i = 0; i < world.army.length; i++) {
        for (var j = i + 1; j < world.army.length; j++) {
          final a = world.army[i];
          final b = world.army[j];
          expect((a.position - b.position).distance,
              greaterThan(a.radius + b.radius - 2));
        }
      }
    });

    test('the army attacks the nearest hostile monster', () {
      final world = makeMonsterWorld();
      // Place one runner right next to a stationary hostile.
      final enemy = addEnemy(
        world,
        type: MonsterType.tank,
        position: const Offset(480, 220),
        hp: 600,
      );
      final ally = world.army.first;
      ally.position = const Offset(480, 250);
      runFor(world, 2500);
      expect(enemy.hp, lessThan(enemy.maxHp));
    });

    test('ranged army monsters fire friendly projectiles', () {
      final world = makeMonsterWorld();
      addEnemy(
        world,
        type: MonsterType.tank,
        position: const Offset(480, 180),
        hp: 900,
      );
      final archer =
          world.army.firstWhere((m) => m.type == MonsterType.ranged);
      archer.position = const Offset(480, 300);
      archer.attackCooldownUntilMs = 0;
      runFor(world, 200);
      expect(world.projectiles.where((p) => !p.hostile), isNotEmpty);
    });

    test('hostile monsters target the army before the distant hero', () {
      final world = makeMonsterWorld(
        army: {MonsterType.tank: 1},
      );
      world.player.position = const Offset(100, 120);
      final ally = world.army.first;
      ally.position = const Offset(700, 360);
      final enemy = addEnemy(
        world,
        type: MonsterType.runner,
        position: const Offset(720, 360),
        hp: 500,
      );
      enemy.speed = 0;
      runFor(world, 1200);
      expect(ally.hp, lessThan(ally.maxHp));
      expect(world.player.hp, rangerNewKit.baseMaxHp);
    });

    test('a runner closes distance in dashing bursts', () {
      final world = makeMonsterWorld();
      // A single stationary allied target, so the dash distance is exact.
      world.army
        ..clear()
        ..add(
          EnemyState(
            id: 'dash_target',
            kind: 'tank',
            type: MonsterType.tank,
            team: MonsterTeam.player,
            position: const Offset(480, 420),
            maxHp: 500,
            speed: 0,
            contactDamage: 0,
            xpValue: 0,
          ),
        );
      world.player.position = const Offset(480, 480);
      final enemy = addEnemy(
        world,
        type: MonsterType.runner,
        position: const Offset(480, 140),
        hp: 500,
      );
      enemy.speed = 138;
      enemy.nextDashAtMs = 0;
      final start = enemy.position;
      runFor(world, 1000);
      expect(enemy.dashUntilMs, greaterThan(0));
      expect((enemy.position - start).distance, greaterThan(110));
      expect(enemy.walkPhase, greaterThan(0));
    });

    test('waves only spawn the four approved types', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(9),
        startingArmy: const <MonsterType, int>{},
      );
      runFor(world, 12000);
      expect(world.enemies, isNotEmpty);
      for (final enemy in world.enemies) {
        expect(MonsterType.values.contains(enemy.type), isTrue);
        expect(enemy.team, MonsterTeam.enemy);
        expect(enemy.level, greaterThanOrEqualTo(1));
      }
      expect(world.enemies.length, lessThanOrEqualTo(world.maxAliveEnemies));
    });

    test('army kills reward XP, resources and essence', () {
      final world = makeMonsterWorld();
      world.resources = 0;
      world.essence = 0;
      final enemy = addEnemy(
        world,
        type: MonsterType.runner,
        position: const Offset(480, 260),
        hp: 1,
      );
      world.army.first.position = const Offset(480, 280);
      runFor(world, 800);
      expect(enemy.hp, lessThanOrEqualTo(0));
      expect(world.resources, greaterThan(0));
      // Earnings are pending until the match is settled; a loss keeps them.
      expect(world.essence, 0);
      expect(world.pendingEssence, greaterThan(0));
      expect(world.pendingMaterials[ProgressionMaterial.monster],
          greaterThan(0));
      world.settleMatch();
      expect(world.essence, greaterThan(0));
      expect(world.materials[ProgressionMaterial.monster], greaterThan(0));
      expect(world.drainEvents().whereType<EnemyKilledEvent>(), isNotEmpty);
    });
  });
}
