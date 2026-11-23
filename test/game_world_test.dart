import 'dart:math' as math;

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/progress/match_xp.dart';
import 'package:archer_fm/game/progress/xp.dart';
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

/// Deterministic Flame world (melee kit, no wave spawns).
GameWorld makeFlameWorld({int seed = 7}) {
  final world = GameWorld(
    kit: flameKit,
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
  group('sprite direction mapping', () {
    test('all eight screen-space facings map to their matching atlas row', () {
      const cases = <({Offset facing, String name})>[
        (facing: Offset(1, 0), name: 'e'),
        (facing: Offset(0.7071, 0.7071), name: 'se'),
        (facing: Offset(0, 1), name: 's'),
        (facing: Offset(-0.7071, 0.7071), name: 'sw'),
        (facing: Offset(-1, 0), name: 'w'),
        (facing: Offset(-0.7071, -0.7071), name: 'nw'),
        (facing: Offset(0, -1), name: 'n'),
        (facing: Offset(0.7071, -0.7071), name: 'ne'),
      ];
      for (final testCase in cases) {
        final index = GameWorld.octantIndexOf(testCase.facing);
        expect(GameWorld.octantNames[index], testCase.name);
      }
    });

    test('zero facing safely preserves the default south-facing sprite', () {
      expect(GameWorld.octantNames[GameWorld.octantIndexOf(Offset.zero)], 's');
    });
  });

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
      world.attachXpLedger(
        MatchXpLedger(matchId: 'gw_levelup', heroId: 'ranger_new'),
        savedTotalXp: heroTotalXpToLevel(9) + heroXpRequired(9) - 2,
      );
      world.drainEvents(); // drop level-up events emitted while restoring state
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
      expect(events.whereType<EnemyKilledEvent>().single.killedBy,
          DamageOrigin.hero);
      final levelUps = events.whereType<LevelUpEvent>().toList();
      expect(levelUps, isNotEmpty);
      expect(world.level, greaterThanOrEqualTo(10));
      expect(
        levelUps.any((event) => event.unlockedAbilityIds.contains('piercing_shot')),
        isTrue,
      );
    });

    test('level cap 40 stops xp accumulation', () {
      final world = makeWorld();
      world.attachXpLedger(
        MatchXpLedger(matchId: 'gw_cap', heroId: 'ranger_new'),
        savedTotalXp: heroTotalXpToLevel(heroMaxLevel),
      );
      world.drainEvents();
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
      expect(world.level, heroMaxLevel);
      expect(world.heroXp.totalXp, heroTotalXpToLevel(heroMaxLevel));
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
      final resourcesBeforeDeath = world.resources;
      runFor(world, 500);
      expect(world.player.dead, isTrue);
      final diedEvents = world.drainEvents().whereType<PlayerDiedEvent>();
      expect(diedEvents, isNotEmpty);
      // Spec §3:50: 10-second respawn and a 20% match-resource loss.
      expect(
        diedEvents.first.lostResources,
        (resourcesBeforeDeath * 0.20).round(),
      );
      expect(world.resources, resourcesBeforeDeath - diedEvents.first.lostResources);
      runFor(world, 10200);
      expect(world.player.dead, isFalse);
      expect(world.player.hp, rangerNewKit.baseMaxHp);
      expect(world.kills, 7);
      expect(
        world.drainEvents().whereType<PlayerRespawnedEvent>(),
        isNotEmpty,
      );
    });

    test('hell_burst stun cancels a started enemy swing', () {
      final world = makeFlameWorld();
      world.level = 20;
      world.player.invulnerableUntilMs = 0;
      final attacker = addEnemy(
        world,
        position: world.player.position + const Offset(50, 0),
        hp: 500,
        xp: 20,
      );
      attacker.windupUntilMs = world.nowMs + 50;
      expect(world.useAbility('hell_burst'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(attacker.stunnedUntilMs, greaterThan(world.nowMs));
      expect(attacker.disabledAt(world.nowMs), isTrue);
      // Starting a swing before the blast must not land during the stun.
      expect(attacker.windupUntilMs, 0);
      runFor(world, 300);
      expect(world.player.hp, world.maxHp);
    });

    test('stunned monsters stop moving until the disable expires', () {
      final world = makeFlameWorld();
      world.level = 20;
      final origin = world.player.position;
      final stunned = addEnemy(
        world,
        position: origin + const Offset(100, 0),
        hp: 500,
        xp: 20,
      );
      stunned.speed = 90;
      final outside = addEnemy(
        world,
        position: origin + const Offset(220, 0),
        hp: 500,
        xp: 20,
      );
      outside.speed = 0;
      expect(world.useAbility('hell_burst'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      final frozenAt = stunned.position;
      runFor(world, 400);
      expect(stunned.position, frozenAt);
      expect(outside.disabledAt(world.nowMs), isFalse);

      runFor(world, 400);
      expect(stunned.disabledAt(world.nowMs), isFalse);
      // Once it recovers, the same monster closes in again.
      expect(
        (stunned.position - origin).distance,
        lessThan((frozenAt - origin).distance),
      );
    });

    test('static_field freezes on activation and on every charged thrust', () {
      final world = GameWorld(
        kit: stormKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.facing = const Offset(1, 0);
      final primary = addEnemy(
        world,
        position: world.player.position + const Offset(100, 0),
        hp: 500,
        xp: 30,
      );
      primary.speed = 80;
      final chained = addEnemy(
        world,
        position: world.player.position + const Offset(240, 0),
        hp: 500,
        xp: 30,
      );
      world.level = 20;
      expect(world.useAbility('static_field'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(primary.frozenUntilMs, greaterThan(world.nowMs));
      expect(primary.disabledAt(world.nowMs), isTrue);
      // The chained monster is outside the field radius on activation.
      expect(chained.disabledAt(world.nowMs), isFalse);

      final holdAt = primary.position;
      runFor(world, 500);
      expect(primary.position, holdAt);
      expect(primary.disabledAt(world.nowMs), isTrue);
      runFor(world, 600);
      expect(primary.disabledAt(world.nowMs), isFalse);

      // The field is still active: a charged thrust re-freezes its victims.
      world.player.energy = stormKit.baseMaxEnergy;
      expect(world.useAbility('thunder_thrust'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      expect(primary.disabledAt(world.nowMs), isTrue);
      expect(chained.disabledAt(world.nowMs), isTrue);
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
      // The arena is a camera window into a larger generated map, so the old
      // fixed 540-unit border is replaced by the map's own border.
      expect(
        world.player.position.dy,
        lessThanOrEqualTo(world.map.size.height - 24),
      );
      expect(world.map.isBlocked(world.player.position, 24), isFalse);
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

  group('Flame melee combat', () {
    test('the swing hits enemies inside the front arc only', () {
      final world = makeFlameWorld();
      final origin = world.player.position;
      world.player.facing = const Offset(1, 0);
      final front = addEnemy(world, position: origin + const Offset(90, 0));
      final behind = addEnemy(
        world,
        position: origin - const Offset(90, 0),
        hp: 40,
        xp: 14,
      );
      final outsideArc = addEnemy(
        world,
        position: origin + const Offset(40, 120),
        hp: 40,
        xp: 14,
      );
      world.requestAttack();
      world.releaseMeleeSwing();
      expect(front.hp, 40 - flameKit.baseDamage);
      expect(behind.hp, 40);
      expect(outsideArc.hp, 40);
    });

    test('combo hits escalate the melee damage 100→110%', () {
      final world = makeFlameWorld();
      world.player.facing = const Offset(1, 0);
      final enemy = addEnemy(
        world,
        position: world.player.position + const Offset(90, 0),
        hp: 200,
        xp: 40,
      );
      world.requestAttack();
      world.releaseMeleeSwing();
      runFor(world, 1250); // attack cycle 1670/1.4 ≈ 1193 ms
      world.requestAttack();
      world.releaseMeleeSwing();
      expect(
        200 - enemy.hp,
        closeTo(flameKit.baseDamage * (1.0 + 1.1), 0.01),
      );
    });

    test('flame_slash deals 180% and applies a 3-tick burn', () {
      final world = makeFlameWorld();
      world.player.facing = const Offset(1, 0);
      final enemy = addEnemy(
        world,
        position: world.player.position + const Offset(90, 0),
        hp: 100,
        xp: 40,
      );
      expect(world.useAbility('flame_slash'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      final swing = 100 - enemy.hp;
      expect(swing, closeTo(flameKit.baseDamage * 1.8, 0.01));
      expect(enemy.burnTicksLeft, 3);
      runFor(world, 3000);
      expect(
        100 - enemy.hp,
        closeTo(flameKit.baseDamage * (1.8 + 0.25 * 3), 0.01),
      );
      expect(enemy.burnTicksLeft, 0);
    });

    test('fire_wave travels and burns every enemy in its path once', () {
      final world = makeFlameWorld();
      world.level = 10;
      world.player.facing = const Offset(1, 0);
      final ahead = addEnemy(world, hp: 100, xp: 40);
      final behind = addEnemy(
        world,
        position: world.player.position - const Offset(150, 0),
        hp: 100,
        xp: 14,
      );
      expect(world.useAbility('fire_wave'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.waves.length, 1);
      runFor(world, 2200); // wave flight + both burn ticks
      // 160% contact + 2 burn ticks of 20%.
      expect(
        100 - ahead.hp,
        closeTo(flameKit.baseDamage * (1.6 + 0.2 * 2), 0.01),
      );
      expect(behind.hp, 100);
      expect(world.waves, isEmpty); // traveled past its 320 range
    });

    test('hell_burst hits only enemies within its radius', () {
      final world = makeFlameWorld();
      world.level = 20;
      final origin = world.player.position;
      final inside = addEnemy(world, position: origin + const Offset(100, 0));
      final outside = addEnemy(
        world,
        position: origin + const Offset(220, 0),
        hp: 100,
        xp: 14,
      );
      expect(world.useAbility('hell_burst'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(
        inside.maxHp - inside.hp,
        closeTo(flameKit.baseDamage * 2.2, 0.01),
      );
      expect(outside.hp, outside.maxHp);
      expect(world.fx.where((effect) => effect.kind == 'burst'), isNotEmpty);
    });

    test('inferno_rage buffs damage, pace and reach for 6 seconds', () {
      final world = makeFlameWorld();
      world.level = 30;
      final rateBefore = world.currentAttackRate();
      final rangeBefore = world.currentMeleeRange();
      expect(world.useAbility('inferno_rage'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.currentDamageMult(), flameKit.buffDamageMult);
      expect(world.currentAttackRate(), rateBefore * flameKit.buffRateMult);
      expect(world.currentMeleeRange(), closeTo(rangeBefore * 1.2, 0.01));
      runFor(world, 6100);
      expect(world.currentDamageMult(), 1.0);
      expect(world.currentMeleeRange(), closeTo(rangeBefore, 0.01));
    });

    test('ability levels gate the flame kit the same way', () {
      final world = makeFlameWorld();
      expect(world.useAbility('flame_slash'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      world.player.energy = flameKit.baseMaxEnergy;
      expect(world.useAbility('fire_wave'), isNull);
      world.level = 10;
      expect(world.useAbility('fire_wave'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      world.player.energy = flameKit.baseMaxEnergy;
      expect(world.useAbility('hell_burst'), isNull);
      world.level = 20;
      expect(world.useAbility('hell_burst'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      world.player.energy = flameKit.baseMaxEnergy;
      expect(world.useAbility('inferno_rage'), isNull);
      world.level = 30;
      expect(world.useAbility('inferno_rage'), isNotNull);
      world.releaseWeaponPayload(volley: true);
    });
  });

  group('Shadow dagger combat', () {
    test('twin_fangs strikes three times at 80% each', () {
      final world = GameWorld(
        kit: shadowKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.facing = const Offset(1, 0);
      final lone = addEnemy(
        world,
        position: world.player.position + const Offset(70, 0),
        hp: 100,
        xp: 14,
      );
      expect(world.useAbility('twin_fangs'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      // 3 × 80% on a lone target.
      expect(
        100 - lone.hp,
        closeTo(shadowKit.baseDamage * 0.8 * 3, 0.01),
      );
    });

    test('shadow_veil grants 4 seconds of immunity and a speed boost', () {
      final world = GameWorld(
        kit: shadowKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.level = 10;
      final speedBefore = world.currentMoveSpeed();
      expect(world.useAbility('shadow_veil'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.player.invulnerableUntilMs, greaterThan(world.nowMs));
      expect(world.currentMoveSpeed(), closeTo(speedBefore * 1.35, 0.01));
      // Enemy contact during the veil is fully ignored.
      final brute = addEnemy(
        world,
        kind: 'brute',
        position: world.player.position + const Offset(30, 0),
        hp: 999,
        xp: 25,
      );
      brute.windupUntilMs = world.nowMs + 10;
      runFor(world, 600);
      expect(world.player.hp, shadowKit.baseMaxHp);
      runFor(world, 3900);
      expect(world.currentMoveSpeed(), speedBefore);
    });

    test('venom_coat makes every swing poison the target', () {
      final world = GameWorld(
        kit: shadowKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.level = 20;
      world.player.facing = const Offset(1, 0);
      final enemy = addEnemy(
        world,
        position: world.player.position + const Offset(70, 0),
        hp: 100,
        xp: 40,
      );
      expect(world.useAbility('venom_coat'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.player.buffUntilMs, greaterThan(world.nowMs));
      world.requestAttack();
      world.releaseMeleeSwing();
      // Swing 100% + two poison ticks of 15%.
      runFor(world, 2000);
      expect(
        100 - enemy.hp,
        closeTo(
          shadowKit.baseDamage * (1.0 * 1.15 + 0.15 * 2 * 1.15),
          0.01,
        ),
      );
    });

    test('venom ticks catch up after a long frame even after the cloak expires', () {
      final world = GameWorld(
        kit: shadowKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.level = 20;
      world.player.facing = const Offset(1, 0);
      final enemy = addEnemy(
        world,
        position: world.player.position + const Offset(70, 0),
        hp: 100,
        xp: 40,
      );
      enemy.speed = 0;
      expect(world.useAbility('venom_coat'), isNotNull);
      world.releaseWeaponPayload(volley: true);

      // The venom is about to expire when the attack applies its two delayed
      // poison ticks. Their damage is captured at application time.
      world.update(7900);
      expect(world.player.buffUntilMs, 8000);
      expect(world.requestAttack(), isTrue);
      world.releaseMeleeSwing();
      world.update(1600);

      expect(world.nowMs, 9500);
      expect(world.player.buffUntilMs, lessThan(world.nowMs));
      expect(
        100 - enemy.hp,
        closeTo(
          shadowKit.baseDamage * (1.0 * 1.15 + 0.15 * 2 * 1.15),
          0.01,
        ),
      );
    });

    test('shadow_execute teleports to the weakest enemy and deals 300%', () {
      final world = GameWorld(
        kit: shadowKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.level = 30;
      world.player.position = const Offset(480, 300);
      final weak = addEnemy(
        world,
        position: const Offset(600, 300),
        hp: 100,
        xp: 14,
      );
      addEnemy(world, position: const Offset(640, 300), hp: 100, xp: 14);
      weak.hp = 45; // the lowest-HP target in reach
      expect(world.useAbility('shadow_execute'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      // The player is now beside the weak target, which took 300%.
      expect(
        45 - weak.hp,
        closeTo(shadowKit.baseDamage * 3.0, 0.01),
      );
      expect((weak.position - world.player.position).distance, lessThan(60));
      expect(
        world.fx.any((effect) => effect.kind == 'burst'),
        isTrue,
      );
    });

    test('ability levels gate the shadow kit the same way', () {
      final world = GameWorld(
        kit: shadowKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.energy = shadowKit.baseMaxEnergy;
      expect(world.useAbility('twin_fangs'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      world.player.energy = shadowKit.baseMaxEnergy;
      expect(world.useAbility('shadow_veil'), isNull);
      world.level = 10;
      expect(world.useAbility('shadow_veil'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      world.player.energy = shadowKit.baseMaxEnergy;
      expect(world.useAbility('venom_coat'), isNull);
      world.level = 20;
      expect(world.useAbility('venom_coat'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      world.player.energy = shadowKit.baseMaxEnergy;
      expect(world.useAbility('shadow_execute'), isNull);
      world.level = 30;
      expect(world.useAbility('shadow_execute'), isNotNull);
      world.releaseWeaponPayload(volley: true);
    });
  });

  group('Storm lightning-spear combat', () {
    test('thunder_thrust stabs 160% and chains 60% to the nearest '
        'neighbour of the target', () {
      final world = GameWorld(
        kit: stormKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.facing = const Offset(1, 0);
      final primary = addEnemy(
        world,
        position: world.player.position + const Offset(120, 0),
        hp: 100,
      );
      final chained = addEnemy(
        world,
        position: world.player.position + const Offset(220, 0),
        hp: 100,
      );
      expect(world.useAbility('thunder_thrust'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      // Primary takes 160%; the chain adds 60% of that onto the enemy
      // nearest to the primary (100 units away, inside the 200 chain range).
      expect(100 - primary.hp, closeTo(stormKit.baseDamage * 1.6, 0.01));
      expect(
        100 - chained.hp,
        closeTo(stormKit.baseDamage * 1.6 * 0.6, 0.01),
      );
    });

    test('thunder_thrust whiff still draws the spear line without damage', () {
      final world = GameWorld(
        kit: stormKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, position: world.player.position + const Offset(400, 0));
      expect(world.useAbility('thunder_thrust'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      expect(world.fx.where((f) => f.kind == 'slash').length, 1);
    });

    test('chain_lightning strikes up to 3 nearest enemies within 180 at '
        '130% each', () {
      final world = GameWorld(
        kit: stormKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      final close = [
        addEnemy(world, position: world.player.position + const Offset(80, 0)),
        addEnemy(world, position: world.player.position + const Offset(120, 0)),
        addEnemy(world, position: world.player.position + const Offset(160, 0)),
        // Outside the 180 strike radius.
        addEnemy(world, position: world.player.position + const Offset(400, 0)),
      ];
      world.level = 10;
      expect(world.useAbility('chain_lightning'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      for (var i = 0; i < 3; i++) {
        // Each close enemy takes exactly one 130% strike.
        expect(
          close[i].hp,
          closeTo(close[i].maxHp - stormKit.baseDamage * 1.3, 0.01),
        );
      }
      // The far enemy is untouched.
      expect(close[3].hp, close[3].maxHp);
      // One jagged bolt fx per struck enemy.
      expect(world.fx.where((f) => f.kind == 'bolt').length, 3);
    });

    test('static_field buffs 8 s and every swing releases a 40% charge', () {
      final world = GameWorld(
        kit: stormKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.facing = const Offset(1, 0);
      final target = addEnemy(
        world,
        position: world.player.position + const Offset(120, 0),
        hp: 100,
      );
      world.level = 20;
      expect(world.useAbility('static_field'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.player.buffUntilMs, greaterThan(world.nowMs + 7000));
      // Swing while charged: 100% × buff mult 1.2 + a second 40% × 1.2.
      world.releaseMeleeSwing();
      expect(
        100 - target.hp,
        closeTo(
          stormKit.baseDamage * (1.0 + 0.4) * stormKit.buffDamageMult,
          0.01,
        ),
      );
    });

    test('tempest_rage boosts damage 1.2x and stretches the spear 1.25x', () {
      final world = GameWorld(
        kit: stormKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      expect(world.currentMeleeRange(), closeTo(stormKit.meleeRange, 0.01));
      expect(world.currentDamageMult(), 1.0);
      world.level = 30;
      expect(world.useAbility('tempest_rage'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(
        world.currentMeleeRange(),
        closeTo(stormKit.meleeRange * 1.25, 0.01),
      );
      expect(world.currentDamageMult(), stormKit.buffDamageMult);
    });

    test('ability levels gate the storm kit the same way', () {
      final world = GameWorld(
        kit: stormKit,
        random: math.Random(3),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.energy = stormKit.baseMaxEnergy;
      expect(world.useAbility('thunder_thrust'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      world.player.energy = stormKit.baseMaxEnergy;
      expect(world.useAbility('chain_lightning'), isNull);
      world.level = 10;
      expect(world.useAbility('chain_lightning'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      world.player.energy = stormKit.baseMaxEnergy;
      expect(world.useAbility('static_field'), isNull);
      world.level = 20;
      expect(world.useAbility('static_field'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      world.player.energy = stormKit.baseMaxEnergy;
      expect(world.useAbility('tempest_rage'), isNull);
      world.level = 30;
      expect(world.useAbility('tempest_rage'), isNotNull);
      world.releaseWeaponPayload(volley: true);
    });
  });

  group('special abilities stay independent of the five-hit combo', () {
    test('ranger: an ability between combo hits neither advances nor '
        'resets the chain', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, hp: 400, xp: 40);
      // Combo hit 1 registers (100%).
      expect(world.requestAttack(), isTrue);
      expect(world.combo.hitIndex, 2);
      world.releaseArrow();
      // A special ability in between: accepted, chain untouched.
      expect(world.useAbility('multi_shot'), isNotNull);
      expect(world.combo.hitIndex, 2);
      expect(world.combo.chainLength, 1);
      world.releaseWeaponPayload(volley: true);
      // Wait out the attack cycle, then the next normal attack resumes at
      // hit 2 (110%), not an advanced 120% nor a reset 100%.
      runFor(world, 1100);
      expect(world.requestAttack(), isTrue);
      expect(world.pendingHitMultiplier, closeTo(1.10, 0.001));
      // Cleanup the volley so it cannot disturb later assertions.
      world.projectiles.clear();
    });

    test('ranger: while an ability is pending the normal attack is refused '
        'and the combo does not advance', () {
      final world = makeWorld();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, hp: 400, xp: 40);
      expect(world.requestAttack(), isTrue);
      world.releaseArrow();
      world.level = 10; // piercing_shot unlocks at 10
      expect(world.useAbility('piercing_shot'), isNotNull);
      expect(world.pendingAbilityId, 'piercing_shot');
      final chainLength = world.combo.chainLength;
      expect(world.requestAttack(), isFalse);
      expect(world.combo.chainLength, chainLength);
      world.releaseWeaponPayload(volley: false);
      expect(world.pendingAbilityId, isNull);
      // After the ability the attack cycle still governs the next press.
      runFor(world, 1100);
      expect(world.requestAttack(), isTrue);
    });

    test('flame: an ability between melee combo hits keeps the chain '
        'position', () {
      final world = GameWorld(
        kit: flameKit,
        random: math.Random(7),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.facing = const Offset(1, 0);
      addEnemy(world, hp: 400, xp: 40);
      expect(world.requestAttack(), isTrue);
      expect(world.combo.hitIndex, 2);
      world.releaseMeleeSwing();
      expect(world.useAbility('flame_slash'), isNotNull);
      expect(world.combo.hitIndex, 2);
      world.releaseWeaponPayload(volley: false);
      runFor(world, 1400);
      expect(world.requestAttack(), isTrue);
      expect(world.pendingHitMultiplier, closeTo(1.10, 0.001));
    });

    test('storm + shadow: abilities never consume combo presses and the '
        'five-hit chain still escalates to 155%', () {
      final world = GameWorld(
        kit: stormKit,
        random: math.Random(7),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.player.facing = const Offset(1, 0);
      // Inside the spear's 125 px reach so the swings really land.
      final enemy = addEnemy(
        world,
        position: world.player.position + const Offset(100, 0),
        hp: 300,
        xp: 40,
      );
      // Hit 1, ability, then hits 2..5 in sequence: the fifth press must
      // still register as hit 5 with the 155% multiplier.
      expect(world.requestAttack(), isTrue);
      world.releaseMeleeSwing();
      expect(world.useAbility('thunder_thrust'), isNotNull);
      world.releaseWeaponPayload(volley: false);
      expect(world.combo.hitIndex, 2);
      runFor(world, 1400);
      for (var hit = 2; hit <= 5; hit++) {
        expect(world.requestAttack(), isTrue);
        world.releaseMeleeSwing();
        runFor(world, 1700);
      }
      expect(enemy.hp, lessThan(enemy.maxHp));
      // Five presses registered: the chain sits on hit 5 (155%) and the next
      // in-window press would wrap back to hit 1.
      expect(world.combo.chainLength, 5);
      expect(world.combo.hitIndex, 5);
      expect(world.pendingHitMultiplier, closeTo(1.55, 0.001));
      // Shadow kit mirrors the same independence.
      final shadow = GameWorld(
        kit: shadowKit,
        random: math.Random(7),
        spawnWaves: false,
      );
      shadow.enemies.clear();
      expect(shadow.requestAttack(), isTrue);
      shadow.releaseMeleeSwing();
      expect(shadow.useAbility('twin_fangs'), isNotNull);
      expect(shadow.combo.hitIndex, 2);
      shadow.releaseWeaponPayload(volley: false);
      runFor(shadow, 1400);
      expect(shadow.requestAttack(), isTrue);
      expect(shadow.pendingHitMultiplier, closeTo(1.10, 0.001));
    });
  });

  group('ability energy and cooldown work for every hero', () {
    for (final kit in [rangerNewKit, flameKit, shadowKit, stormKit]) {
      final ability = kit.abilities.first; // the level-1 special
      final label = '${kit.heroId} ${ability.id}';
      test(
        '$label costs energy and its cooldown blocks immediate reuse',
        () {
          final world = GameWorld(
            kit: kit,
            random: math.Random(7),
            spawnWaves: false,
          );
          world.enemies.clear();
          world.player.energy = kit.baseMaxEnergy.toDouble();
          expect(world.useAbility(ability.id), isNotNull);
          expect(world.player.energy, kit.baseMaxEnergy - ability.energyCost);
          // Release the queued payload like the weapon-event frame does.
          world.releaseWeaponPayload(volley: !ability.usesAttackClip);
          // Inside the cooldown: rejected.
          expect(world.useAbility(ability.id), isNull);
          // Regen never jumps the cooldown.
          for (var t = 0; t < ability.cooldownMs - 100; t += 16) {
            world.update(16);
          }
          expect(world.useAbility(ability.id), isNull);
          // Once the cooldown elapses (and energy refills), it is accepted.
          for (var t = 0; t < 400; t += 16) {
            world.update(16);
          }
          world.player.energy = kit.baseMaxEnergy.toDouble();
          expect(world.useAbility(ability.id), isNotNull);
        },
      );
    }
  });
}
