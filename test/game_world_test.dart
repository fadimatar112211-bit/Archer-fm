import 'dart:math' as math;

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a deterministic world and fills the spawn budget so wave spawns
/// never disturb the focused scenario.
GameWorld makeWorld({int seed = 7}) {
  final world = GameWorld(
    kit: rangerNewKit,
    random: math.Random(seed),
    spawnWaves: false,
  );
  world.enemies.clear();
  world.projectiles.clear();
  return world;
}

EnemyState addEnemy(
  GameWorld world, {
  String kind = 'slime',
  Offset? position,
  double hp = 40,
  double xp = 10,
  bool ranged = false,
}) {
  final enemy = EnemyState(
    id: 'test_${world.enemies.length}',
    kind: kind,
    position: position ?? world.player.position + const Offset(150, 0),
    maxHp: hp,
    speed: 0,
    contactDamage: 8,
    xpValue: xp.round(),
    ranged: ranged,
  );
  world.enemies.add(enemy);
  return enemy;
}

void runFor(GameWorld world, int ms, {int releaseEveryMs = 0}) {
  var sinceRelease = 0;
  for (var t = 0; t < ms; t += 16) {
    world.update(16);
    sinceRelease += 16;
    if (releaseEveryMs > 0 && sinceRelease >= releaseEveryMs) {
      sinceRelease = 0;
      world.releaseArrow();
    }
  }
}

void main() {
  group('attack → projectile → damage', () {
    test('a normal hit deals exactly 100% base damage', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      final enemy = addEnemy(world); // 40 hp, 150 px to the east
      expect(world.requestAttack(), isTrue);
      world.releaseArrow();
      expect(world.projectiles.length, 1);
      runFor(world, 800);
      expect(enemy.hp, 40 - rangerNewKit.baseDamage);
    });

    test('combo hits escalate the real damage 100→110→120→135→155%', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      // One tanky target to absorb the whole chain.
      final enemy = addEnemy(world, hp: 200, xp: 40);
      final base = rangerNewKit.baseDamage;
      final expected = [
        1.00,
        1.10,
        1.20,
        1.35,
        1.55,
      ].map((m) => base * m);
      var applied = 0.0;
      var clock = 0;
      for (var hit = 0; hit < 5; hit++) {
        expect(world.requestAttack(), isTrue);
        world.releaseArrow();
        // Advance far enough for the arrow to land and the cycle to pass.
        while (clock < (hit + 1) * 1100) {
          world.update(16);
          clock += 16;
        }
        applied = 200 - enemy.hp;
      }
      expect(applied, closeTo(expected.reduce((a, b) => a + b), 0.01));
    });

    test('a projectile damages an enemy at most once', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, position: world.player.position + const Offset(100, 0));
      addEnemy(world, position: world.player.position + const Offset(104, 0), hp: 40);
      // Piercing shot passes through both but counts each once.
      world.pendingAbilityId = 'piercing_shot';
      world.releaseWeaponPayload(volley: false);
      expect(world.projectiles.single.pierceLeft, 99);
      runFor(world, 1200);
      final damaged = world.enemies
          .where((e) => e.hp < e.maxHp)
          .length;
      final totalLoss = world.enemies
          .fold(0.0, (sum, e) => sum + (e.maxHp - e.hp));
      expect(damaged, 2);
      expect(totalLoss, closeTo(rangerNewKit.baseDamage * 2.2 * 2, 0.01));
    });

    test('combo window expiry restarts at 100%', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, hp: 500, xp: 40);
      final base = rangerNewKit.baseDamage;
      world.requestAttack();
      world.releaseArrow();
      runFor(world, 1100);
      // 1.10x
      world.requestAttack();
      world.releaseArrow();
      runFor(world, 1100);
      final afterSecond = world.totalDamageDealt;
      expect(afterSecond, closeTo(base * (1.00 + 1.10), 0.01));
      // Long idle past the 1800 ms window.
      runFor(world, 2600);
      world.requestAttack();
      world.releaseArrow();
      runFor(world, 1100);
      expect(
        world.totalDamageDealt,
        closeTo(base * (1.00 + 1.10 + 1.00), 0.01),
      );
    });
  });

  group('abilities', () {
    test('locked ability is rejected until the hero level unlocks it', () {
      final world = makeWorld();
      expect(world.level, 1);
      expect(world.useAbility('multi_shot'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      // Above level 1: locked.
      world.player.energy = rangerNewKit.baseMaxEnergy;
      expect(world.useAbility('piercing_shot'), isNull);
      world.level = 10;
      world.player.energy = rangerNewKit.baseMaxEnergy;
      expect(world.useAbility('piercing_shot'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      world.player.energy = rangerNewKit.baseMaxEnergy;
      expect(world.useAbility('arrow_rain'), isNull); // 20
      world.level = 20;
      world.player.energy = rangerNewKit.baseMaxEnergy;
      expect(world.useAbility('arrow_rain'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      world.level = 30;
      world.player.energy = rangerNewKit.baseMaxEnergy;
      expect(world.useAbility('gale_surge'), isNotNull);
      world.releaseWeaponPayload(volley: true);
    });

    test('multi_shot fires five arrows, each at 60% damage', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, hp: 500, xp: 40);
      expect(world.useAbility('multi_shot'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.projectiles.length, 5);
      expect(world.projectiles.first.damage,
          closeTo(rangerNewKit.baseDamage * 0.6, 0.01));
    });

    test('arrow_rain ticks AoE damage inside its radius only', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      final inside = addEnemy(world, hp: 100, xp: 40);
      final outside = addEnemy(
        world,
        position: world.player.position + const Offset(400, 0),
        hp: 100,
        xp: 40,
      );
      world.level = 20;
      expect(world.useAbility('arrow_rain'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.zones.length, 1);
      // 8 ticks × 250 ms.
      runFor(world, 2200);
      final insideLoss = 100 - inside.hp;
      expect(insideLoss, closeTo(rangerNewKit.baseDamage * 0.35 * 8, 0.01));
      expect(outside.hp, 100);
    });

    test('gale_surge buffs damage and attack pace for 6 seconds', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, hp: 900, xp: 60);
      final cycleBefore = (world.attackCycleMs / world.currentAttackRate()).round();
      world.level = 30;
      expect(world.useAbility('gale_surge'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.currentDamageMult(), 1.2);
      expect(
        (world.attackCycleMs / world.currentAttackRate()).round(),
        lessThan(cycleBefore),
      );
      runFor(world, 6100);
      expect(world.currentDamageMult(), 1.0);
    });

    test('ability cooldown blocks immediate reuse', () {
      final world = makeWorld();
      expect(world.useAbility('multi_shot'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.useAbility('multi_shot'), isNull);
      runFor(world, 6100);
      expect(world.useAbility('multi_shot'), isNotNull);
    });

    test('ability costs energy and normal attacks refill some', () {
      final world = makeWorld();
      world.player.energy = 30;
      world.requestAttack();
      world.releaseArrow();
      expect(world.player.energy, greaterThan(30));
      world.player.energy = 100;
      expect(world.useAbility('multi_shot'), isNotNull);
      expect(world.player.energy, 100 - 25);
    });
  });

  group('progression', () {
    test('kills grant xp and level-ups emit events with ability unlocks', () {
      final world = makeWorld();
      // 2 slimes + 2 archers = 48 xp → level 1 needs 75… engineer levels:
      world.level = 9;
      world.xp = 0;
      final enemy = addEnemy(world, hp: 1, xp: 500);
      world.spawnArrow(
        origin: enemy.position - const Offset(60, 0),
        direction: const Offset(1, 0),
        damage: 5,
        speed: 500,
        range: 90,
        tint: 0xFF62E86C,
      );
      runFor(world, 400);
      expect(enemy.hp, lessThanOrEqualTo(0));
      final events = world.drainEvents();
      expect(
        events.whereType<LevelUpEvent>().isNotEmpty,
        isTrue,
      );
      expect(world.level, greaterThan(9));
      final leveled = events.whereType<LevelUpEvent>().first;
      expect(leveled.unlockedAbilityIds, contains('piercing_shot'));
    });

    test('level cap 40 stops xp accumulation', () {
      final world = makeWorld();
      world.level = 40;
      final enemy = addEnemy(world, hp: 1, xp: 1000);
      world.spawnArrow(
        origin: enemy.position - const Offset(60, 0),
        direction: const Offset(1, 0),
        damage: 5,
        speed: 500,
        range: 90,
        tint: 0xFF62E86C,
      );
      runFor(world, 400);
      expect(world.level, 40);
    });
  });

  group('danger and recovery', () {
    test('player dies, respawns and keeps progress', () {
      final world = makeWorld();
      world.player.hp = 5;
      world.player.invulnerableUntilMs = 0;
      world.player.position = const Offset(480, 300);
      final brute = addEnemy(
        world,
        kind: 'brute',
        position: world.player.position + const Offset(30, 0),
        hp: 999,
        xp: 25,
      );
      brute.windupUntilMs = world.nowMs + 10;
      world.kills = 7;
      runFor(world, 500);
      expect(world.player.dead, isTrue);
      final diedEvents = world.drainEvents().whereType<PlayerDiedEvent>();
      expect(diedEvents, isNotEmpty);
      runFor(world, 3000);
      expect(world.player.dead, isFalse);
      expect(world.player.hp, rangerNewKit.baseMaxHp);
      expect(world.kills, 7);
      expect(
        world.drainEvents().whereType<PlayerRespawnedEvent>(),
        isNotEmpty,
      );
    });

    test('dodge grants invulnerability against enemy arrows', () {
      final world = makeWorld();
      world.player.invulnerableUntilMs = 0;
      world.player.position = const Offset(480, 300);
      final archer = addEnemy(
        world,
        kind: 'archer',
        position: world.player.position + const Offset(200, 0),
        hp: 999,
        xp: 14,
        ranged: true,
      );
      archer.attackCooldownUntilMs = world.nowMs + 10000;
      expect(world.requestDodge(), isTrue);
      expect(world.player.invulnerableUntilMs, greaterThan(world.nowMs));
      // Enemy arrow lands during the i-frames.
      world.spawnArrow(
        origin: archer.position,
        direction: const Offset(-1, 0),
        damage: 6,
        speed: 800,
        range: 300,
        tint: 0xFFFF7A5A,
      );
      runFor(world, 700);
      expect(world.player.hp, rangerNewKit.baseMaxHp);
    });

    test('dodge resets the combo chain', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, hp: 500, xp: 40);
      world.requestAttack();
      world.releaseArrow();
      runFor(world, 1100);
      world.requestAttack();
      world.releaseArrow();
      runFor(world, 1100);
      expect(world.combo.chainLength, 2);
      expect(world.requestDodge(), isTrue);
      expect(world.combo.chainLength, 0);
      expect(world.combo.hitIndex, 1);
    });
  });

  group('movement and facing', () {
    test('octant mapping matches the rendered sprite directions', () {
      expect(GameWorld.octantNames[GameWorld.octantIndexOf(const Offset(0, 1))], 's');
      expect(GameWorld.octantNames[GameWorld.octantIndexOf(const Offset(1, 0))], 'e');
      expect(GameWorld.octantNames[GameWorld.octantIndexOf(const Offset(0, -1))], 'n');
      expect(GameWorld.octantNames[GameWorld.octantIndexOf(const Offset(-1, 0))], 'w');
      expect(
        GameWorld.octantNames[
            GameWorld.octantIndexOf(const Offset(0.7071, 0.7071))],
        'se',
      );
      expect(
        GameWorld.octantNames[
            GameWorld.octantIndexOf(const Offset(-0.7071, -0.7071))],
        'nw',
      );
    });

    test('joystick input moves the player and clamps to the arena', () {
      final world = makeWorld();
      world.player.position = const Offset(480, 400);
      world.setMoveInput(const Offset(0, 1));
      runFor(world, 1000);
      expect(world.player.position.dy, greaterThan(400));
      expect(world.player.position.dy, lessThanOrEqualTo(540 - 28));
    });

    test('auto-aim turns the hero toward the nearest enemy', () {
      final world = makeWorld();
      world.player.position = const Offset(480, 300);
      world.player.facing = const Offset(0, 1);
      addEnemy(world, position: const Offset(700, 300));
      expect(world.requestAttack(), isTrue);
      expect(world.player.facing.dx, greaterThan(0.9));
      expect(world.player.facing.dy, lessThan(0.1));
    });
  });

  group('waves', () {
    test('waves keep spawning over time within the alive cap', () {
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(11),
      );
      // Let the initial wave schedule (1.5 s) elapse several times.
      runFor(world, 20000);
      expect(world.enemies, isNotEmpty);
      expect(world.enemies.length, lessThanOrEqualTo(world.maxAliveEnemies));
    });
  });
}
