import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/network/match_world_authority.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/world/castle_system.dart';

void main() {
  late ArenaMap map;
  late MatchWorldAuthority world;

  setUp(() {
    map = ArenaMap.generate(Random(42));
    world = MatchWorldAuthority(
      map: map,
      playerIds: const ['p1', 'p2', 'p3', 'p4'],
      random: Random(7),
    );
  });

  test('maps all four match player IDs to their own seven-crystal castles', () {
    expect(world.castles.castles.map((castle) => castle.ownerId),
        ['p1', 'p2', 'p3', 'p4']);
    for (final id in world.playerIds) {
      expect(world.livingCrystals(id), 7);
      expect(world.castles.castleOf(id)!.crystals, hasLength(7));
    }
  });

  test('rejects friendly crystal damage and updates enemy crystal counts', () {
    final ownCrystal = world.castles.castleOf('p1')!.crystals.first;
    expect(
      world.damageCrystal(
        attackerId: 'p1',
        crystalId: ownCrystal.id,
        amount: 100,
      ).error,
      'friendly_target',
    );

    final enemyCrystal = world.castles.castleOf('p2')!.crystals.first;
    final result = world.damageCrystal(
      attackerId: 'p1',
      crystalId: enemyCrystal.id,
      amount: enemyCrystal.maxHp + 1,
    );
    expect(result.accepted, isTrue);
    expect(result.destroyedNow, isTrue);
    expect(result.livingCrystals, 6);
    expect(world.livingCrystals('p2'), 6);
  });

  test('captures a mine after ten uninterrupted seconds and produces pickups', () {
    final mine = world.mines.mines.first;
    final positions = {
      'p1': mine.position,
      'p2': map.castleAnchors[1],
      'p3': map.castleAnchors[2],
      'p4': map.castleAnchors[3],
    };
    world.tick(
      deltaMs: 10000,
      nowMs: 10000,
      authoritativePositions: positions,
    );
    expect(mine.ownerId, 'p1');

    world.tick(
      deltaMs: mine.size.productionIntervalMs,
      nowMs: 10000 + mine.size.productionIntervalMs,
    );
    expect(world.mines.pickups, isNotEmpty);
  });

  test('rebuild requires the canonical wallet and respects castle cap', () {
    final castle = world.castles.castleOf('p1')!;
    final destroyed = castle.crystals.first;
    world.damageCrystal(
      attackerId: 'p2',
      crystalId: destroyed.id,
      amount: destroyed.maxHp + 1,
    );
    final result = world.rebuildCrystal(
      ownerId: 'p1',
      position: castle.anchor + const Offset(0, 240),
    );
    expect(result, CrystalRebuildResult.notEnoughResources);
    expect(world.livingCrystals('p1'), 6);
    expect(world.resources['p1'], 0);
  });

  test('rejects unknown player identities', () {
    expect(
      () => world.movePlayer('not-a-player', const Offset(1, 0), 18),
      throwsArgumentError,
    );
  });
}
