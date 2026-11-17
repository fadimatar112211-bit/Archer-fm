/// Data-driven combat kit for one hero.
///
/// The kit is the single source of truth for a hero's base stats, the five-hit
/// normal-attack chain and the four special abilities. Gameplay code reads it,
/// the ability buttons render from it and the tests assert against it, so the
/// design numbers (100/110/120/135/155% combo, ability unlocks at levels
/// 1/10/20/30) live here and nowhere else.
library;

/// One step of the normal-attack combo chain.
class ComboHit {
  const ComboHit({
    required this.index,
    required this.multiplier,
    required this.labelAr,
  });

  /// 1-based combo position (1..5).
  final int index;

  /// Damage multiplier against the hero's base damage.
  final double multiplier;

  final String labelAr;
}

/// One special ability of a hero.
class AbilityDef {
  const AbilityDef({
    required this.id,
    required this.nameAr,
    required this.descAr,
    required this.unlockLevel,
    required this.cooldownMs,
    required this.energyCost,
  });

  final String id;
  final String nameAr;
  final String descAr;

  /// Hero level required before the ability can be used (1, 10, 20 or 30).
  final int unlockLevel;

  final int cooldownMs;
  final int energyCost;
}

/// Base combat statistics and chain definition for one hero.
class HeroKit {
  const HeroKit({
    required this.heroId,
    required this.nameAr,
    required this.weaponAr,
    required this.baseDamage,
    required this.baseMaxHp,
    required this.baseMaxEnergy,
    required this.energyRegenPerSec,
    required this.moveSpeed,
    required this.comboWindowMs,
    required this.comboHits,
    required this.abilities,
    required this.attackPace,
    required this.playable,
  });

  final String heroId;
  final String nameAr;
  final String weaponAr;

  /// Damage of a single 100% hit before combo/ability multipliers.
  final double baseDamage;
  final double baseMaxHp;
  final double baseMaxEnergy;
  final double energyRegenPerSec;
  final double moveSpeed;

  /// Time (ms) the player has to chain into the next combo hit.
  final int comboWindowMs;

  /// Exactly five chain steps for the normal attack.
  final List<ComboHit> comboHits;

  /// Exactly four abilities, ordered by unlock level.
  final List<AbilityDef> abilities;

  /// Playback rate applied to the authored attack clip so combat feels snappy
  /// without re-rendering sprites. Events stay frame-based, so weapon timing
  /// and damage stay in sync at any pace.
  final double attackPace;

  /// False while a hero only has viewer assets but no full combat build yet.
  final bool playable;

  ComboHit comboHit(int index) => comboHits[(index - 1).clamp(0, 4)];

  /// Abilities available at or below [level], in unlock order.
  List<AbilityDef> abilitiesUnlockedAt(int level) =>
      abilities.where((a) => a.unlockLevel <= level).toList();

  AbilityDef? abilityById(String id) {
    for (final ability in abilities) {
      if (ability.id == id) return ability;
    }
    return null;
  }
}

/// The shared five-step chain: 100/110/120/135/155% of base damage.
const List<ComboHit> standardCombo = [
  ComboHit(index: 1, multiplier: 1.00, labelAr: 'ضربة أولى'),
  ComboHit(index: 2, multiplier: 1.10, labelAr: 'ضربة ثانية'),
  ComboHit(index: 3, multiplier: 1.20, labelAr: 'ضربة ثالثة'),
  ComboHit(index: 4, multiplier: 1.35, labelAr: 'ضربة رابعة'),
  ComboHit(index: 5, multiplier: 1.55, labelAr: 'ضربة خامسة'),
];

/// Ranger (`ranger_new`) — green energy bow. The full combat build.
const HeroKit rangerNewKit = HeroKit(
  heroId: 'ranger_new',
  nameAr: 'الرامي الجديد',
  weaponAr: 'قوس الطاقة الخضراء',
  baseDamage: 12,
  baseMaxHp: 100,
  baseMaxEnergy: 100,
  energyRegenPerSec: 7,
  moveSpeed: 168,
  comboWindowMs: 1800,
  comboHits: standardCombo,
  attackPace: 1.6,
  playable: true,
  abilities: [
    AbilityDef(
      id: 'multi_shot',
      nameAr: 'وابل متعدد',
      descAr: 'خمسة سهام خضراء تتفرّج لتغطي زاوية واسعة، كل سهم بضرر 60%.',
      unlockLevel: 1,
      cooldownMs: 6000,
      energyCost: 25,
    ),
    AbilityDef(
      id: 'piercing_shot',
      nameAr: 'سهم ثاقب',
      descAr: 'سهم واحد خارق يخترق كل الأعداء في خطه بضرر 220%.',
      unlockLevel: 10,
      cooldownMs: 8000,
      energyCost: 30,
    ),
    AbilityDef(
      id: 'arrow_rain',
      nameAr: 'مطر السهام',
      descAr: 'مطر سهم خضراء على منطقة محددة، 8 موجات بضرر 35% لكل موجة.',
      unlockLevel: 20,
      cooldownMs: 12000,
      energyCost: 40,
    ),
    AbilityDef(
      id: 'gale_surge',
      nameAr: 'اندفاع الرياح',
      descAr: 'طاقة خضراء تسرّع الطلقات والحركة 6 ثوانٍ وتزيد الضرر 20%.',
      unlockLevel: 30,
      cooldownMs: 20000,
      energyCost: 35,
    ),
  ],
);

/// Kits for heroes still awaiting their combat build (assets are done or in
/// progress, gameplay comes in later phases in roster order).
const HeroKit flameKit = HeroKit(
  heroId: 'flame',
  nameAr: 'فارس اللهب',
  weaponAr: 'سيف اللهب العظيم',
  baseDamage: 16,
  baseMaxHp: 110,
  baseMaxEnergy: 100,
  energyRegenPerSec: 7,
  moveSpeed: 160,
  comboWindowMs: 1800,
  comboHits: standardCombo,
  attackPace: 1.4,
  playable: false,
  abilities: [],
);

const HeroKit shadowKit = HeroKit(
  heroId: 'shadow',
  nameAr: 'ظل الليل',
  weaponAr: 'خنجران توأمان',
  baseDamage: 14,
  baseMaxHp: 95,
  baseMaxEnergy: 100,
  energyRegenPerSec: 7,
  moveSpeed: 178,
  comboWindowMs: 1800,
  comboHits: standardCombo,
  attackPace: 1.4,
  playable: false,
  abilities: [],
);

const HeroKit stormKit = HeroKit(
  heroId: 'storm',
  nameAr: 'حامل العاصفة',
  weaponAr: 'رمح الصاعقة',
  baseDamage: 15,
  baseMaxHp: 100,
  baseMaxEnergy: 100,
  energyRegenPerSec: 7,
  moveSpeed: 164,
  comboWindowMs: 1800,
  comboHits: standardCombo,
  attackPace: 1.4,
  playable: false,
  abilities: [],
);

HeroKit kitForHero(String heroId) {
  switch (heroId) {
    case 'ranger_new':
      return rangerNewKit;
    case 'flame':
      return flameKit;
    case 'shadow':
      return shadowKit;
    case 'storm':
      return stormKit;
    default:
      return rangerNewKit;
  }
}
