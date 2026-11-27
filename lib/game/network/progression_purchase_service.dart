import '../progression/hero_progress.dart';
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

  Future<Map<String, dynamic>> purchase({
    required String trustedAccountId,
    required String purchaseType,
    required String targetId,
    required String idempotencyKey,
  }) async {
    if (!const {'weapon_unlock', 'weapon_upgrade', 'monster_upgrade'}
        .contains(purchaseType)) {
      throw const FormatException('unsupported_purchase_type');
    }
    if (targetId.isEmpty || targetId.length > 96 ||
        idempotencyKey.isEmpty || idempotencyKey.length > 128) {
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

    return client.purchaseProgression(
      trustedAccountId: trustedAccountId,
      purchaseType: purchaseType,
      targetId: targetId,
      cost: cost,
      maxLevel: 40,
      expectedHeroRevision: heroRevision,
      expectedMonsterRevision: monsterRevision,
      idempotencyKey: idempotencyKey,
    );
  }

  int _revision(Map<String, dynamic> row, String label) {
    final value = row['revision'];
    if (value is! num || value < 0 || value != value.toInt()) {
      throw FormatException('invalid_$label_revision');
    }
    return value.toInt();
  }
}
