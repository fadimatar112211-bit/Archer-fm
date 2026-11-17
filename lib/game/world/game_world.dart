import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../combat/combo.dart';
import '../combat/hero_kit.dart';

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

  /// Stat buff from `gale_surge`.
  int buffUntilMs = 0;
}

/// Simulation state of one enemy.
class EnemyState {
  EnemyState({
    required this.id,
    required this.kind,
    required this.position,
    required this.maxHp,
    required this.speed,
    required this.contactDamage,
    required this.xpValue,
    this.ranged = false,
  }) : hp = maxHp;

  final String id;
  final String kind;
  Offset position;
  double hp;
  final double maxHp;
  final double speed;
  final double contactDamage;
  final int xpValue;

  /// Ranged enemies keep distance and shoot instead of closing in.
  final bool ranged;

  double attackCooldownUntilMs = 0;
  int windupUntilMs = 0;

  /// Visual hit flash timer (ms timestamp).
  int hitFlashUntilMs = 0;
  Offset facing = const Offset(0, 1);
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
  });

  final String id;
  Offset position;
  final Offset velocity;
  final double damage;
  int pierceLeft;
  double traveled = 0;
  final double maxTravel;
  final int tint;
  final bool big;

  /// True while this arrow was shot by an enemy.
  bool get fromEnemy => tint == 0xFFFF7A5A;
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
  })  : rng = random ?? math.Random(),
        player = PlayerState() {
    player.hp = kit.baseMaxHp;
    player.energy = kit.baseMaxEnergy * 0.5;
    if (spawnWaves) spawnWave(initial: true);
  }

  final HeroKit kit;
  final math.Random rng;

  /// Disable to script exact enemy setups in tests.
  final bool spawnWaves;
  final PlayerState player;
  final List<EnemyState> enemies = [];
  final List<ProjectileState> projectiles = [];
  final List<ZoneState> zones = [];

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
  int get maxAliveEnemies => 8;

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
  /// forwards (`volley_release` for skill-clip abilities, `projectile_release`
  /// for the piercing shot's focused draw).
  void releaseWeaponPayload({required bool volley}) {
    if (player.dead) return;
    final ability = pendingAbilityId;
    if (ability == null) return;
    if (volley && ability != 'piercing_shot') {
      pendingAbilityId = null;
      _fireAbilityVolley(ability);
    } else if (!volley && ability == 'piercing_shot') {
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
        break;
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
    _updateProjectiles(deltaMs);
    _updateZones();
    _updateWaves();
    _regenEnergy(deltaMs);
  }

  List<WorldEvent> drainEvents() {
    final drained = List<WorldEvent>.of(_events);
    _events.clear();
    return drained;
  }

  // ---- Internals ------------------------------------------------------------

  double currentAttackRate() =>
      player.buffUntilMs > nowMs ? kit.attackPace * 1.5 : kit.attackPace;

  double currentDamageMult() => player.buffUntilMs > nowMs ? 1.2 : 1.0;

  double currentMoveSpeed() {
    var speed = kit.moveSpeed;
    if (player.buffUntilMs > nowMs) speed *= 1.25;
    if (player.dodgeBurstUntilMs > nowMs) speed *= 2.2;
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
      final toPlayer = player.position - enemy.position;
      final dist = toPlayer.distance;
      if (dist > 1) enemy.facing = toPlayer / dist;

      if (player.dead) continue;

      if (enemy.windupUntilMs > 0 && nowMs >= enemy.windupUntilMs) {
        enemy.windupUntilMs = 0;
        if (dist < 64) {
          _damagePlayer(enemy.contactDamage);
        }
        enemy.attackCooldownUntilMs = nowMs + 1600;
      }

      final attackRange = enemy.ranged ? 260.0 : 46.0;
      final preferred = enemy.ranged ? 210.0 : 40.0;
      final canAct = nowMs >= enemy.attackCooldownUntilMs &&
          enemy.windupUntilMs == 0;
      if (canAct && dist <= attackRange) {
        if (enemy.ranged) {
          enemy.attackCooldownUntilMs = nowMs + 2400;
          spawnArrow(
            origin: enemy.position,
            direction: enemy.facing,
            damage: enemy.contactDamage,
            speed: 240,
            range: 340,
            tint: 0xFFFF7A5A,
          );
        } else {
          enemy.windupUntilMs = nowMs + 400;
        }
        continue;
      }

      // Movement: close in; ranged enemies hold their preferred distance.
      final Offset stepDir;
      if (enemy.ranged) {
        if (dist > preferred + 40) {
          stepDir = enemy.facing;
        } else if (dist < preferred - 60) {
          stepDir = -enemy.facing;
        } else {
          stepDir = Offset.zero;
        }
      } else {
        stepDir = enemy.facing;
      }
      final speedMult = enemy.windupUntilMs > 0 ? 0.0 : 1.0;
      enemy.position = Offset(
        _clampD(
          enemy.position.dx +
              stepDir.dx * enemy.speed * speedMult * deltaMs / 1000,
          20,
          arenaWidth - 20,
        ),
        _clampD(
          enemy.position.dy +
              stepDir.dy * enemy.speed * speedMult * deltaMs / 1000,
          60,
          arenaHeight - 24,
        ),
      );
    }
    enemies.removeWhere((enemy) => enemy.hp <= 0);
  }

  void _updateProjectiles(int deltaMs) {
    for (final projectile in projectiles) {
      final step = projectile.velocity * (deltaMs / 1000);
      projectile.position = projectile.position + step;
      projectile.traveled += step.distance;
      if (projectile.traveled >= projectile.maxTravel) continue;
      if (projectile.fromEnemy) {
        // Enemy arrow: hits the player once.
        if (!player.dead &&
            nowMs >= player.invulnerableUntilMs &&
            (projectile.position - player.position).distance < 22) {
          projectile.traveled = projectile.maxTravel;
          _damagePlayer(projectile.damage);
        }
        continue;
      }
      for (final enemy in enemies) {
        if (enemy.hp <= 0 || projectile.hitIds.contains(enemy.id)) continue;
        if ((projectile.position - enemy.position).distance < 20) {
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

  void _updateWaves() {
    if (!spawnWaves) return;
    if (nowMs < _waveAtMs) return;
    spawnWave();
  }

  void spawnWave({bool initial = false}) {
    _wave++;
    _waveAtMs = nowMs + (initial ? 1500 : waveIntervalMs);
    var count = math.min(2 + _wave ~/ 2, 5);
    if (initial) count = 3;
    for (var i = 0; i < count && enemies.length < maxAliveEnemies; i++) {
      enemies.add(_spawnEnemy());
    }
  }

  EnemyState _spawnEnemy() {
    Offset position;
    do {
      position = Offset(
        60 + rng.nextDouble() * (arenaWidth - 120),
        80 + rng.nextDouble() * (arenaHeight - 130),
      );
    } while ((position - player.position).distance < 260);
    final roll = rng.nextDouble();
    if (roll < 0.2 && _wave >= 2) {
      return EnemyState(
        id: 'enemy_${_nextEntityId++}',
        kind: 'brute',
        position: position,
        maxHp: 95,
        speed: 55,
        contactDamage: 14,
        xpValue: 25,
      );
    }
    if (roll < 0.55) {
      return EnemyState(
        id: 'enemy_${_nextEntityId++}',
        kind: 'archer',
        position: position,
        maxHp: 26,
        speed: 95,
        contactDamage: 6,
        xpValue: 14,
        ranged: true,
      );
    }
    return EnemyState(
      id: 'enemy_${_nextEntityId++}',
      kind: 'slime',
      position: position,
      maxHp: 40,
      speed: 120,
      contactDamage: 8,
      xpValue: 10,
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
      ),
    );
  }

  void _damageEnemy(EnemyState enemy, double amount) {
    enemy.hp -= amount;
    enemy.hitFlashUntilMs = nowMs + 160;
    totalDamageDealt += amount;
    player.energy = _clampD(player.energy + 2, 0, kit.baseMaxEnergy);
    if (enemy.hp <= 0) {
      kills++;
      _addXp(enemy.xpValue);
      _events.add(EnemyKilledEvent(enemy.kind, enemy.xpValue));
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
