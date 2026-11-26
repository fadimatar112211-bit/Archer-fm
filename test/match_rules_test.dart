import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/match/match_rules.dart';

List<MatchParticipantSeed> fourPlayers() => const [
      MatchParticipantSeed(playerId: 'p1'),
      MatchParticipantSeed(playerId: 'p2'),
      MatchParticipantSeed(playerId: 'p3'),
      MatchParticipantSeed(playerId: 'p4'),
    ];

void main() {
  group('MatchDuration', () {
    test('exposes only the five approved durations', () {
      expect(
        MatchDuration.choices.map((choice) => choice.minutes),
        [10, 20, 30, 45, 60],
      );
      expect(MatchDuration.fromMinutes(30), MatchDuration.thirty);
      expect(() => MatchDuration.fromMinutes(15), throwsArgumentError);
    });
  });

  group('MatchRulesEngine', () {
    test('requires exactly four distinct non-empty player IDs', () {
      expect(
        () => MatchRulesEngine(
          duration: MatchDuration.ten,
          participants: fourPlayers().take(3).toList(),
        ),
        throwsArgumentError,
      );
      expect(
        () => MatchRulesEngine(
          duration: MatchDuration.ten,
          participants: const [
            MatchParticipantSeed(playerId: 'p1'),
            MatchParticipantSeed(playerId: 'p1'),
            MatchParticipantSeed(playerId: 'p3'),
            MatchParticipantSeed(playerId: 'p4'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('does not run or accept score before start', () {
      final match = MatchRulesEngine(
        duration: MatchDuration.ten,
        participants: fourPlayers(),
      );
      expect(match.addScore('p1', 10).accepted, isFalse);
      expect(match.advance(const Duration(seconds: 1)).accepted, isFalse);
      expect(match.start().accepted, isTrue);
      expect(match.start().accepted, isFalse);
    });

    test('finishes immediately when exactly one non-forfeited player owns crystals', () {
      final match = MatchRulesEngine(
        duration: MatchDuration.ten,
        participants: fourPlayers(),
      )..start();

      expect(match.setLivingCrystals('p2', 0).accepted, isTrue);
      expect(match.setLivingCrystals('p3', 0).accepted, isTrue);
      expect(match.setLivingCrystals('p4', 0).accepted, isTrue);

      expect(match.phase, MatchPhase.finished);
      expect(match.result?.winnerId, 'p1');
      expect(match.result?.reason, MatchFinishReason.lastCrystalHolder);
    });

    test('all players losing crystals does not invent an immediate winner', () {
      final match = MatchRulesEngine(
        duration: MatchDuration.ten,
        participants: fourPlayers(),
      )..start();

      for (final player in ['p1', 'p2', 'p3', 'p4']) {
        expect(match.setLivingCrystals(player, 0).accepted, isTrue);
      }

      expect(match.phase, MatchPhase.running);
      expect(match.result, isNull);
      expect(match.allRemainingPlayersHaveNoCrystals, isTrue);
    });

    test('time expiry ranks by score then by remaining crystals', () {
      final match = MatchRulesEngine(
        duration: MatchDuration.ten,
        participants: fourPlayers(),
      )..start();

      match.addScore('p1', 100);
      match.addScore('p2', 150);
      match.addScore('p3', 150);
      match.setLivingCrystals('p2', 2);
      match.setLivingCrystals('p3', 5);

      expect(match.advance(const Duration(minutes: 10)).accepted, isTrue);
      expect(match.phase, MatchPhase.finished);
      expect(match.result?.winnerId, 'p3');
      expect(match.result?.reason, MatchFinishReason.timeExpired);
      expect(match.remaining, Duration.zero);
    });

    test('a complete tie stays a tie instead of inventing another tiebreaker', () {
      final match = MatchRulesEngine(
        duration: MatchDuration.ten,
        participants: fourPlayers(),
      )..start();

      match.addScore('p1', 100);
      match.addScore('p2', 100);
      match.setLivingCrystals('p1', 4);
      match.setLivingCrystals('p2', 4);

      match.advance(const Duration(minutes: 10));
      expect(match.result?.winnerId, isNull);
      expect(match.result?.tiedPlayerIds, containsAll(['p1', 'p2']));
    });

    test('forfeiting during an active match counts as a loss', () {
      final match = MatchRulesEngine(
        duration: MatchDuration.ten,
        participants: fourPlayers(),
      )..start();

      expect(match.forfeit('p2').accepted, isTrue);
      expect(match.participants.firstWhere((p) => p.playerId == 'p2').hasForfeited, isTrue);
      expect(match.addScore('p2', 20).accepted, isFalse);
    });

    test('last non-forfeited player wins even without a crystal', () {
      final match = MatchRulesEngine(
        duration: MatchDuration.ten,
        participants: fourPlayers(),
      )..start();

      match.forfeit('p2');
      match.forfeit('p3');
      match.forfeit('p4');

      expect(match.phase, MatchPhase.finished);
      expect(match.result?.winnerId, 'p1');
      expect(match.result?.reason, MatchFinishReason.lastPlayerRemaining);
    });

    test('negative time, score and invalid crystal counts are rejected', () {
      final match = MatchRulesEngine(
        duration: MatchDuration.ten,
        participants: fourPlayers(),
      )..start();

      expect(match.advance(const Duration(milliseconds: -1)).accepted, isFalse);
      expect(match.addScore('p1', -1).accepted, isFalse);
      expect(match.setLivingCrystals('p1', 8).accepted, isFalse);
    });
  });
}
