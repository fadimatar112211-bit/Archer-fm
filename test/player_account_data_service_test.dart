import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/auth/player_account_data_service.dart';

void main() {
  group('PlayerAccountDataService validation', () {
    test('accepts a valid Arabic display name', () {
      expect(
        () => PlayerAccountDataService.validateDisplayName('فادي البطل'),
        returnsNormally,
      );
    });

    test('rejects blank, oversized and direction-override names', () {
      expect(
        () => PlayerAccountDataService.validateDisplayName('   '),
        throwsArgumentError,
      );
      expect(
        () => PlayerAccountDataService.validateDisplayName('x' * 33),
        throwsArgumentError,
      );
      expect(
        () => PlayerAccountDataService.validateDisplayName('name\u202Etxt'),
        throwsArgumentError,
      );
    });
  });

  group('PlayerProfile', () {
    test('parses the profile returned by the own-profile RLS query', () {
      final profile = PlayerProfile.fromJson({
        'user_id': '123e4567-e89b-42d3-a456-426614174000',
        'display_name': 'فارس',
        'created_at': '2026-11-27T10:00:00Z',
        'updated_at': '2026-11-27T11:00:00Z',
      });
      expect(profile.displayName, 'فارس');
      expect(profile.createdAt?.year, 2026);
    });

    test('rejects malformed profile rows', () {
      expect(
        () => PlayerProfile.fromJson({'user_id': 7}),
        throwsFormatException,
      );
    });
  });

  group('PlayerCurrencyTransaction', () {
    test('parses a signed immutable ledger entry', () {
      final transaction = PlayerCurrencyTransaction.fromJson({
        'id': 12,
        'amount': -25,
        'reason': 'weapon_upgrade',
        'reference_id': 'upgrade-abc',
        'created_at': '2026-11-27T12:00:00Z',
      });
      expect(transaction.amount, -25);
      expect(transaction.reason, 'weapon_upgrade');
    });

    test('rejects malformed ledger entries', () {
      expect(
        () => PlayerCurrencyTransaction.fromJson({
          'id': 'bad',
          'amount': '25',
          'reason': 10,
        }),
        throwsFormatException,
      );
    });
  });

  group('PlayerMatchResult', () {
    test('parses a match history entry', () {
      final result = PlayerMatchResult.fromJson({
        'id': 'result-1',
        'match_id': 'match-1',
        'placement': 2,
        'score': 700,
        'crystals_remaining': 4,
        'finish_reason': 'timeExpired',
        'completed_at': '2026-11-27T12:00:00Z',
      });
      expect(result.placement, 2);
      expect(result.crystalsRemaining, 4);
    });

    test('rejects out-of-range placement and crystal counts', () {
      expect(
        () => PlayerMatchResult.fromJson({
          'id': 'result-1',
          'match_id': 'match-1',
          'placement': 5,
          'score': 700,
          'crystals_remaining': 8,
          'finish_reason': 'timeExpired',
        }),
        throwsFormatException,
      );
    });
  });
}
