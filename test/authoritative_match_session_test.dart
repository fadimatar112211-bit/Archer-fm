import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/match/match_rules.dart';
import 'package:archer_fm/game/network/authoritative_match_session.dart';

void main() {
  test('enforces four-player lobby, canonical loadouts and selected duration', () {
    final session = AuthoritativeMatchSession.fromCreateMessage(\n      '123456',\n      {'durationMinutes': 10},\n    );
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
