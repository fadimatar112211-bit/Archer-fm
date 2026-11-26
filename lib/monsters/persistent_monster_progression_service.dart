import 'monster_models.dart';
import 'monster_progression.dart';
import 'file_monster_progress_store.dart';

/// Trusted economy configuration for permanent monster upgrades.
abstract interface class MonsterProgressionEconomy {
  int? upgradeCost(MonsterType type, int nextLevel);
}

/// Result of a persisted, server-authoritative monster upgrade.
class PersistentMonsterUpgrade {
  const PersistentMonsterUpgrade({
    required this.result,
    required this.currencyBalance,
    required this.level,
  });

  final MonsterUpgradeResult result;
  final int currencyBalance;
  final int level;

  bool get accepted => result == MonsterUpgradeResult.upgraded;
}

/// Loads, upgrades and persists a player's permanent monster levels.
///
/// Account IDs must come from verified server authentication. Currency debit
/// and refund callbacks must operate on that same authenticated profile.
/// Successful upgrades are persisted before this method reports acceptance.
class PersistentMonsterProgressionService {
  PersistentMonsterProgressionService({
    required this.store,
    required this.catalog,
    required this.growth,
    required this.economy,
  });

  final FileMonsterProgressStore store;
  final MonsterCatalog catalog;
  final Map<MonsterType, MonsterUpgradeGrowth> growth;
  final MonsterProgressionEconomy economy;
  final Map<String, Future<void>> _accountQueues = {};

  Future<MonsterProgression> load(String trustedAccountId) =>
      _serialize(trustedAccountId, () async {
        final data = await store.loadData(trustedAccountId);
        return _restore(data);
      });

  Future<PersistentMonsterUpgrade> upgrade(
    String trustedAccountId, {
    required MonsterType type,
    required int currentCurrency,
    required bool Function(int amount) tryDebit,
    required void Function(int amount) refund,
  }) =>
      _serialize(trustedAccountId, () async {
        final progression = _restore(
          await store.loadData(trustedAccountId),
        );
        final currentLevel = progression.levelOf(type);
        if (currentLevel >= MonsterProgression.maxLevel) {
          return PersistentMonsterUpgrade(
            result: MonsterUpgradeResult.maxLevelReached,
            currencyBalance: currentCurrency,
            level: currentLevel,
          );
        }
        final nextLevel = currentLevel + 1;
        final cost = economy.upgradeCost(type, nextLevel);
        if (cost == null || cost < 0) {
          throw StateError('No valid upgrade cost configured for ${type.name}.');
        }

        final result = progression.upgrade(
          type: type,
          currentCurrency: currentCurrency,
          tryDebit: tryDebit,
          refund: refund,
        );
        if (result != MonsterUpgradeResult.upgraded) {
          return PersistentMonsterUpgrade(
            result: result,
            currencyBalance: currentCurrency,
            level: progression.levelOf(type),
          );
        }

        try {
          await store.save(trustedAccountId, progression);
        } catch (_) {
          // The in-memory progression is discarded; reload sees the old save.
          // Restore the profile currency if durable progression could not commit.
          refund(cost);
          rethrow;
        }
        return PersistentMonsterUpgrade(
          result: result,
          currencyBalance: currentCurrency - cost,
          level: progression.levelOf(type),
        );
      });

  MonsterProgression _restore(Map<String, Object?> data) =>
      MonsterProgression.fromSaveData(
        catalog: catalog,
        growth: growth,
        costForLevel: (type, level) =>
            economy.upgradeCost(type, level) ?? -1,
        data: data,
      );

  Future<T> _serialize<T>(
    String trustedAccountId,
    Future<T> Function() action,
  ) {
    final previous = _accountQueues[trustedAccountId] ?? Future<void>.value();
    final operation = previous.then<T>(
      (_) => action(),
      onError: (_) => action(),
    );
    final tail = operation.then<void>((_) {}, onError: (_) {});
    _accountQueues[trustedAccountId] = tail;
    return operation.whenComplete(() {
      if (identical(_accountQueues[trustedAccountId], tail)) {
        _accountQueues.remove(trustedAccountId);
      }
    });
  }
}
