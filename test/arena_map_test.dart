import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archer_fm/arena/arena_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ArenaMap map;

  setUpAll(() async {
    final jsonText = await rootBundle.loadString('assets/maps/arena/archer_fm_map.json');
    final gridText = await rootBundle.loadString('assets/maps/arena/nav_grid.txt');
    final heightText = await rootBundle.loadString('assets/maps/arena/height_map.csv');
    map = ArenaMap.parse(
      jsonText: jsonText,
      navGridText: gridText,
      heightMapCsv: heightText,
    );
  });

  test('dimensions and core data counts are preserved', () {
    expect(map.grid.length, 96);
    expect(map.grid.every((row) => row.length == 96), isTrue);
    expect(map.heights.length, 96);
    expect(map.heights.every((row) => row.length == 96), isTrue);
    expect(map.players.length, 4);
    expect(map.crystals.length, 28);
    expect(map.towers.length, 8);
    expect(map.walls.length, 24);
    expect(map.rocks.length, 16);
    expect(map.camps.length, 17);
    expect(map.controlPoints.length, 5);
    expect(map.bridges.length, 8);
  });

  test('each player has seven crystals and two towers', () {
    for (final player in map.players) {
      expect(map.crystals.where((c) => c.ownerId == player.id).length, 7);
      expect(map.towers.where((t) => t.ownerId == player.id).length, 2);
    }
  });

  test('spawns and towers are on walkable cells', () {
    for (final player in map.players) {
      expect(map.walkableAt(player.spawnX, player.spawnY), isTrue,
          reason: '${player.id} spawn is blocked');
    }
  });

  test('water and authored obstacles are not walkable', () {
    final waterRow = map.grid.indexWhere((row) => row.contains('~'));
    final waterCol = map.grid[waterRow].indexOf('~');
    final waterCell = ArenaCell(waterCol, waterRow);
    expect(map.walkableCell(waterCell), isFalse);
    for (final wall in map.walls) {
      final cell = map.worldToCell(wall.rect.centerX, wall.rect.centerY);
      expect(map.walkableCell(cell), isFalse,
          reason: 'wall ${wall.id} is walkable');
    }
    for (final rock in map.rocks) {
      final cell = map.worldToCell(rock.rect.centerX, rock.rect.centerY);
      expect(map.walkableCell(cell), isFalse,
          reason: 'rock ${rock.id} is walkable');
    }
    for (final tower in map.towers) {
      final cell = map.worldToCell(tower.rect.centerX, tower.rect.centerY);
      expect(map.walkableCell(cell), isFalse,
          reason: 'tower ${tower.id} is walkable');
    }
  });

  test('intact crystals are not walkable', () {
    for (final crystal in map.crystals) {
      final cell = map.worldToCell(crystal.x, crystal.y);
      expect(map.walkableCell(cell), isFalse,
          reason: 'crystal ${crystal.id} is walkable');
    }
  });

  test('out-of-bounds cells are blocked', () {
    expect(map.walkableCell(const ArenaCell(-1, 0)), isFalse);
    expect(map.walkableCell(const ArenaCell(96, 0)), isFalse);
    expect(map.walkableAt(100, 0), isFalse);
  });

  test('A* route from P1 spawn to map centre exists and is valid', () {
    final player = map.players.first;
    final start = map.worldToCell(player.spawnX, player.spawnY);
    final goal = map.nearestWalkable(map.worldToCell(0, 0));
    final path = map.findPath(start, goal);
    expect(path, isNotEmpty);
    expect(path.first, start);
    expect(path.last, goal);
    for (final cell in path) {
      expect(map.walkableCell(cell), isTrue);
    }
    for (var i = 1; i < path.length; i++) {
      final dc = (path[i].col - path[i - 1].col).abs();
      final dr = (path[i].row - path[i - 1].row).abs();
      expect(dc <= 1 && dr <= 1, isTrue, reason: 'non-adjacent path step');
      if (dc == 1 && dr == 1) {
        expect(
          map.walkableCell(ArenaCell(path[i - 1].col + dc, path[i - 1].row)) &&
              map.walkableCell(ArenaCell(path[i - 1].col, path[i - 1].row + dr)),
          isTrue,
          reason: 'diagonal corner cut',
        );
      }
    }
  });

  test('line of sight is blocked by walls and clear on roads', () {
    final tower = map.towers.first;
    expect(
      map.lineOfSight(
        tower.rect.centerX,
        tower.rect.centerY,
        0,
        -46,
      ),
      isFalse,
    );
    final player = map.players.first;
    expect(map.lineOfSight(player.spawnX, player.spawnY, 0, -20), isTrue);
  });

  test('destroying a crystal opens its footprint and changes revision', () {
    final crystal = map.crystals.first;
    final revisionBefore = map.revision;
    final opened = map.destroyCrystal(crystal.id);
    expect(opened, isTrue);
    expect(map.revision, greaterThan(revisionBefore));
    expect(crystal.destroyed, isTrue);
    for (final cell in map.footprintCells(crystal.footprint)) {
      expect(map.walkableCell(cell), isTrue,
          reason: 'crystal footprint still blocked');
    }
  });

  test('height map values are finite and within authored range', () {
    for (final row in map.heights) {
      for (final value in row) {
        expect(value.isFinite, isTrue);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThanOrEqualTo(2));
      }
    }
  });

  test('camp centres and control points are inside the map', () {
    for (final camp in map.camps) {
      expect(camp.x.abs(), lessThanOrEqualTo(48));
      expect(camp.y.abs(), lessThanOrEqualTo(48));
    }
    for (final point in map.controlPoints) {
      expect(point.x.abs(), lessThanOrEqualTo(48));
      expect(point.y.abs(), lessThanOrEqualTo(48));
    }
  });
}
