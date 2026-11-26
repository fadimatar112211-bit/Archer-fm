import 'dart:math' as math;

import '../monsters/monster_army.dart';
import '../monsters/monster_combat.dart';
import '../monsters/monster_combat_resolver.dart';
import '../monsters/monster_external_entity_adapter.dart';
import '../monsters/monster_match_combat_loop.dart';
import '../monsters/monster_match_runtime.dart';
import '../monsters/monster_models.dart';
import '../monsters/monster_projectile_manager.dart';
import '../monsters/monster_projectiles.dart';
import '../monsters/monster_ranged_attack_handler.dart';
import 'arena_map.dart';
import 'arena_navigation.dart';

/// One authoritative hero in the arena match.
///
/// Rendering (Hero3D) reads this state; combat, movement, health and respawn
/// stay independent of the widget layer so the match is unit-testable.
class ArenaHeroState {
  ArenaHeroState({
    required this.id,
    required this.ownerId,
    required this.playerIndex,
    required this.heroId,
    required this.x,
    required this.y,
    required this.spawnX,
    required this.spawnY,
    this.maxHealth = 100,
  }) : health = maxHealth;

  final String id;
  final String ownerId;
  final int playerIndex;

  /// Hero3D asset id: ranger, flame, shadow, storm.
  final String heroId;
  final double spawnX;
  final double spawnY;
  final int maxHealth;

  double x;
  double y;
  int health;
  double facingX = 0;
  double facingY = 1;
  double respawnRemaining = 0;

  final List<(double, double)> path = [];
  int pathIndex = 0;

  bool get isAlive => health > 0;
  double get healthFraction => (health / maxHealth).clamp(0.0, 1.0).toDouble();

  bool applyDamage(double amount) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    if (!isAlive) return false;
    health = math.max(0, health - amount.round());
    return !isAlive;
  }

  void respawn() {
    health = maxHealth;
    x = spawnX;
    y = spawnY;
    respawnRemaining = 0;
    path.clear();
    pathIndex = 0;
  }

  void clearPath() {
    path.clear();
    pathIndex = 0;
  }
}

class ArenaCampState {
  ArenaCampState({
    required this.camp,
    required this.ownerId,
    required this.army,
  }) : timer = camp.spawnSeconds;

  final ArenaCamp camp;
  final String ownerId;
  final MonsterArmy army;
  double timer;
  bool hasSpawned = false;

  int get aliveCount => army.aliveCount;
  bool get isWaiting => aliveCount == 0;
}

class ArenaControlPointState {
  ArenaControlPointState(this.point);

  final ArenaControlPoint point;
  String? ownerId;
  String? capturingOwnerId;
  double captureProgress = 0;

  static const double captureSeconds = 8;
}

class ArenaMatch {
  ArenaMatch({
    required this.map,
    MonsterCatalog? catalog,
    this.clock,
  }) : catalog = catalog ?? defaultCatalog() {
    for (var i = 0; i < map.players.length; i++) {
      final player = map.players[i];
      heroes.add(ArenaHeroState(
        id: 'hero:${player.id}',
        ownerId: player.id,
        playerIndex: i,
        heroId: _heroIds[i % _heroIds.length],
        x: player.spawnX,
        y: player.spawnY,
        spawnX: player.spawnX,
        spawnY: player.spawnY,
      ));
    }

    for (final camp in map.camps) {
      final ownerId = 'camp:${camp.id}';
      final army = MonsterArmy.fromUnits(
        ownerId: ownerId,
        idPrefix: ownerId,
        catalog: this.catalog,
        units: const [],
        castleX: camp.x,
        castleY: camp.y,
      );
      final state = ArenaCampState(camp: camp, ownerId: ownerId, army: army);
      camps.add(state);
      armies.add(army);
      _campByOwner[ownerId] = state;
      _externalEntities.add(MonsterExternalEntityAdapter(
        id: 'camp-anchor:${camp.id}',
        ownerId: ownerId,
        kind: MonsterTargetKind.crystal,
        isAlive: true,
        positionX: camp.x,
        positionY: camp.y,
        applyDamage: (_) => false,
      ));
    }

    for (final hero in heroes) {
      _externalEntities.add(MonsterExternalEntityAdapter(
        id: hero.id,
        ownerId: hero.ownerId,
        kind: MonsterTargetKind.hero,
        isAlive: hero.isAlive,
        positionX: hero.x,
        positionY: hero.y,
        isAliveNow: () => hero.isAlive,
        positionXNow: () => hero.x,
        positionYNow: () => hero.y,
        applyDamage: (amount) {
          final died = hero.applyDamage(amount);
          if (died) {
            hero.respawnRemaining = heroRespawnSeconds;
            addEvent('سقط ${hero.ownerId}. إعادة الظهور بعد ${heroRespawnSeconds.toInt()} ث');
          }
          return died;
        },
      ));
    }

    for (final crystal in map.crystals) {
      _externalEntities.add(MonsterExternalEntityAdapter(
        id: 'crystal:${crystal.id}',
        ownerId: crystal.ownerId,
        kind: MonsterTargetKind.crystal,
        isAlive: crystal.isAlive,
        positionX: crystal.x,
        positionY: crystal.y,
        isAliveNow: () => crystal.isAlive,
        applyDamage: (amount) {
          final destroyed = crystal.applyDamage(amount);
          if (destroyed) _onCrystalDestroyed(crystal);
          return destroyed;
        },
      ));
    }

    for (final point in map.controlPoints) {
      controlPoints.add(ArenaControlPointState(point));
    }

    final projectiles = MonsterProjectileManager(maxActiveProjectiles: 96);
    _grid = ArenaMonsterNavigationGrid(map);
    _gridRevision = map.revision;
    _combatLoop = MonsterMatchCombatLoop(
      combat: const MonsterCombatController(),
      resolver: const MonsterCombatResolver(),
      rangedHandler: const MonsterRangedAttackHandler(),
      projectiles: projectiles,
      projectileSpeed: 18,
      projectileId: (source) => '${source.id}-projectile-${_projectileSeq++}',
      navigationGrid: _grid,
    );
    _runtime = MonsterMatchRuntime(armies: armies, combatLoop: _combatLoop);
  }

  static const List<String> _heroIds = ['ranger', 'flame', 'shadow', 'storm'];

  static const double heroMoveSpeed = 5.0;
  static const double heroAttackRange = 4.0;
  static const double heroDamage = 45.0;
  static const double heroRespawnSeconds = 8.0;

  static const double towerDamage = 28.0;
  static const double towerCooldownSeconds = 1.2;

  final ArenaMap map;
  final MonsterCatalog catalog;
  final DateTime Function()? clock;

  final List<ArenaHeroState> heroes = [];
  final List<ArenaCampState> camps = [];
  final List<ArenaControlPointState> controlPoints = [];
  final List<MonsterArmy> armies = [];
  final List<MonsterExternalEntityAdapter> _externalEntities = [];
  final Map<String, ArenaCampState> _campByOwner = {};
  final Map<String, ArenaCampState> _campByUnit = {};
  final Map<String, double> _towerCooldowns = {};
  final List<String> _events = [];

  late final MonsterMatchCombatLoop _combatLoop;
  late MonsterMatchRuntime _runtime;
  late ArenaMonsterNavigationGrid _grid;
  int _gridRevision = 0;
  int _projectileSeq = 0;
  DateTime _now = DateTime.utc(2026, 11, 26, 12);
  bool _disposed = false;

  MonsterMatchRuntime get runtime => _runtime;
  ArenaMonsterNavigationGrid get navigationGrid => _grid;
  List<MonsterUnit> get liveMonsters => _runtime.liveUnits;
  List<MonsterUnit> get dyingMonsters => _runtime.dyingUnits;
  List<MonsterProjectile> get projectiles =>
      _combatLoop.projectiles.active;
  Set<String> get attackingMonsterIds =>
      _runtime.lastResult?.attackingUnitIds ?? const {};

  List<String> get events => List.unmodifiable(_events);
  List<ArenaCrystal> get crystals => map.crystals;

  ArenaHeroState get localHero => heroes.first;
  ArenaPlayer get localPlayer => map.players.first;

  String get clockLabel {
    final minutes = _now.minute.toString().padLeft(2, '0');
    final seconds = _now.second.toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static MonsterCatalog defaultCatalog() => MonsterCatalog({
        MonsterType.blindStalker: MonsterDefinition(
          type: MonsterType.blindStalker,
          baseStats: MonsterStats(
            // goblin camp: 150 HP / 12 damage / 10 gold (design table).
            maxHealth: 150,
            damage: 12,
            moveSpeed: 3.5,
            attackRange: 2.2,
            attackCooldown: const Duration(milliseconds: 900),
            purchaseCost: 10,
          ),
        ),
        MonsterType.werewolf: MonsterDefinition(
          type: MonsterType.werewolf,
          baseStats: MonsterStats(
            // wolf camp: 400 HP / 30 damage / 30 gold.
            maxHealth: 400,
            damage: 30,
            moveSpeed: 5.5,
            attackRange: 2.4,
            attackCooldown: const Duration(milliseconds: 800),
            purchaseCost: 30,
          ),
        ),
        MonsterType.stoneGolem: MonsterDefinition(
          type: MonsterType.stoneGolem,
          baseStats: MonsterStats(
            // golem camp: 1400 HP / 70 damage / 100 gold.
            maxHealth: 1400,
            damage: 70,
            moveSpeed: 2.0,
            attackRange: 3.0,
            attackCooldown: const Duration(milliseconds: 1400),
            purchaseCost: 100,
          ),
        ),
        MonsterType.bogMonster: MonsterDefinition(
          type: MonsterType.bogMonster,
          baseStats: MonsterStats(
            // crystal drake: 6000 HP / 140 damage / 500 gold.
            maxHealth: 6000,
            damage: 140,
            moveSpeed: 3.0,
            attackRange: 3.5,
            attackCooldown: const Duration(milliseconds: 1500),
            purchaseCost: 500,
          ),
        ),
      });

  /// Closest available 3D monster for each authored camp type.
  ///
  /// The package has four camp types (goblin/wolf/golem/crystal_drake) but the
  /// integrated 3D pack has four different monsters. The mapping keeps the
  /// authored counts, HP, damage and gold while documenting the visual
  /// conflict instead of silently renaming the map data.
  static MonsterType monsterTypeForCamp(ArenaCampType type) {
    switch (type) {
      case ArenaCampType.goblin:
        return MonsterType.blindStalker;
      case ArenaCampType.wolf:
        return MonsterType.werewolf;
      case ArenaCampType.golem:
        return MonsterType.stoneGolem;
      case ArenaCampType.crystalDrake:
        return MonsterType.bogMonster;
    }
  }

  static String campLabel(ArenaCampType type) {
    switch (type) {
      case ArenaCampType.goblin:
        return 'عفريت';
      case ArenaCampType.wolf:
        return 'ذئب';
      case ArenaCampType.golem:
        return 'غولم';
      case ArenaCampType.crystalDrake:
        return 'تنين البلورة';
    }
  }

  ArenaCampState? campForUnit(String unitId) => _campByUnit[unitId];

  Iterable<ArenaCrystal> aliveCrystalsOf(String ownerId) =>
      map.crystals.where((c) => c.ownerId == ownerId && c.isAlive);

  int aliveCrystalsCount(String ownerId) => aliveCrystalsOf(ownerId).length;

  ArenaHeroState heroFor(String ownerId) =>
      heroes.firstWhere((hero) => hero.ownerId == ownerId);

  void _onCrystalDestroyed(ArenaCrystal crystal) {
    map.destroyCrystal(crystal.id);
    addEvent('تحطمت بلورة ${crystal.id} (${crystal.ownerId}) وفُتح ممرها');
  }

  void _syncDestroyedCrystals() {
    for (final crystal in map.crystals) {
      if (crystal.destroyed) map.destroyCrystal(crystal.id);
    }
  }

  void addEvent(String message) {
    _events.insert(0, message);
    if (_events.length > 12) _events.removeRange(12, _events.length);
  }

  /// Advances the authoritative arena simulation.
  void update(Duration elapsed) {
    if (_disposed) throw StateError('ArenaMatch was disposed.');
    if (elapsed.isNegative) throw ArgumentError.value(elapsed, 'elapsed');
    if (elapsed == Duration.zero) return;
    final seconds = elapsed.inMicroseconds / 1e6;
    _now = _now.add(elapsed);

    _syncDestroyedCrystals();
    _updateHeroRespawns(seconds);
    _updateCampSpawns(seconds);
    _updateHeroPaths(seconds);
    _updateTowers(seconds);
    _updateControlPoints(seconds);
    _tickMonsters(elapsed);
    _enforceLeash(seconds);
  }

  void _updateHeroRespawns(double seconds) {
    for (final hero in heroes) {
      if (hero.isAlive) continue;
      hero.respawnRemaining -= seconds;
      if (hero.respawnRemaining <= 0) {
        hero.respawn();
        addEvent('عاد ${hero.ownerId} إلى نقطة البداية');
      }
    }
  }

  void _updateCampSpawns(double seconds) {
    for (final state in camps) {
      if (state.aliveCount > 0) continue;
      state.timer -= seconds;
      if (state.timer > 0) continue;
      _spawnCamp(state);
    }
  }

  void _spawnCamp(ArenaCampState state) {
    final camp = state.camp;
    final type = monsterTypeForCamp(camp.type);
    final centerCell = map.nearestWalkable(map.worldToCell(camp.x, camp.y));
    for (var i = 0; i < camp.count; i++) {
      final angle = camp.count == 1 ? 0.0 : i / camp.count * math.pi * 2;
      final radius = camp.count == 1 ? 0.0 : 1.2;
      var x = camp.x + math.cos(angle) * radius;
      var y = camp.y + math.sin(angle) * radius;
      if (!map.walkableAt(x, y)) {
        final cell = map.nearestWalkable(map.worldToCell(x, y));
        final center = map.cellCenter(cell);
        x = center.$1;
        y = center.$2;
      }
      if (!map.walkableAt(x, y)) {
        final center = map.cellCenter(centerCell);
        x = center.$1;
        y = center.$2;
      }
      final unit = state.army.addUnit(type, positionX: x, positionY: y);
      _campByUnit[unit.id] = state;
    }
    state.timer = camp.respawnSeconds;
    state.hasSpawned = true;
    addEvent('ظهر ${camp.count} × ${campLabel(camp.type)} في ${camp.id}');
  }

  void _updateHeroPaths(double seconds) {
    for (final hero in heroes) {
      if (!hero.isAlive) continue;
      final distance = heroMoveSpeed * seconds;
      if (hero.path.isNotEmpty) {
        _advanceAlongPath(hero, distance);
      }
    }
  }

  void _advanceAlongPath(ArenaHeroState hero, double distance) {
    var remaining = distance;
    while (remaining > 0 && hero.pathIndex < hero.path.length) {
      final target = hero.path[hero.pathIndex];
      final dx = target.$1 - hero.x;
      final dy = target.$2 - hero.y;
      final segment = math.sqrt(dx * dx + dy * dy);
      if (segment <= 0.08) {
        hero.pathIndex++;
        continue;
      }
      final step = math.min(remaining, segment);
      final nx = hero.x + dx / segment * step;
      final ny = hero.y + dy / segment * step;
      if (!map.walkableAt(nx, ny)) {
        hero.clearPath();
        return;
      }
      hero.x = nx;
      hero.y = ny;
      hero.facingX = dx / segment;
      hero.facingY = dy / segment;
      remaining -= step;
      if (step >= segment - 1e-9) hero.pathIndex++;
    }
    if (hero.pathIndex >= hero.path.length) hero.clearPath();
  }

  /// Tap-to-move: computes a weighted A* route and stores it for [update].
  List<ArenaCell> moveHeroTo(ArenaHeroState hero, double x, double y) {
    if (!hero.isAlive) return const [];
    final start = map.worldToCell(hero.x, hero.y);
    final requested = map.worldToCell(x, y);
    final goal = map.nearestWalkable(requested);
    if (start == goal) return const [];
    final cells = map.findPath(start, goal);
    if (cells.isEmpty) {
      addEvent('لا يوجد مسار إلى الهدف');
      return const [];
    }
    final waypoints = map.worldPath(cells);
    hero.path
      ..clear()
      ..add((hero.x, hero.y))
      ..addAll(waypoints);
    hero.pathIndex = 0;
    return cells;
  }

  /// Joystick/direct movement with cell collision and axis sliding.
  bool moveHeroBy(ArenaHeroState hero, double dx, double dy, Duration elapsed) {
    if (!hero.isAlive || elapsed.isNegative) return false;
    final length = math.sqrt(dx * dx + dy * dy);
    if (!length.isFinite || length < 0.001) return false;
    final seconds = elapsed.inMicroseconds / 1e6;
    final step = heroMoveSpeed * seconds;
    final ux = dx / length;
    final uy = dy / length;
    hero.clearPath();
    hero.facingX = ux;
    hero.facingY = uy;

    var nx = hero.x + ux * step;
    var ny = hero.y + uy * step;
    if (map.walkableAt(nx, ny)) {
      hero.x = nx;
      hero.y = ny;
      return true;
    }
    nx = hero.x + ux * step;
    if (map.walkableAt(nx, hero.y)) {
      hero.x = nx;
      return true;
    }
    ny = hero.y + uy * step;
    if (map.walkableAt(hero.x, ny)) {
      hero.y = ny;
      return true;
    }
    return false;
  }

  void _updateTowers(double seconds) {
    for (final tower in map.towers) {
      var cooldown = (_towerCooldowns[tower.id] ?? 0) - seconds;
      if (cooldown > 0) {
        _towerCooldowns[tower.id] = cooldown;
        continue;
      }
      MonsterUnit? best;
      var bestDistance = double.infinity;
      for (final unit in _runtime.liveUnits) {
        if (!unit.isAlive) continue;
        final dx = unit.positionX - tower.rect.centerX;
        final dy = unit.positionY - tower.rect.centerY;
        final d2 = dx * dx + dy * dy;
        if (d2 > tower.range * tower.range || d2 >= bestDistance) continue;
        if (!map.lineOfSight(
          tower.rect.centerX,
          tower.rect.centerY,
          unit.positionX,
          unit.positionY,
        )) {
          continue;
        }
        best = unit;
        bestDistance = d2;
      }
      if (best == null) continue;
      best.applyDamage(towerDamage);
      _towerCooldowns[tower.id] = towerCooldownSeconds;
      addEvent('برج ${tower.id} أصاب ${campLabelForUnit(best)}');
    }
  }

  String campLabelForUnit(MonsterUnit unit) {
    final camp = _campByUnit[unit.id];
    if (camp == null) return 'وحش';
    return campLabel(camp.camp.type);
  }

  void _updateControlPoints(double seconds) {
    final drakeAlive = camps.any((state) =>
        state.camp.type == ArenaCampType.crystalDrake && state.aliveCount > 0);
    for (final state in controlPoints) {
      final point = state.point;
      if (point.id == 'CentralAltar' && drakeAlive) {
        state.capturingOwnerId = null;
        state.captureProgress = 0;
        continue;
      }
      final owners = <String>{};
      for (final hero in heroes) {
        if (!hero.isAlive) continue;
        final dx = hero.x - point.x;
        final dy = hero.y - point.y;
        if (dx * dx + dy * dy <= point.captureRadius * point.captureRadius) {
          owners.add(hero.ownerId);
        }
      }
      if (owners.length != 1) {
        state.capturingOwnerId = null;
        state.captureProgress = math.max(0, state.captureProgress - seconds);
        continue;
      }
      final owner = owners.single;
      if (state.ownerId == owner) {
        state.capturingOwnerId = null;
        state.captureProgress = 0;
        continue;
      }
      if (state.capturingOwnerId != owner) {
        state.capturingOwnerId = owner;
        state.captureProgress = 0;
      }
      state.captureProgress += seconds;
      if (state.captureProgress >= ArenaControlPointState.captureSeconds) {
        state.ownerId = owner;
        state.capturingOwnerId = null;
        state.captureProgress = 0;
        addEvent('سيطر ${owner} على ${point.id}');
      }
    }
  }

  void _tickMonsters(Duration elapsed) {
    if (map.revision != _gridRevision) {
      _grid = ArenaMonsterNavigationGrid(map);
      _gridRevision = map.revision;
    }
    if (_runtime.liveUnits.isEmpty) return;
    _runtime.tick(
      externalEntities: _externalEntities,
      now: _now,
      elapsed: elapsed,
      navigationGrid: _grid,
    );
  }

  void _enforceLeash(double seconds) {
    for (final state in camps) {
      for (final unit in state.army.units) {
        if (!unit.isAlive) continue;
        final dx = unit.positionX - state.camp.x;
        final dy = unit.positionY - state.camp.y;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance > state.camp.leash) {
          unit.targetId = null;
          unit.targetKind = null;
        } else if (distance <= state.camp.leash * 0.5 &&
            unit.targetId == null &&
            unit.health < unit.stats.maxHealth) {
          unit.health = math.min(
            unit.stats.maxHealth,
            unit.health + unit.stats.maxHealth * 0.08 * seconds,
          );
        }
      }
    }
  }

  /// Hero basic attack against the nearest monster or enemy crystal in range.
  bool attackWithHero(ArenaHeroState hero) {
    if (!hero.isAlive) return false;
    MonsterUnit? monster;
    var bestDistance = double.infinity;
    for (final unit in _runtime.liveUnits) {
      if (!unit.isAlive) continue;
      final dx = unit.positionX - hero.x;
      final dy = unit.positionY - hero.y;
      final d2 = dx * dx + dy * dy;
      if (d2 > heroAttackRange * heroAttackRange || d2 >= bestDistance) continue;
      if (!map.lineOfSight(hero.x, hero.y, unit.positionX, unit.positionY)) {
        continue;
      }
      monster = unit;
      bestDistance = d2;
    }

    ArenaCrystal? crystal;
    for (final candidate in map.crystals) {
      if (!candidate.isAlive || candidate.ownerId == hero.ownerId) continue;
      final dx = candidate.x - hero.x;
      final dy = candidate.y - hero.y;
      final d2 = dx * dx + dy * dy;
      if (d2 > heroAttackRange * heroAttackRange || d2 >= bestDistance) continue;
      if (!map.lineOfSight(hero.x, hero.y, candidate.x, candidate.y)) continue;
      crystal = candidate;
      bestDistance = d2;
    }

    if (monster != null) {
      final label = campLabelForUnit(monster);
      final died = monster.applyDamage(heroDamage);
      addEvent(died ? 'أسقط البطل $label' : 'أصاب البطل $label');
      return true;
    }
    if (crystal != null) {
      final destroyed = crystal.applyDamage(heroDamage);
      if (destroyed) _onCrystalDestroyed(crystal);
      addEvent(destroyed
          ? 'دمّر البطل بلورة ${crystal.id}'
          : 'أصاب البطل بلورة ${crystal.id}');
      return true;
    }
    addEvent('لا يوجد هدف داخل المدى (4 م)');
    return false;
  }

  /// Convenience used by tests and the HUD.
  ArenaCrystal? nearestEnemyCrystal(ArenaHeroState hero) {
    ArenaCrystal? best;
    var bestDistance = double.infinity;
    for (final crystal in map.crystals) {
      if (!crystal.isAlive || crystal.ownerId == hero.ownerId) continue;
      final dx = crystal.x - hero.x;
      final dy = crystal.y - hero.y;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestDistance) {
        best = crystal;
        bestDistance = d2;
      }
    }
    return best;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _combatLoop.clear();
  }
}
