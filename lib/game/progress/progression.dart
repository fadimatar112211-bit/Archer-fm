import 'dart:math' as math;

import 'equipment.dart';
import 'hero_progress.dart';

/// The four permanent upgrade categories. Every category spends the shared
/// permanent currency plus its **own** material, as required by the spec.
enum ProgressionMaterial { hero, monster, equipment, capacity }

const int progressionMaterialCount = 4;

extension ProgressionMaterialInfo on ProgressionMaterial {
  String get nameAr => switch (this) {
        ProgressionMaterial.hero => 'شظايا بطل',
        ProgressionMaterial.monster => 'أنسجة وحوش',
        ProgressionMaterial.equipment => 'خامات معدات',
        ProgressionMaterial.capacity => 'بلورات سعة',
      };

  int get color => switch (this) {
        ProgressionMaterial.hero => 0xFF62E86C,
        ProgressionMaterial.monster => 0xFFFF7A5A,
        ProgressionMaterial.equipment => 0xFF57B7FF,
        ProgressionMaterial.capacity => 0xFFFFD257,
      };
}

/// Result of adding a chest item to the inventory.
enum EquipmentAddResult { added, duplicate }

class EquipmentAddOutcome {
  const EquipmentAddOutcome(this.result, {this.materialGained = 0});

  final EquipmentAddResult result;
  final int materialGained;

  bool get isDuplicate => result == EquipmentAddResult.duplicate;
}

/// Confirmed starting carry capacity; permanent upgrades raise it.
const int baseCarryCapacity = 500;
const int capacityUpgradeStep = 50;
const int maxCapacityLevel = 20;

/// Hero stat upgrades are separate from the XP level. Provisional cap and
/// bonuses, because the spec fixes only the equipment level cap.
const int maxHeroUpgradeLevel = 40;

/// Mutable account/hero progression used by the shop, equipment page and the
/// match screen. Persistence still happens through [HeroProgress].
class ProgressionController {
  ProgressionController({
    required this.heroId,
    int currency = 0,
    Map<ProgressionMaterial, int>? materials,
    List<EquipmentItem>? equipment,
    Map<EquipmentSlot, String>? equipped,
    int capacityLevel = 0,
    int heroUpgradeLevel = 0,
  })  : currency = currency < 0 ? 0 : currency,
        materials = {
          for (final material in ProgressionMaterial.values)
            material: math.max(0, materials?[material] ?? 0),
        },
        equipment = [...?equipment],
        equipped = {...?equipped},
        capacityLevel = capacityLevel.clamp(0, maxCapacityLevel),
        heroUpgradeLevel = heroUpgradeLevel.clamp(0, maxHeroUpgradeLevel) {
    _repairEquipped();
  }

  factory ProgressionController.fromProgress(
    String heroId,
    HeroProgress progress,
  ) {
    return ProgressionController(
      heroId: heroId,
      currency: progress.essence,
      materials: {
        for (final entry in progress.materials.entries)
          if (ProgressionMaterial.values
              .any((material) => material.name == entry.key))
            ProgressionMaterial.values
                    .firstWhere((material) => material.name == entry.key):
                entry.value,
      },
      equipment: progress.equipment,
      equipped: {
        for (final entry in progress.equipped.entries)
          if (EquipmentSlot.values.any((slot) => slot.name == entry.key))
            EquipmentSlot.values
                    .firstWhere((slot) => slot.name == entry.key):
                entry.value,
      },
      capacityLevel: progress.capacityLevel,
      heroUpgradeLevel: progress.heroUpgradeLevel,
    );
  }

  final String heroId;
  int currency;
  final Map<ProgressionMaterial, int> materials;
  final List<EquipmentItem> equipment;
  final Map<EquipmentSlot, String> equipped;
  int capacityLevel;
  int heroUpgradeLevel;

  int materialOf(ProgressionMaterial material) => materials[material] ?? 0;

  void addMaterial(ProgressionMaterial material, int amount) {
    if (amount <= 0) return;
    materials[material] = materialOf(material) + amount;
  }

  bool spendMaterial(ProgressionMaterial material, int amount) {
    if (amount <= 0) return true;
    if (materialOf(material) < amount) return false;
    materials[material] = materialOf(material) - amount;
    return true;
  }

  bool spendCurrency(int amount) {
    if (amount < 0 || currency < amount) return false;
    currency -= amount;
    return true;
  }

  // ---- Equipment ------------------------------------------------------------

  EquipmentItem? itemById(String id) {
    for (final item in equipment) {
      if (item.id == id) return item;
    }
    return null;
  }

  EquipmentItem? equippedIn(EquipmentSlot slot) {
    final id = equipped[slot];
    return id == null ? null : itemById(id);
  }

  /// Items currently worn, one per slot.
  List<EquipmentItem> get equippedItems => [
        for (final slot in EquipmentSlot.values)
          if (equippedIn(slot) != null) equippedIn(slot)!,
      ];

  EquipmentBonuses get bonuses {
    final itemBonuses = EquipmentBonuses.forItems(equippedItems);
    return EquipmentBonuses(
      hpMultiplier: itemBonuses.hpMultiplier *
          (1 + heroUpgradeLevel * 0.015),
      damageMultiplier: itemBonuses.damageMultiplier *
          (1 + heroUpgradeLevel * 0.010),
      moveMultiplier: itemBonuses.moveMultiplier,
    );
  }

  int get carryCapacity =>
      baseCarryCapacity + capacityLevel * capacityUpgradeStep;

  /// Adds a chest item. A duplicate template becomes equipment materials;
  /// a new item is stored and auto-equipped when its slot is empty.
  EquipmentAddOutcome addEquipment(EquipmentItem item) {
    final duplicate = equipment.any((owned) => owned.isDuplicateOf(item));
    if (duplicate) {
      final gained = item.rarity.duplicateMaterialValue;
      addMaterial(ProgressionMaterial.equipment, gained);
      return EquipmentAddOutcome(
        EquipmentAddResult.duplicate,
        materialGained: gained,
      );
    }
    var id = item.id;
    var suffix = 1;
    while (itemById(id) != null) {
      id = '${item.id}_${suffix++}';
    }
    final stored = EquipmentItem(
      id: id,
      slot: item.slot,
      rarity: item.rarity,
      level: item.level,
    );
    equipment.add(stored);
    if (equippedIn(stored.slot) == null) {
      equipped[stored.slot] = stored.id;
    }
    return const EquipmentAddOutcome(EquipmentAddResult.added);
  }

  bool equip(String itemId) {
    final item = itemById(itemId);
    if (item == null) return false;
    equipped[item.slot] = item.id;
    return true;
  }

  bool unequip(EquipmentSlot slot) {
    if (!equipped.containsKey(slot)) return false;
    equipped.remove(slot);
    return true;
  }

  /// Sells an unequipped item for permanent currency.
  bool sell(String itemId) {
    final item = itemById(itemId);
    if (item == null) return false;
    if (equipped.values.contains(itemId)) return false;
    equipment.removeWhere((owned) => owned.id == itemId);
    currency += item.sellValue;
    return true;
  }

  bool canUpgradeItem(EquipmentItem item) =>
      !item.isMaxLevel &&
      currency >= item.upgradeCurrencyCost &&
      materialOf(ProgressionMaterial.equipment) >=
          item.upgradeMaterialCost;

  /// Upgrades one item to the next level, capped at 40.
  bool upgradeItem(String itemId) {
    final item = itemById(itemId);
    if (item == null || !canUpgradeItem(item)) return false;
    currency -= item.upgradeCurrencyCost;
    materials[ProgressionMaterial.equipment] =
        materialOf(ProgressionMaterial.equipment) -
            item.upgradeMaterialCost;
    final index = equipment.indexWhere((owned) => owned.id == itemId);
    equipment[index] = item.withLevel(item.cappedLevel + 1);
    return true;
  }

  // ---- Hero and capacity ----------------------------------------------------

  int get heroUpgradeCurrencyCost =>
      heroUpgradeLevel >= maxHeroUpgradeLevel
          ? 0
          : 60 + heroUpgradeLevel * 30;

  int get heroUpgradeMaterialCost =>
      heroUpgradeLevel >= maxHeroUpgradeLevel ? 0 : 3 + heroUpgradeLevel;

  bool get canUpgradeHero =>
      heroUpgradeLevel < maxHeroUpgradeLevel &&
      currency >= heroUpgradeCurrencyCost &&
      materialOf(ProgressionMaterial.hero) >= heroUpgradeMaterialCost;

  bool upgradeHero() {
    if (!canUpgradeHero) return false;
    currency -= heroUpgradeCurrencyCost;
    materials[ProgressionMaterial.hero] =
        materialOf(ProgressionMaterial.hero) - heroUpgradeMaterialCost;
    heroUpgradeLevel++;
    return true;
  }

  int get capacityCurrencyCost =>
      capacityLevel >= maxCapacityLevel ? 0 : 80 + capacityLevel * 40;

  int get capacityMaterialCost =>
      capacityLevel >= maxCapacityLevel ? 0 : 4 + capacityLevel * 2;

  bool get canUpgradeCapacity =>
      capacityLevel < maxCapacityLevel &&
      currency >= capacityCurrencyCost &&
      materialOf(ProgressionMaterial.capacity) >= capacityMaterialCost;

  bool upgradeCapacity() {
    if (!canUpgradeCapacity) return false;
    currency -= capacityCurrencyCost;
    materials[ProgressionMaterial.capacity] =
        materialOf(ProgressionMaterial.capacity) - capacityMaterialCost;
    capacityLevel++;
    return true;
  }

  /// Overall account power shown on roster/shop pages (provisional).
  int get accountPower {
    var power = 1 + heroUpgradeLevel + capacityLevel;
    for (final item in equippedItems) {
      power += (item.rarity.index + 1) * item.cappedLevel;
    }
    return power;
  }

  /// Drops equipped ids that no longer point at an owned item.
  void _repairEquipped() {
    equipped.removeWhere((slot, id) => itemById(id) == null);
  }
}
