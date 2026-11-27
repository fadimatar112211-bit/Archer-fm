import 'package:supabase_flutter/supabase_flutter.dart';

/// A read/update-only client surface for the authenticated player's account.
/// It deliberately exposes no client-side currency or progression mutation.
class PlayerAccountDataService {
  PlayerAccountDataService(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('A signed-in account is required.');
    }
    return id;
  }

  Future<PlayerProfile> loadProfile() async {
    final row = await _client
        .from('player_profiles')
        .select('user_id, display_name, created_at, updated_at')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) {
      throw StateError('The player profile has not been provisioned yet.');
    }
    return PlayerProfile.fromJson(row);
  }

  Future<PlayerProfile> updateDisplayName(String displayName) async {
    final normalized = displayName.trim();
    validateDisplayName(normalized);
    final row = await _client
        .from('player_profiles')
        .update({'display_name': normalized})
        .eq('user_id', _userId)
        .select('user_id, display_name, created_at, updated_at')
        .single();
    return PlayerProfile.fromJson(row);
  }

  /// Reads the wallet from the authenticated player's own RLS-protected
  /// progression row. Currency changes remain server-only.
  Future<PlayerWallet> loadWallet() async {
    final row = await _client
        .from('hero_progress')
        .select('data, revision')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null || row['data'] is! Map) {
      throw const FormatException('Invalid player wallet record.');
    }
    final data = Map<String, dynamic>.from(row['data'] as Map);
    final rawBalance = data['permanentCurrency'];
    final revision = row['revision'];
    if (rawBalance is! num ||
        rawBalance < 0 ||
        rawBalance != rawBalance.toInt() ||
        revision is! num ||
        revision < 0 ||
        revision != revision.toInt()) {
      throw const FormatException('Invalid player wallet values.');
    }
    return PlayerWallet(
      permanentCurrency: rawBalance.toInt(),
      progressionRevision: revision.toInt(),
    );
  }


  Future<PlayerMonsterProgress> loadMonsterProgress() async {
    final row = await _client
        .from('monster_progress')
        .select('data, revision')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null ||
        row['data'] is! Map ||
        row['revision'] is! num ||
        (row['revision'] as num) < 0 ||
        (row['revision'] as num) != (row['revision'] as num).toInt()) {
      throw const FormatException('Invalid player monster progression record.');
    }
    return PlayerMonsterProgress.fromSaveData(
      Map<String, dynamic>.from(row['data'] as Map),
      (row['revision'] as num).toInt(),
    );
  }

  Future<List<PlayerCurrencyTransaction>> loadCurrencyHistory({
    int limit = 30,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 100.');
    }
    final rows = await _client
        .from('currency_transactions')
        .select('id, amount, reason, reference_id, created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((row) => PlayerCurrencyTransaction.fromJson(row))
        .toList(growable: false);
  }

  Future<List<PlayerMatchResult>> loadRecentMatches({int limit = 20}) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 100.');
    }
    final rows = await _client
        .from('match_results')
        .select(
          'id, match_id, placement, score, crystals_remaining, finish_reason, completed_at',
        )
        .eq('user_id', _userId)
        .order('completed_at', ascending: false)
        .limit(limit);
    return rows.map((row) => PlayerMatchResult.fromJson(row)).toList(growable: false);
  }

  static void validateDisplayName(String value) {
    if (value.isEmpty ||
        value != value.trim() ||
        value.length > 32 ||
        value.runes.any((rune) =>
            rune < 32 || rune == 127 || (rune >= 0x202A && rune <= 0x202E))) {
      throw ArgumentError.value(
        value,
        'displayName',
        'Use 1–32 visible characters without control or direction-override characters.',
      );
    }
  }
}

class PlayerProfile {
  const PlayerProfile({
    required this.userId,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String? displayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final id = json['user_id'];
    final name = json['display_name'];
    if (id is! String || (name != null && name is! String)) {
      throw const FormatException('Invalid player profile.');
    }
    return PlayerProfile(
      userId: id,
      displayName: name as String?,
      createdAt: _dateOrNull(json['created_at']),
      updatedAt: _dateOrNull(json['updated_at']),
    );
  }
}


class PlayerMonsterProgress {
  const PlayerMonsterProgress({
    required this.runner,
    required this.tank,
    required this.stalker,
    required this.ranged,
    required this.revision,
  });

  final int runner;
  final int tank;
  final int stalker;
  final int ranged;
  final int revision;

  factory PlayerMonsterProgress.fromSaveData(
    Map<String, dynamic> data,
    int revision,
  ) {
    final rawLevels = data['levels'];
    if (data['version'] != 1 ||
        revision < 0 ||
        rawLevels is! Map ||
        rawLevels.length != 4) {
      throw const FormatException('Invalid player monster progression.');
    }
    int level(String key) {
      final value = rawLevels[key];
      if (value is! num ||
          value != value.toInt() ||
          value < 1 ||
          value > 40) {
        throw FormatException('Invalid saved monster level: $key.');
      }
      return value.toInt();
    }
    if (rawLevels.keys.any((key) =>
        key is! String ||
        !const {'runner', 'tank', 'stalker', 'ranged'}.contains(key))) {
      throw const FormatException('Unknown monster progression type.');
    }
    return PlayerMonsterProgress(
      runner: level('runner'),
      tank: level('tank'),
      stalker: level('stalker'),
      ranged: level('ranged'),
      revision: revision,
    );
  }
}

class PlayerWallet {
  const PlayerWallet({
    required this.permanentCurrency,
    required this.progressionRevision,
  });

  final int permanentCurrency;
  final int progressionRevision;
}

class PlayerCurrencyTransaction {
  const PlayerCurrencyTransaction({
    required this.id,
    required this.amount,
    required this.reason,
    required this.referenceId,
    required this.createdAt,
  });

  final int id;
  final int amount;
  final String reason;
  final String? referenceId;
  final DateTime? createdAt;

  factory PlayerCurrencyTransaction.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final amount = json['amount'];
    final reason = json['reason'];
    final reference = json['reference_id'];
    if (id is! num ||
        id != id.toInt() ||
        amount is! num ||
        amount != amount.toInt() ||
        reason is! String ||
        (reference != null && reference is! String)) {
      throw const FormatException('Invalid currency transaction.');
    }
    return PlayerCurrencyTransaction(
      id: id.toInt(),
      amount: amount.toInt(),
      reason: reason,
      referenceId: reference as String?,
      createdAt: _dateOrNull(json['created_at']),
    );
  }
}

class PlayerMatchResult {
  const PlayerMatchResult({
    required this.id,
    required this.matchId,
    required this.placement,
    required this.score,
    required this.crystalsRemaining,
    required this.finishReason,
    required this.completedAt,
  });

  final String id;
  final String matchId;
  final int placement;
  final int score;
  final int crystalsRemaining;
  final String finishReason;
  final DateTime? completedAt;

  factory PlayerMatchResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final matchId = json['match_id'];
    final placement = json['placement'];
    final score = json['score'];
    final crystals = json['crystals_remaining'];
    final reason = json['finish_reason'];
    if (id is! String ||
        matchId is! String ||
        placement is! num ||
        placement != placement.toInt() ||
        score is! num ||
        score != score.toInt() ||
        crystals is! num ||
        crystals != crystals.toInt() ||
        reason is! String ||
        reason.isEmpty ||
        reason.length > 48 ||
        id.isEmpty ||
        matchId.isEmpty ||
        placement.toInt() < 1 ||
        placement.toInt() > 4 ||
        score < 0 ||
        crystals.toInt() < 0 ||
        crystals.toInt() > 7) {
      throw const FormatException('Invalid player match result.');
    }
    return PlayerMatchResult(
      id: id,
      matchId: matchId,
      placement: placement.toInt(),
      score: score.toInt(),
      crystalsRemaining: crystals.toInt(),
      finishReason: reason,
      completedAt: _dateOrNull(json['completed_at']),
    );
  }
}

DateTime? _dateOrNull(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Invalid timestamp in player account data.');
  }
  return DateTime.tryParse(value);
}
