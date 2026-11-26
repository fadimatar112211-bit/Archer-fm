import 'hero_roster.dart';

/// Result returned by a player action. A rejected action has [accepted] false
/// and never mutates health, combo progress, or cooldowns.
class CombatActionResult {
  const CombatActionResult({
    required this.accepted,
    required this.messageAr,
    this.damage = 0,
    this.targetHealth = 0,
    this.comboIndex,
    this.cooldownRemainingMs = 0,
  });

  final bool accepted;
  final String messageAr;
  final int damage;
  final int targetHealth;
  final int? comboIndex;
  final int cooldownRemainingMs;
}

/// Small deterministic combat simulation shared by the hero sandbox and tests.
/// It deliberately owns no Flutter/UI dependencies.
class HeroCombatRuntime {
  HeroCombatRuntime({
    required this.hero,
    this.level = 1,
    this.targetMaxHealth = 100000,
    required this.comboResetWindowMs,
  })  : targetHealth = targetMaxHealth,
        selectedWeaponIndex = 0 {
    if (level < 1 || level > heroLevelCap) {
      throw RangeError.range(level, 1, heroLevelCap, 'level');
    }
    if (targetMaxHealth <= 0) {
      throw RangeError.value(targetMaxHealth, 'targetMaxHealth');
    }
    if (comboResetWindowMs <= 0) {
      throw RangeError.value(comboResetWindowMs, 'comboResetWindowMs');
    }
  }

  final HeroCombatDefinition hero;
  final int targetMaxHealth;
  final int comboResetWindowMs;
  int _comboResetRemainingMs = 0;
  int targetHealth;
  int level;
  int experience = 0;
  int selectedWeaponIndex;
  int comboIndex = 0;
  int attackCooldownRemainingMs = 0;
  final List<int> _ultimateCooldowns = [0, 0, 0, 0];

  int get health => hero.healthAt(level);
  double get moveSpeed => hero.moveSpeed;
  HeroWeapon get selectedWeapon => hero.weapons[selectedWeaponIndex];
  List<int> get ultimateCooldowns =>
      List<int>.unmodifiable(_ultimateCooldowns);

  int experienceToNextLevel(int currentLevel) =>
      currentLevel >= heroLevelCap ? 0 : 100 + currentLevel * 50;

  int get experienceRequired => experienceToNextLevel(level);

  void advance(Duration elapsed) {
    final milliseconds = elapsed.inMilliseconds;
    if (milliseconds <= 0) return;
    attackCooldownRemainingMs =
        (attackCooldownRemainingMs - milliseconds).clamp(0, 1 << 30).toInt();
    for (var i = 0; i < _ultimateCooldowns.length; i++) {
      _ultimateCooldowns[i] =
          (_ultimateCooldowns[i] - milliseconds).clamp(0, 1 << 30).toInt();
    }
    if (_comboResetRemainingMs > 0) {
      _comboResetRemainingMs =
          (_comboResetRemainingMs - milliseconds).clamp(0, 1 << 30).toInt();
      if (_comboResetRemainingMs == 0) comboIndex = 0;
    }
  }

  /// Damage, crowd-control interruption or other server-confirmed interruption
  /// can reset the combo without changing Ultimate cooldowns.
  void resetCombo() {
    comboIndex = 0;
    _comboResetRemainingMs = 0;
  }

  CombatActionResult selectWeapon(int index) {
    if (index < 0 || index >= hero.weapons.length) {
      throw RangeError.index(index, hero.weapons, 'index');
    }
    selectedWeaponIndex = index;
    comboIndex = 0;
    return CombatActionResult(
      accepted: true,
      messageAr: 'تم تجهيز ${selectedWeapon.nameAr}',
      targetHealth: targetHealth,
    );
  }

  CombatActionResult attack() {
    if (attackCooldownRemainingMs > 0) {
      return CombatActionResult(
        accepted: false,
        messageAr: 'الهجوم قيد التبريد',
        targetHealth: targetHealth,
        cooldownRemainingMs: attackCooldownRemainingMs,
      );
    }
    final currentHit = comboIndex;
    final raw = hero.damageAt(level) *
        selectedWeapon.damageMultiplier *
        const [1.0, 1.05, 1.1, 1.2, 1.55][currentHit];
    final damage = raw.round();
    targetHealth = (targetHealth - damage).clamp(0, targetMaxHealth).toInt();
    comboIndex = (comboIndex + 1) % comboHitCount;
    _comboResetRemainingMs = comboResetWindowMs;
    attackCooldownRemainingMs = selectedWeapon.cooldownMs;
    return CombatActionResult(
      accepted: true,
      messageAr: 'ضربة ${currentHit + 1} من 5',
      damage: damage,
      targetHealth: targetHealth,
      comboIndex: currentHit + 1,
      cooldownRemainingMs: attackCooldownRemainingMs,
    );
  }

  CombatActionResult useUltimate(int index) {
    if (index < 0 || index >= hero.ultimates.length) {
      throw RangeError.index(index, hero.ultimates, 'index');
    }
    final ultimate = hero.ultimates[index];
    if (level < ultimate.unlockLevel) {
      return CombatActionResult(
        accepted: false,
        messageAr: 'تُفتح عند المستوى ${ultimate.unlockLevel}',
        targetHealth: targetHealth,
      );
    }
    final remaining = _ultimateCooldowns[index];
    if (remaining > 0) {
      return CombatActionResult(
        accepted: false,
        messageAr: 'المهارة قيد التبريد',
        targetHealth: targetHealth,
        cooldownRemainingMs: remaining,
      );
    }
    final damage = (hero.damageAt(level) * ultimate.damageMultiplier).round();
    targetHealth = (targetHealth - damage).clamp(0, targetMaxHealth).toInt();
    _ultimateCooldowns[index] = ultimate.cooldownMs;
    return CombatActionResult(
      accepted: true,
      messageAr: 'تم تنفيذ ${ultimate.nameAr}',
      damage: damage,
      targetHealth: targetHealth,
      cooldownRemainingMs: ultimate.cooldownMs,
    );
  }

  /// Awards XP and applies every level gained, stopping at the level-40 cap.
  int gainExperience(int amount) {
    if (amount < 0) throw RangeError.value(amount, 'amount');
    if (level == heroLevelCap || amount == 0) return 0;
    experience += amount;
    var gained = 0;
    while (level < heroLevelCap) {
      final required = experienceToNextLevel(level);
      if (experience < required) break;
      experience -= required;
      level++;
      gained++;
    }
    if (level == heroLevelCap) experience = 0;
    return gained;
  }

  void resetTarget() {
    targetHealth = targetMaxHealth;
    resetCombo();
  }
}
