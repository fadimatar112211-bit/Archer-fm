import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/supabase_match_settlement_store.dart';

void main() {
  group('MatchSettlementReceipt', () {
    test('parses the atomic result, reward transaction and balance', () {
      final receipt = MatchSettlementReceipt.fromJson({
        'result_id': 'c0a8012e-7a12-4f89-8f5d-8cdb4e5d8f91',
        'reward_transaction_id': 42,
        'currency_balance': 175,
      });

      expect(receipt.resultId, 'c0a8012e-7a12-4f89-8f5d-8cdb4e5d8f91');
      expect(receipt.rewardTransactionId, 42);
      expect(receipt.currencyBalance, 175);
    });

    test('accepts a result with no currency reward', () {
      final receipt = MatchSettlementReceipt.fromJson({
        'result_id': 'c0a8012e-7a12-4f89-8f5d-8cdb4e5d8f91',
        'reward_transaction_id': null,
        'currency_balance': 20,
      });

      expect(receipt.rewardTransactionId, isNull);
      expect(receipt.currencyBalance, 20);
    });

    test('rejects an incomplete or malformed database response', () {
      expect(
        () => MatchSettlementReceipt.fromJson({
          'result_id': 7,
          'currency_balance': 'not-a-number',
        }),
        throwsFormatException,
      );
    });
  });
}
