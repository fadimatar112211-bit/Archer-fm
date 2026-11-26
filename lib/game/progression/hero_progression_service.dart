import 'hero_progress.dart';

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
