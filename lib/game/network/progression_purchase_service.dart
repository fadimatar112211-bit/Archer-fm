import '../progression/hero_progress.dart';
import '../heroes/hero_roster.dart';
import '../progression/progression_economy_configuration.dart';
import '../../monsters/monster_models.dart';
import 'supabase_rest_client.dart';

/// Server-only purchase boundary. The authenticated account ID is supplied by
/// the token-verifying HTTP gateway; all prices and revisions are read here.
class ProgressionPurchaseService {
  ProgressionPurchaseService({
    required this.client,
    required this.economy,
  });

  final SupabaseRestClient client;
  final ProgressionEconomyConfiguration economy;

  Future<Map<String, dynamic>> catalog(String trustedAccountId) async {
    final heroRow = await client.loadProgressionRow(
      table: 'hero_progress',
      trustedAccountId: trustedAccountId,
    );
    final monsterRow = await client.loadProgressionRow(
      table: 'monster_progress',
      trustedAccountId: trustedAccountId,
    );
    if (heroRow == null || monsterRow == null ||
        heroRow['data'] is! Map<String, dynamic> ||
        monsterRow['data'] is! Map) {
      throw const FormatException('account_progress_missing');
    }
    final hero = HeroProgress.fromJson(heroRow['data'] as Map<String, dynamic>);
    final monsterData = monsterRow['data'] as Map;
    final rawLevels = monsterData['levels'];
    if (monsterData['version'] != 1 || rawLevels is! Map) {
      throw const FormatException('invalid_monster_progress');
    }
    final weapons = <Map<String, Object?>>[];
    for (final heroDefinition in archerFmHeroes) {
      for (final weapon in heroDefinition.weapons) {
        final owned = hero.ownsWeapon(weapon.id);
        final level = hero.weaponLevel(weapon.id);
        final type = owned ? 'weapon_upgrade' : 'weapon_unlock';
        final cost = owned
            ? economy.weaponUpgradeCost(weapon.id, level + 1)
            : economy.unlockCost(weapon.id);
        weapons.add({
          'id': weapon.id,
          'name': weapon.nameAr,
          'hero': heroDefinition.nameAr,
          'owned': owned,
          'level': level,
          'purchaseType': type,
          'cost': cost,
          'available': cost != null && (!owned || level < 40),
        });
      }
    }
    final monsters = <Map<String, Object?>>[];
    const names = {
      'runner': 'العدّاء',
      'tank': 'المدرّع',
      'stalker': 'المتسلّل',
      'ranged': 'الرامي',
    };
    for (final type in MonsterType.values) {
      final level = rawLevels[type.name];
      if (level is! int || level < 1 || level > 40) {
        throw const FormatException('invalid_monster_progress');
      }
      monsters.add({
        'id': type.name,
        'name': names[type.name],
        'level': level,
        'purchaseType': 'monster_upgrade',
        'cost': level < 40 ? economy.monsterUpgradeCost(type.name, level + 1) : null,
        'available': level < 40 && economy.monsterUpgradeCost(type.name, level + 1) != null,
      });
    }
    return {'weapons': weapons, 'monsters': monsters};
  }

  Future<Map<String, dynamic>> purchase({
    required String trustedAccountId,
    required String purchaseType,
    required String targetId,
    required String idempotencyKey,
    required int quotedCost,
  }) async {
    if (!const {'weapon_unlock', 'weapon_upgrade', 'monster_upgrade'}
        .contains(purchaseType)) {
      throw const FormatException('unsupported_purchase_type');
    }
    if (targetId.isEmpty || targetId.length > 96 ||
        idempotencyKey.isEmpty || idempotencyKey.length > 128 || quotedCost <= 0) {
      throw const FormatException('invalid_purchase_request');
    }

    final heroRow = await client.loadProgressionRow(
      table: 'hero_progress',
      trustedAccountId: trustedAccountId,
    );
    final monsterRow = await client.loadProgressionRow(
      table: 'monster_progress',
      trustedAccountId: trustedAccountId,
    );
    if (heroRow == null || monsterRow == null) {
      throw const FormatException('account_progress_missing');
    }
    final heroRevision = _revision(heroRow, 'hero');
    final monsterRevision = _revision(monsterRow, 'monster');
    final heroData = heroRow['data'];
    final monsterData = monsterRow['data'];
    if (heroData is! Map<String, dynamic> || monsterData is! Map) {
      throw const FormatException('invalid_account_progress');
    }

    late final int cost;
    if (purchaseType == 'weapon_unlock') {
      cost = economy.unlockCost(targetId) ??
          (throw const FormatException('unknown_weapon'));
    } else if (purchaseType == 'weapon_upgrade') {
      final progress = HeroProgress.fromJson(heroData);
      if (!progress.ownsWeapon(targetId)) {
        throw const FormatException('weapon_locked');
      }
      final nextLevel = progress.weaponLevel(targetId) + 1;
      cost = economy.weaponUpgradeCost(targetId, nextLevel) ??
          (throw const FormatException('weapon_max_level_or_unknown'));
    } else {
      if (!const {'runner', 'tank', 'stalker', 'ranged'}.contains(targetId)) {
        throw const FormatException('unknown_monster');
      }
      final rawLevels = monsterData['levels'];
      if (monsterData['version'] != 1 || rawLevels is! Map) {
        throw const FormatException('invalid_monster_progress');
      }
      final current = rawLevels[targetId];
      if (current is! int || current < 1 || current >= 40) {
        throw const FormatException('monster_max_level_or_invalid');
      }
      cost = economy.monsterUpgradeCost(targetId, current + 1) ??
          (throw const FormatException('monster_upgrade_not_configured'));
    }

    final existingPurchase = await client.loadProgressionPurchaseByIdempotencyKey(
      trustedAccountId: trustedAccountId,
      idempotencyKey: idempotencyKey,
    );
    var rpcCost = cost;
    if (existingPurchase != null) {
      final amount = existingPurchase['amount'];
      if (existingPurchase['reason'] != purchaseType ||
          existingPurchase['reference_id'] != targetId ||
          amount is! num || amount >= 0 || amount != amount.toInt()) {
        throw const FormatException('idempotency_conflict');
      }
      // The first request committed before its response was lost. Replay the
      // original ledger amount so SQL returns the prior receipt without debit.
      rpcCost = -amount.toInt();
    } else if (cost != quotedCost) {
      throw const FormatException('quote_changed');
    }
    try {
      return await client.purchaseProgression(
        trustedAccountId: trustedAccountId,
        purchaseType: purchaseType,
        targetId: targetId,
        cost: rpcCost,
        maxLevel: 40,
        expectedHeroRevision: heroRevision,
        expectedMonsterRevision: monsterRevision,
        idempotencyKey: idempotencyKey,
      );
    } on SupabaseRestException catch (error) {
      if (error.statusCode >= 400 && error.statusCode < 500) {
        throw FormatException(error.code ?? 'purchase_rejected');
      }
      rethrow;
    }
  }

  int _revision(Map<String, dynamic> row, String label) {
    final value = row['revision'];
    if (value is! num || value < 0 || value != value.toInt()) {
      throw FormatException('invalid_$label_revision');
    }
    return value.toInt();
  }
}
