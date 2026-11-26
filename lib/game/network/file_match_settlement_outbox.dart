import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef MatchSettlementDelivery = Future<void> Function(
  Map<String, dynamic> settlement,
);

/// Disk-backed retry queue for finalized match settlements.
///
/// The item is written and flushed to disk before the first network attempt.
/// Re-delivery is safe because the database RPC uses the item's idempotency
/// key. Keep the file on a private persistent volume, never in a public web root.
class FileMatchSettlementOutbox {
  FileMatchSettlementOutbox({
    required this.file,
    required this.deliver,
  });

  final File file;
  final MatchSettlementDelivery deliver;
  final List<Map<String, dynamic>> _pending = [];
  Future<void> _tail = Future<void>.value();
  bool _loaded = false;

  int get pendingCount => _pending.length;

  Future<void> load() => _serialize(() async {
        if (_loaded) return;
        if (await file.exists()) {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is! List) {
            throw const FormatException('Settlement outbox must be a JSON list.');
          }
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid settlement outbox item.');
            }
            _validate(item);
            _pending.add(Map<String, dynamic>.from(item));
          }
        }
        _loaded = true;
      });

  Future<void> enqueueAndFlush({
    required String matchId,
    required String accountId,
    required int placement,
    required int score,
    required int crystalsRemaining,
    required String finishReason,
    required int rewardAmount,
    required String idempotencyKey,
  }) =>
      _serialize(() async {
        await _loadUnlocked();
        final item = <String, dynamic>{
          'matchId': matchId,
          'accountId': accountId,
          'placement': placement,
          'score': score,
          'crystalsRemaining': crystalsRemaining,
          'finishReason': finishReason,
          'rewardAmount': rewardAmount,
          'idempotencyKey': idempotencyKey,
        };
        _validate(item);
        final existing = _pending.indexWhere(
          (entry) => entry['idempotencyKey'] == idempotencyKey,
        );
        if (existing < 0) {
          _pending.add(item);
          await _persistUnlocked();
        } else if (jsonEncode(_pending[existing]) != jsonEncode(item)) {
          throw StateError('Conflicting settlement uses an existing idempotency key.');
        }
        await _flushUnlocked();
      });

  Future<void> flushPending() => _serialize(() async {
        await _loadUnlocked();
        await _flushUnlocked();
      });

  Future<void> _loadUnlocked() async {
    if (_loaded) return;
    if (await file.exists()) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        throw const FormatException('Settlement outbox must be a JSON list.');
      }
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid settlement outbox item.');
        }
        _validate(item);
        _pending.add(Map<String, dynamic>.from(item));
      }
    }
    _loaded = true;
  }

  Future<void> _flushUnlocked() async {
    while (_pending.isNotEmpty) {
      // Do not remove an item until the database confirms its idempotent RPC.
      await deliver(Map<String, dynamic>.unmodifiable(_pending.first));
      _pending.removeAt(0);
      await _persistUnlocked();
    }
  }

  Future<void> _persistUnlocked() async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final sink = temporary.openWrite(mode: FileMode.writeOnly);
    sink.write(jsonEncode(_pending));
    await sink.flush();
    await sink.close();
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  void _validate(Map<String, dynamic> item) {
    final matchId = item['matchId'];
    final accountId = item['accountId'];
    final placement = item['placement'];
    final score = item['score'];
    final crystals = item['crystalsRemaining'];
    final reason = item['finishReason'];
    final reward = item['rewardAmount'];
    final key = item['idempotencyKey'];
    if (matchId is! String || matchId.isEmpty || matchId.length > 128 ||
        accountId is! String || !_isUuid(accountId) ||
        placement is! int || placement < 1 || placement > 4 ||
        score is! int || score < 0 ||
        crystals is! int || crystals < 0 || crystals > 7 ||
        reason is! String || reason.isEmpty || reason.length > 48 ||
        reward is! int || reward < 0 ||
        key is! String || key.isEmpty || key.length > 128) {
      throw const FormatException('Invalid match settlement outbox record.');
    }
  }

  bool _isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }
}
