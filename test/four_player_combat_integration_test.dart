import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/network/authoritative_match_session.dart';
import 'package:archer_fm/game/network/match_combat_authority.dart';
import 'package:archer_fm/game/match/match_rules.dart';
import 'package:archer_fm/game/network/websocket_game_host.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/monsters/monster_models.dart';

MatchCombatConfiguration _configuration() {
  final catalog = MonsterCatalog({
    for (final type in MonsterType.values)
      type: MonsterDefinition(
        type: type,
        baseStats: const MonsterStats(
          maxHealth: 1000,
          damage: 12,
          moveSpeed: 20,
          attackRange: 36,
          attackCooldown: Duration(milliseconds: 700),
          purchaseCost: 10,
        ),
      ),
  });
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
  );
}

Future<Map<String, dynamic>> _next(
  Stream<Map<String, dynamic>> messages,
  bool Function(Map<String, dynamic>) predicate,
) =>
    messages.firstWhere(predicate);

Stream<Map<String, dynamic>> _messages(WebSocket socket) =>
    socket.map((raw) => jsonDecode(raw as String) as Map<String, dynamic>);

void main() {
  test('four real WebSocket clients share one authoritative combat match', () async {
    final host = WebSocketGameHost(
      address: InternetAddress.loopbackIPv4,
      port: 0,
      tickInterval: const Duration(milliseconds: 10),
      broadcastInterval: const Duration(milliseconds: 20),
      sessionFactory: AuthoritativeMatchSession.configuredFactory(
        combatConfiguration: _configuration(),
        mapFactory: () => ArenaMap.generate(Random(444)),
      ),
    );
    await host.start();
    final sockets = <WebSocket>[];
    final streams = <Stream<Map<String, dynamic>>>[];

    try {
      String? roomCode;
      for (var i = 0; i < 4; i++) {
        final socket = await WebSocket.connect(host.uri.toString());
        sockets.add(socket);
        final messages = _messages(socket).asBroadcastStream();
        streams.add(messages);
        final welcomeFuture = _next(messages, (m) => m['type'] == 'welcome');
        socket.add(jsonEncode(i == 0
            ? {'type': 'create', 'durationMinutes': 10}
            : {'type': 'join', 'code': roomCode}));
        final welcome = await welcomeFuture;
        expect(welcome['id'], 'p${i + 1}');
        roomCode ??= welcome['code'] as String;
      }

      for (var i = 0; i < 4; i++) {
        final hero = archerFmHeroes[i];
        var ack = _next(streams[i], (m) => m['type'] == 'ack' && m['seq'] == 1);
        sockets[i].add(jsonEncode({
          'type': 'select',
          'seq': 1,
          'heroId': hero.id.name,
          'weaponId': hero.weapons.first.id,
        }));
        expect((await ack)['error'], isNull);

        ack = _next(streams[i], (m) => m['type'] == 'ack' && m['seq'] == 2);
        sockets[i].add(jsonEncode({
          'type': 'army_select',
          'seq': 2,
          'counts': {'runner': 20},
        }));
        expect((await ack)['error'], isNull);
      }

      final startAck = _next(
        streams.first,
        (m) => m['type'] == 'ack' && m['seq'] == 3,
      );
      final runningStates = [
        for (final stream in streams)
          _next(stream, (m) => m['type'] == 'state' && m['phase'] == 'running'),
      ];
      sockets.first.add(jsonEncode({'type': 'start', 'seq': 3}));
      expect((await startAck)['error'], isNull);
      final states = await Future.wait(runningStates);

      for (final state in states) {
        expect(state['durationMinutes'], 10);
        expect(state['phase'], MatchPhase.running.name);
        final combat = state['combat'] as Map;
        expect((combat['heroes'] as Map).keys, hasLength(4));
        expect(combat['monsters'], hasLength(80));
        final world = state['world'] as Map;
        expect((world['castles'] as List), hasLength(4));
        expect(world['livingCrystals'], hasLength(4));
      }

      // Malformed movement, forged targets, purchases without funds and
      // client-side score injection are all rejected by the host.
      var ack = _next(streams.first, (m) => m['type'] == 'ack' && m['seq'] == 4);
      sockets.first.add(jsonEncode({
        'type': 'move',
        'seq': 4,
        'dx': 50,
        'dy': 0,
      }));
      expect((await ack)['error'], 'invalid_movement');

      ack = _next(streams.first, (m) => m['type'] == 'ack' && m['seq'] == 5);
      sockets.first.add(jsonEncode({
        'type': 'attack',
        'seq': 5,
        'targetId': 'hero_p2',
      }));
      expect((await ack)['error'], 'attack_rejected');

      ack = _next(streams.first, (m) => m['type'] == 'ack' && m['seq'] == 6);
      sockets.first.add(jsonEncode({
        'type': 'purchase',
        'seq': 6,
        'monsterType': 'runner',
      }));
      expect((await ack)['error'], 'purchase_rejected');

      ack = _next(streams.first, (m) => m['type'] == 'ack' && m['seq'] == 7);
      sockets.first.add(jsonEncode({
        'type': 'awardScore',
        'seq': 7,
        'points': 999999,
      }));
      expect((await ack)['error'], 'unsupported_command');

      expect(host.connectedPlayerCount, 4);
      expect(host.roomCount, 1);
    } finally {
      for (final socket in sockets) {
        await socket.close();
      }
      await host.close();
    }
  });
}
