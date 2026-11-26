import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';

import '../lib/game/world/arena_map.dart';
import '../lib/game/world/arena_projection.dart';
import '../lib/game/world/castle_system.dart';
import '../lib/game/world/fog_of_war.dart';
import '../lib/game/world/mine_system.dart';

void main() {
  test('generated arena has four valid player castle anchors and map features', () {
    final map = ArenaMap.generate(math.Random(73));
    expect(map.castleAnchors, hasLength(4));
    expect(map.mines, hasLength(mapMineCount));
    expect(map.biomes.map((patch) => patch.kind).toSet(), TerrainKind.values.toSet());
    expect(map.rivers, isNotEmpty);
    expect(map.rivers.every((river) => river.bridges.isNotEmpty), isTrue);
    for (final castle in map.castleAnchors) {
      expect(castle.dx, inInclusiveRange(0, map.size.width));
      expect(castle.dy, inInclusiveRange(0, map.size.height));
      expect(map.isWater(castle), isFalse);
    }
  });

  test('each of four castles starts with seven crystals: four exposed and three sheltered', () {
    final map = ArenaMap.generate(math.Random(29));
    final castles = CastleController(map: map);
    expect(castles.castles, hasLength(4));
    for (final castle in castles.castles) {
      expect(castle.crystals, hasLength(castleCrystalCount));
      expect(castle.crystals.where((crystal) => crystal.exposed), hasLength(4));
      expect(castle.crystals.where((crystal) => !crystal.exposed), hasLength(3));
      expect(castle.aliveCount, 7);
    }
  });

  test('mine capture is uninterrupted and contested players pause progress', () {
    final map = ArenaMap.generate(math.Random(11));
    final mines = MineController(map: map, random: math.Random(11));
    final mine = mines.mines.first;
    mines.update(deltaMs: 4000, nowMs: 4000, players: {'p1': mine.position});
    expect(mine.captureProgressMs, 4000);
    mines.update(deltaMs: 3000, nowMs: 7000, players: {'p1': mine.position, 'p2': mine.position});
    expect(mine.captureProgressMs, 4000);
    mines.update(deltaMs: 6000, nowMs: 13000, players: {'p1': mine.position});
    expect(mine.ownerId, 'p1');
  });

  test('fog reveals explored cells and leaves distant cells hidden', () {
    final fog = FogOfWar(worldWidth: 1024, worldHeight: 1024);
    fog.reveal(const Offset(256, 256), 180);
    expect(fog.isRevealed(const Offset(256, 256)), isTrue);
    expect(fog.isRevealed(const Offset(900, 900)), isFalse);
    expect(fog.hiddenCellsIn(const Rect.fromLTWH(0, 0, 1024, 1024)), isNotEmpty);
  });

  test('oblique map projection round-trips world positions', () {
    const projection = ArenaWorldProjection(
      yawRadians: 0.24,
      groundScaleY: 0.766,
      scale: 1.3,
    );
    for (final point in const [Offset.zero, Offset(960, 540), Offset(1900, 1300)]) {
      final restored = projection.unprojectGround(projection.projectGround(point));
      expect(restored.dx, closeTo(point.dx, 1e-8));
      expect(restored.dy, closeTo(point.dy, 1e-8));
    }
  });
}
