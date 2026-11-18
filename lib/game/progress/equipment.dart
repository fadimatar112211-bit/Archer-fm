import 'dart:math' as math;

/// Equipment slots, rarities and the item model.
///
/// Confirmed rules (`PROJECT_STATUS.md` §Progression, equipment, and rewards):
/// six slots (weapon, helmet, armor, boots, ring, necklace), five rarities
/// (Common, Rare, Epic, Legendary, Mythic), equipment levels cap at 40,
/// equipment/weapons come from gameplay and chests, duplicates become upgrade
/// materials, unwanted equipment can be sold, and chests contain equipment and
/// weapons only.
///
/// The stat values and sell values below are **provisional balancing values**
/// (see `PROJECT_STATUS.md` §5): the requirements define slots, rarities and
/// the level cap, but not final stat curves or prices.

enum EquipmentSlot { weapon, helmet, armor, boots, ring, necklace }

const int equipmentSlotCount = 6;

extension EquipmentSlotInfo on EquipmentSlot {
  String get nameAr => switch (this) {
        EquipmentSlot.weapon => 'سلاح',
        EquipmentSlot.helmet => 'خوذة',
        EquipmentSlot.armor => 'درع',
        EquipmentSlot.boots => 'حذاء',
        EquipmentSlot.ring => 'خاتم',
        EquipmentSlot.necklace => 'قلادة',
      };
}

enum EquipmentRarity { common, rare, epic, legendary, mythic }

const int equipmentRarityCount = 5;

extension EquipmentRarityInfo on EquipmentRarity {
  String get nameAr => switch (this) {
        EquipmentRarity.common => 'عادي',
        EquipmentRarity.rare => 'نادر',
        EquipmentRarity.epic => 'ملحمي',
        EquipmentRarity.legendary => 'أسطوري',
        EquipmentRarity.mythic => 'خرافي',
      };

  int get color => switch (this) {
        EquipmentRarity.common => 0xFFB8C2C8,
        EquipmentRarity.rare => 0xFF57B7FF,
        EquipmentRarity.epic => 0xFFB57BFF,
        EquipmentRarity.legendary => 0xFFFFB52E,
        EquipmentRarity.mythic => 0xFFFF5A8A,
      };

  /// Provisional relative power of the rarity.
  double get power => switch (this) {
        EquipmentRarity.common => 1.0,
        EquipmentRarity.rare => 1.25,
        EquipmentRarity.epic => 1.6,
        EquipmentRarity.legendary => 2.0,
        EquipmentRarity.mythic => 2.5,
      };

  /// Provisional chest appearance weight out of 100.
  int get chestWeight => switch (this) {
        EquipmentRarity.common => 55,
        EquipmentRarity.rare => 27,
        EquipmentRarity.epic => 12,
        EquipmentRarity.legendary => 5,
        EquipmentRarity.mythic => 1,
      };

  /// Provisional sale value before the level bonus.
  int get baseSellValue => switch (this) {
        EquipmentRarity.common => 20,
        EquipmentRarity.rare => 45,
        EquipmentRarity.epic => 90,
        EquipmentRarity.legendary => 180,
        EquipmentRarity.mythic => 360,
      };

  /// Provisional duplicate-material value.
  int get duplicateMaterialValue => switch (this) {
        EquipmentRarity.common => 1,
        EquipmentRarity.rare => 2,
        EquipmentRarity.epic => 3,
        EquipmentRarity.legendary => 5,
        EquipmentRarity.mythic => 8,
      };
}

/// Equipment levels cap at 40, as confirmed by the requirements.
const int equipmentMaxLevel = 40;

/// One owned equipment item. Levels are immutable; upgrading replaces the item
/// so saved profiles never share mutable state.
class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.slot,
    required this.rarity,
    this.level = 1,
  });

  final String id;
  final EquipmentSlot slot;
  final EquipmentRarity rarity;
  final int level;

  int get cappedLevel => level.clamp(1, equipmentMaxLevel);
  bool get isMaxLevel => cappedLevel >= equipmentMaxLevel;

  EquipmentItem withLevel(int newLevel) => EquipmentItem(
        id: id,
        slot: slot,
        rarity: rarity,
        level: newLevel.clamp(1, equipmentMaxLevel),
      );

  /// Duplicate detection uses the item template (slot + rarity), because the
  /// requirements do not define named unique items.
  bool isDuplicateOf(EquipmentItem other) =>
      slot == other.slot && rarity == other.rarity;

  /// Provisional HP fraction added while equipped.
  double get hpBonusFraction {
    final perLevel = switch (slot) {
      EquipmentSlot.helmet => 0.008,
      EquipmentSlot.armor => 0.010,
      EquipmentSlot.necklace => 0.006,
      _ => 0.0,
    };
    return perLevel * cappedLevel * rarity.power;
  }

  /// Provisional damage fraction added while equipped.
  double get damageBonusFraction {
    final perLevel = switch (slot) {
      EquipmentSlot.weapon => 0.008,
      EquipmentSlot.ring => 0.005,
      _ => 0.0,
    };
    return perLevel * cappedLevel * rarity.power;
  }

  /// Provisional movement fraction added while equipped.
  double get moveBonusFraction =>
      slot == EquipmentSlot.boots
          ? 0.0025 * cappedLevel * rarity.power
          : 0.0;

  /// Provisional sale value: rarity base plus a small level bonus.
  int get sellValue => rarity.baseSellValue + (cappedLevel - 1) * 2;

  /// Provisional upgrade price in permanent currency.
  int get upgradeCurrencyCost => 40 + (cappedLevel - 1) * 20;

  /// Provisional upgrade price in equipment materials.
  int get upgradeMaterialCost => 1 + (cappedLevel - 1) ~/ 10;

  Map<String, dynamic> toJson() => {
        'id': id,
        'slot': slot.name,
        'rarity': rarity.name,
        'level': cappedLevel,
      };

  static EquipmentItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final slotName = raw['slot'];
    final rarityName = raw['rarity'];
    final level = raw['level'];
    if (id is! String || slotName is! String || rarityName is! String) {
      return null;
    }
    final slot = EquipmentSlot.values
        .where((candidate) => candidate.name == slotName)
        .firstOrNull;
    final rarity = EquipmentRarity.values
        .where((candidate) => candidate.name == rarityName)
        .firstOrNull;
    if (slot == null || rarity == null) return null;
    return EquipmentItem(
      id: id,
      slot: slot,
      rarity: rarity,
      level: level is int ? level.clamp(1, equipmentMaxLevel) : 1,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Combined combat bonuses from all equipped items. Defaults are neutral so a
/// profile without equipment keeps the hero's old stats exactly.
class EquipmentBonuses {
  const EquipmentBonuses({
    this.hpMultiplier = 1.0,
    this.damageMultiplier = 1.0,
    this.moveMultiplier = 1.0,
  });

  final double hpMultiplier;
  final double damageMultiplier;
  final double moveMultiplier;

  static EquipmentBonuses forItems(Iterable<EquipmentItem> equipped) {
    var hp = 0.0;
    var damage = 0.0;
    var move = 0.0;
    for (final item in equipped) {
      hp += item.hpBonusFraction;
      damage += item.damageBonusFraction;
      move += item.moveBonusFraction;
    }
    return EquipmentBonuses(
      hpMultiplier: 1 + hp,
      damageMultiplier: 1 + damage,
      moveMultiplier: 1 + move,
    );
  }
}

/// Deterministic chest roll: equipment and weapons only, weighted by rarity.
/// The caller supplies the match RNG so a given match seed always yields the
/// same chest contents.
EquipmentItem rollChestItem(math.Random random, {required String id}) {
  final roll = random.nextInt(100);
  var threshold = 0;
  var rarity = EquipmentRarity.common;
  for (final candidate in EquipmentRarity.values) {
    threshold += candidate.chestWeight;
    if (roll < threshold) {
      rarity = candidate;
      break;
    }
  }
  final slot = EquipmentSlot.values[random.nextInt(EquipmentSlot.values.length)];
  return EquipmentItem(id: id, slot: slot, rarity: rarity);
}
