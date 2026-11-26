import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/network/match_combat_authority.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_progression.dart';
import 'package:archer_fm/game/match/match_rules.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/world/castle_system.dart';
import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/websocket_game_host.dart';


MatchCombatConfiguration _combatConfiguration({
  int p1RunnerLevel = 1,
  double weaponUpgradeDamagePerLevel = 0,
}) {
  final catalog = MonsterCatalog({
    for (final type in MonsterType.values)
      type: MonsterDefinition(
        type: type,
        baseStats: const MonsterStats(
          maxHealth: 1000,
          damage: 5,
          moveSpeed: 12,
          attackRange: 10,
          attackCooldown: Duration(milliseconds: 500),
          purchaseCost: 10,
        ),
      ),
  });
  final progression = MonsterProgression(
    catalog: catalog,
    growth: {
      for (final type in MonsterType.values)
        type: const MonsterUpgradeGrowth(
          healthPerLevel: 0.1,
          damagePerLevel: 0.05,
          speedPerLevel: 0.02,
        ),
    },
    costForLevel: (_, level) => level * 10,
    levels: {MonsterType.runner: p1RunnerLevel},
  );
  return MatchCombatConfiguration(
    monsterCatalog: catalog,
    projectileSpeed: 120,
    maxActiveProjectiles: 128,
    maxUnitsPerArmy: 100,
    worldUnitsPerSecond: 100,
    comboResetWindowMs: 1200,
    maxHeroEnergy: 100,
    energyRegenerationPerSecond: 1,
    ultimateEnergyCosts: {
      for (final hero in archerFmHeroes)
        for (final ultimate in hero.ultimates) ultimate.id: 20,
    },
    weaponUpgradeDamagePerLevel: weaponUpgradeDamagePerLevel,
    monsterKillScore: 5,
    monsterKillResources: 3,
    heroKillScore: 15,
    heroKillResources: 10,
    monsterProgressionByPlayer: p1RunnerLevel == 1
        ? const {}
        : {'p1': progression},
  );
}

AuthoritativeMatchSession _combatReadySession({
  int p1RunnerLevel = 1,
  int Function(String playerId, String heroId)? heroLevelForPlayer,
}) {
  final session = AuthoritativeMatchSession(
    code: 'combat1',
    mapFactory: () => ArenaMap.generate(Random(123)),
    combatConfiguration: _combatConfiguration(p1RunnerLevel: p1RunnerLevel),
    heroLevelForPlayer: heroLevelForPlayer,
  );
  final players = [for (var i = 0; i < 4; i++) session.join()!];
  for (var i = 0; i < players.length; i++) {
    final hero = archerFmHeroes[i];
    expect(
      session.handle(players[i], {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': hero.weapons.first.id,
      }),
      isNull,
    );
    expect(
      session.handle(players[i], {
        'type': 'army_select',
        'counts': {'runner': 20},
      }),
      isNull,
    );
  }
  expect(session.handle(players.first, {'type': 'start'}), isNull);
  return session;
}

void main() {
  test('snapshot publishes deterministic static arena geometry for clients', () {
    final session = _combatReadySession();
    final world = session.snapshot()['world'] as Map;

    expect(world['size'], isA<Map>());
    expect(world['biomes'], isA<List>());
    expect(world['rivers'], isA<List>());
    expect(world['obstacles'], isA<List>());
    expect(world['mapPickups'], isA<List>());
    expect(world['playerPositions'], isA<Map>());
    expect(world['castles'], hasLength(4));

    final castles = (world['castles'] as List).cast<Map>();
    for (final castle in castles) {
      expect(castle['walls'], isA<List>());
      expect(castle['crystals'], hasLength(7));
      for (final wall in (castle['walls'] as List).cast<Map>()) {
        expect(wall['radius'], isA<num>());
        expect(wall['startAngle'], isA<num>());
        expect(wall['sweep'], isA<num>());
      }
    }

    final rivers = (world['rivers'] as List).cast<Map>();
    for (final river in rivers) {
      expect(river['points'], isA<List>());
      expect(river['bridges'], isA<List>());
    }
  });


  test('player-scoped snapshots hide distant enemy units before network send', () {
    final session = _combatReadySession();
    final player = session.players.first;
    final full = session.snapshot();
    final scoped = session.snapshotFor(player);
    final fullWorld = full['world'] as Map;
    final scopedCombat = scoped['combat'] as Map;
    final allCombat = full['combat'] as Map;
    final origin = (fullWorld['playerPositions'] as Map)[player.id] as Map;
    final originX = (origin['x'] as num).toDouble();
    final originY = (origin['y'] as num).toDouble();
    final allMonsters = (allCombat['monsters'] as List).cast<Map>();
    final scopedMonsters = (scopedCombat['monsters'] as List).cast<Map>();

    final distantEnemyIds = allMonsters
        .where((monster) {
          if (monster['ownerId'] == player.id) return false;
          final dx = (monster['x'] as num).toDouble() - originX;
          final dy = (monster['y'] as num).toDouble() - originY;
          return dx * dx + dy * dy > enemyVisibleRadius * enemyVisibleRadius;
        })
        .map((monster) => monster['id'])
        .toSet();
    expect(distantEnemyIds, isNotEmpty);

    final scopedIds = scopedMonsters.map((monster) => monster['id']).toSet();
    expect(scopedIds.intersection(distantEnemyIds), isEmpty);
    for (final monster in scopedMonsters) {
      if (monster['ownerId'] == player.id) continue;
      final dx = (monster['x'] as num).toDouble() - originX;
      final dy = (monster['y'] as num).toDouble() - originY;
      expect(dx * dx + dy * dy,
          lessThanOrEqualTo(enemyVisibleRadius * enemyVisibleRadius));
    }
  });

  test('configured factory creates combat-enabled WebSocket room sessions', () {
    final factory = AuthoritativeMatchSession.configuredFactory(
      combatConfiguration: _combatConfiguration(),
      mapFactory: () => ArenaMap.generate(Random(777)),
    );
    final session = factory('configured1', {'durationMinutes': 10})
        as AuthoritativeMatchSession;
    final players = [for (var i = 0; i < 4; i++) session.join()!];
    for (var i = 0; i < players.length; i++) {
      final hero = archerFmHeroes[i];
      expect(
        session.handle(players[i], {
          'type': 'select',
          'heroId': hero.id.name,
          'weaponId': hero.weapons.first.id,
        }),
        isNull,
      );
      expect(
        session.handle(players[i], {
          'type': 'army_select',
          'counts': {'runner': 20},
        }),
        isNull,
      );
    }
    expect(session.handle(players.first, {'type': 'start'}), isNull);
    expect(session.combat, isNotNull);
    expect(session.combat!.armies, hasLength(4));
    expect(session.rules!.duration.minutes, 10);
  });

  test('loaded permanent monster progression scales only its owner army', () {
    final session = _combatReadySession(p1RunnerLevel: 3);
    final p1Army = session.combat!.armies.firstWhere((army) => army.ownerId == 'p1');
    final p2Army = session.combat!.armies.firstWhere((army) => army.ownerId == 'p2');

    expect(p1Army.units.first.stats.maxHealth, 1200);
    expect(p1Army.units.first.stats.damage, closeTo(5.5, 1e-9));
    expect(p2Army.units.first.stats.maxHealth, 1000);
    expect(
      session.combat!.configuration.monsterProgressionByPlayer['p1']!.levelOf(
        MonsterType.runner,
      ),
      3,
    );
  });

  test('loads trusted permanent hero levels and resets combo on damage interruption', () {
    final session = AuthoritativeMatchSession(
      code: 'levels1',
      mapFactory: () => ArenaMap.generate(Random(765)),
      combatConfiguration: _combatConfiguration(),
      heroLevelForPlayer: (playerId, heroId) => switch (playerId) {
        'p1' => 10,
        'p2' => 20,
        'p3' => 30,
        _ => 1,
      },
    );
    final players = [for (var i = 0; i < 4; i++) session.join()!];
    for (var i = 0; i < players.length; i++) {
      final hero = archerFmHeroes[i];
      expect(session.handle(players[i], {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': hero.weapons.first.id,
      }), isNull);
      expect(session.handle(players[i], {
        'type': 'army_select',
        'counts': {'runner': 20},
      }), isNull);
    }
    expect(session.handle(players.first, {'type': 'start'}), isNull);

    final p1 = session.combat!.heroes['p1']!;
    final p2 = session.combat!.heroes['p2']!;
    final p3 = session.combat!.heroes['p3']!;
    expect(p1.level, 10);
    expect(p1.maxHealth, 762);
    expect(p2.level, 20);
    expect(p3.level, 30);
    expect(p1.combat.useUltimate(1).accepted, isTrue);
    expect(p1.combat.useUltimate(2).accepted, isFalse);
    p1.combat.energy = 0;
    expect(p1.combat.useUltimate(0).accepted, isFalse);
    expect(p1.combat.ultimateCooldowns[0], 0);

    final enemy = session.combat!.armies
        .firstWhere((army) => army.ownerId == 'p2')
        .units.first;
    final p1Position = session.world!.playerPositions['p1']!;
    enemy.positionX = p1Position.dx;
    enemy.positionY = p1Position.dy;
    expect(session.handle(players.first, {
      'type': 'attack',
      'targetId': enemy.id,
    }), isNull);
    expect(p1.combat.comboIndex, 1);
    p1.applyDamage(1);
    expect(p1.combat.comboIndex, 0);
  });

  test('selected weapon upgrades are loaded only from trusted server context', () {
    final session = AuthoritativeMatchSession(
      code: 'weapon-upgrades',
      mapFactory: () => ArenaMap.generate(Random(901)),
      combatConfiguration: _combatConfiguration(
        weaponUpgradeDamagePerLevel: 0.05,
      ),
      weaponUpgradeLevelForPlayer: (playerId, weaponId) =>
          playerId == 'p1' ? 2 : 0,
    );
    final players = [for (var i = 0; i < 4; i++) session.join()!];
    for (var i = 0; i < players.length; i++) {
      final hero = archerFmHeroes.first;
      expect(session.handle(players[i], {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': hero.weapons.first.id,
        // Untrusted extra fields are ignored by the server.
        'weaponUpgradeLevel': 40,
      }), isNull);
      expect(session.handle(players[i], {
        'type': 'army_select',
        'counts': {'runner': 20},
      }), isNull);
    }
    expect(session.handle(players.first, {'type': 'start'}), isNull);

    final upgraded = session.combat!.heroes['p1']!.combat;
    final baseline = session.combat!.heroes['p2']!.combat;
    expect(upgraded.weaponUpgradeLevel, 2);
    expect(baseline.weaponUpgradeLevel, 0);
    expect(upgraded.weaponUpgradeMultiplier, closeTo(1.1, 1e-9));
    expect(
      upgraded.attack().damage,
      (baseline.attack().damage * 1.1).round(),
    );
  });

  test('a monster kill grants configured score and resources exactly once', () {
    final session = _combatReadySession();
    final enemy = session.combat!.armies
        .firstWhere((army) => army.ownerId == 'p2')
        .units.first;
    final p1Position = session.world!.playerPositions['p1']!;
    enemy.positionX = p1Position.dx;
    enemy.positionY = p1Position.dy;
    enemy.health = 1;

    expect(session.world!.resources['p1'], 0);
    expect(session.handle(session.players.first, {
      'type': 'attack',
      'targetId': enemy.id,
    }), isNull);
    expect(enemy.isAlive, isFalse);
    expect(session.world!.resources['p1'], 3);
    final firstScore = (session.snapshot()['participants'] as List)
        .cast<Map>()
        .firstWhere((item) => item['playerId'] == 'p1')['score'];
    expect(firstScore, 5);

    expect(session.handle(session.players.first, {
      'type': 'attack',
      'targetId': enemy.id,
    }), 'attack_rejected');
    expect(session.world!.resources['p1'], 3);
    final secondScore = (session.snapshot()['participants'] as List)
        .cast<Map>()
        .firstWhere((item) => item['playerId'] == 'p1')['score'];
    expect(secondScore, 5);
  });

  test('Flame basic attacks apply live burn damage over time', () {
    final session = _combatReadySession();
    final authority = session.combat!;
    final players = session.players.toList(growable: false);
    final flame = players[1];
    final target = authority.armies
        .firstWhere((army) => army.ownerId == 'p1')
        .units.first;
    final flamePosition = session.world!.playerPositions[flame.id]!;
    target.positionX = flamePosition.dx;
    target.positionY = flamePosition.dy;
    final before = target.health;

    expect(session.handle(flame, {
      'type': 'attack',
      'targetId': target.id,
    }), isNull);
    expect(target.health, before - 62);
    authority.tick(const Duration(seconds: 1));
    expect(target.health, before - 66);
  });

  test('Storm basic attacks stun an enemy hero and prevent movement temporarily', () {
    final session = _combatReadySession();
    final authority = session.combat!;
    final players = session.players.toList(growable: false);
    final storm = players[3];
    final victim = players[0];
    final stormPosition = session.world!.playerPositions[storm.id]!;
    session.world!.setPlayerPosition(
      victim.id,
      stormPosition + const Offset(1, 0),
    );
    final victimPosition = session.world!.playerPositions[victim.id]!;

    expect(session.handle(storm, {
      'type': 'attack',
      'targetId': 'hero_${victim.id}',
    }), isNull);
    expect(
      authority.moveHero(
        victim.id,
        const Offset(1, 0),
        const Duration(seconds: 1),
      ),
      victimPosition,
    );
    authority.tick(const Duration(milliseconds: 300));
    expect(
      authority.moveHero(
        victim.id,
        const Offset(1, 0),
        const Duration(milliseconds: 100),
      ),
      isNot(victimPosition),
    );
  });

  test('Shadow basic attacks apply live poison ticks and preserve kill attribution', () {
    final session = _combatReadySession();
    final authority = session.combat!;
    final shadow = session.players[2];
    final target = authority.armies
        .firstWhere((army) => army.ownerId == 'p1')
        .units.first;
    final shadowPosition = session.world!.playerPositions[shadow.id]!;
    target.positionX = shadowPosition.dx;
    target.positionY = shadowPosition.dy;
    for (final army in authority.armies) {
      for (final unit in army.units) {
        if (unit.id != target.id) {
          unit.positionX += 3000;
          unit.positionY += 3000;
        }
      }
    }
    final before = target.health;
    expect(session.handle(shadow, {
      'type': 'attack',
      'targetId': target.id,
    }), isNull);
    final afterHit = target.health;
    expect(afterHit, lessThan(before));
    authority.tick(const Duration(seconds: 1));
    expect(target.health, afterHit - 3);
  });

  test('Storm level-30 freeze Ultimate disables enemy actions until expiry', () {
    final session = _combatReadySession(
      heroLevelForPlayer: (playerId, _) => playerId == 'p4' ? 30 : 1,
    );
    final authority = session.combat!;
    final storm = session.players[3];
    final victim = session.players.first;
    final stormPosition = session.world!.playerPositions[storm.id]!;
    session.world!.setPlayerPosition(
      victim.id,
      stormPosition + const Offset(1, 0),
    );
    final victimPosition = session.world!.playerPositions[victim.id]!;

    expect(session.handle(storm, {
      'type': 'ultimate',
      'index': 2,
      'targetId': 'hero_${victim.id}',
    }), isNull);
    expect(
      authority.moveHero(
        victim.id,
        const Offset(0, 1),
        const Duration(milliseconds: 200),
      ),
      victimPosition,
    );
    authority.tick(const Duration(milliseconds: 900));
    expect(
      authority.moveHero(
        victim.id,
        const Offset(0, 1),
        const Duration(milliseconds: 100),
      ),
      isNot(victimPosition),
    );
  });

  test('integrates 20-unit armies, monster damage, hero combo and Ultimate', () {
    final session = _combatReadySession();
    final authority = session.combat!;
    expect(authority.armies, hasLength(4));
    expect(authority.armies.fold<int>(
      0, (sum, army) => sum + army.aliveCount,
    ), 80);

    final p1Position = session.world!.playerPositions['p1']!;
    final enemy = authority.armies
        .firstWhere((army) => army.ownerId == 'p2')
        .units.first;
    enemy.positionX = p1Position.dx;
    enemy.positionY = p1Position.dy;
    enemy.order = MonsterOrder.advance;

    session.tick(const Duration(milliseconds: 500));
    expect(enemy.targetId, 'hero_p1');
    expect(authority.monsters.lastResult!.meleeHitsApplied, greaterThan(0));
    expect(authority.heroes['p1']!.health, lessThan(600));

    final attackAck = session.handle(
      session.players.first,
      {'type': 'attack', 'targetId': enemy.id},
    );
    expect(attackAck, isNull);
    expect(enemy.health, 946);
    expect(authority.heroes['p1']!.combat.comboIndex, 1);

    final ultimateAck = session.handle(
      session.players.first,
      {'type': 'ultimate', 'index': 0, 'targetId': enemy.id},
    );
    expect(ultimateAck, isNull);
    expect(authority.heroes['p1']!.combat.comboIndex, 1);
    expect(authority.heroes['p1']!.combat.energy, 80);
    expect(enemy.health, lessThan(946));
    final heroSnapshot = (session.snapshot()['combat'] as Map)['heroes'] as Map;
    expect((heroSnapshot['p1'] as Map)['energy'], 80);
    expect((heroSnapshot['p1'] as Map)['maxEnergy'], 100);

    expect(
      session.handle(
        session.players.first,
        {'type': 'attack', 'targetId': enemy.id},
      ),
      'attack_rejected',
    );
  });

  test('connects monster AI attacks directly to canonical crystal HP', () {
    final session = _combatReadySession();
    final authority = session.combat!;
    final enemyArmy = authority.armies.firstWhere((army) => army.ownerId == 'p2');
    final enemy = enemyArmy.units.first;
    for (final unit in enemyArmy.units.skip(1).toList()) {
      unit.applyDamage(unit.health);
      enemyArmy.removeDefeated(unit.id);
    }
    final crystal = session.world!.castles.castleOf('p1')!.crystals.first;
    enemy.positionX = crystal.position.dx;
    enemy.positionY = crystal.position.dy;
    enemy.order = MonsterOrder.advance;
    final initialHp = crystal.hp;

    session.tick(const Duration(milliseconds: 500));

    expect(enemy.targetId, crystal.id);
    expect(authority.monsters.lastResult!.meleeHitsApplied, greaterThan(0));
    expect(crystal.hp, lessThan(initialHp));
    final p1Standing = (session.snapshot()['participants'] as List)
        .cast<Map>()
        .firstWhere((item) => item['playerId'] == 'p1');
    expect(p1Standing['livingCrystals'], 7);
  });


  test('hero death applies one resource penalty and respawns with protection', () {
    final session = _combatReadySession();
    final authority = session.combat!;
    final hero = authority.heroes['p1']!;
    final spawn = session.world!.playerPositions['p1']!;
    session.world!.creditResources('p1', 100);
    hero.health = 5;

    final enemyArmy = authority.armies.firstWhere((army) => army.ownerId == 'p2');
    final enemy = enemyArmy.units.first;
    enemy.positionX = spawn.dx;
    enemy.positionY = spawn.dy;
    enemy.order = MonsterOrder.advance;

    session.tick(const Duration(milliseconds: 500));
    expect(hero.isAlive, isFalse);
    expect(hero.respawnRemaining, const Duration(seconds: 10));
    expect(session.world!.resources['p1'], 80);

    session.tick(const Duration(seconds: 10));
    expect(hero.isAlive, isTrue);
    expect(hero.health, hero.maxHealth);
    expect(hero.protectionRemaining, const Duration(seconds: 5));
    expect(session.world!.playerPositions['p1'], spawn);
    expect(session.world!.resources['p1'], 80);
  });

  test('defeated heroes cannot attack, cast Ultimates or purchase units', () {
    final session = _combatReadySession();
    final authority = session.combat!;
    final hero = authority.heroes['p1']!;
    final enemy = authority.armies
        .firstWhere((army) => army.ownerId == 'p2')
        .units.first;
    hero.health = 0;
    expect(
      authority.attack('p1', enemy.id).accepted,
      isFalse,
    );
    expect(
      authority.useUltimate('p1', 0, enemy.id).accepted,
      isFalse,
    );
    expect(
      authority.purchaseMonster('p1', MonsterType.runner),
      isNull,
    );
    expect(hero.combat.comboIndex, 0);
  });

  test('server movement is speed-capped and purchases debit the match wallet', () {
    final session = _combatReadySession();
    final authority = session.combat!;
    final before = session.world!.playerPositions['p1']!;
    const directions = [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
      Offset(0.70710678118, 0.70710678118),
      Offset(-0.70710678118, 0.70710678118),
      Offset(0.70710678118, -0.70710678118),
      Offset(-0.70710678118, -0.70710678118),
    ];
    final direction = directions.firstWhere(
      (candidate) =>
          (session.world!.map.slideMove(before, candidate * 11.2, 18) - before)
                  .distance >
              0,
    );
    expect(
      session.handle(session.players.first, {
        'type': 'move',
        'dx': direction.dx,
        'dy': direction.dy,
      }),
      isNull,
    );
    session.tick(const Duration(milliseconds: 100));
    final after = session.world!.playerPositions['p1']!;
    expect((after - before).distance, lessThanOrEqualTo(11.21));
    expect((after - before).distance, greaterThan(0));

    session.world!.creditResources('p1', 100);
    final beforeCount = authority.armies.firstWhere((a) => a.ownerId == 'p1').aliveCount;
    expect(
      session.handle(
        session.players.first,
        {'type': 'purchase', 'monsterType': 'runner'},
      ),
      isNull,
    );
    expect(
      authority.armies.firstWhere((a) => a.ownerId == 'p1').aliveCount,
      beforeCount + 1,
    );
    expect(session.world!.resources['p1'], 90);
  });


  test('routes crystal rebuild requests through server-owned player identity and wallet', () {
    final session = _combatReadySession();
    final p1 = session.players.first;
    final castle = session.world!.castles.castleOf('p1')!;
    final crystal = castle.crystals.first;
    expect(
      session.damageCrystal(
        attackerId: 'p2',
        crystalId: crystal.id,
        amount: crystal.maxHp + 1,
      ).destroyedNow,
      isTrue,
    );

    final cost = session.world!.castles.rebuildCost(castle);
    Offset? validPosition;
    for (var radius = 40.0; radius <= 280 && validPosition == null; radius += 20) {
      for (var step = 0; step < 24; step++) {
        final angle = step * 2 * pi / 24;
        final candidate = castle.anchor +
            Offset(cos(angle) * radius, sin(angle) * radius);
        if (session.world!.castles.validateRebuild(
              castle,
              candidate,
              resources: cost,
            ) == CrystalRebuildResult.ok) {
          validPosition = candidate;
          break;
        }
      }
    }
    expect(validPosition, isNotNull);
    session.world!.creditResources('p1', cost);

    expect(session.handle(p1, {
      'type': 'rebuild_crystal',
      'ownerId': 'p2',
      'x': validPosition!.dx,
      'y': validPosition.dy,
    }), isNull);
    expect(session.world!.livingCrystals('p1'), 7);
    expect(session.world!.livingCrystals('p2'), 7);
    expect(session.world!.resources['p1'], 0);
    expect(
      (session.snapshot()['players'] as List)
          .cast<Map>()
          .firstWhere((player) => player['id'] == 'p1')['lastRebuild'],
      isA<Map>(),
    );

    expect(session.handle(p1, {
      'type': 'rebuild_crystal',
      'x': double.nan,
      'y': 0,
    }), 'invalid_rebuild_position');
  });

  test('requires a valid individual twenty-unit army before a configured match starts', () {
    final session = AuthoritativeMatchSession(
      code: 'army01',
      combatConfiguration: _combatConfiguration(),
      mapFactory: () => ArenaMap.generate(Random(321)),
    );
    final players = [for (var i = 0; i < 4; i++) session.join()!];
    for (var i = 0; i < players.length; i++) {
      final hero = archerFmHeroes[i];
      session.handle(players[i], {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': hero.weapons.first.id,
      });
    }
    expect(
      session.handle(players.first, {'type': 'army_select', 'counts': {'runner': 19}}),
      'invalid_army_selection',
    );
    expect(
      session.handle(players.first, {'type': 'army_select', 'counts': {'unknown': 20}}),
      'invalid_army_selection',
    );
    expect(
      session.handle(players.first, {'type': 'army_select', 'counts': {'runner': 20}}),
      isNull,
    );
    expect(session.handle(players.first, {'type': 'start'}), 'all_players_must_select_army');
    expect(session.combat, isNull);
  });

  test('enforces four-player lobby, canonical loadouts and selected duration', () {
    final session = AuthoritativeMatchSession.fromCreateMessage(
      '123456',
      {'durationMinutes': 10},
    );
    final players = [for (var i = 0; i < 4; i++) session.join()!];
    expect(session.join(), isNull);

    for (var i = 0; i < players.length; i++) {
      final hero = archerFmHeroes[i];
      expect(
        session.handle(players[i], {
          'type': 'select',
          'heroId': hero.id.name,
          'weaponId': hero.weapons.first.id,
        }),
        isNull,
      );
    }
    expect(session.handle(players.first, {'type': 'start'}), isNull);
    expect(session.rules!.phase, MatchPhase.running);
    expect(session.rules!.duration.minutes, 10);
    expect(session.snapshot()['phase'], 'running');
  });

  test('session owns the four castles and updates match tiebreaks on crystal loss', () {
    final session = AuthoritativeMatchSession(
      code: 'world01',
      mapFactory: () => ArenaMap.generate(Random(123)),
    );
    final players = [for (var i = 0; i < 4; i++) session.join()!];
    for (var i = 0; i < players.length; i++) {
      final hero = archerFmHeroes[i];
      session.handle(players[i], {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': hero.weapons.first.id,
      });
    }
    expect(session.handle(players.first, {'type': 'start'}), isNull);
    expect(session.world, isNotNull);
    expect(session.world!.castles.castles.map((castle) => castle.ownerId),
        ['p1', 'p2', 'p3', 'p4']);

    final target = session.world!.castles.castleOf('p2')!.crystals.first;
    final result = session.damageCrystal(
      attackerId: 'p1',
      crystalId: target.id,
      amount: target.maxHp + 1,
    );
    expect(result.destroyedNow, isTrue);
    final standings = session.snapshot()['participants'] as List;
    final p2 = standings.firstWhere((item) => (item as Map)['playerId'] == 'p2')
        as Map;
    expect(p2['livingCrystals'], 6);
    final worldSnapshot = session.snapshot()['world'] as Map;
    expect(worldSnapshot['livingCrystals']['p2'], 6);
    expect(worldSnapshot['castles'], hasLength(4));
    final p2Castle = (worldSnapshot['castles'] as List)
        .cast<Map>()
        .firstWhere((castle) => castle['ownerId'] == 'p2');
    expect(p2Castle['crystals'], hasLength(7));
  });

  test('rejects incomplete lobby, invalid loadout and client-side score spoofing', () {
    final session = AuthoritativeMatchSession(code: '654321');
    final first = session.join()!;
    expect(session.handle(first, {'type': 'start'}), 'need_four_players');
    expect(
      session.handle(first, {
        'type': 'select',
        'heroId': 'not_a_hero',
        'weaponId': 'fake_weapon',
      }),
      'invalid_loadout',
    );
    expect(session.handle(first, {'type': 'awardScore', 'points': 999999}),
        'unsupported_command');
  });

  test('score and crystal changes are accepted only through trusted methods', () {
    final session = AuthoritativeMatchSession(code: '111111');
    final players = [for (var i = 0; i < 4; i++) session.join()!];
    for (var i = 0; i < players.length; i++) {
      final hero = archerFmHeroes[i];
      session.handle(players[i], {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': hero.weapons.first.id,
      });
    }
    session.handle(players.first, {'type': 'start'});

    expect(session.awardScore(players.first.id, 25).accepted, isTrue);
    expect(session.updateLivingCrystals(players.first.id, 6).accepted, isTrue);
    final participants = session.snapshot()['participants'] as List;
    final firstState = participants.first as Map;
    expect(firstState['score'], 25);
    expect(firstState['livingCrystals'], 6);
  });

  test('blocks locked weapons unless trusted progression validates ownership', () {
    final hero = archerFmHeroes.first;
    final lockedWeapon = hero.weapons[1].id;
    final blocked = AuthoritativeMatchSession(code: '444444');
    final player = blocked.join()!;
    expect(
      blocked.handle(player, {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': lockedWeapon,
      }),
      'weapon_locked',
    );

    final allowed = AuthoritativeMatchSession(
      code: '555555',
      canUseWeapon: (playerId, weaponId) =>
          playerId == 'p1' && weaponId == lockedWeapon,
    );
    final allowedPlayer = allowed.join()!;
    expect(
      allowed.handle(allowedPlayer, {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': lockedWeapon,
      }),
      isNull,
    );
  });

  test('server checks every non-starting weapon against trusted ownership', () {
    for (final hero in archerFmHeroes) {
      for (var index = 0; index < hero.weapons.length; index++) {
        final session = AuthoritativeMatchSession(code: 'weapon${hero.id.name}$index');
        final player = session.join()!;
        final result = session.handle(player, {
          'type': 'select',
          'heroId': hero.id.name,
          'weaponId': hero.weapons[index].id,
        });
        expect(
          result,
          index == 0 ? isNull : 'weapon_locked',
          reason: '${hero.id.name}: weapon index $index',
        );
      }
    }

    final session = AuthoritativeMatchSession(code: 'crossweapon');
    final player = session.join()!;
    expect(session.handle(player, {
      'type': 'select',
      'heroId': HeroId.ranger.name,
      'weaponId': heroCombatById(HeroId.flame).weapons.first.id,
    }), 'invalid_loadout');
  });

  test('disconnect permits one-time token-rotating resume', () {
    final session = AuthoritativeMatchSession(code: '222222');
    final player = session.join()!;
    final token = player.resumeToken;
    session.disconnect(player);
    expect(player.connected, isFalse);
    final resumed = session.resume(token);
    expect(resumed?.id, player.id);
    expect(resumed?.connected, isTrue);
    expect(resumed!.resumeToken, isNot(token));

    // The previously issued bearer token must not be reusable.
    expect(session.resume(token), isNull);
    session.disconnect(resumed);
    expect(session.resume(resumed.resumeToken)?.id, player.id);
  });

  test('runs a four-player lobby through the real WebSocket gateway', () async {
    final host = WebSocketGameHost(
      address: InternetAddress.loopbackIPv4,
      port: 0,
      tickInterval: const Duration(milliseconds: 10),
      broadcastInterval: const Duration(milliseconds: 20),
      sessionFactory: AuthoritativeMatchSession.fromCreateMessage,
    );
    await host.start();
    final sockets = <WebSocket>[];
    final streams = <Stream<Map<String, dynamic>>>[];
    try {
      String? roomCode;
      for (var i = 0; i < 4; i++) {
        final socket = await WebSocket.connect(host.uri.toString());
        sockets.add(socket);
        final messages = socket
            .map((raw) => jsonDecode(raw as String) as Map<String, dynamic>)
            .asBroadcastStream();
        streams.add(messages);
        final welcomeFuture = messages.firstWhere(
          (message) => message['type'] == 'welcome',
        );
        socket.add(jsonEncode(
          i == 0
              ? {'type': 'create', 'durationMinutes': 10}
              : {'type': 'join', 'code': roomCode},
        ));
        final welcome = await welcomeFuture;
        roomCode ??= welcome['code'] as String;
      }

      for (var i = 0; i < 4; i++) {
        final hero = archerFmHeroes[i];
        final ackFuture = streams[i].firstWhere(
          (message) => message['type'] == 'ack' && message['seq'] == 1,
        );
        sockets[i].add(jsonEncode({
          'type': 'select',
          'seq': 1,
          'heroId': hero.id.name,
          'weaponId': hero.weapons.first.id,
        }));
        expect((await ackFuture)['error'], isNull);
      }

      final startAckFuture = streams.first.firstWhere(
        (message) => message['type'] == 'ack' && message['seq'] == 2,
      );
      final runningStateFuture = streams.first.firstWhere(
        (message) => message['type'] == 'state' && message['phase'] == 'running',
      );
      sockets.first.add(jsonEncode({'type': 'start', 'seq': 2}));
      expect((await startAckFuture)['error'], isNull);
      final runningState = await runningStateFuture;
      expect(runningState['durationMinutes'], 10);
      expect((runningState['players'] as List).length, 4);
    } finally {
      for (final socket in sockets) {
        await socket.close();
      }
      await host.close();
    }
  });

  test('match clock ends at the configured duration', () {
    final session = AuthoritativeMatchSession(code: '333333', durationMinutes: 10);
    final players = [for (var i = 0; i < 4; i++) session.join()!];
    for (var i = 0; i < players.length; i++) {
      final hero = archerFmHeroes[i];
      session.handle(players[i], {
        'type': 'select',
        'heroId': hero.id.name,
        'weaponId': hero.weapons.first.id,
      });
    }
    session.handle(players.first, {'type': 'start'});
    session.tick(const Duration(minutes: 10));
    expect(session.rules!.phase, MatchPhase.finished);
    expect(session.snapshot()['phase'], 'finished');
  });
}
