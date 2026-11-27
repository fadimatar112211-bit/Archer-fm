import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/auth/player_account_data_service.dart';
import 'package:archer_fm/game/progression/hero_progress.dart';

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
        () => PlayerAccountDataService.validateDisplayName(List.filled(33, 'x').join()),
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

    test('rejects fractional ledger values', () {
      expect(
        () => PlayerCurrencyTransaction.fromJson({
          'id': 1.5,
          'amount': 10,
          'reason': 'match_reward',
        }),
        throwsFormatException,
      );
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

    test('rejects fractional match result values', () {
      expect(
        () => PlayerMatchResult.fromJson({
          'id': 'result-1',
          'match_id': 'match-1',
          'placement': 1,
          'score': 7.5,
          'crystals_remaining': 2,
          'finish_reason': 'timeExpired',
        }),
        throwsFormatException,
      );
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

  group('PlayerMonsterProgress', () {
    test('parses all four persisted monster levels', () {
      final progress = PlayerMonsterProgress.fromSaveData({
        'version': 1,
        'levels': {
          'runner': 4,
          'tank': 8,
          'stalker': 2,
          'ranged': 6,
        },
      }, 9);
      expect(progress.runner, 4);
      expect(progress.tank, 8);
      expect(progress.stalker, 2);
      expect(progress.ranged, 6);
      expect(progress.revision, 9);
    });

    test('rejects unsupported schema, missing types and out-of-range levels', () {
      expect(
        () => PlayerMonsterProgress.fromSaveData({
          'version': 2,
          'levels': {
            'runner': 1,
            'tank': 1,
            'stalker': 1,
            'ranged': 1,
          },
        }, 0),
        throwsFormatException,
      );
      expect(
        () => PlayerMonsterProgress.fromSaveData({
          'version': 1,
          'levels': {'runner': 1},
        }, 0),
        throwsFormatException,
      );
      expect(
        () => PlayerMonsterProgress.fromSaveData({
          'version': 1,
          'levels': {
            'runner': 41,
            'tank': 1,
            'stalker': 1,
            'ranged': 1,
          },
        }, 0),
        throwsFormatException,
      );
    });
  });


  group('PlayerHeroProgress', () {
    test('parses all hero levels and weapon ownership summary', () {
      final data = HeroProgress.fresh().toJson();
      data['heroLevels'] = {
        'ranger': 2,
        'flame': 3,
        'shadow': 4,
        'storm': 5,
      };
      data['weaponUpgradeLevels'] = {'ranger_greenbow': 2};
      final progress = PlayerHeroProgress.fromSaveData(data, 7);
      expect(progress.rangerLevel, 2);
      expect(progress.flameLevel, 3);
      expect(progress.shadowLevel, 4);
      expect(progress.stormLevel, 5);
      expect(progress.unlockedWeaponCount, 4);
      expect(progress.weaponUpgradeCount, 1);
      expect(progress.revision, 7);
    });

    test('rejects malformed or unknown hero progression', () {
      final data = HeroProgress.fresh().toJson();
      data['heroLevels'] = {'ranger': 41};
      expect(
        () => PlayerHeroProgress.fromSaveData(data, 0),
        throwsFormatException,
      );
      expect(
        () => PlayerHeroProgress.fromSaveData(HeroProgress.fresh().toJson(), -1),
        throwsFormatException,
      );
    });
  });

}
