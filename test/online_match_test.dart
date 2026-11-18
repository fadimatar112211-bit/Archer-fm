import 'dart:io';
import 'dart:math' as math;

import 'package:archer_fm/game/net/authority.dart';
import 'package:archer_fm/game/net/match_models.dart';
import 'package:archer_fm/game/net/online_match_client.dart';
import 'package:archer_fm/game/net/online_match_server.dart';
import 'package:archer_fm/game/net/protocol.dart';
import 'package:archer_fm/game/net/room_coordinator.dart';
import 'package:archer_fm/game/social/account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Raw TCP/socket messages arrive asynchronously; a longer settle keeps the
/// suite deterministic under parallel load and slow CI runners.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

MatchPlayer player(String id,
        {int score = 0, int crystals = 7, String heroId = 'ranger_new'}) =>
    MatchPlayer(
      id: id,
      username: id,
      heroId: heroId,
      score: score,
      crystals: crystals,
    );

void main() {
  group('match rules and rooms', () {
    test('the five confirmed match lengths are offered', () {
      expect(
        MatchDuration.values.map((duration) => duration.minutes).toList(),
        [10, 20, 30, 45, 60],
      );
      expect(MatchDuration.fromMinutes(45), MatchDuration.m45);
      expect(MatchDuration.fromMinutes(15), isNull);
    });

    test('random matchmaking only pairs the same match duration', () {
      final coordinator = RoomCoordinator(random: math.Random(1));
      final first = coordinator.queueForMatch(
        playerId: 'a',
        username: 'a',
        heroId: 'ranger_new',
        duration: MatchDuration.m20,
      );
      final other = coordinator.queueForMatch(
        playerId: 'b',
        username: 'b',
        heroId: 'flame',
        duration: MatchDuration.m30,
      );
      final matching = coordinator.queueForMatch(
        playerId: 'c',
        username: 'c',
        heroId: 'shadow',
        duration: MatchDuration.m20,
      );
      expect(other!.code, isNot(first!.code));
      expect(matching!.code, first.code);
      expect(first.players.length, 2);
      expect(first.players.map((member) => member.heroId),
          containsAll(['ranger_new', 'shadow']));
    });

    test('private rooms use a code, the owner removes players, leaving is free',
        () {
      final coordinator = RoomCoordinator(random: math.Random(2));
      final room = coordinator.createRoom(
        ownerId: 'owner',
        username: 'owner',
        duration: MatchDuration.m10,
        heroId: 'ranger_new',
      );
      expect(room.code.length, RoomCoordinator.inviteCodeLength);
      expect(coordinator.inviteByUsername(room.code, 'friend'), room.code);
      final joined = coordinator.joinRoom(
        code: room.code.toLowerCase(),
        playerId: 'friend',
        username: 'friend',
        heroId: 'flame',
      );
      expect(joined, same(room));
      expect(coordinator.removePlayer(room.code, 'friend', 'owner'), isFalse);
      expect(coordinator.removePlayer(room.code, 'owner', 'friend'), isTrue);
      expect(room.players.length, 1);
      coordinator.queueForMatch(
        playerId: 'owner',
        username: 'owner',
        heroId: 'ranger_new',
        duration: MatchDuration.m10,
      );
      final left = coordinator.leaveRoom('owner');
      expect(left, isNotNull);
      expect(left!.player('owner'), isNull);
    });

    test('time-up uses score then crystal count; no invented tie-breaker', () {
      final timeUp = decideMatch(
        [player('a', score: 5, crystals: 2), player('b', score: 5, crystals: 4)],
        MatchEndReason.timeUp,
      );
      expect(timeUp.winnerIds, ['b']);

      final tied = decideMatch(
        [player('a', score: 5, crystals: 2), player('b', score: 5, crystals: 2)],
        MatchEndReason.timeUp,
      );
      expect(tied.winnerIds, containsAll(['a', 'b']));

      final last = decideMatch(
        [player('a', crystals: 3), player('b', crystals: 0)],
        MatchEndReason.lastPlayerWithCrystals,
      );
      expect(last.winnerIds, ['a']);
    });

    test('four distinct player colours and four ready players start a match',
        () {
      final coordinator = RoomCoordinator(random: math.Random(3));
      final room = coordinator.createRoom(
        ownerId: 'a',
        username: 'a',
        duration: MatchDuration.m60,
        heroId: 'ranger_new',
      );
      for (final id in ['b', 'c', 'd']) {
        coordinator.joinRoom(
          code: room.code,
          playerId: id,
          username: id,
          heroId: 'flame',
        );
      }
      expect(room.players.map((member) => member.colorValue).toSet().length, 4);
      expect(coordinator.startMatch(room.code, 'a'), isFalse);
      for (final id in ['a', 'b', 'c', 'd']) {
        coordinator.setReady(room.code, id, true);
      }
      expect(coordinator.startMatch(room.code, 'a'), isTrue);
      expect(room.players.every((member) => member.state == RoomMemberState.playing),
          isTrue);
    });
  });

  group('authoritative validation', () {
    MatchAuthority authority() => MatchAuthority(
          players: [
            AuthorityPlayer(
              id: 'a',
              username: 'a',
              heroId: 'ranger_new',
              maxHp: 100,
              position: const Offset(100, 100),
              colorValue: 1,
              carryCapacity: 20,
            ),
            AuthorityPlayer(
              id: 'b',
              username: 'b',
              heroId: 'flame',
              maxHp: 100,
              position: const Offset(160, 100),
              colorValue: 2,
            ),
          ],
          mapBounds: const Rect.fromLTWH(0, 0, 500, 500),
        );

    test('teleports and out-of-bounds movement are rejected', () {
      final game = authority();
      expect(game.move('a', const Offset(140, 100), 200), isTrue);
      expect(game.move('a', const Offset(5000, 100), 216), isFalse);
      expect(game.player('a')!.position, const Offset(140, 100));
      // A legal step past the left edge is clamped to the map bounds.
      expect(game.move('a', const Offset(-1, 100), 1200), isTrue);
      expect(game.player('a')!.position.dx, 0);
      expect(game.violations, isNotEmpty);
    });

    test('damage, kills and score are server-owned and capped', () {
      final game = authority();
      expect(
        game.applyDamage(
          attackerId: 'a',
          targetId: 'b',
          amount: 1000,
          maximumDamage: 30,
        ),
        isFalse,
      );
      expect(game.player('b')!.hp, 100);
      for (var i = 0; i < 4; i++) {
        expect(
          game.applyDamage(
            attackerId: 'a',
            targetId: 'b',
            amount: 30,
            maximumDamage: 30,
            distance: 60,
          ),
          isTrue,
        );
      }
      expect(game.player('b')!.hp, 0);
      expect(game.player('a')!.kills, 1);
      expect(game.player('a')!.score, 1);
      expect(
        game.applyDamage(
          attackerId: 'a',
          targetId: 'b',
          amount: 5,
          maximumDamage: 30,
        ),
        isFalse,
      );
      expect(game.player('a')!.score, 1);
      expect(game.respawn('b'), isTrue);
      expect(game.player('b')!.hp, game.player('b')!.maxHp);
    });

    test('resources require proximity and respect the carry cap', () {
      final game = authority();
      expect(
        game.collectResource(
          id: 'a',
          pickupPosition: const Offset(400, 400),
          amount: 12,
        ),
        isFalse,
      );
      expect(game.player('a')!.resources, 0);
      expect(
        game.collectResource(
          id: 'a',
          pickupPosition: const Offset(100, 100),
          amount: 12,
        ),
        isTrue,
      );
      expect(
        game.collectResource(
          id: 'a',
          pickupPosition: const Offset(100, 100),
          amount: 50,
        ),
        isTrue,
      );
      expect(game.player('a')!.resources, 20);
      expect(game.spendResources('a', 5), isTrue);
      expect(game.player('a')!.resources, 15);
    });

    test('crystal destruction credits score and closes the last-standing match',
        () {
      final game = authority();
      expect(game.destroyCrystal('a', 'a'), isFalse);
      for (var i = 0; i < 7; i++) {
        expect(game.destroyCrystal('a', 'b'), isTrue);
      }
      expect(game.player('a')!.score, 7);
      expect(game.player('b')!.crystals, 0);
      expect(game.lastStanding(), isTrue);
    });
  });

  group('social and online flow', () {
    test('username search, friend requests and opponent stats', () async {
      final social = SocialService(store: MemorySocialStore());
      expect(await social.signIn('Lina', 'pw'), isTrue);
      expect(await social.signIn('Omar', 'pw'), isTrue);
      expect(social.searchByUsername('li').single.username, 'lina');
      expect(await social.sendFriendRequest('lina'), isTrue);
      expect(await social.signIn('Lina', 'pw'), isTrue);
      expect(social.incomingRequests.single.from, 'omar');
      expect(await social.acceptFriendRequest('omar'), isTrue);
      expect(social.friends.single.username, 'omar');
      final opponent = social.profileOf('omar');
      expect(opponent, isNotNull);
      expect(opponent!.username, 'omar');
      await social.recordMatch(won: true, kills: 4);
      expect(social.current!.wins, 1);
      expect(social.current!.kills, 4);
    });

    test('loopback clients see the room, start and authoritative result',
        () async {
      final pair = LoopbackTransportPair();
      final pair2 = LoopbackTransportPair();
      var clock = 0;
      final server = OnlineMatchServer(
        autoTick: false,
        clock: () => clock,
        seed: 77,
      );
      final a = OnlineMatchClient(
        transport: pair.a,
        username: 'a',
        heroId: 'ranger_new',
      );
      final b = OnlineMatchClient(
        transport: pair.b,
        username: 'b',
        heroId: 'flame',
      );
      final c = OnlineMatchClient(
        transport: pair2.a,
        username: 'c',
        heroId: 'shadow',
      );
      final d = OnlineMatchClient(
        transport: pair2.b,
        username: 'd',
        heroId: 'storm',
      );
      server
        ..attach(pair.serverA)
        ..attach(pair.serverB)
        ..attach(pair2.serverA)
        ..attach(pair2.serverB);
      a.createRoom(MatchDuration.m10);
      await settle();
      for (final client in [b, c, d]) {
        client.joinRoom(a.room!.code);
      }
      await settle();
      for (final client in [a, b, c, d]) {
        client.ready(true);
      }
      await settle();
      expect(a.room!.players.length, 4);
      a.startMatch();
      await settle();
      expect(a.seed, 77);
      expect(a.players.length, 4);

      clock = 1000;
      server.tick();
      await settle();
      expect(a.elapsedMs, 1000);

      // Attack is applied by the authority, not by the client's claimed HP.
      a.sendAttack(
        targetId: b.playerId!,
        amount: 50,
        maxDamage: 30,
        distance: 20,
      );
      await settle();
      expect(server.authority!.player(b.playerId!)!.hp, 100);

      // A match ends at the last player with crystals, so all three rivals
      // must lose their seven crystals.
      for (final target in [b, c, d]) {
        for (var i = 0; i < 7; i++) {
          a.sendCrystal(target.playerId!);
        }
      }
      await settle();
      expect(a.result, isNotNull);
      expect(a.result!.reason, MatchEndReason.lastPlayerWithCrystals);
      expect(a.result!.winnerIds, [a.playerId]);
      await a.close();
      await b.close();
      await c.close();
      await d.close();
      await pair.close();
      await pair2.close();
      await server.close();
    });

    test('a real TCP socket host accepts a client on loopback', () async {
      final server = OnlineMatchServer(
        autoTick: false,
        seed: 9,
      );
      await server.start(address: InternetAddress.loopbackIPv4);
      final client = await OnlineMatchClient.connect(
        host: '127.0.0.1',
        port: server.port,
        username: 'socket_player',
        heroId: 'ranger_new',
      );
      client.createRoom(MatchDuration.m20);
      await settle();
      expect(client.playerId, isNotEmpty);
      expect(client.room, isNotNull);
      expect(client.room!.duration, MatchDuration.m20);
      expect(server.coordinator.room(client.room!.code), isNotNull);
      await client.close();
      await server.close();
    });
  });
}
