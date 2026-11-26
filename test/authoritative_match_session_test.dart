import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/match/match_rules.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/websocket_game_host.dart';

void main() {
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
