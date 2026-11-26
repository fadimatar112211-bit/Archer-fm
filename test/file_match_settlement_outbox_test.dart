import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/file_match_settlement_outbox.dart';

void main() {
  late Directory directory;
  late File file;

  const settlement = <String, Object>{
    'matchId': 'room-unique-match-1',
    'accountId': '123e4567-e89b-42d3-a456-426614174000',
    'placement': 2,
    'score': 900,
    'crystalsRemaining': 3,
    'finishReason': 'timeExpired',
    'rewardAmount': 0,
    'idempotencyKey': 'match:room-unique-match-1:user:123e4567-e89b-42d3-a456-426614174000:reward:v1',
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('archer-fm-outbox-');
    file = File('${directory.path}/pending.json');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists before delivery and removes only after confirmed delivery', () async {
    var shouldFail = true;
    final delivered = <Map<String, dynamic>>[];
    final outbox = FileMatchSettlementOutbox(
      file: file,
      deliver: (item) async {
        if (shouldFail) throw const SocketException('offline');
        delivered.add(item);
      },
    );

    await expectLater(
      outbox.enqueueAndFlush(
        matchId: settlement['matchId']! as String,
        accountId: settlement['accountId']! as String,
        placement: settlement['placement']! as int,
        score: settlement['score']! as int,
        crystalsRemaining: settlement['crystalsRemaining']! as int,
        finishReason: settlement['finishReason']! as String,
        rewardAmount: settlement['rewardAmount']! as int,
        idempotencyKey: settlement['idempotencyKey']! as String,
      ),
      throwsA(isA<SocketException>()),
    );
    expect(outbox.pendingCount, 1);
    expect(await file.exists(), isTrue);

    shouldFail = false;
    await outbox.flushPending();
    expect(delivered, hasLength(1));
    expect(outbox.pendingCount, 0);
    expect(await file.readAsString(), '[]');
  });

  test('restores pending settlements after constructing a new outbox', () async {
    final first = FileMatchSettlementOutbox(
      file: file,
      deliver: (_) async => throw const SocketException('offline'),
    );
    await expectLater(
      first.enqueueAndFlush(
        matchId: settlement['matchId']! as String,
        accountId: settlement['accountId']! as String,
        placement: settlement['placement']! as int,
        score: settlement['score']! as int,
        crystalsRemaining: settlement['crystalsRemaining']! as int,
        finishReason: settlement['finishReason']! as String,
        rewardAmount: settlement['rewardAmount']! as int,
        idempotencyKey: settlement['idempotencyKey']! as String,
      ),
      throwsA(isA<SocketException>()),
    );

    final delivered = <Map<String, dynamic>>[];
    final restarted = FileMatchSettlementOutbox(
      file: file,
      deliver: (item) async => delivered.add(item),
    );
    await restarted.load();
    expect(restarted.pendingCount, 1);
    await restarted.flushPending();
    expect(delivered.single['matchId'], settlement['matchId']);
    expect(restarted.pendingCount, 0);
  });

  test('rejects conflicting data for an existing idempotency key', () async {
    final outbox = FileMatchSettlementOutbox(
      file: file,
      deliver: (_) async => throw const SocketException('offline'),
    );
    Future<void> enqueue({required int reward}) => outbox.enqueueAndFlush(
          matchId: settlement['matchId']! as String,
          accountId: settlement['accountId']! as String,
          placement: settlement['placement']! as int,
          score: settlement['score']! as int,
          crystalsRemaining: settlement['crystalsRemaining']! as int,
          finishReason: settlement['finishReason']! as String,
          rewardAmount: reward,
          idempotencyKey: settlement['idempotencyKey']! as String,
        );

    await expectLater(enqueue(reward: 0), throwsA(isA<SocketException>()));
    await expectLater(enqueue(reward: 10), throwsA(isA<StateError>()));
  });
}
