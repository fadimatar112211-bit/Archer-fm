import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/network/match_combat_authority.dart';
import 'package:archer_fm/monsters/monster_army.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/game/match/match_rules.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/websocket_game_host.dart';


MatchCombatConfiguration _combatConfiguration() {
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
  final counts = {for (final type in MonsterType.values) type: 0};
  counts[MonsterType.runner] = 20;
  return MatchCombatConfiguration(
    monsterCatalog: catalog,
    projectileSpeed: 120,
    maxActiveProjectiles: 128,
    maxUnitsPerArmy: 100,
    worldUnitsPerSecond: 100,
  );
}

AuthoritativeMatchSession _combatReadySession() {
  final session = AuthoritativeMatchSession(
    code: 'combat1',
    mapFactory: () => ArenaMap.generate(Random(123)),
    combatConfiguration: _combatConfiguration(),
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
    expect(enemy.health, lessThan(946));

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

  test('disconnect permits resume without forfeiting', () {
    final session = AuthoritativeMatchSession(code: '222222');
    final player = session.join()!;
    final token = player.resumeToken;
    session.disconnect(player);
    expect(player.connected, isFalse);
    final resumed = session.resume(token);
    expect(resumed?.id, player.id);
    expect(resumed?.connected, isTrue);
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
