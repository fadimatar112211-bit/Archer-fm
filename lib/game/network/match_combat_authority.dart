import 'dart:math' as math;
import 'dart:ui';

import '../heroes/hero_combat_runtime.dart';
import '../heroes/hero_roster.dart';
import '../../monsters/monster_army.dart';
import '../../monsters/monster_combat.dart';
import '../../monsters/monster_combat_resolver.dart';
import '../../monsters/monster_external_entity_adapter.dart';
import '../../monsters/monster_formation_movement.dart';
import '../../monsters/monster_match_combat_loop.dart';
import '../../monsters/monster_match_runtime.dart';
import '../../monsters/monster_models.dart';
import '../../monsters/monster_projectile_manager.dart';
import '../../monsters/monster_ranged_attack_handler.dart';
import 'match_world_authority.dart';

/// Approved balance/configuration supplied by the host, not invented here.
/// Each player must provide their own pre-match selection of exactly 20 units.
class MatchCombatConfiguration {
  MatchCombatConfiguration({
    required this.monsterCatalog,
    required this.projectileSpeed,
    required this.maxActiveProjectiles,
    required this.maxUnitsPerArmy,
    required this.worldUnitsPerSecond,
  }) {
    if (!projectileSpeed.isFinite || projectileSpeed <= 0 ||
        maxActiveProjectiles <= 0 ||
        maxUnitsPerArmy < 20 ||
        !worldUnitsPerSecond.isFinite || worldUnitsPerSecond <= 0) {
      throw ArgumentError('Combat movement/projectile configuration is invalid.');
    }
  }

  final MonsterCatalog monsterCatalog;
  final double projectileSpeed;
  final int maxActiveProjectiles;
  final int maxUnitsPerArmy;
  final double worldUnitsPerSecond;
}

class MatchHeroState {
  MatchHeroState({
    required this.playerId,
    required this.definition,
    required this.weaponId,
    this.level = 1,
  }) : combat = HeroCombatRuntime(hero: definition, level: level) {
    final index = definition.weapons.indexWhere((weapon) => weapon.id == weaponId);
    if (index < 0) throw ArgumentError.value(weaponId, 'weaponId');
    combat.selectWeapon(index);
    health = maxHealth;
  }

  final String playerId;
  final HeroCombatDefinition definition;
  final String weaponId;
  final int level;
  final HeroCombatRuntime combat;
  late double health;

  double get maxHealth => definition.healthAt(level).toDouble();
  bool get isAlive => health > 0;
  String get entityId => 'hero_$playerId';
}

/// The authoritative combat bridge. It adapts real match heroes and crystals
/// into the existing monster AI/resolver, and routes player attacks into the
/// same live monster/hero/crystal state.
class MatchCombatAuthority {
  MatchCombatAuthority({
    required this.world,
    required Map<String, HeroCombatDefinition> heroes,
    required Map<String, String> weaponIds,
    required Map<String, InitialArmySelection> initialArmies,
    required this.configuration,
    math.Random? random,
  }) {
    if (heroes.length != world.playerIds.length ||
        weaponIds.length != world.playerIds.length ||
        initialArmies.length != world.playerIds.length ||
        world.playerIds.any((id) =>
            !heroes.containsKey(id) ||
            !weaponIds.containsKey(id) ||
            !initialArmies.containsKey(id))) {
      throw ArgumentError('Combat loadouts and initial armies must cover all four players.');
    }

    final armies = <MonsterArmy>[];
    for (final playerId in world.playerIds) {
      final castle = world.castles.castleOf(playerId)!;
      final hero = heroes[playerId]!;
      final weaponId = weaponIds[playerId]!;
      final heroState = MatchHeroState(
        playerId: playerId,
        definition: hero,
        weaponId: weaponId,
      );
      _heroes[playerId] = heroState;
      armies.add(MonsterArmy(
        ownerId: playerId,
        idPrefix: '$playerId-army',
        catalog: configuration.monsterCatalog,
        selection: initialArmies[playerId]!,
        maxUnits: configuration.maxUnitsPerArmy,
        castleX: castle.anchor.dx,
        castleY: castle.anchor.dy,
      ));
    }

    final projectileManager = MonsterProjectileManager(
      maxActiveProjectiles: configuration.maxActiveProjectiles,
    );
    monsters = MonsterMatchRuntime(
      armies: armies,
      combatLoop: MonsterMatchCombatLoop(
        combat: const MonsterCombatController(),
        resolver: const MonsterCombatResolver(),
        rangedHandler: const MonsterRangedAttackHandler(),
        projectiles: projectileManager,
        projectileSpeed: configuration.projectileSpeed,
        projectileId: _projectileId,
        obstaclesFor: (_) => [
          for (final obstacle in world.map.obstacles)
            MonsterMovementObstacle(
              x: obstacle.position.dx,
              y: obstacle.position.dy,
              radius: obstacle.radius,
            ),
        ],
        movementSpeedMultiplierFor: (unit) => world.map.movementFactorAt(
          Offset(unit.positionX, unit.positionY),
        ),
      ),
    );
    _random = random ?? math.Random();
  }

  final MatchWorldAuthority world;
  final MatchCombatConfiguration configuration;
  final Map<String, MatchHeroState> _heroes = {};
  late final MonsterMatchRuntime monsters;
  late final math.Random _random;
  int _nextProjectileId = 1;
  DateTime _now = DateTime.utc(2026, 1, 1);

  Map<String, MatchHeroState> get heroes => Map.unmodifiable(_heroes);
  List<MonsterArmy> get armies => monsters.armies;

  String _projectileId(MonsterUnit _) =>
      'match-projectile-${_nextProjectileId++}-${_random.nextInt(1 << 24)}';

  /// Movement input is a normalized direction, never a client world position.
  /// The speed cap is derived from the selected hero and server tick duration.
  Offset moveHero(String playerId, Offset direction, Duration elapsed) {
    final hero = _requireHero(playerId);
    if (!hero.isAlive) throw StateError('A defeated hero cannot move.');
    if (elapsed.isNegative ||
        !direction.dx.isFinite ||
        !direction.dy.isFinite) {
      throw ArgumentError('Movement input and elapsed time must be finite.');
    }
    final length = direction.distance;
    if (length > 1.000001) {
      throw ArgumentError('Movement direction must be normalized to a maximum length of one.');
    }
    if (length == 0 || elapsed == Duration.zero) {
      return world.playerPositions[playerId]!;
    }
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final distance = hero.definition.moveSpeed *
        configuration.worldUnitsPerSecond *
        seconds *
        (length < 1 ? length : 1.0) *
        world.map.movementFactorAt(world.playerPositions[playerId]!);
    final delta = direction / length * distance;
    return world.movePlayer(playerId, delta, 18);
  }

  /// One manual tap = one hit. Cooldown, weapon multiplier and five-hit combo
  /// are owned by the canonical HeroCombatRuntime.
  CombatActionResult attack(String playerId, String targetId) {
    final hero = _requireHero(playerId);
    if (!hero.isAlive) return _rejected('البطل مهزوم');
    final target = _resolveTarget(targetId);
    if (target == null || !target.isAlive) {
      return _rejected('الهدف غير موجود');
    }
    if (target.ownerId == playerId) return _rejected('لا يمكن مهاجمة حليف');
    final position = world.playerPositions[playerId]!;
    if (_distance(position.dx, position.dy, target.x, target.y) >
        hero.definition.attackRange) {
      return _rejected('الهدف خارج مدى السلاح');
    }
    final result = hero.combat.attack();
    if (!result.accepted) return result;
    target.applyDamage(result.damage.toDouble());
    return result;
  }

  /// Executes an unlocked Ultimate against the selected enemy target. The
  /// authored radius is applied around that target; combo state is untouched.
  CombatActionResult useUltimate(
    String playerId,
    int ultimateIndex,
    String targetId,
  ) {
    final hero = _requireHero(playerId);
    if (!hero.isAlive) return _rejected('البطل مهزوم');
    final target = _resolveTarget(targetId);
    if (target == null || !target.isAlive) {
      return _rejected('الهدف غير موجود');
    }
    if (target.ownerId == playerId) return _rejected('لا يمكن استهداف حليف');
    final origin = world.playerPositions[playerId]!;
    if (_distance(origin.dx, origin.dy, target.x, target.y) >
        hero.definition.attackRange) {
      return _rejected('الهدف خارج مدى المهارة');
    }

    final result = hero.combat.useUltimate(ultimateIndex);
    if (!result.accepted) return result;
    final radius = hero.definition.ultimates[ultimateIndex].radius;
    for (final candidate in _allTargets()) {
      if (candidate.ownerId == playerId || !candidate.isAlive) continue;
      if (_distance(candidate.x, candidate.y, target.x, target.y) <= radius) {
        candidate.applyDamage(result.damage.toDouble());
      }
    }
    return result;
  }

  /// Purchases one unit using the authoritative match wallet. Cost comes from
  /// the canonical monster catalog; failed spawns refund the exact debit.
  MonsterPurchase? purchaseMonster(String playerId, MonsterType type) {
    if (!_requireHero(playerId).isAlive) return null;
    final army = monsters.armies.firstWhere((item) => item.ownerId == playerId);
    final balance = world.resources[playerId]!;
    return army.purchaseAtomically(
      type: type,
      currentResources: balance,
      tryDebit: (amount) => world.trySpendResources(playerId, amount),
      refund: (amount) => world.creditResources(playerId, amount),
    );
  }

  MonsterMatchTickResult tick(Duration elapsed) {
    if (elapsed.isNegative) throw ArgumentError.value(elapsed, 'elapsed');
    for (final hero in _heroes.values) {
      hero.combat.advance(elapsed);
    }
    _now = _now.add(elapsed);
    final result = monsters.tick(
      now: _now,
      elapsed: elapsed,
      externalEntities: _externalEntities(),
    );
    return result;
  }

  void clear() => monsters.combatLoop.clear();

  MatchHeroState _requireHero(String playerId) {
    final hero = _heroes[playerId];
    if (hero == null) throw ArgumentError.value(playerId, 'playerId');
    return hero;
  }

  CombatActionResult _rejected(String message) => CombatActionResult(
        accepted: false,
        messageAr: message,
      );

  double _distance(double x1, double y1, double x2, double y2) =>
      math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));

  _MatchCombatTarget? _resolveTarget(String id) {
    for (final target in _allTargets()) {
      if (target.id == id) return target;
    }
    return null;
  }

  List<_MatchCombatTarget> _allTargets() {
    final targets = <_MatchCombatTarget>[];
    for (final hero in _heroes.values) {
      final position = world.playerPositions[hero.playerId]!;
      targets.add(_MatchCombatTarget(
        id: hero.entityId,
        ownerId: hero.playerId,
        kind: MonsterTargetKind.hero,
        x: position.dx,
        y: position.dy,
        alive: () => hero.isAlive,
        damage: (amount) {
          hero.health = math.max(0, hero.health - amount).toDouble();
          return !hero.isAlive;
        },
      ));
    }
    for (final army in monsters.armies) {
      for (final unit in army.units) {
        targets.add(_MatchCombatTarget(
          id: unit.id,
          ownerId: unit.ownerId,
          kind: MonsterTargetKind.monster,
          x: unit.positionX,
          y: unit.positionY,
          alive: () => unit.isAlive,
          damage: unit.applyDamage,
        ));
      }
    }
    for (final castle in world.castles.castles) {
      if (castle.fallen) continue;
      for (final crystal in castle.alive) {
        targets.add(_MatchCombatTarget(
          id: crystal.id,
          ownerId: crystal.ownerId,
          kind: MonsterTargetKind.crystal,
          x: crystal.position.dx,
          y: crystal.position.dy,
          alive: () => !crystal.destroyed && !castle.fallen,
          damage: (amount) => world.castles.damageCrystal(crystal, amount),
        ));
      }
    }
    return targets;
  }

  Iterable<MonsterExternalEntityAdapter> _externalEntities() sync* {
    for (final hero in _heroes.values) {
      final position = world.playerPositions[hero.playerId]!;
      yield MonsterExternalEntityAdapter(
        id: hero.entityId,
        ownerId: hero.playerId,
        kind: MonsterTargetKind.hero,
        isAlive: hero.isAlive,
        positionX: position.dx,
        positionY: position.dy,
        isAliveNow: () => hero.isAlive,
        positionXNow: () => world.playerPositions[hero.playerId]!.dx,
        positionYNow: () => world.playerPositions[hero.playerId]!.dy,
        applyDamage: (amount) {
          hero.health = math.max(0, hero.health - amount).toDouble();
          return !hero.isAlive;
        },
      );
    }

    for (final castle in world.castles.castles) {
      if (castle.fallen) continue;
      for (final crystal in castle.alive) {
        yield MonsterExternalEntityAdapter(
          id: crystal.id,
          ownerId: crystal.ownerId,
          kind: MonsterTargetKind.crystal,
          isAlive: !crystal.destroyed,
          positionX: crystal.position.dx,
          positionY: crystal.position.dy,
          isAliveNow: () => !crystal.destroyed && !castle.fallen,
          positionXNow: () => crystal.position.dx,
          positionYNow: () => crystal.position.dy,
          applyDamage: (amount) => world.castles.damageCrystal(crystal, amount),
        );
      }
    }
  }
}

class _MatchCombatTarget {
  const _MatchCombatTarget({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.x,
    required this.y,
    required this.alive,
    required this.damage,
  });

  final String id;
  final String ownerId;
  final MonsterTargetKind kind;
  final double x;
  final double y;
  final bool Function() alive;
  final bool Function(double amount) damage;

  bool get isAlive => alive();
  bool applyDamage(double amount) => damage(amount);
}
