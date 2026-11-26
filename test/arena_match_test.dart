import 'package:flutter_test/flutter_test.dart';

import 'package:archer_fm/arena/arena_map.dart';
import 'package:archer_fm/arena/arena_match.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ArenaMap map;
  late ArenaMatch match;

  setUpAll(() async {
    map = await ArenaMap.load();
  });

  setUp(() {
    match = ArenaMatch(map: map);
  });

  test('match initializes four heroes at authored spawns', () {
    expect(match.heroes.length, 4);
    for (var i = 0; i < map.players.length; i++) {
      expect(match.heroes[i].ownerId, map.players[i].id);
      expect(match.heroes[i].x, map.players[i].spawnX);
      expect(match.heroes[i].y, map.players[i].spawnY);
    }
  });

  test('match initializes 28 crystals', () {
    expect(match.crystals.length, 28);
    expect(match.crystals.every((crystal) => crystal.isAlive), isTrue);
  });

  test('match initializes 17 camps with no monsters and timers', () {
    expect(match.camps.length, 17);
    for (final camp in match.camps) {
      expect(camp.aliveCount, 0);
      expect(camp.timer, greaterThan(0));
    }
  });

  test('monster navigation adapter follows the map orientation', () {
    final grid = match.navigationGrid;
    final player = map.players.first;
    expect(grid.worldToCell(player.spawnX, player.spawnY).x, inInclusiveRange(0, 95));
    expect(grid.worldToCell(player.spawnX, player.spawnY).y, inInclusiveRange(0, 95));
    final center = grid.cellCenter(grid.worldToCell(player.spawnX, player.spawnY));
    expect(center.$1, closeTo(player.spawnX, 0.5));
    expect(center.$2, closeTo(player.spawnY, 0.5));
    final spawnCell = grid.worldToCell(player.spawnX, player.spawnY);
    expect(grid.isWalkable(spawnCell), isTrue);
    expect(grid.isWalkable(MonsterGridCell(-1, 0)), isFalse);
    expect(grid.isWalkable(MonsterGridCell(96, 0)), isFalse);
  });

  test('monster pathfinder can route from P1 spawn to centre', () {
    final pathfinder = MonsterPathfinder();
    final player = map.players.first;
    final path = pathfinder.findPath(
      grid: match.navigationGrid,
      startX: player.spawnX,
      startY: player.spawnY,
      goalX: 0,
      goalY: 0,
    );
    expect(path, isNotNull);
    expect(path!.length, greaterThan(10));
    for (final cell in path) {
      expect(match.navigationGrid.isWalkable(cell), isTrue);
    }
  });

  test('goblin camps spawn after 30 seconds', () {
    final goblinCamps = match.camps
        .where((camp) => camp.camp.type == ArenaCampType.goblin)
        .length;
    expect(goblinCamps, 8);
    for (var i = 0; i < 30; i++) {
      match.update(const Duration(seconds: 1));
    }
    final spawned = match.camps
        .where((camp) => camp.camp.type == ArenaCampType.goblin)
        .fold<int>(0, (sum, camp) => sum + camp.aliveCount);
    expect(spawned, 24);
    expect(match.liveMonsters.length, 24);
    for (final unit in match.liveMonsters) {
      expect(unit.type, MonsterType.blindStalker);
    }
  });

  test('wolf camps spawn after 60 seconds', () {
    for (var i = 0; i < 60; i++) {
      match.update(const Duration(seconds: 1));
    }
    final wolves = match.camps
        .where((camp) => camp.camp.type == ArenaCampType.wolf)
        .fold<int>(0, (sum, camp) => sum + camp.aliveCount);
    expect(wolves, 8);
  });

  test('camp mapping preserves authored monster stats', () {
    final goblinCamp = match.camps.firstWhere(
        (camp) => camp.camp.type == ArenaCampType.goblin);
    for (var i = 0; i < 30; i++) match.update(const Duration(seconds: 1));
    for (final unit in goblinCamp.army.units) {
      expect(unit.stats.maxHealth, 150);
      expect(unit.stats.damage, 12);
      expect(unit.stats.purchaseCost, 10);
    }
  });

  test('camp respawn occurs after a camp is wiped', () {
    for (var i = 0; i < 30; i++) match.update(const Duration(seconds: 1));
    final state = match.camps.firstWhere(
        (camp) => camp.camp.type == ArenaCampType.goblin);
    for (final unit in state.army.units.toList()) {
      unit.applyDamage(unit.health);
    }
    match.update(const Duration(seconds: 1));
    expect(state.aliveCount, 0);
    for (var i = 0; i < 61; i++) {
      match.update(const Duration(seconds: 1));
    }
    expect(state.aliveCount, state.camp.count);
  });

  test('crystal destruction updates map and match', () {
    final crystal = match.crystals.first;
    crystal.applyDamage(crystal.maxHealth);
    match.update(const Duration(milliseconds: 100));
    expect(crystal.destroyed, isTrue);
    expect(match.aliveCrystalsCount(crystal.ownerId),
        lessThan(match.crystals.where((c) => c.ownerId == crystal.ownerId).length));
    for (final cell in map.footprintCells(crystal.footprint)) {
      expect(map.walkableCell(cell), isTrue);
    }
  });

  test('hero movement follows an A* route and stays walkable', () {
    final hero = match.localHero;
    final path = match.moveHeroTo(hero, 0, 0);
    expect(path, isNotEmpty);
    for (var i = 0; i < 20; i++) {
      match.update(const Duration(milliseconds: 100));
    }
    expect(map.walkableAt(hero.x, hero.y), isTrue);
    expect(hero.path.isNotEmpty || (hero.x - 0).abs() + (hero.y - 0).abs() < 2,
        isTrue);
  });

  test('hero attack damages the nearest monster or enemy crystal', () {
    for (var i = 0; i < 30; i++) match.update(const Duration(seconds: 1));
    final hero = match.localHero;
    final camp = match.camps.firstWhere(
        (c) => c.camp.type == ArenaCampType.goblin);
    final unit = camp.army.units.first;
    hero.x = unit.positionX;
    hero.y = unit.positionY + 1;
    final before = unit.health;
    final result = match.attackWithHero(hero);
    expect(result, isTrue);
    expect(unit.health, lessThan(before));
  });

  test('camp monsters damage a nearby hero', () {
    for (var i = 0; i < 30; i++) match.update(const Duration(seconds: 1));
    final hero = match.localHero;
    final camp = match.camps.firstWhere(
        (c) => c.camp.type == ArenaCampType.goblin);
    final unit = camp.army.units.first;
    hero.x = unit.positionX;
    hero.y = unit.positionY + 1;
    final before = hero.health;
    for (var i = 0; i < 20; i++) {
      match.update(const Duration(milliseconds: 100));
    }
    expect(hero.health, lessThan(before));
  });

  test('monster pathfinding cannot leave the map', () {
    final pathfinder = MonsterPathfinder();
    final path = pathfinder.findPath(
      grid: match.navigationGrid,
      startX: 0,
      startY: 0,
      goalX: 100,
      goalY: 0,
    );
    expect(path, isNull);
  });
}
