import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../combat/combo.dart';
import '../combat/hero_kit.dart';
import '../monsters/monster_models.dart';

/// Logical size of the battle arena in world units.
const double arenaWidth = 960;
const double arenaHeight = 540;

double _clampD(double value, double lo, double hi) =>
    value < lo ? lo : (value > hi ? hi : value);

/// Events the world emits for the UI layer each frame.
sealed class WorldEvent {
  const WorldEvent();
}

class EnemyKilledEvent extends WorldEvent {
  const EnemyKilledEvent(this.enemyKind, this.xpGained);
  final String enemyKind;
  final int xpGained;
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
  const PlayerDiedEvent();
}

class PlayerRespawnedEvent extends WorldEvent {
  const PlayerRespawnedEvent();
}

class AbilityReadyEvent extends WorldEvent {
  const AbilityReadyEvent(this.abilityId);
  final String abilityId;
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

  /// Invulnerability window (dodge) end time.
  int invulnerableUntilMs = 0;

  /// Temporary movement burst from dodging.
  int dodgeBurstUntilMs = 0;

  /// Movement boost from Shadow's veil.
  int speedBoostUntilMs = 0;

  /// Stat buff from `gale_surge`.
  int buffUntilMs = 0;
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

  /// True while this projectile belongs to the hostile side. Hostile shots
  /// damage the player and the player's monsters; friendly shots (the hero and
  /// the player's ranged monsters) damage hostile monsters only.
  final bool hostile;

  bool get fromEnemy => hostile;
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
/// (`setMoveInput`, `requestAttack`, `useAbility`, `requestDodge`), and the
/// sprite layer forwards weapon events at the exact frames the animations
/// define (`projectile_release`, `volley_release`). Damage is only ever dealt
/// through those weapon-event driven spawns, so the bow motion and the damage
/// stay in sync. A fixed-step `update()` advances everything else.
class GameWorld {
  GameWorld({
    required this.kit,
    math.Random? random,
    this.spawnWaves = true,
    Map<MonsterType, int>? startingArmy,
  })  : rng = random ?? math.Random(),
        player = PlayerState(),
        _startingArmy = startingArmy ?? MonsterCatalog.defaultStartingArmy {
    player.hp = kit.baseMaxHp;
    player.energy = kit.baseMaxEnergy * 0.5;
    if (spawnWaves) {
      _spawnStartingArmy();
      spawnWave(initial: true);
    } else if (startingArmy != null) {
      _spawnStartingArmy();
    }
  }

  final HeroKit kit;
  final math.Random rng;

  /// Disable to script exact enemy setups in tests.
  final bool spawnWaves;
  final PlayerState player;
  final List<EnemyState> enemies = [];

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

  /// Match currency used to buy monsters during the battle.
  int resources = 320;

  /// Permanent currency used to upgrade monster types between/inside
  /// matches. Earned by defeating hostile monsters.
  int essence = 0;

  final Map<MonsterType, int> _startingArmy;
  int _armySeq = 0;
  int _incomeCarryMs = 0;

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
  int dodgeReadyAtMs = 0;
  final Map<String, int> abilityReadyAtMs = {};

  // Progression.
  int kills = 0;
  int level = 1;
  int xp = 0;
  double totalDamageDealt = 0;

  int _waveAtMs = 0;
  int _wave = 0;
  int _nextEntityId = 0;

  final List<WorldEvent> _events = [];

  static const int kitComboWindowMs = 1800;

  // ---- Tunables -------------------------------------------------------------

  double get attackRange => 260;
  int get attackCycleMs => (1670 / kit.attackPace).round();
  double get projectileSpeed => 430;
  double get projectileRange => 330;
  int get respawnDelayMs => 2500;
  int get dodgeCooldownMs => 3000;
  int get waveIntervalMs => 8000;
  int get maxAliveEnemies => maxAliveEnemiesCap;

  // ---- Input ----------------------------------------------------------------

  void setMoveInput(Offset direction) {
    final length = direction.distance;
    moveInput = length > 1 ? direction / length : direction;
  }

  /// Whether a normal attack can start right now.
  bool canAttack() => !player.dead && nowMs >= attackReadyAtMs;

  /// Starts a normal attack: registers the combo hit and captures its damage
  /// multiplier. The arrow itself spawns when the animation reaches its
  /// `projectile_release` frame and the sprite layer calls [releaseArrow].
  bool requestAttack() {
    if (pendingAbilityId != null) return false;
    if (!canAttack()) return false;
    final hit = combo.advance(nowMs);
    pendingHitMultiplier = kit.comboHit(hit).multiplier;
    attackReadyAtMs = nowMs + (attackCycleMs / currentAttackRate()).round();
    // Face the auto-aim target, or the movement direction while kiting.
    final target = nearestEnemy(attackRange);
    if (target != null) {
      player.facing = _normalize(target.position - player.position);
    } else if (moveInput.distance > 0.01) {
      player.facing = _normalize(moveInput);
    }
    return true;
  }

  /// Spawns the arrow at the `projectile_release` animation frame.
  void releaseArrow() {
    if (player.dead) return;
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
    if (player.dead) return null;
    if (pendingAbilityId != null) return null;
    final def = kit.abilityById(abilityId);
    if (def == null) return null;
    if (def.unlockLevel > level) return null;
    if (nowMs < (abilityReadyAtMs[abilityId] ?? 0)) return null;
    if (player.energy < def.energyCost) return null;
    abilityReadyAtMs[abilityId] = nowMs + def.cooldownMs;
    player.energy -= def.energyCost;
    pendingAbilityId = abilityId;
    return abilityId;
  }

  /// Spawns the ability payload on the weapon-event frame the sprite layer
  /// forwards. [volley] true = the skill-clip's burst event (`volley_release`
  /// for Ranger, `inferno_burst` for Flame); false = the primary clip's
  /// release/impact event (`projectile_release` / `melee_impact`).
  void releaseWeaponPayload({required bool volley}) {
    if (player.dead) return;
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
    _damageEnemy(primary, primaryDamage);
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
        // 8 s: every thrust releases a second 40% charge on its target.
        player.buffUntilMs = nowMs + 8000;
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
    player.position = Offset(
      _clampD(target.position.dx - target.facing.dx * 30, 28, arenaWidth - 28),
      _clampD(target.position.dy - target.facing.dy * 30, 70, arenaHeight - 28),
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
    if (player.dead) return;
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
      // Static field: a buffed Storm releases a second 40% charge on the
      // thrust's target (first enemy hit).
      if (kit.heroId == 'storm' &&
          enemy.hp > 0 &&
          player.buffUntilMs > nowMs) {
        _damageEnemy(
          enemy,
          kit.baseDamage * 0.4 * currentDamageMult(),
        );
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

  /// Starts the dodge: i-frames + a short movement burst. Resets the combo,
  /// because a dodge interrupts the attack chain.
  bool requestDodge() {
    if (player.dead || nowMs < dodgeReadyAtMs) return false;
    dodgeReadyAtMs = nowMs + dodgeCooldownMs;
    player.invulnerableUntilMs = nowMs + 500;
    player.dodgeBurstUntilMs = nowMs + 320;
    combo.reset();
    return true;
  }

  // ---- Simulation -----------------------------------------------------------

  /// Fixed-step advance. Call with small deltas (16 ms) from the game loop.
  void update(int deltaMs) {
    nowMs += deltaMs;
    _updatePlayer(deltaMs);
    _updateEnemies(deltaMs);
    _updateArmy(deltaMs);
    _updateProjectiles(deltaMs);
    _updateZones();
    _updateFireWaves(deltaMs);
    _updateBurns();
    _pruneFx();
    _pruneCorpses();
    _updateEconomy(deltaMs);
    _updateWaves();
    _regenEnergy(deltaMs);
  }

  List<WorldEvent> drainEvents() {
    final drained = List<WorldEvent>.of(_events);
    _events.clear();
    return drained;
  }

  // ---- Internals ------------------------------------------------------------

  double currentAttackRate() => player.buffUntilMs > nowMs
      ? kit.attackPace * kit.buffRateMult
      : kit.attackPace;

  double currentDamageMult() =>
      player.buffUntilMs > nowMs ? kit.buffDamageMult : 1.0;

  /// Melee reach, widened while the rage buff is active (Storm's tempest
  /// rage stretches the spear line the farthest).
  double currentMeleeRange() => kit.meleeRange *
      (player.buffUntilMs > nowMs ? (kit.heroId == 'storm' ? 1.25 : 1.2) : 1.0);

  double currentMoveSpeed() {
    var speed = kit.moveSpeed;
    if (player.buffUntilMs > nowMs) speed *= kit.buffMoveMult;
    if (player.dodgeBurstUntilMs > nowMs) speed *= 2.2;
    if (player.speedBoostUntilMs > nowMs) speed *= 1.35;
    return speed;
  }

  void _updatePlayer(int deltaMs) {
    if (player.dead) {
      if (nowMs >= player.respawnAtMs) _respawn();
      return;
    }
    final speed = currentMoveSpeed();
    final step = moveInput * (speed * deltaMs / 1000);
    player.position = Offset(
      _clampD(player.position.dx + step.dx, 28, arenaWidth - 28),
      _clampD(player.position.dy + step.dy, 70, arenaHeight - 28),
    );
    if (moveInput.distance > 0.01) {
      player.facing = _normalize(moveInput);
    }
  }

  void _updateEnemies(int deltaMs) {
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      enemy.moving = false;

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
        final anchor = Offset(
          _clampD(
            player.position.dx +
                armyFormationOffset(ally.groupSlot, army.length).dx,
            26,
            arenaWidth - 26,
          ),
          _clampD(
            player.position.dy +
                armyFormationOffset(ally.groupSlot, army.length).dy,
            70,
            arenaHeight - 26,
          ),
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
          );
        } else {
          _damageEnemy(target, ally.contactDamage);
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
    final step = dir * (monster.speed * speedMult * deltaMs / 1000);
    monster.position = Offset(
      _clampD(monster.position.dx + step.dx, 20, arenaWidth - 20),
      _clampD(monster.position.dy + step.dy, 60, arenaHeight - 24),
    );
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
      for (final enemy in enemies) {
        if (enemy.hp <= 0 || projectile.hitIds.contains(enemy.id)) continue;
        if ((projectile.position - enemy.position).distance <
            enemy.radius + 8) {
          projectile.hitIds.add(enemy.id);
          _damageEnemy(enemy, projectile.damage);
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
        60 + rng.nextDouble() * (arenaWidth - 120),
        80 + rng.nextDouble() * (arenaHeight - 130),
      );
      tries++;
    } while (tries < 40 &&
        ((position - player.position).distance < 280 ||
            army.any((ally) =>
                (ally.position - position).distance <
                ally.radius + 30)));

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
    var position = Offset(
      _clampD(base.dx + offset.dx + jitter.dx, 26, arenaWidth - 26),
      _clampD(base.dy + offset.dy + jitter.dy, 70, arenaHeight - 26),
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
    position = Offset(
      _clampD(position.dx, 26, arenaWidth - 26),
      _clampD(position.dy, 70, arenaHeight - 26),
    );
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
  /// army is full or the player cannot afford it. Reinforcements appear beside
  /// the player, the current stand-in for the castle spawn point.
  bool buyMonster(MonsterType type) {
    final price = MonsterCatalog.def(type).price;
    if (army.length >= maxArmySize || resources < price) return false;
    resources -= price;
    _spawnArmyMonster(
      type,
      slot: army.length,
      near: player.position + const Offset(0, 46),
    );
    return true;
  }

  bool canBuyMonster(MonsterType type) =>
      army.length < maxArmySize &&
      resources >= MonsterCatalog.def(type).price;

  /// Permanent per-type upgrade, paid with monster essence. The new level is
  /// applied to every future purchase (existing monsters keep their stats).
  bool upgradeMonster(MonsterType type) {
    final cost = upgrades.upgradeCost(type);
    if (!upgrades.canUpgrade(type, essence)) return false;
    upgrades.upgrade(type, essence: essence);
    essence -= cost;
    return true;
  }

  void _updateEconomy(int deltaMs) {
    // Passive match income stands in for the mine system until it exists.
    _incomeCarryMs += deltaMs;
    while (_incomeCarryMs >= 1500) {
      _incomeCarryMs -= 1500;
      resources = math.min(9999, resources + 2);
    }
  }

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
      ),
    );
  }

  void _damageEnemy(EnemyState enemy, double amount) {
    if (enemy.hp <= 0) return;
    enemy.hp -= amount;
    enemy.hitFlashUntilMs = nowMs + 160;
    totalDamageDealt += amount;
    if (!player.dead) {
      player.energy = _clampD(player.energy + 2, 0, kit.baseMaxEnergy);
    }
    if (enemy.hp <= 0) {
      enemy.hp = 0;
      kills++;
      _addXp(enemy.xpValue);
      _addCorpse(enemy);
      // Permanent currency for the kill, scaled with the monster's value.
      essence += 1 + enemy.xpValue ~/ 12;
      resources = math.min(
        9999,
        resources + 2 + MonsterCatalog.def(enemy.type).price ~/ 6,
      );
      _events.add(EnemyKilledEvent(enemy.kind, enemy.xpValue));
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
      player.respawnAtMs = nowMs + respawnDelayMs;
      _events.add(const PlayerDiedEvent());
    }
  }

  void _respawn() {
    player.dead = false;
    player.hp = kit.baseMaxHp;
    player.position = const Offset(arenaWidth / 2, arenaHeight * 0.62);
    player.invulnerableUntilMs = nowMs + 1500;
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

  void _addXp(int amount) {
    if (level >= 40) return;
    xp += amount;
    while (level < 40 && xp >= xpForLevel(level)) {
      xp -= xpForLevel(level);
      level++;
      final unlocked = kit.abilities
          .where((ability) => ability.unlockLevel == level)
          .map((ability) => ability.id)
          .toList();
      _events.add(LevelUpEvent(level, unlocked));
      for (final id in unlocked) {
        _events.add(AbilityReadyEvent(id));
      }
    }
  }

  /// XP required to advance from [level] to [level] + 1.
  static int xpForLevel(int level) => 30 + level * 45;

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
