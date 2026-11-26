import 'hero_progress.dart';
import 'file_hero_progress_store.dart';

/// Economy values are provided by the authoritative server configuration.
/// This interface intentionally has no default prices or upgrade multipliers.
abstract interface class HeroProgressionEconomy {
  int? unlockCost(String weaponId);
  int? upgradeCost(String weaponId, int nextLevel);
  int maxUpgradeLevel(String weaponId);
}

class ProgressionTransaction {
  const ProgressionTransaction({
    required this.result,
    required this.currencyBalance,
    required this.weaponLevel,
  });

  final ProgressionResult result;
  final int currencyBalance;
  final int weaponLevel;

  bool get accepted => result == ProgressionResult.ok;
}

/// Server-side transaction boundary for weapon ownership and upgrades.
///
/// The caller must authenticate the player, load their progression, invoke
/// this service, and persist the changed progression only when [accepted].
class HeroProgressionService {
  const HeroProgressionService(this.economy);

  final HeroProgressionEconomy economy;

  ProgressionTransaction unlock(HeroProgress progress, String weaponId) {
    final cost = economy.unlockCost(weaponId);
    final result = cost == null
        ? ProgressionResult.unknownWeapon
        : progress.unlockWeapon(weaponId, cost: cost);
    return ProgressionTransaction(
      result: result,
      currencyBalance: progress.permanentCurrency,
      weaponLevel: progress.weaponLevel(weaponId),
    );
  }

  ProgressionTransaction upgrade(HeroProgress progress, String weaponId) {
    final cost = economy.upgradeCost(
      weaponId,
      progress.weaponLevel(weaponId) + 1,
    );
    final result = cost == null
        ? ProgressionResult.unknownWeapon
        : progress.upgradeWeapon(
            weaponId,
            cost: cost,
            maxLevel: economy.maxUpgradeLevel(weaponId),
          );
    return ProgressionTransaction(
      result: result,
      currencyBalance: progress.permanentCurrency,
      weaponLevel: progress.weaponLevel(weaponId),
    );
  }
}


/// Persistence-aware progression boundary for authenticated server handlers.
///
/// Account IDs must come from the server's verified authentication context,
/// never from a client-supplied profile string. Operations for one account are
/// serialized so concurrent unlock/upgrade requests cannot spend the same
/// balance twice or overwrite each other's progress.
class PersistentHeroProgressionService {
  PersistentHeroProgressionService({
    required this.store,
    required this.economy,
  });

  final FileHeroProgressStore store;
  final HeroProgressionEconomy economy;
  final Map<String, Future<void>> _accountQueues = {};

  Future<HeroProgress> load(String trustedAccountId) =>
      _serialize(trustedAccountId, () => store.load(trustedAccountId));

  Future<bool> ownsWeapon(
    String trustedAccountId,
    String weaponId,
  ) async {
    final progress = await load(trustedAccountId);
    return progress.ownsWeapon(weaponId);
  }

  Future<ProgressionTransaction> unlockWeapon(
    String trustedAccountId,
    String weaponId,
  ) =>
      _serialize(trustedAccountId, () async {
        final progress = await store.load(trustedAccountId);
        final result = HeroProgressionService(economy).unlock(progress, weaponId);
        if (result.accepted) await store.save(trustedAccountId, progress);
        return result;
      });

  Future<ProgressionTransaction> upgradeWeapon(
    String trustedAccountId,
    String weaponId,
  ) =>
      _serialize(trustedAccountId, () async {
        final progress = await store.load(trustedAccountId);
        final result = HeroProgressionService(economy).upgrade(progress, weaponId);
        if (result.accepted) await store.save(trustedAccountId, progress);
        return result;
      });

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
