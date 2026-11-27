import 'supabase_rest_client.dart';

/// Durable result returned after an atomic server-side match settlement.
class MatchSettlementReceipt {
  const MatchSettlementReceipt({
    required this.resultId,
    required this.currencyBalance,
    this.rewardTransactionId,
  });

  final String resultId;
  final int currencyBalance;
  final int? rewardTransactionId;

  factory MatchSettlementReceipt.fromJson(Map<String, dynamic> json) {
    final resultId = json['result_id'];
    final balance = json['currency_balance'];
    final transactionId = json['reward_transaction_id'];
    if (resultId is! String ||
        balance is! num ||
        (transactionId != null && transactionId is! num)) {
      throw const FormatException('Invalid match settlement receipt.');
    }
    return MatchSettlementReceipt(
      resultId: resultId,
      currencyBalance: balance.toInt(),
      rewardTransactionId: transactionId?.toInt(),
    );
  }
}

/// Server-only adapter for the database's atomic match-result/reward RPC.
///
/// Call only after the authoritative match engine has finalized standings.
/// The user ID must be the verified Supabase Auth subject; reward amounts and
/// result fields must be calculated by trusted server code.
class SupabaseMatchSettlementStore {
  const SupabaseMatchSettlementStore(this.client);

  final SupabaseRestClient client;

  Future<MatchSettlementReceipt> finalizePlayer({
    required String matchId,
    required String verifiedUserId,
    required int placement,
    required int score,
    required int crystalsRemaining,
    required String finishReason,
    required int rewardAmount,
    required String idempotencyKey,
  }) async {
    final receipt = await client.finalizeMatchPlayerResult(
      matchId: matchId,
      trustedAccountId: verifiedUserId,
      placement: placement,
      score: score,
      crystalsRemaining: crystalsRemaining,
      finishReason: finishReason,
      rewardAmount: rewardAmount,
      idempotencyKey: idempotencyKey,
    );
    return MatchSettlementReceipt.fromJson(receipt);
  }
}
