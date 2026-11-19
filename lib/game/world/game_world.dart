import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../combat/combo.dart';
import '../combat/hero_kit.dart';
import '../monsters/monster_models.dart';
import 'arena_map.dart';
import '../progress/equipment.dart';
import '../progress/match_xp.dart';
import '../progress/progression.dart';
import '../progress/xp.dart';
import 'castle_system.dart';
import 'fog_of_war.dart';
import 'mine_system.dart';

/// Logical size of the camera window in world units. The match map itself is
/// larger and generated per match (see [ArenaMap]); these constants only
/// describe how much of it is visible at once.
const double arenaWidth = 960;
const double arenaHeight = 540;

/// Camera follow smoothing. 0 = instant snap to hero, 1 = never moves.
/// Values around 0.10–0.20 give a smooth Archero-style follow without
/// feeling sluggish.
const double cameraLerpFactor = 0.14;

double _clampD(double value, double lo, double hi) =>
    value < lo ? lo : (value > hi ? hi : value);

/// Events the world emits for the UI layer each frame.
sealed class WorldEvent {
  const WorldEvent();
}

/// Which simulation system actually landed a hit. XP is only awarded for hero
/// or owned-monster hits; hostile hits never generate rewards.
enum DamageOrigin { hero, monster, enemy }

class EnemyKilledEvent extends WorldEvent {
  const EnemyKilledEvent(
    this.enemyKind,
    this.xpGained, {
    this.enemyId = '',
    this.killedBy = DamageOrigin.hero,
    this.monsterType,
  });
  final String enemyKind;
  final int xpGained;
  final String enemyId;
  final DamageOrigin killedBy;
  final MonsterType? monsterType;
}

/// Real damage dealt by one of the player's monsters to a hostile unit. The
/// XP ledger uses [unitId] to deduplicate the same unit across repeated hits.
class MonsterDamageEvent extends WorldEvent {
  const MonsterDamageEvent({
    required this.type,
    required this.unitId,
    required this.amount,
    this.isKill = false,
  });
  final MonsterType type;
  final String unitId;
  final double amount;
  final bool isKill;
}

/// Emitted when one of the player's permanently-owned monsters dies. The
/// monster is gone for the rest of the match and must be repurchased.
class ArmyMonsterLostEvent extends WorldEvent {
  const ArmyMonsterLostEvent(this.type);
  final MonsterType type;
}

class LevelUpEvent extends WorldEvent {
  const LevelUpEvent(this.newLevel, this.unlockedAbilityIds);
  final int newLevel;
  final List<String> unlockedAbilityIds;
}

class PlayerDamagedEvent extends WorldEvent {
  const PlayerDamagedEvent(this.amount);
  final double amount;
}

class PlayerDiedEvent extends WorldEvent {
  const PlayerDiedEvent({this.lostResources = 0});
  final int lostResources;
}

class PlayerRespawnedEvent extends WorldEvent {
  const PlayerRespawnedEvent();
}

class AbilityReadyEvent extends WorldEvent {
  const AbilityReadyEvent(this.abilityId);
  final String abilityId;
}

/// A player finished capturing a mine (neutral or taken from an opponent).
class MineCapturedEvent extends WorldEvent {
  const MineCapturedEvent({
    required this.size,
    required this.ownerId,
    this.mineKey = '',
    this.neutral = false,
  });
  final MineSize size;
  final String ownerId;

  /// Stable identity of the mine, used by the XP ledger to pay once.
  final String mineKey;

  /// True when the mine was neutral before this capture.
  final bool neutral;
}

/// Resource pickups were touched and added to the match wallet.
class MineResourceCollectedEvent extends WorldEvent {
  const MineResourceCollectedEvent({
    required this.amount,
    required this.total,
    this.pickupIds = const [],
  });
  final int amount;
  final int total;

  /// Ids of the real pickups consumed by this touch.
  final List<String> pickupIds;
}

/// One crystal of [ownerId] lost all its HP.
class CrystalDestroyedEvent extends WorldEvent {
  const CrystalDestroyedEvent({
    required this.ownerId,
    required this.slot,
    this.destroyedBy = DamageOrigin.hero,
    this.monsterType,
  });
  final String ownerId;
  final int slot;
  final DamageOrigin destroyedBy;
  final MonsterType? monsterType;
}

/// Every crystal of [ownerId] is destroyed: the castle disappears until its
/// first rebuild.
class CastleFellEvent extends WorldEvent {
  const CastleFellEvent(this.ownerId);
  final String ownerId;
}

/// A crystal was rebuilt during combat.
class CrystalRebuiltEvent extends WorldEvent {
  const CrystalRebuiltEvent({required this.slot, required this.cost});
  final int slot;
  final int cost;
}

/// The hero touched a map chest. The screen adds [item] to the persistent
/// inventory (or converts a duplicate into equipment materials).
class ChestOpenedEvent extends WorldEvent {
  const ChestOpenedEvent(this.item);
  final EquipmentItem item;
}

/// Simulation state of the playable hero.
class PlayerState {
  Offset position =
      const Offset(arenaWidth / 2, arenaHeight * 0.62);
  Offset facing = const Offset(0, 1);
  double hp = 0;
  double energy = 0;
  bool dead = false;
  int respawnAtMs = 0;

  /// Invulnerability window (Shadow's veil / respawn) end time.
  int invulnerableUntilMs = 0;

  /// Movement boost from Shadow's veil.
  int speedBoostUntilMs = 0;

  /// Stat buff from `gale_surge` / `inferno_rage` / `static_field` / etc.
  int buffUntilMs = 0;

  /// Extra charge window from Storm's `static_field` (separate from the
  /// generic stat buff so `tempest_rage` does not freeze on its own).
  int staticFieldUntilMs = 0;

  /// Freeze (Storm) and stun (Flame) disable a target temporarily.
  int frozenUntilMs = 0;
  int stunnedUntilMs = 0;

  bool disabledAt(int now) => now < frozenUntilMs || now < stunnedUntilMs;
}

/// Simulation state of one monster.
///
/// Both sides use this class: `world.enemies` are hostile monsters and
/// `world.army` are the player's permanently-owned monsters. [type] drives the
/// catalog stats, [team] drives targeting, and [walkPhase] / [attackAnimUntilMs]
/// drive the procedural walk and attack animations painted by `ArenaPainter`.
class EnemyState {
  EnemyState({
    required this.id,
    required this.kind,
    required this.position,
    required this.maxHp,
    required this.speed,
    required this.contactDamage,
    required this.xpValue,
    bool ranged = false,
    MonsterType? type,
    this.team = MonsterTeam.enemy,
    this.level = 1,
    double? radius,
  })  : type = type ?? monsterTypeFromName(kind),
        ranged = ranged ||
            (type ?? monsterTypeFromName(kind)) == MonsterType.ranged,
        radius = radius ?? MonsterCatalog.def(
            type ?? monsterTypeFromName(kind)).radius,
        hp = maxHp;

  final String id;

  /// Legacy display name (`slime`, `archer`, `brute`) or the production type
  /// name. Kept for kill events and old captures; gameplay uses [type].
  final String kind;
  final MonsterType type;
  final MonsterTeam team;
  final int level;
  final double radius;

  Offset position;
  double hp;
  final double maxHp;
  double speed;
  final double contactDamage;
  final int xpValue;

  /// Ranged monsters keep distance and shoot instead of closing in.
  final bool ranged;

  double attackCooldownUntilMs = 0;
  int windupUntilMs = 0;

  /// Burn/dot state (Flame's flame_slash).
  int burnTicksLeft = 0;
  int burnNextTickAtMs = 0;
  double burnTickDamage = 0;

  /// Visual hit flash timer (ms timestamp).
  int hitFlashUntilMs = 0;
  Offset facing = const Offset(0, 1);

  /// Temporary disable effects. The spec requires freeze and stun to stop a
  /// target for a short time; neither grants damage resistance.
  int frozenUntilMs = 0;
  int stunnedUntilMs = 0;

  bool disabledAt(int now) => now < frozenUntilMs || now < stunnedUntilMs;

  // ---- Animation / behaviour state -----------------------------------------

  /// True while the monster is actually stepping this frame.
  bool moving = false;

  /// Distance-driven gait clock. Two legs use `sin(walkPhase)` and
  /// `sin(walkPhase + pi)`, so they alternate like a real walk cycle.
  double walkPhase = 0;

  /// End timestamp of the current attack lunge.
  int attackAnimUntilMs = 0;

  /// Runner dash window / schedule.
  int dashUntilMs = 0;
  int nextDashAtMs = 0;

  /// Stalker strafe phase offset so the pack does not move in lockstep.
  double strafePhase = 0;

  /// Stable formation slot used when the army has no target nearby.
  int groupSlot = 0;

  MonsterAnimState animStateAt(int nowMs) {
    if (hp <= 0) return MonsterAnimState.death;
    if (nowMs < attackAnimUntilMs) return MonsterAnimState.attack;
    if (moving) return MonsterAnimState.walk;
    return MonsterAnimState.idle;
  }

  double get hpRatio => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);
}

/// One live arrow in the air. The `hitIds` set guarantees a single projectile
/// can damage a given enemy at most once.
class ProjectileState {
  ProjectileState({
    required this.id,
    required this.position,
    required this.velocity,
    required this.damage,
    required this.pierceLeft,
    required this.maxTravel,
    required this.tint,
    required this.big,
    bool? hostile,
    this.sourceMonsterId,
    this.sourceMonsterType,
    this.visualHeight = 0,
  }) : hostile = hostile ?? tint == 0xFFFF7A5A;

  final String id;
  Offset position;
  final Offset velocity;
  final double damage;
  int pierceLeft;
  double traveled = 0;
  final double maxTravel;
  final int tint;
  final bool big;

  /// Visual lift above the ground anchor, in world units. Depth sorting and
  /// collision continue to use [position]; only the rendered arrow is lifted.
  final double visualHeight;

  /// True while this projectile belongs to the hostile side. Hostile shots
  /// damage the player and the player's monsters; friendly shots (the hero and
  /// the player's ranged monsters) damage hostile monsters only.
  final bool hostile;

  bool get fromEnemy => hostile;

  /// Set when a player-owned ranged monster fired the arrow, so its XP can be
  /// attributed to the correct type.
  final String? sourceMonsterId;
  final MonsterType? sourceMonsterType;
  final Set<String> hitIds = {};
}

/// Ground AoE (arrow rain): pulses damage to every enemy inside its radius.
class ZoneState {
  ZoneState({
    required this.center,
    required this.radius,
    required this.tickDamage,
    required this.tickIntervalMs,
    required this.ticksLeft,
    required this.nextTickAtMs,
  });

  final Offset center;
  final double radius;
  final double tickDamage;
  final int tickIntervalMs;
  int ticksLeft;
  int nextTickAtMs;
}

/// Traveling ground wave (Flame's fire wave): damages every enemy in its
/// moving band once as it crosses them.
class WaveState {
  WaveState({
    required this.position,
    required this.velocity,
    required this.halfWidth,
    required this.damage,
    required this.maxTravel,
  });

  Offset position;
  final Offset velocity;
  final double halfWidth;
  final double damage;
  final double maxTravel;
  double traveled = 0;
  final Set<String> hitIds = {};
}

/// Transient combat effect for the painter: melee slash arcs, explosion rings.
class GameFx {
  GameFx({
    required this.kind,
    required this.position,
    required this.facing,
    required this.radius,
    required this.bornAtMs,
    required this.color,
  });

  /// `slash` (arc in front), `burst` (expanding ring around position).
  final String kind;
  final Offset position;
  final Offset facing;
  final double radius;
  final int bornAtMs;
  final int color;

  static const lifetimeMs = 420;
}

/// The full battle simulation for one playable hero.
///
/// The class is deliberately widget-free: input arrives as simple calls
/// (`setMoveInput`, `requestAttack`, `useAbility`) and the
/// sprite layer forwards weapon events at the exact frames the animations
/// define (`projectile_release`, `volley_release`). Damage is only ever dealt
/// through those weapon-event driven spawns, so the bow motion and the damage
/// stay in sync. A fixed-step `update()` advances everything else.
class GameWorld {
  GameWorld({
    required this.kit,
    math.Random? random,
    int? seed,
    this.spawnWaves = true,
    Map<MonsterType, int>? startingArmy,
    this.bonuses = const EquipmentBonuses(),
    int carryCapacity = baseCarryCapacity,
    MatchXpLedger? xpLedger,
    String? matchId,
    String heroId = 'ranger_new',
    int savedTotalXp = 0,
  })  : rng = random ?? (seed != null ? math.Random(seed) : math.Random()),
        player = PlayerState(),
        xpLedger = xpLedger ??
            MatchXpLedger(
              matchId: matchId ??
                  'local_${DateTime.now().microsecondsSinceEpoch}',
              heroId: heroId,
            ),
        initialTotalXp = savedTotalXp < 0 ? 0 : savedTotalXp,
        _startingArmy = startingArmy ?? MonsterCatalog.defaultStartingArmy {
    player.hp = maxHp;
    player.energy = kit.baseMaxEnergy * 0.5;
    this.xpLedger.onChange = refreshXpState;
    // One large map per match. Networked matches pass the authoritative host's
    // seed so every device simulates exactly the same world (spec §13/§14).
    map = ArenaMap.generate(
      math.Random(seed ?? rng.nextInt(0x3fffffff)),
    );
    fog = FogOfWar(
      worldWidth: map.size.width,
      worldHeight: map.size.height,
    );
    // Mines, their production and the collectable pickups on the ground.
    mineSystem = MineController(
      map: map,
      random: math.Random(rng.nextInt(0x3fffffff)),
    )..carryCapacity = carryCapacity;
    // Four castles, seven crystals each, laid out from the map anchors.
    castleSystem = CastleController(map: map);
    player.position = map.playerSpawn;
    fog.reveal(player.position, fogRevealRadius);
    // Initialise the smoothed camera at the hero's starting position so the
    // first frame does not snap from (0,0).
    _cameraTarget = _idealCameraOrigin();
    _cameraPosition = _cameraTarget;
    if (spawnWaves) {
      _spawnStartingArmy();
      spawnWave(initial: true);
    } else if (startingArmy != null) {
      _spawnStartingArmy();
    }
  }

  HeroKit kit;
  final math.Random rng;

  /// Hero max HP including equipped equipment and permanent hero upgrades.
  double get maxHp => kit.baseMaxHp * bonuses.hpMultiplier;

  /// Disable to script exact enemy setups in tests.
  final bool spawnWaves;
  final PlayerState player;
  final List<EnemyState> enemies = [];

  /// Smoothed camera follow position in world units (top-left of the camera
  /// window). Lerps toward the hero-centered target each frame so the camera
  /// does not snap instantly when the player changes direction.
  Offset _cameraPosition = Offset.zero;

  /// Ideal (clamped) camera origin for the current frame, computed from the
  /// hero position. Used as the lerp target for [_cameraPosition].
  Offset _cameraTarget = Offset.zero;

  /// Smoothed camera origin exposed to the renderer and to tap→world input
  /// conversion so both see the same camera position.
  Offset get cameraOrigin => _cameraPosition;

  /// Generated match world: size, biomes, rivers/bridges, obstacles, mines,
  /// pickups and castle anchors.
  late final ArenaMap map;

  /// Permanently remembered explored cells of [map].
  late final FogOfWar fog;

  /// Neutral/owned mines, production and resource pickups.
  late final MineController mineSystem;

  /// All castles, their crystals and the rebuild rules.
  late final CastleController castleSystem;

  /// The player's permanently-owned monster army. Dead members are removed and
  /// never respawn; the player must buy replacements.
  final List<EnemyState> army = [];

  /// Short-lived death animations for both sides.
  final List<MonsterCorpse> corpses = [];

  final List<ProjectileState> projectiles = [];
  final List<ZoneState> zones = [];
  final List<WaveState> waves = [];

  /// Transient combat visuals (slash arcs, burst rings), world-managed.
  final List<GameFx> fx = [];

  /// Per-type permanent upgrade levels (1..40), shared with the save layer.
  final MonsterUpgrades upgrades = MonsterUpgrades();

  /// Match currency used to buy monsters during the battle. Collected
  /// pickups stop at [MineController.carryCapacity].
  int resources = 320;

  /// Permanent currency used to upgrade heroes, monster types, equipment and
  /// carry capacity. The match's earnings stay pending until [settleMatch],
  /// so a lost/disconnected match still credits what was earned.
  int essence = 0;

  /// Permanent materials earned this match, pending until [settleMatch].
  int pendingEssence = 0;
  final Map<ProgressionMaterial, int> pendingMaterials = {};

  /// Permanent materials wallet (spent by the shop and upgrade pages).
  final Map<ProgressionMaterial, int> materials = {};

  /// Equipment stats applied to this match (neutral by default).
  EquipmentBonuses bonuses;

  final Map<MonsterType, int> _startingArmy;
  int _armySeq = 0;

  /// Performance-driven cap for the live army (the design leaves the exact
  /// number to device testing; 40 keeps the arena readable on phones).
  static const int maxArmySize = 40;
  static const int startingArmySize = 20;
  static const int maxAliveEnemiesCap = 12;
  static const int armyAggroRange = 340;
  static const int enemyAggroRange = 320;

  /// Movement input from the joystick, normalized (length ≤ 1).
  Offset moveInput = Offset.zero;

  /// World clock, advanced by [update].
  int nowMs = 0;

  late final ComboTracker combo = ComboTracker(windowMs: kit.comboWindowMs);

  /// Multiplier captured from the combo when the current attack started.
  double pendingHitMultiplier = 1.0;

  /// Ability queued by [useAbility], released by the matching weapon event.
  String? pendingAbilityId;

  int attackReadyAtMs = 0;
  final Map<String, int> abilityReadyAtMs = {};

  // Progression.
  int kills = 0;
  int level = 1;
  int xp = 0;

  /// Lifetime XP of the selected hero, derived from the authoritative curve.
  int totalXp = 0;

  /// Event ledger for this match. Every gameplay reward is recorded here once;
  /// the UI and the save layer consume the same finalized award.
  MatchXpLedger xpLedger;
  int initialTotalXp;

  double totalDamageDealt = 0;

  int _waveAtMs = 0;
  int _wave = 0;
  int _nextEntityId = 0;

  final List<WorldEvent> _events = [];

  static const int kitComboWindowMs = 1800;

  // ---- Tunables -------------------------------------------------------------

  double get attackRange => 260 * kit.rangeMultiplier;
  int get attackCycleMs => (1670 / kit.attackPace).round();
  double get projectileSpeed => 430;
  double get projectileRange => 330 * kit.rangeMultiplier;
  /// Spec §3:50 — ten-second respawn and five seconds of spawn protection.
  int get respawnDelayMs => 10000;
  int get respawnProtectionMs => 5000;

  /// Authoritative XP view of the selected hero inside this match.
  HeroXpState get heroXp {
    final cap = heroTotalXpToLevel(heroMaxLevel);
    if (initialTotalXp >= cap) return HeroXpState.fromTotal(cap);
    final total = initialTotalXp + xpLedger.currentHeroXp;
    return HeroXpState.fromTotal(total >= cap ? cap : total);
  }

  /// Attaches the shared match ledger (network matches create it outside the
  /// world) and refreshes the provisional HUD state from the saved total.
  void attachXpLedger(MatchXpLedger ledger, {required int savedTotalXp}) {
    xpLedger = ledger;
    initialTotalXp = savedTotalXp < 0 ? 0 : savedTotalXp;
    xpLedger.onChange = refreshXpState;
    refreshXpState();
  }

  /// Recomputes level/XP after a confirmed reward. Level-up events are emitted
  /// when the curve is crossed, so the HUD and audio stay in sync with the
  /// persisted total.
  void refreshXpState() {
    final state = heroXp;
    final previous = level;
    level = state.level;
    xp = state.xp;
    totalXp = state.totalXp;
    if (state.level > previous) {
      for (var crossed = previous + 1; crossed <= state.level; crossed++) {
        final unlocked = kit.abilities
            .where((ability) => ability.unlockLevel == crossed)
            .map((ability) => ability.id)
            .toList();
        _events.add(LevelUpEvent(crossed, unlocked));
        for (final id in unlocked) {
          _events.add(AbilityReadyEvent(id));
        }
      }
    }
  }

  /// Initial balance placeholders: the spec only says freeze/stun disable the
  /// target temporarily, without giving durations.
  static const int freezeDurationMs = 900;
  static const int stunDurationMs = 700;

  int get waveIntervalMs => 8000;
  int get maxAliveEnemies => maxAliveEnemiesCap;

  /// Applies a temporary disable to one monster. Freeze and stun behave the
  /// same for movement and attacks; they only differ in duration/source.
  /// An in-progress windup is cancelled so it cannot land after the effect.
  void _disableEnemy(EnemyState enemy, {required bool freeze}) {
    if (enemy.hp <= 0) return;
    final until = nowMs + (freeze ? freezeDurationMs : stunDurationMs);
    if (freeze) {
      enemy.frozenUntilMs = math.max(enemy.frozenUntilMs, until);
    } else {
      enemy.stunnedUntilMs = math.max(enemy.stunnedUntilMs, until);
    }
    enemy.windupUntilMs = 0;
    enemy.moving = false;
  }

  // ---- Input ----------------------------------------------------------------

  void setMoveInput(Offset direction) {
    final length = direction.distance;
    moveInput = length > 1 ? direction / length : direction;
  }

  /// Whether a normal attack can start right now.
  bool canAttack() => !player.dead &&
      !player.disabledAt(nowMs) &&
      nowMs >= attackReadyAtMs;

  /// Starts a normal attack: registers the combo hit and captures its damage
  /// multiplier. The arrow itself spawns when the animation reaches its
  /// `projectile_release` frame and the sprite layer calls [releaseArrow].
  bool requestAttack() {
    if (pendingAbilityId != null) return false;
    if (!canAttack()) return false;
    final hit = combo.advance(nowMs);
    pendingHitMultiplier = kit.comboHit(hit).multiplier;
    attackReadyAtMs = nowMs + (attackCycleMs / currentAttackRate()).round();
    // Face the auto-aim target (monster or rival crystal), or the movement
    // direction while kiting.
    final target = _nearestHostilePoint(attackRange);
    if (target != null) {
      player.facing = _normalize(target - player.position);
    } else if (moveInput.distance > 0.01) {
      player.facing = _normalize(moveInput);
    }
    xpLedger.markActivity();
    return true;
  }

  /// Spawns the arrow at the `projectile_release` animation frame.
  void releaseArrow() {
    if (player.dead || player.disabledAt(nowMs)) return;
    spawnArrow(
      origin: player.position,
      direction: player.facing,
      damage: kit.baseDamage * pendingHitMultiplier * currentDamageMult(),
      speed: projectileSpeed,
      range: projectileRange,
      tint: 0xFF62E86C,
    );
    player.energy = _clampD(player.energy + 4, 0, kit.baseMaxEnergy);
  }

  /// Attempts one of the hero's abilities. Returns the ability id on success,
  /// `null` when the ability is locked, on cooldown, or energy is short.
  String? useAbility(String abilityId) {
    if (player.dead || player.disabledAt(nowMs)) return null;
    if (pendingAbilityId != null) return null;
    final def = kit.abilityById(abilityId);
    if (def == null) return null;
    if (def.unlockLevel > level) return null;
    if (nowMs < (abilityReadyAtMs[abilityId] ?? 0)) return null;
    if (player.energy < def.energyCost) return null;
    abilityReadyAtMs[abilityId] = nowMs + def.cooldownMs;
    player.energy -= def.energyCost;
    pendingAbilityId = abilityId;
    xpLedger.markActivity();
    return abilityId;
  }

  /// Spawns the ability payload on the weapon-event frame the sprite layer
  /// forwards. [volley] true = the skill-clip's burst event (`volley_release`
  /// for Ranger, `inferno_burst` for Flame); false = the primary clip's
  /// release/impact event (`projectile_release` / `melee_impact`).
  void releaseWeaponPayload({required bool volley}) {
    if (player.dead || player.disabledAt(nowMs)) return;
    final ability = pendingAbilityId;
    if (ability == null) return;
    if (volley) {
      if (ability == 'piercing_shot' || ability == 'flame_slash') return;
      pendingAbilityId = null;
      _fireAbilityVolley(ability);
    } else {
      switch (ability) {
        case 'piercing_shot':
          pendingAbilityId = null;
          spawnArrow(
            origin: player.position,
            direction: player.facing,
            damage: kit.baseDamage * 2.2 * currentDamageMult(),
            speed: 560,
            range: 520,
            tint: 0xFFB7FF7A,
            pierceLeft: 99,
            big: true,
          );
        case 'flame_slash':
          pendingAbilityId = null;
          _meleeSwing(multiplier: 1.8, applyBurn: true);
        case 'twin_fangs':
          pendingAbilityId = null;
          _twinFangsStrike();
        case 'thunder_thrust':
          pendingAbilityId = null;
          _thunderThrust();
      }
    }
  }

  /// Storm's thunder thrust: a 160% spear stab on the primary target, then
  /// 60% of that damage chains as lightning to the nearest other enemy.
  void _thunderThrust() {
    final range = currentMeleeRange();
    final halfArc = kit.meleeArcRadians;
    EnemyState? primary;
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      final delta = enemy.position - player.position;
      final dist = delta.distance;
      if (dist > range + 18) continue;
      if (dist > 1) {
        final facingDot =
            (delta.dx * player.facing.dx + delta.dy * player.facing.dy) /
                dist;
        if (facingDot < math.cos(halfArc)) continue;
      }
      primary = enemy;
      break;
    }
    if (primary == null) {
      // Whiffed thrust: the swing still shows.
      fx.add(
        GameFx(
          kind: 'slash',
          position: player.position,
          facing: player.facing,
          radius: range,
          bornAtMs: nowMs,
          color: kit.accentColor,
        ),
      );
      return;
    }
    final primaryDamage = kit.baseDamage * 1.6 * currentDamageMult();
    final fieldActive = nowMs < player.staticFieldUntilMs;
    _damageEnemy(primary, primaryDamage);
    if (fieldActive) _disableEnemy(primary, freeze: true);
    fx.add(
      GameFx(
        kind: 'slash',
        position: player.position,
        facing: player.facing,
        radius: range,
        bornAtMs: nowMs,
        color: kit.accentColor,
      ),
    );
    // Chain: 60% of the primary damage onto the nearest other living enemy.
    EnemyState? chain;
    var chainDist = double.infinity;
    for (final enemy in enemies) {
      if (enemy.hp <= 0 || enemy == primary) continue;
      final dist = (enemy.position - primary.position).distance;
      if (dist < chainDist) {
        chainDist = dist;
        chain = enemy;
      }
    }
    if (chain != null && chainDist <= 200) {
      _damageEnemy(chain, primaryDamage * 0.6);
      if (fieldActive) _disableEnemy(chain, freeze: true);
      fx.add(
        GameFx(
          kind: 'bolt',
          position: primary.position,
          facing: chain.position - primary.position,
          radius: chainDist,
          bornAtMs: nowMs,
          color: kit.accentColor,
        ),
      );
    }
  }

  void _fireAbilityVolley(String ability) {
    switch (ability) {
      case 'multi_shot':
        for (var i = -2; i <= 2; i++) {
          final angle = _angleOf(player.facing) + i * 0.16;
          spawnArrow(
            origin: player.position,
            direction: Offset(math.cos(angle), math.sin(angle)),
            damage: kit.baseDamage * 0.6 * currentDamageMult(),
            speed: projectileSpeed,
            range: projectileRange,
            tint: 0xFF9BE845,
          );
        }
        break;
      case 'arrow_rain':
        final targetEnemy = nearestEnemy(attackRange * 1.4);
        final center =
            targetEnemy?.position ?? (player.position + player.facing * 180);
        zones.add(
          ZoneState(
            center: center,
            radius: 150,
            tickDamage: kit.baseDamage * 0.35 * currentDamageMult(),
            tickIntervalMs: 250,
            ticksLeft: 8,
            nextTickAtMs: nowMs + 200,
          ),
        );
        break;
      case 'gale_surge':
        player.buffUntilMs = nowMs + 6000;
        fx.add(
          GameFx(
            kind: 'burst',
            position: player.position,
            facing: player.facing,
            radius: 95,
            bornAtMs: nowMs,
            color: kit.accentColor,
          ),
        );
        break;
      case 'fire_wave':
        waves.add(
          WaveState(
            position: player.position,
            velocity: player.facing * 260,
            halfWidth: 62,
            damage: kit.baseDamage * 1.6 * currentDamageMult(),
            maxTravel: 320,
          ),
        );
        break;
      case 'hell_burst':
        final radius = 140.0;
        for (final enemy in enemies) {
          if (enemy.hp <= 0) continue;
          if ((enemy.position - player.position).distance <= radius) {
            _damageEnemy(
              enemy,
              kit.baseDamage * 2.2 * currentDamageMult(),
            );
            // The blast also stuns survivors for a short, fixed window.
            _disableEnemy(enemy, freeze: false);
          }
        }
        fx.add(
          GameFx(
            kind: 'burst',
            position: player.position,
            facing: player.facing,
            radius: radius,
            bornAtMs: nowMs,
            color: kit.accentColor,
          ),
        );
        break;
      case 'inferno_rage':
        player.buffUntilMs = nowMs + 6000;
        break;
      case 'shadow_veil':
        player.invulnerableUntilMs = nowMs + 4000;
        player.speedBoostUntilMs = nowMs + 4000;
        fx.add(
          GameFx(
            kind: 'burst',
            position: player.position,
            facing: player.facing,
            radius: 70,
            bornAtMs: nowMs,
            color: kit.accentColor,
          ),
        );
        break;
      case 'venom_coat':
        player.buffUntilMs = nowMs + 8000;
        fx.add(
          GameFx(
            kind: 'burst',
            position: player.position,
            facing: player.facing,
            radius: 85,
            bornAtMs: nowMs,
            color: kit.accentColor,
          ),
        );
        break;
      case 'chain_lightning':
        // Up to 3 nearest enemies within 180 are struck for 130% each.
        final candidates = enemies
            .where((e) => e.hp > 0)
            .toList()
          ..sort(
            (a, b) => (a.position - player.position)
                .distance
                .compareTo((b.position - player.position).distance),
          );
        var struck = 0;
        for (final enemy in candidates) {
          if (struck >= 3) break;
          if ((enemy.position - player.position).distance > 180) break;
          struck++;
          _damageEnemy(
            enemy,
            kit.baseDamage * 1.3 * currentDamageMult(),
          );
          fx.add(
            GameFx(
              kind: 'bolt',
              position: player.position,
              facing: enemy.position - player.position,
              radius: (enemy.position - player.position).distance,
              bornAtMs: nowMs,
              color: kit.accentColor,
            ),
          );
        }
        break;
      case 'static_field':
        // 8 s: every thrust releases a second 40% charge on its target and
        // freezes the spear's victims. The field also freezes nearby monsters
        // on activation so the disable has an immediate effect.
        player.buffUntilMs = nowMs + 8000;
        player.staticFieldUntilMs = nowMs + 8000;
        final fieldRadius = currentMeleeRange() + 30;
        for (final enemy in enemies) {
          if (enemy.hp <= 0) continue;
          if ((enemy.position - player.position).distance <= fieldRadius) {
            _disableEnemy(enemy, freeze: true);
          }
        }
        fx.add(
          GameFx(
            kind: 'burst',
            position: player.position,
            facing: player.facing,
            radius: 90,
            bornAtMs: nowMs,
            color: kit.accentColor,
          ),
        );
        break;
      case 'tempest_rage':
        // 6 s storm rage: faster attacks, harder hits, longer reach.
        player.buffUntilMs = nowMs + 6000;
        fx.add(
          GameFx(
            kind: 'burst',
            position: player.position,
            facing: player.facing,
            radius: 110,
            bornAtMs: nowMs,
            color: kit.accentColor,
          ),
        );
        break;
      case 'shadow_execute':
        _shadowExecute();
        break;
    }
  }

  /// Three rapid dagger stabs in the wide dagger arc: 80% each, so a lone
  /// target takes 240% while a crowd gets spread across up to three hits.
  void _twinFangsStrike() {
    final range = currentMeleeRange();
    final halfArc = kit.meleeArcRadians;
    var hits = 0;
    for (var i = 0; i < 3; i++) {
      for (final enemy in enemies) {
        if (enemy.hp <= 0) continue;
        final delta = enemy.position - player.position;
        final dist = delta.distance;
        if (dist > range + 18) continue;
        if (dist > 1) {
          final facingDot =
              (delta.dx * player.facing.dx + delta.dy * player.facing.dy) /
                  dist;
          if (facingDot < math.cos(halfArc)) continue;
        }
        hits++;
        _damageEnemy(enemy, kit.baseDamage * 0.8 * currentDamageMult());
        if (enemy.hp > 0 && player.buffUntilMs > nowMs) {
          _applyDoT(enemy, ticks: 2, tickDamage: kit.baseDamage * 0.15);
        }
      }
    }
    fx.add(
      GameFx(
        kind: 'slash',
        position: player.position,
        facing: player.facing,
        radius: range,
        bornAtMs: nowMs,
        color: kit.accentColor,
      ),
    );
    if (hits > 0) {
      player.energy = _clampD(player.energy + 3, 0, kit.baseMaxEnergy);
    }
  }

  /// Teleports to the weakest (lowest current HP) enemy within reach and
  /// stabs it for 300%. Assassination identity: finishers, not crowd damage.
  void _shadowExecute() {
    EnemyState? target;
    var lowest = double.infinity;
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      final dist = (enemy.position - player.position).distance;
      if (dist > 320) continue;
      if (enemy.hp < lowest) {
        lowest = enemy.hp;
        target = enemy;
      }
    }
    if (target == null) {
      // No target in reach: refund the energy so the button is not wasted.
      final def = kit.abilityById('shadow_execute');
      if (def != null) {
        player.energy = _clampD(
          player.energy + def.energyCost,
          0,
          kit.baseMaxEnergy,
        );
        abilityReadyAtMs['shadow_execute'] = 0;
      }
      return;
    }
    // Land behind the target, facing it.
    player.position = map.clampToBounds(
      Offset(
        target.position.dx - target.facing.dx * 30,
        target.position.dy - target.facing.dy * 30,
      ),
      24,
    );
    player.facing = target.facing;
    _damageEnemy(target, kit.baseDamage * 3.0 * currentDamageMult());
    fx.add(
      GameFx(
        kind: 'burst',
        position: target.position,
        facing: player.facing,
        radius: 60,
        bornAtMs: nowMs,
        color: kit.accentColor,
      ),
    );
    player.energy = _clampD(player.energy + 3, 0, kit.baseMaxEnergy);
  }

  /// The primary melee swing: damages every enemy inside the swing arc on the
  /// `melee_impact` animation frame. Called by the sprite layer for melee
  /// heroes; [multiplierOverride] is used by the flame_slash ability.
  void releaseMeleeSwing() {
    if (player.dead || player.disabledAt(nowMs)) return;
    _meleeSwing(multiplier: pendingHitMultiplier);
  }

  void _meleeSwing({required double multiplier, bool applyBurn = false}) {
    final range = currentMeleeRange();
    final halfArc = kit.meleeArcRadians;
    var hits = 0;
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      final delta = enemy.position - player.position;
      final dist = delta.distance;
      if (dist > range + 18) continue; // +18: enemy body radius grace
      if (dist > 1) {
        final facingDot =
            (delta.dx * player.facing.dx + delta.dy * player.facing.dy) /
                dist;
        if (facingDot < math.cos(halfArc)) continue;
      }
      hits++;
      _damageEnemy(enemy, kit.baseDamage * multiplier * currentDamageMult());
      if (applyBurn && enemy.hp > 0) {
        _applyDoT(
          enemy,
          ticks: 3,
          tickDamage: kit.baseDamage * 0.25 * currentDamageMult(),
        );
      }
      // Venom coat: a buffed Shadow poisons everything it stabs.
      if (kit.heroId == 'shadow' &&
          enemy.hp > 0 &&
          player.buffUntilMs > nowMs) {
        _applyDoT(
          enemy,
          ticks: 2,
          tickDamage: kit.baseDamage * 0.15 * currentDamageMult(),
        );
      }
      // Static field: a buffed Storm releases a second 40% charge and freezes
      // every enemy caught in the charged swing.
      if (kit.heroId == 'storm' &&
          enemy.hp > 0 &&
          player.buffUntilMs > nowMs) {
        _damageEnemy(
          enemy,
          kit.baseDamage * 0.4 * currentDamageMult(),
        );
        if (nowMs < player.staticFieldUntilMs) {
          _disableEnemy(enemy, freeze: true);
        }
      }
    }
    // Crystals are attacked directly, in any order, from the same swing.
    for (final crystal in castleSystem.hostileCrystals.toList()) {
      final delta = crystal.position - player.position;
      final dist = delta.distance;
      if (dist > range + 18 + crystalRadius) continue;
      if (dist > 1) {
        final facingDot =
            (delta.dx * player.facing.dx + delta.dy * player.facing.dy) / dist;
        if (facingDot < math.cos(halfArc)) continue;
      }
      hits++;
      _damageCrystal(
        crystal,
        kit.baseDamage * multiplier * currentDamageMult(),
      );
    }
    fx.add(
      GameFx(
        kind: 'slash',
        position: player.position,
        facing: player.facing,
        radius: range,
        bornAtMs: nowMs,
        color: kit.accentColor,
      ),
    );
    if (hits > 0) {
      player.energy = _clampD(player.energy + 3, 0, kit.baseMaxEnergy);
    }
  }

  // ---- Simulation -----------------------------------------------------------

  /// Fixed-step advance. Call with small deltas (16 ms) from the game loop.
  void update(int deltaMs) {
    nowMs += deltaMs;
    _updatePlayer(deltaMs);
    fog.reveal(player.position, fogRevealRadius);

    // ---- Camera follow -------------------------------------------------------
    // Lerp the smoothed camera position toward the hero-centered target so the
    // camera follows smoothly instead of snapping instantly.
    _cameraTarget = _idealCameraOrigin();
    _cameraPosition = Offset(
      _cameraPosition.dx +
          (_cameraTarget.dx - _cameraPosition.dx) * cameraLerpFactor,
      _cameraPosition.dy +
          (_cameraTarget.dy - _cameraPosition.dy) * cameraLerpFactor,
    );

    _updateEnemies(deltaMs);
    _updateArmy(deltaMs);
    _updateCrystalCombat();
    _updateProjectiles(deltaMs);
    _updateZones();
    _updateFireWaves(deltaMs);
    _updateBurns();
    _pruneFx();
    _pruneCorpses();
    _updateMines(deltaMs);
    _updateChests();
    _updateWaves();
    _regenEnergy(deltaMs);
  }

  /// Ideal (clamped) camera origin derived from the hero position. The camera
  /// window is centred on the hero and clamped so it never shows area outside
  /// the map bounds.
  Offset _idealCameraOrigin() {
    final map = this.map;
    final maxX = math.max(0.0, map.size.width - arenaWidth);
    final maxY = math.max(0.0, map.size.height - arenaHeight);
    return Offset(
      (player.position.dx - arenaWidth / 2).clamp(0.0, maxX).toDouble(),
      (player.position.dy - arenaHeight / 2).clamp(0.0, maxY).toDouble(),
    );
  }

  List<WorldEvent> drainEvents() {
    final drained = List<WorldEvent>.of(_events);
    _events.clear();
    return drained;
  }

  /// "Enemy monsters are shown only when nearby": true while [enemy] is within
  /// [enemyVisibleRadius] of the hero.
  bool isEnemyVisible(EnemyState enemy) =>
      (enemy.position - player.position).distance <= enemyVisibleRadius;

  /// Hostile monsters currently close enough to be rendered.
  Iterable<EnemyState> get visibleEnemies => enemies.where(isEnemyVisible);

  // ---- Internals ------------------------------------------------------------

  double currentAttackRate() => player.buffUntilMs > nowMs
      ? kit.attackPace * kit.buffRateMult
      : kit.attackPace;

  double currentDamageMult() =>
      (player.buffUntilMs > nowMs ? kit.buffDamageMult : 1.0) *
      bonuses.damageMultiplier;

  /// Melee reach, widened while the rage buff is active (Storm's tempest
  /// rage stretches the spear line the farthest).
  double currentMeleeRange() => kit.meleeRange *
      kit.rangeMultiplier *
      (player.buffUntilMs > nowMs ? (kit.heroId == 'storm' ? 1.25 : 1.2) : 1.0);

  double currentMoveSpeed() {
    var speed = kit.moveSpeed * bonuses.moveMultiplier;
    if (player.buffUntilMs > nowMs) speed *= kit.buffMoveMult;
    if (player.speedBoostUntilMs > nowMs) speed *= 1.35;
    return speed;
  }

  void _updatePlayer(int deltaMs) {
    if (player.dead) {
      if (nowMs >= player.respawnAtMs) _respawn();
      return;
    }
    // Freeze/stun stop the hero too if a future effect ever targets the player.
    if (player.disabledAt(nowMs)) return;
    final speed = currentMoveSpeed();
    // Shallow water slows the hero; bridges are dry.
    final step = moveInput *
        (speed * map.movementFactorAt(player.position) * deltaMs / 1000);
    player.position = map.slideMove(player.position, step, 24);
    if (moveInput.distance > 0.01) {
      player.facing = _normalize(moveInput);
    }
  }

  void _updateEnemies(int deltaMs) {
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      enemy.moving = false;
      // A frozen/stunned monster neither moves nor finishes an attack.
      if (enemy.disabledAt(nowMs)) continue;

      // Target the nearest of the player's monsters; fall back to the hero.
      EnemyState? armyTarget;
      var best = double.infinity;
      for (final ally in army) {
        if (ally.hp <= 0) continue;
        final dist = (ally.position - enemy.position).distance;
        if (dist < best && dist <= enemyAggroRange) {
          best = dist;
          armyTarget = ally;
        }
      }
      final Offset? targetPos = armyTarget?.position ??
          (player.dead ? null : player.position);
      if (targetPos == null) continue;

      final toTarget = targetPos - enemy.position;
      final dist = toTarget.distance;
      if (dist > 1) enemy.facing = toTarget / dist;

      // Finish a started swing. Damage only lands if the target is still in
      // reach, so sidestepping an attack works for the hero and the army.
      if (enemy.windupUntilMs > 0 && nowMs >= enemy.windupUntilMs) {
        enemy.windupUntilMs = 0;
        final reach = armyTarget != null
            ? (armyTarget.hp > 0
                ? (armyTarget.position - enemy.position).distance
                : double.infinity)
            : (player.dead
                ? double.infinity
                : (player.position - enemy.position).distance);
        if (reach < 64) {
          if (armyTarget != null && armyTarget.hp > 0) {
            _damageMonster(armyTarget, enemy.contactDamage);
          } else if (!player.dead) {
            _damagePlayer(enemy.contactDamage);
          }
        }
        enemy.attackCooldownUntilMs =
            (nowMs + MonsterCatalog.def(enemy.type).attackCooldownMs)
                .toDouble();
      }
      if (enemy.windupUntilMs > 0) continue;

      final def = MonsterCatalog.def(enemy.type);
      final canAct =
          nowMs >= enemy.attackCooldownUntilMs && enemy.windupUntilMs == 0;
      if (canAct && dist <= def.attackRange) {
        if (enemy.ranged) {
          enemy.attackCooldownUntilMs = (nowMs + def.attackCooldownMs).toDouble();
          enemy.attackAnimUntilMs = nowMs + 260;
          spawnArrow(
            origin: enemy.position,
            direction: enemy.facing,
            damage: enemy.contactDamage,
            speed: 240,
            range: 340,
            tint: 0xFFFF7A5A,
            hostile: true,
          );
        } else {
          enemy.windupUntilMs = nowMs + 320;
          enemy.attackAnimUntilMs = nowMs + 320;
        }
        continue;
      }

      // Movement: melee closes in, ranged holds its preferred band, stalkers
      // circle, runners dash in bursts.
      var stepDir = enemy.facing;
      var speedMult = 1.0;
      if (enemy.ranged) {
        if (dist > def.preferredRange + 30) {
          stepDir = enemy.facing;
        } else if (dist < def.preferredRange - 45) {
          stepDir = -enemy.facing;
        } else {
          stepDir = Offset.zero;
        }
      } else if (dist <= def.attackRange * 0.9) {
        stepDir = Offset.zero;
      } else if (enemy.type == MonsterType.stalker) {
        final side = Offset(-enemy.facing.dy, enemy.facing.dx);
        final sway = math.sin(nowMs / 520 + enemy.strafePhase);
        stepDir = _normalize(enemy.facing + side * (sway * 0.55));
      } else if (enemy.type == MonsterType.runner &&
          nowMs >= enemy.nextDashAtMs) {
        enemy.dashUntilMs = nowMs + 360;
        enemy.nextDashAtMs = nowMs + 2400;
      }
      if (nowMs < enemy.dashUntilMs) speedMult = 2.15;
      if (stepDir.distance > 0.001) {
        _moveMonster(
          enemy,
          stepDir,
          deltaMs,
          speedMult: speedMult,
          neighbors: enemies,
        );
      }
    }
    enemies.removeWhere((enemy) => enemy.hp <= 0);
  }

  /// The player's army: automatically picks the nearest hostile monster,
  /// fights it, and otherwise regroups in a ring around the hero.
  void _updateArmy(int deltaMs) {
    for (final ally in army) {
      if (ally.hp <= 0) continue;
      ally.moving = false;
      if (ally.disabledAt(nowMs)) continue;

      EnemyState? target;
      var best = double.infinity;
      for (final enemy in enemies) {
        if (enemy.hp <= 0) continue;
        final dist = (enemy.position - ally.position).distance;
        if (dist < best && dist <= armyAggroRange) {
          best = dist;
          target = enemy;
        }
      }

      if (target == null) {
        // No enemy in range: walk back into formation around the hero.
        final anchor = map.clampToBounds(
          Offset(
            player.position.dx +
                armyFormationOffset(ally.groupSlot, army.length).dx,
            player.position.dy +
                armyFormationOffset(ally.groupSlot, army.length).dy,
          ),
          24,
        );
        final delta = anchor - ally.position;
        if (delta.distance > 16) {
          ally.facing = _normalize(delta);
          _moveMonster(ally, delta, deltaMs, neighbors: army);
        }
        continue;
      }

      final toTarget = target.position - ally.position;
      final dist = toTarget.distance;
      if (dist > 1) ally.facing = toTarget / dist;
      final def = MonsterCatalog.def(ally.type);

      if (dist <= def.attackRange &&
          nowMs >= ally.attackCooldownUntilMs) {
        ally.attackCooldownUntilMs = (nowMs + def.attackCooldownMs).toDouble();
        ally.attackAnimUntilMs = nowMs + 260;
        if (ally.ranged) {
          spawnArrow(
            origin: ally.position,
            direction: ally.facing,
            damage: ally.contactDamage,
            speed: 300,
            range: 320,
            tint: def.accent,
            sourceMonsterId: ally.id,
            sourceMonsterType: ally.type,
          );
        } else {
          _damageEnemy(
            target,
            ally.contactDamage,
            origin: DamageOrigin.monster,
            monsterType: ally.type,
          );
        }
        continue;
      }

      var stepDir = ally.facing;
      if (ally.ranged) {
        if (dist > def.preferredRange + 20) {
          stepDir = ally.facing;
        } else if (dist < def.preferredRange - 40) {
          stepDir = -ally.facing;
        } else {
          stepDir = Offset.zero;
        }
      } else if (dist <= def.attackRange * 0.85) {
        stepDir = Offset.zero;
      } else if (ally.type == MonsterType.stalker) {
        final side = Offset(-ally.facing.dy, ally.facing.dx);
        final sway = math.sin(nowMs / 480 + ally.strafePhase);
        stepDir = _normalize(ally.facing + side * (sway * 0.6));
      }
      if (stepDir.distance > 0.001) {
        _moveMonster(ally, stepDir, deltaMs, neighbors: army);
      }
    }
    army.removeWhere((ally) => ally.hp <= 0);
  }

  /// Spec §3:58 — monsters can attack enemy crystals and defend their owner's
  /// crystals. Enemy monsters strike the local castle's crystals when the hero
  /// is not close enough to distract them; the player's army strikes rival
  /// crystals when no hostile monster is nearer. The army's existing aggro on
  /// enemies approaching our crystals is what provides active defence.
  void _updateCrystalCombat() {
    const double crystalStrikeRange = 72 + crystalRadius;
    const double heroDistractionRange = 260.0;

    // Hostile monsters attacking the local player's crystals.
    for (final enemy in enemies) {
      if (enemy.hp <= 0 || enemy.disabledAt(nowMs)) continue;
      if (enemy.windupUntilMs > 0 || nowMs < enemy.attackCooldownUntilMs) {
        continue;
      }
      if (!player.dead &&
          (player.position - enemy.position).distance <
              heroDistractionRange) {
        continue;
      }
      CrystalState? target;
      var best = crystalStrikeRange;
      for (final crystal in castleSystem.playerCastle.alive) {
        final d = (crystal.position - enemy.position).distance;
        if (d < best) {
          best = d;
          target = crystal;
        }
      }
      if (target == null) continue;
      enemy.facing = _normalize(target.position - enemy.position);
      enemy.attackAnimUntilMs = nowMs + 260;
      enemy.attackCooldownUntilMs =
          (nowMs + MonsterCatalog.def(enemy.type).attackCooldownMs).toDouble();
      _damageCrystal(target, enemy.contactDamage, origin: DamageOrigin.enemy);
      fx.add(
        GameFx(
          kind: 'slash',
          position: target.position,
          facing: enemy.facing,
          radius: 36,
          bornAtMs: nowMs,
          color: 0xFFFF7A5A,
        ),
      );
    }

    // The player's army attacking rival crystals (and, by prioritising nearby
    // hostile monsters, defending our own).
    for (final ally in army) {
      if (ally.hp <= 0 || ally.disabledAt(nowMs)) continue;
      if (nowMs < ally.attackCooldownUntilMs) continue;
      CrystalState? target;
      var best = crystalStrikeRange;
      for (final crystal in castleSystem.hostileCrystals) {
        final d = (crystal.position - ally.position).distance;
        if (d < best) {
          best = d;
          target = crystal;
        }
      }
      if (target == null) continue;
      var nearestFoe = double.infinity;
      for (final enemy in enemies) {
        if (enemy.hp <= 0) continue;
        final d = (enemy.position - ally.position).distance;
        if (d < nearestFoe) nearestFoe = d;
      }
      if (nearestFoe < best) continue;
      ally.facing = _normalize(target.position - ally.position);
      ally.attackAnimUntilMs = nowMs + 260;
      ally.attackCooldownUntilMs =
          (nowMs + MonsterCatalog.def(ally.type).attackCooldownMs).toDouble();
      _damageCrystal(
        target,
        ally.contactDamage,
        origin: DamageOrigin.monster,
        monsterType: ally.type,
      );
      fx.add(
        GameFx(
          kind: 'slash',
          position: target.position,
          facing: ally.facing,
          radius: 36,
          bornAtMs: nowMs,
          color: MonsterCatalog.def(ally.type).accent,
        ),
      );
    }
  }

  /// Steps [monster] in [direction] with simple same-team separation so packs
  /// walk as a group instead of merging into one blob. Advances the gait clock
  /// with the distance actually travelled, which is what animates the legs.
  void _moveMonster(
    EnemyState monster,
    Offset direction,
    int deltaMs, {
    double speedMult = 1.0,
    List<EnemyState>? neighbors,
  }) {
    var dir = _normalize(direction);
    var separation = Offset.zero;
    if (neighbors != null) {
      for (final other in neighbors) {
        if (identical(other, monster) || other.hp <= 0) continue;
        final away = monster.position - other.position;
        final dist = away.distance;
        final minGap = monster.radius + other.radius + 6;
        if (dist > 0.001 && dist < minGap) {
          separation += away / dist * ((minGap - dist) / minGap);
        }
      }
    }
    if (separation.distance > 0.001) {
      dir = _normalize(dir + separation * 1.4);
    }

    final before = monster.position;
    final step = dir *
        (monster.speed *
            speedMult *
            map.movementFactorAt(monster.position) *
            deltaMs /
            1000);
    monster.position =
        map.slideMove(monster.position, step, monster.radius * 0.9);
    final moved = (monster.position - before).distance;
    monster.moving = moved > 0.02;
    if (monster.moving) {
      monster.walkPhase += moved * 0.22;
    }
  }

  void _updateProjectiles(int deltaMs) {
    for (final projectile in projectiles) {
      final step = projectile.velocity * (deltaMs / 1000);
      projectile.position = projectile.position + step;
      projectile.traveled += step.distance;
      if (projectile.traveled >= projectile.maxTravel) continue;
      if (projectile.hostile) {
        // Hostile arrow: the player's monsters body-block it first, then the
        // hero. One projectile damages at most one of them.
        var consumed = false;
        for (final ally in army) {
          if (ally.hp <= 0 || projectile.hitIds.contains(ally.id)) continue;
          if ((projectile.position - ally.position).distance <
              ally.radius + 6) {
            projectile.hitIds.add(ally.id);
            _damageMonster(ally, projectile.damage);
            // The arrow is spent on the first body it hits.
            projectile.traveled = projectile.maxTravel;
            consumed = true;
            break;
          }
        }
        if (!consumed &&
            !player.dead &&
            nowMs >= player.invulnerableUntilMs &&
            (projectile.position - player.position).distance < 22) {
          projectile.traveled = projectile.maxTravel;
          _damagePlayer(projectile.damage);
        }
        continue;
      }
      final projectileOrigin = projectile.sourceMonsterType == null
          ? DamageOrigin.hero
          : DamageOrigin.monster;
      for (final enemy in enemies) {
        if (enemy.hp <= 0 || projectile.hitIds.contains(enemy.id)) continue;
        if ((projectile.position - enemy.position).distance <
            enemy.radius + 8) {
          projectile.hitIds.add(enemy.id);
          _damageEnemy(
            enemy,
            projectile.damage,
            origin: projectileOrigin,
            monsterType: projectile.sourceMonsterType,
            unitId: projectile.sourceMonsterId,
          );
          if (projectile.pierceLeft <= 0) {
            projectile.traveled = projectile.maxTravel;
            break;
          }
          projectile.pierceLeft--;
        }
      }
      if (projectile.traveled >= projectile.maxTravel) continue;
      // Rival crystals are solid targets for the hero's arrows.
      for (final crystal in castleSystem.hostileCrystals.toList()) {
        if (projectile.hitIds.contains(crystal.id)) continue;
        if ((projectile.position - crystal.position).distance <
            crystalRadius + 8) {
          projectile.hitIds.add(crystal.id);
          _damageCrystal(
            crystal,
            projectile.damage,
            origin: projectileOrigin,
            monsterType: projectile.sourceMonsterType,
          );
          if (projectile.pierceLeft <= 0) {
            projectile.traveled = projectile.maxTravel;
            break;
          }
          projectile.pierceLeft--;
        }
      }
    }
    projectiles.removeWhere((p) => p.traveled >= p.maxTravel);
  }

  void _updateZones() {
    for (final zone in zones) {
      if (zone.ticksLeft <= 0 || nowMs < zone.nextTickAtMs) continue;
      zone.nextTickAtMs = nowMs + zone.tickIntervalMs;
      zone.ticksLeft--;
      for (final enemy in enemies) {
        if (enemy.hp <= 0) continue;
        if ((enemy.position - zone.center).distance <= zone.radius) {
          _damageEnemy(enemy, zone.tickDamage);
        }
      }
      for (final crystal in castleSystem.hostileCrystals.toList()) {
        if ((crystal.position - zone.center).distance <= zone.radius) {
          _damageCrystal(crystal, zone.tickDamage);
        }
      }
    }
    zones.removeWhere((zone) => zone.ticksLeft <= 0);
  }

  void _updateFireWaves(int deltaMs) {
    for (final wave in waves) {
      final step = wave.velocity * (deltaMs / 1000);
      wave.position = wave.position + step;
      wave.traveled += step.distance;
      if (wave.traveled >= wave.maxTravel) continue;
      for (final enemy in enemies) {
        if (enemy.hp <= 0 || wave.hitIds.contains(enemy.id)) continue;
        if ((enemy.position - wave.position).distance <= wave.halfWidth) {
          wave.hitIds.add(enemy.id);
          _damageEnemy(enemy, wave.damage);
          if (enemy.hp > 0) {
            _applyDoT(
              enemy,
              ticks: 2,
              tickDamage: kit.baseDamage * 0.2 * currentDamageMult(),
            );
          }
        }
      }
      for (final crystal in castleSystem.hostileCrystals.toList()) {
        if (wave.hitIds.contains(crystal.id)) continue;
        if ((crystal.position - wave.position).distance <= wave.halfWidth) {
          wave.hitIds.add(crystal.id);
          _damageCrystal(crystal, wave.damage);
        }
      }
    }
    waves.removeWhere((wave) => wave.traveled >= wave.maxTravel);
  }

  /// Applies a damage-over-time effect (Flame's burn, Shadow's venom): a few
  /// ticks of [tickDamage] every 800 ms on [enemy].
  void _applyDoT(
    EnemyState enemy, {
    required int ticks,
    required double tickDamage,
  }) {
    if (enemy.burnTicksLeft > 0) {
      // Refresh with the stronger source instead of stacking.
      enemy.burnTickDamage =
          enemy.burnTickDamage < tickDamage ? tickDamage : enemy.burnTickDamage;
      enemy.burnTicksLeft =
          enemy.burnTicksLeft < ticks ? ticks : enemy.burnTicksLeft;
      return;
    }
    enemy.burnTicksLeft = ticks;
    enemy.burnTickDamage = tickDamage;
    enemy.burnNextTickAtMs = nowMs + 800;
  }

  void _updateBurns() {
    for (final enemy in enemies) {
      if (enemy.hp <= 0 || enemy.burnTicksLeft <= 0) continue;
      if (nowMs < enemy.burnNextTickAtMs) continue;
      enemy.burnNextTickAtMs = nowMs + 800;
      enemy.burnTicksLeft--;
      _damageEnemy(enemy, enemy.burnTickDamage);
    }
  }

  void _pruneFx() {
    fx.removeWhere((effect) => nowMs - effect.bornAtMs > GameFx.lifetimeMs);
  }

  void _updateWaves() {
    if (!spawnWaves) return;
    if (nowMs < _waveAtMs) return;
    spawnWave();
  }

  void spawnWave({bool initial = false}) {
    _wave++;
    _waveAtMs = nowMs + (initial ? 1500 : waveIntervalMs);
    var count = math.min(3 + _wave, 10);
    if (initial) count = 5;
    for (var i = 0; i < count && enemies.length < maxAliveEnemies; i++) {
      enemies.add(_spawnEnemy());
    }
  }

  EnemyState _spawnEnemy() {
    Offset position;
    var tries = 0;
    do {
      position = Offset(
        60 + rng.nextDouble() * (map.size.width - 120),
        80 + rng.nextDouble() * (map.size.height - 130),
      );
      tries++;
    } while (tries < 40 &&
        ((position - player.position).distance < 280 ||
            map.isBlocked(position, 18) ||
            map.isWater(position) ||
            army.any((ally) =>
                (ally.position - position).distance <
                ally.radius + 30)));
    if (map.isBlocked(position, 16) || map.isWater(position)) {
      position = map.clampToBounds(map.center, 40);
    }

    // Weighted draft of the four approved types. Runners are the bulk,
    // stalkers flank, ranged pressure and tanks anchor the wave.
    final roll = rng.nextDouble();
    final MonsterType type;
    if (roll < 0.36) {
      type = MonsterType.runner;
    } else if (roll < 0.60) {
      type = MonsterType.stalker;
    } else if (roll < 0.82) {
      type = MonsterType.ranged;
    } else {
      type = MonsterType.tank;
    }
    final level = (1 + (_wave - 1) ~/ 2).clamp(1, monsterMaxLevel);
    final stats = MonsterStats.of(type, level);
    return EnemyState(
      id: 'enemy_${_nextEntityId++}',
      kind: type.name,
      type: type,
      team: MonsterTeam.enemy,
      level: level,
      position: position,
      maxHp: stats.maxHp,
      speed: stats.speed,
      contactDamage: stats.damage,
      xpValue: stats.xpValue,
      ranged: type == MonsterType.ranged,
      radius: stats.radius,
    );
  }

  void _spawnStartingArmy() {
    final distribution = _startingArmy.isEmpty
        ? MonsterCatalog.defaultStartingArmy
        : _startingArmy;
    var slot = 0;
    for (final entry in distribution.entries) {
      for (var i = 0; i < entry.value && army.length < maxArmySize; i++) {
        _spawnArmyMonster(entry.key, slot: slot++);
      }
    }
    // Always honour the documented free 20-monster army even if the caller
    // passed a partial distribution.
    while (army.length < startingArmySize) {
      _spawnArmyMonster(MonsterType.runner, slot: slot++);
    }
  }

  EnemyState _spawnArmyMonster(
    MonsterType type, {
    int? slot,
    Offset? near,
  }) {
    final level = upgrades.levelOf(type);
    final stats = MonsterStats.of(type, level);
    final formationSlot = slot ?? army.length;
    final base = near ?? player.position;
    final jitter = Offset(
      (rng.nextDouble() - 0.5) * 16,
      (rng.nextDouble() - 0.5) * 16,
    );
    final offset = armyFormationOffset(formationSlot, math.max(army.length + 1, 20));
    var position = map.clampToBounds(
      Offset(base.dx + offset.dx + jitter.dx, base.dy + offset.dy + jitter.dy),
      24,
    );
    // Never spawn inside an existing army monster: the ring layout is roomy,
    // but the per-spawn jitter can close a gap. Push the newcomer out along
    // the connecting line until the bodies no longer overlap.
    for (final other in army) {
      if (other.hp <= 0) continue;
      final away = position - other.position;
      final gap = away.distance;
      final minGap = stats.radius + other.radius + 6;
      if (gap > 0.001 && gap < minGap) {
        position += away / gap * (minGap - gap);
      }
    }
    position = map.clampToBounds(position, 24);
    final monster = EnemyState(
      id: 'army_${_armySeq++}',
      kind: type.name,
      type: type,
      team: MonsterTeam.player,
      level: level,
      position: position,
      maxHp: stats.maxHp,
      speed: stats.speed,
      contactDamage: stats.damage,
      xpValue: 0,
      ranged: type == MonsterType.ranged,
      radius: stats.radius,
    );
    monster.groupSlot = formationSlot;
    monster.strafePhase = rng.nextDouble() * math.pi * 2;
    monster.nextDashAtMs = nowMs + rng.nextInt(1400);
    army.add(monster);
    return monster;
  }

  /// Buys one monster of [type] with match resources. Returns false when the
  /// army is full or the player cannot afford it. Spec §3:60: reinforcements
  /// appear beside the owner's castle.
  bool buyMonster(MonsterType type) {
    final price = MonsterCatalog.def(type).price;
    if (army.length >= maxArmySize || resources < price) return false;
    resources -= price;
    final anchor = castleSystem.playerCastle.anchor;
    final angle = army.length * 0.9;
    _spawnArmyMonster(
      type,
      slot: army.length,
      near: map.clampToBounds(
        anchor + Offset(math.cos(angle), math.sin(angle)) * 150,
        28,
      ),
    );
    return true;
  }

  bool canBuyMonster(MonsterType type) =>
      army.length < maxArmySize &&
      resources >= MonsterCatalog.def(type).price;

  /// Material cost of the next level of [type] (its own category, as required).
  int monsterUpgradeMaterialCostFor(MonsterType type) =>
      1 + (upgrades.levelOf(type) - 1) ~/ 5;

  /// Permanent per-type upgrade, paid with monster essence **and** monster
  /// materials. The new level applies to every future purchase (existing
  /// monsters keep their stats).
  bool upgradeMonster(MonsterType type) {
    final cost = upgrades.upgradeCost(type);
    final materialCost = monsterUpgradeMaterialCostFor(type);
    final available = materials[ProgressionMaterial.monster] ?? 0;
    if (!upgrades.canUpgrade(type, essence) || available < materialCost) {
      return false;
    }
    upgrades.upgrade(type, essence: essence);
    essence -= cost;
    materials[ProgressionMaterial.monster] = available - materialCost;
    return true;
  }

  void _updateMines(int deltaMs) {
    final players = <String, Offset>{
      if (!player.dead) MineController.localPlayerId: player.position,
    };
    final neutralBefore = {
      for (final mine in mineSystem.mines) mine: mine.isNeutral,
    };
    mineSystem.update(deltaMs: deltaMs, nowMs: nowMs, players: players);

    // Produced and loose resources are only credited by touching them, never
    // automatically, and never beyond the carry capacity.
    final collected = mineSystem.collectAt(
      player.position,
      currentResources: resources,
    );
    for (final pickup in collected) {
      resources += pickup.amount;
      xpLedger.recordMineCollection(pickup.id);
      _events.add(
        MineResourceCollectedEvent(
          amount: pickup.amount,
          total: resources,
          pickupIds: [pickup.id],
        ),
      );
      refreshXpState();
    }

    // Report newly captured mines once each.
    for (final mine in mineSystem.mines) {
      final owner = mine.ownerId;
      if (owner == null) {
        _announcedMineOwners.remove(mine);
        continue;
      }
      if (_announcedMineOwners[mine] == owner) continue;
      _announcedMineOwners[mine] = owner;
      final neutral = neutralBefore[mine] ?? false;
      if (owner == MineController.localPlayerId) {
        xpLedger.recordMineCapture(_mineKey(mine), neutral: neutral);
        refreshXpState();
        pendingMaterials[ProgressionMaterial.capacity] =
            (pendingMaterials[ProgressionMaterial.capacity] ?? 0) + 1;
      }
      _events.add(
        MineCapturedEvent(
          size: mine.size,
          ownerId: owner,
          mineKey: _mineKey(mine),
          neutral: neutral,
        ),
      );
    }
  }

  String _mineKey(MineState mine) {
    final site = mine.site;
    return 'mine_${site.position.dx.toStringAsFixed(1)}_'
        '${site.position.dy.toStringAsFixed(1)}_${site.size.name}';
  }

  final Map<MineState, String> _announcedMineOwners = {};

  int _chestSeq = 0;

  /// Chests are opened by touching them, like resource pickups. The screen
  /// stores the rolled item in the persistent inventory (duplicates become
  /// equipment materials).
  void _updateChests() {
    if (player.dead) return;
    for (final pickup in List<MapPickup>.of(map.pickups)) {
      if (pickup.kind != PickupKind.chest) continue;
      if ((pickup.position - player.position).distance > 34) continue;
      map.pickups.remove(pickup);
      final item = rollChestItem(
        rng,
        id: 'chest_${nowMs}_${_chestSeq++}',
      );
      _events.add(ChestOpenedEvent(item));
    }
  }

  /// Credits the match's permanent currency and materials after the match.
  /// Players keep everything they earned even when they lose.
  void settleMatch() {
    essence = math.min(0x7fffffff, essence + pendingEssence);
    pendingEssence = 0;
    for (final entry in pendingMaterials.entries) {
      materials[entry.key] = (materials[entry.key] ?? 0) + entry.value;
    }
    pendingMaterials.clear();
  }

  /// Swaps in a kit with a persisted weapon-mastery level. Stats are read
  /// through [kit] everywhere, so this applies immediately without rebuilding
  /// the world (and without losing in-match XP).
  void setKit(HeroKit nextKit) {
    kit = nextKit;
    if (player.hp > maxHp) player.hp = maxHp;
    if (player.energy > kit.baseMaxEnergy) player.energy = kit.baseMaxEnergy;
  }

  /// Applies the saved progression before/at the start of a match: equipment
  /// stats, permanent hero upgrades and the upgraded carry capacity.
  void applyProgression({
    required EquipmentBonuses bonuses,
    required int carryCapacity,
  }) {
    final wasFull = !player.dead && player.hp >= maxHp - 0.01;
    this.bonuses = bonuses;
    mineSystem.carryCapacity = carryCapacity;
    if (wasFull) {
      player.hp = maxHp;
    } else {
      player.hp = math.min(player.hp, maxHp);
    }
  }

  /// Mines owned by the local hero.
  int get ownedMineCount =>
      mineSystem.ownedMineCount(MineController.localPlayerId);

  /// The mine the hero is standing in, if any (drives the HUD progress bar).
  MineState? get currentMine => mineSystem.mineContaining(player.position);

  /// Pickups currently lying on the ground.
  List<ResourcePickup> get resourcePickups => mineSystem.pickups;

  void _pruneCorpses() {
    corpses.removeWhere(
      (corpse) => nowMs - corpse.bornAtMs > MonsterCorpse.lifetimeMs,
    );
  }

  void _addCorpse(EnemyState monster) {
    corpses.add(
      MonsterCorpse(
        type: monster.type,
        team: monster.team,
        position: monster.position,
        facing: monster.facing,
        bornAtMs: nowMs,
      ),
    );
  }

  void spawnArrow({
    required Offset origin,
    required Offset direction,
    required double damage,
    required double speed,
    required double range,
    required int tint,
    int pierceLeft = 0,
    bool big = false,
    bool? hostile,
    String? sourceMonsterId,
    MonsterType? sourceMonsterType,
  }) {
    projectiles.add(
      ProjectileState(
        id: 'proj_${_nextEntityId++}',
        position: origin + direction * 18,
        velocity: _normalize(direction) * speed,
        damage: damage,
        pierceLeft: pierceLeft,
        maxTravel: range,
        tint: tint,
        big: big,
        hostile: hostile,
        sourceMonsterId: sourceMonsterId,
        sourceMonsterType: sourceMonsterType,
      ),
    );
  }

  void _damageEnemy(
    EnemyState enemy,
    double amount, {
    DamageOrigin origin = DamageOrigin.hero,
    MonsterType? monsterType,
    String? unitId,
  }) {
    if (enemy.hp <= 0 || amount <= 0) return;
    final applied = amount > enemy.hp ? enemy.hp : amount;
    enemy.hp -= applied;
    enemy.hitFlashUntilMs = nowMs + 160;
    if (origin != DamageOrigin.enemy) totalDamageDealt += applied;
    if (!player.dead && origin == DamageOrigin.hero) {
      player.energy = _clampD(player.energy + 2, 0, kit.baseMaxEnergy);
    }
    if (origin == DamageOrigin.monster && monsterType != null) {
      xpLedger.recordMonsterDamage(
        type: monsterType,
        unitId: unitId ?? enemy.id,
        amount: applied,
      );
    }
    if (enemy.hp <= 0) {
      enemy.hp = 0;
      kills++;
      if (origin == DamageOrigin.hero) {
        xpLedger.recordEnemyKill(enemy.id);
      } else if (origin == DamageOrigin.monster && monsterType != null) {
        xpLedger.recordMonsterKill(
          type: monsterType,
          unitId: enemy.id,
        );
      }
      _addCorpse(enemy);
      // Permanent currency/materials for the kill are credited after the
      // match (a loss or disconnect still keeps them).
      pendingEssence += 1 + enemy.xpValue ~/ 12;
      pendingMaterials[ProgressionMaterial.monster] =
          (pendingMaterials[ProgressionMaterial.monster] ?? 0) + 1;
      resources = math.min(
        9999,
        resources + 2 + MonsterCatalog.def(enemy.type).price ~/ 6,
      );
      _events.add(
        EnemyKilledEvent(
          enemy.kind,
          enemy.xpValue,
          enemyId: enemy.id,
          killedBy: origin,
          monsterType: monsterType,
        ),
      );
      refreshXpState();
    }
  }

  /// Damage to one of the player's permanently-owned monsters. A dead ally is
  /// removed from the army for the rest of the match and must be repurchased.
  void _damageMonster(EnemyState monster, double amount) {
    if (monster.hp <= 0) return;
    monster.hp -= amount;
    monster.hitFlashUntilMs = nowMs + 140;
    if (monster.hp <= 0) {
      monster.hp = 0;
      _addCorpse(monster);
      _events.add(ArmyMonsterLostEvent(monster.type));
    }
  }

  void _damagePlayer(double amount) {
    if (player.dead || nowMs < player.invulnerableUntilMs) return;
    player.hp -= amount;
    combo.reset();
    _events.add(PlayerDamagedEvent(amount));
    if (player.hp <= 0) {
      player.hp = 0;
      player.dead = true;
      // Spec §3:50: lose 20% of the resources carried in the current match.
      final lost = (resources * 0.20).round();
      resources -= lost;
      player.respawnAtMs = nowMs + respawnDelayMs;
      _events.add(PlayerDiedEvent(lostResources: lost));
    }
  }

  void _respawn() {
    player.dead = false;
    player.hp = maxHp;
    player.position = map.playerSpawn;
    player.invulnerableUntilMs = nowMs + respawnProtectionMs;
    combo.reset();
    // Clear enemies camping the spawn point.
    enemies.removeWhere(
      (enemy) => (enemy.position - player.position).distance < 120,
    );
    _events.add(const PlayerRespawnedEvent());
  }

  void _regenEnergy(int deltaMs) {
    if (player.dead) return;
    player.energy = _clampD(
      player.energy + kit.energyRegenPerSec * deltaMs / 1000,
      0,
      kit.baseMaxEnergy,
    );
  }

  /// XP required to advance from [level] to [level] + 1. Kept as a static
  /// compatibility seam for older callers; the authoritative formula lives in
  /// `progress/xp.dart`.
  static int xpForLevel(int level) => heroXpRequired(level);

  /// The local hero's castle.
  CastleState get playerCastle => castleSystem.playerCastle;

  /// Current cost of the next crystal rebuild (rises with every rebuild).
  int get crystalRebuildCost =>
      castleSystem.rebuildCost(castleSystem.playerCastle);

  /// Rebuilds the next missing crystal at [position] during combat: paid
  /// immediately, built instantly, and only inside the player's territory on
  /// clear dry ground away from obstacles and mines.
  CrystalRebuildResult rebuildCrystalAt(Offset position) {
    final castle = castleSystem.playerCastle;
    final cost = castleSystem.rebuildCost(castle);
    final result = castleSystem.validateRebuild(
      castle,
      position,
      resources: resources,
    );
    if (result != CrystalRebuildResult.ok) return result;
    final crystal = castleSystem.rebuild(castle, position);
    if (crystal == null) return CrystalRebuildResult.atMax;
    resources -= cost;
    _events.add(CrystalRebuiltEvent(slot: crystal.slot, cost: cost));
    return CrystalRebuildResult.ok;
  }

  /// Nearest point the hero can aim at: a hostile monster or a rival crystal.
  Offset? _nearestHostilePoint(double maxRange) {
    final enemy = nearestEnemy(maxRange);
    var best = enemy?.position;
    var bestDistance = enemy == null
        ? maxRange
        : (enemy.position - player.position).distance;
    for (final crystal in castleSystem.hostileCrystals) {
      final distance = (crystal.position - player.position).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = crystal.position;
      }
    }
    return best;
  }

  /// Test seam: applies real crystal damage so the destruction event/cue path
  /// can be exercised without waiting for a wave to reach the castle.
  void debugDamageCrystal(CrystalState crystal, double amount) =>
      _damageCrystal(crystal, amount);

  void _damageCrystal(
    CrystalState crystal,
    double amount, {
    DamageOrigin origin = DamageOrigin.hero,
    MonsterType? monsterType,
  }) {
    if (amount <= 0) return;
    final applied = amount > crystal.hp ? crystal.hp : amount;
    if (origin == DamageOrigin.monster && monsterType != null) {
      xpLedger.recordMonsterObjective(
        type: monsterType,
        crystalId: crystal.id,
        amount: applied,
      );
    }
    final castle = castleSystem.castleOf(crystal.ownerId);
    final destroyed = castleSystem.damageCrystal(crystal, amount);
    if (!destroyed) return;
    if (origin == DamageOrigin.hero) {
      xpLedger.recordCrystal(crystal.ownerId, crystal.slot);
    }
    if (crystal.ownerId != castleSystem.localPlayerId) {
      pendingEssence += 30 + crystal.slot * 10;
      pendingMaterials[ProgressionMaterial.hero] =
          (pendingMaterials[ProgressionMaterial.hero] ?? 0) + 1;
    }
    _events.add(
      CrystalDestroyedEvent(
        ownerId: crystal.ownerId,
        slot: crystal.slot,
        destroyedBy: origin,
        monsterType: monsterType,
      ),
    );
    if (castle != null && castle.fallen) {
      if (crystal.ownerId != castleSystem.localPlayerId) {
        xpLedger.recordCastle(crystal.ownerId);
      }
      _events.add(CastleFellEvent(crystal.ownerId));
    }
    refreshXpState();
  }

  EnemyState? nearestEnemy(double maxRange) {
    EnemyState? best;
    var bestDist = maxRange;
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      final dist = (enemy.position - player.position).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = enemy;
      }
    }
    return best;
  }

  /// The compass-facing direction (of 8) closest to [v].
  ///
  /// Screen space: +x is right (east), +y is down (south), so the sprite
  /// directions follow atan2(dy, dx): 0 → `e`, 45° → `se`, 90° → `s`, …
  static const List<String> octantNames = [
    'e',
    'se',
    's',
    'sw',
    'w',
    'nw',
    'n',
    'ne',
  ];

  static const List<Offset> _octants = [
    Offset(1, 0), // e
    Offset(0.7071, 0.7071), // se
    Offset(0, 1), // s
    Offset(-0.7071, 0.7071), // sw
    Offset(-1, 0), // w
    Offset(-0.7071, -0.7071), // nw
    Offset(0, -1), // n
    Offset(0.7071, -0.7071), // ne
  ];

  /// Index into [octantNames] of the facing closest to [v].
  static int octantIndexOf(Offset v) {
    if (v.distance < 0.001) return 2;
    final angle = math.atan2(v.dy, v.dx);
    return ((angle / (math.pi / 4)).round() + 8) % 8;
  }

  static Offset octantOf(Offset v) => _octants[octantIndexOf(v)];

  static Offset _normalize(Offset v) {
    final length = v.distance;
    return length > 0 ? v / length : const Offset(0, 1);
  }

  static double _angleOf(Offset v) => math.atan2(v.dy, v.dx);
}
