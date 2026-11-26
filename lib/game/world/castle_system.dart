import 'dart:math' as math;
import 'dart:ui';

import 'arena_map.dart';
import 'mine_system.dart';

/// Castles and their seven crystals.
///
/// Confirmed rules (`PROJECT_STATUS.md` §Castles and crystals):
/// one castle and seven crystals per player, fixed starting HP values, some
/// crystals exposed and some inside walls, every crystal attackable directly,
/// a castle falls and disappears when all seven die while the player stays in
/// the match, rebuilt crystals reuse their original HP value, each successive
/// rebuild costs more, rebuilding is immediate during combat, rebuilt crystals
/// can be destroyed again, and the maximum is seven crystals.
///
/// Not confirmed yet: whether "seven" counts simultaneous or total crystals,
/// the rebuild cost curve, the exact new-castle rule, and the meaning of a
/// player's territory. This implementation uses seven simultaneous crystals
/// (the stated maximum), a provisional linear cost curve, the documented
/// proposed "new castle returns with the first rebuilt crystal" rule, and a
/// provisional circular territory around the player's castle.

/// Exactly seven crystals, with the confirmed starting HP values in order.
const int castleCrystalCount = 7;
const List<int> crystalMaxHpValues = [
  500,
  700,
  900,
  1200,
  1500,
  1800,
  2200,
];

/// Provisional radius of a player's rebuilding territory around their castle.
const double castleTerritoryRadius = 320;

/// Crystal body radius for placement checks and hit tests.
const double crystalRadius = 20;

/// Layout radii for exposed (outside the wall ring) and sheltered crystals.
const double crystalOuterRingRadius = 176;
const double crystalInnerRingRadius = 104;
const double castleWallRadius = 146;

/// Provisional rebuild cost: base plus a rising step per rebuild.
const int crystalRebuildBaseCost = 120;
const int crystalRebuildCostStep = 60;

enum CrystalRebuildResult {
  ok,
  notEnoughResources,
  atMax,
  outsideTerritory,
  blocked,
}

/// One crystal of one castle.
class CrystalState {
  CrystalState({
    required this.id,
    required this.ownerId,
    required this.slot,
    required this.position,
    required this.exposed,
    required this.maxHp,
  }) : hp = maxHp;

  final String id;
  final String ownerId;

  /// 0..6; also selects the HP value from [crystalMaxHpValues].
  final int slot;
  final Offset position;

  /// True outside the wall ring ("exposed"), false inside it.
  final bool exposed;
  final double maxHp;
  double hp;

  bool get destroyed => hp <= 0;
  double get hpRatio => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);
}

/// One stone arc of a castle wall. Walls are drawn around the sheltered
/// crystals; the spec does not say they block movement, so they stay visual.
class CastleWall {
  const CastleWall({
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.sweep,
  });

  final Offset center;
  final double radius;
  final double startAngle;
  final double sweep;
}

/// One player's castle. Rivals keep the same shape until online players exist.
class CastleState {
  CastleState({
    required this.ownerId,
    required this.anchor,
    required this.isLocal,
  });

  final String ownerId;
  final Offset anchor;
  final bool isLocal;
  final List<CrystalState> crystals = [];
  final List<CastleWall> walls = [];

  /// A fallen castle disappears from the world until the first rebuild.
  bool fallen = false;

  /// Number of completed rebuilds; drives the rising cost.
  int rebuilds = 0;

  bool get standing => !fallen;

  Iterable<CrystalState> get alive =>
      crystals.where((crystal) => !crystal.destroyed);

  int get aliveCount => alive.length;
  int get destroyedCount => castleCrystalCount - aliveCount;

  CastleWall buildWall(double startAngle, double sweep) => CastleWall(
        center: anchor,
        radius: castleWallRadius,
        startAngle: startAngle,
        sweep: sweep,
      );
}

/// Castle layout, crystal damage and rebuilding.
class CastleController {
  CastleController({
    required this.map,
    this.localPlayerId = MineController.localPlayerId,
  }) {
    castles = [
      for (var i = 0; i < map.castleAnchors.length; i++)
        CastleState(
          ownerId: i == 0 ? localPlayerId : 'rival_$i',
          anchor: map.castleAnchors[i],
          isLocal: i == 0,
        ),
    ];
    for (final castle in castles) {
      castle.crystals.addAll(_buildCrystals(castle));
      castle.walls.addAll(_buildWalls(castle.anchor));
    }
  }

  final ArenaMap map;
  final String localPlayerId;
  late final List<CastleState> castles;

  CastleState get playerCastle => castles.first;

  /// Castles that are still standing (fallen ones are not represented).
  Iterable<CastleState> get standingCastles =>
      castles.where((castle) => castle.standing);

  /// Crystals of the three rival castles, i.e. the local player's targets.
  Iterable<CrystalState> get hostileCrystals sync* {
    for (final castle in castles) {
      if (castle.ownerId == localPlayerId || !castle.standing) continue;
      yield* castle.alive;
    }
  }

  /// All crystals that should stay on the minimap: every standing castle's
  /// living crystals, at any distance.
  Iterable<CrystalState> get mappedCrystals sync* {
    for (final castle in standingCastles) {
      yield* castle.alive;
    }
  }

  CastleState? castleOf(String ownerId) {
    for (final castle in castles) {
      if (castle.ownerId == ownerId) return castle;
    }
    return null;
  }

  CastleState? castleAt(int index) =>
      index >= 0 && index < castles.length ? castles[index] : null;

  /// Starts each castle with seven crystals: four exposed outside the wall
  /// ring and three sheltered inside it.
  List<CrystalState> _buildCrystals(CastleState castle) {
    final crystals = <CrystalState>[];
    for (var slot = 0; slot < castleCrystalCount; slot++) {
      final exposed = slot < 4;
      final baseAngle = exposed
          ? math.pi / 4 + slot * math.pi / 2
          : slot * (math.pi * 2 / 3);
      final baseRadius =
          exposed ? crystalOuterRingRadius : crystalInnerRingRadius;
      final position = _clearSpot(
        castle.anchor,
        baseAngle,
        baseRadius,
        exposed,
      );
      crystals.add(
        CrystalState(
          id: '${castle.ownerId}_crystal_$slot',
          ownerId: castle.ownerId,
          slot: slot,
          position: position,
          exposed: (position - castle.anchor).distance > castleWallRadius,
          maxHp: crystalMaxHpValues[slot].toDouble(),
        ),
      );
    }
    return crystals;
  }

  /// Looks for the closest clear spot to the requested ring position.
  Offset _clearSpot(
    Offset anchor,
    double angle,
    double radius,
    bool exposed,
  ) {
    for (var attempt = 0; attempt < 24; attempt++) {
      final ring = radius + (attempt.isEven ? 1 : -1) * (attempt * 4.0);
      final wobble = (attempt % 5 - 2) * 0.08;
      final candidate = anchor +
          Offset(
            math.cos(angle + wobble) * ring,
            math.sin(angle + wobble) * ring,
          );
      if (map.isWater(candidate)) continue;
      if (map.isBlocked(candidate, crystalRadius + 6)) continue;
      // Keep exposed crystals outside and sheltered crystals inside the ring.
      final distance = (candidate - anchor).distance;
      if (exposed && distance <= castleWallRadius) continue;
      if (!exposed && distance >= castleWallRadius) continue;
      return candidate;
    }
    // Guaranteed fallback: the castle anchor itself is always clear.
    final fallback = exposed
        ? anchor + const Offset(crystalOuterRingRadius, 0)
        : anchor + const Offset(0, crystalInnerRingRadius);
    return fallback;
  }

  List<CastleWall> _buildWalls(Offset anchor) {
    // Four stone arcs with a gate at each exposed crystal angle (45°, 135°,
    // 225°, 315°). Each gate is 24° wide.
    const gateHalf = 12 * math.pi / 180;
    const gateAngles = [
      math.pi / 4,
      math.pi * 3 / 4,
      math.pi * 5 / 4,
      math.pi * 7 / 4,
    ];
    final walls = <CastleWall>[];
    for (var i = 0; i < gateAngles.length; i++) {
      final start = gateAngles[i] + gateHalf;
      final end = (i == gateAngles.length - 1
              ? gateAngles[0] + math.pi * 2
              : gateAngles[i + 1]) -
          gateHalf;
      walls.add(
        CastleWall(
          center: anchor,
          radius: castleWallRadius,
          startAngle: start,
          sweep: end - start,
        ),
      );
    }
    return walls;
  }

  /// Damages [crystal]. Returns true when this hit destroys it.
  bool damageCrystal(CrystalState crystal, double amount) {
    if (amount <= 0 || crystal.destroyed) return false;
    final castle = castleOf(crystal.ownerId);
    if (castle == null || castle.fallen) return false;
    crystal.hp = math.max(0, crystal.hp - amount);
    if (crystal.destroyed) {
      if (castle.aliveCount == 0) castle.fallen = true;
      return true;
    }
    return false;
  }

  /// The next rebuild cost for [castle]; grows with every rebuild.
  int rebuildCost(CastleState castle) =>
      crystalRebuildBaseCost + crystalRebuildCostStep * castle.rebuilds;

  CrystalRebuildResult validateRebuild(
    CastleState castle,
    Offset position, {
    required int resources,
  }) {
    if (castle.aliveCount >= castleCrystalCount) {
      return CrystalRebuildResult.atMax;
    }
    if (resources < rebuildCost(castle)) {
      return CrystalRebuildResult.notEnoughResources;
    }
    if ((position - castle.anchor).distance > castleTerritoryRadius) {
      return CrystalRebuildResult.outsideTerritory;
    }
    if (map.isWater(position) ||
        map.isBlocked(position, crystalRadius + 4)) {
      return CrystalRebuildResult.blocked;
    }
    for (final mine in map.mines) {
      if ((mine.position - position).distance <
          mine.radius + crystalRadius + 16) {
        return CrystalRebuildResult.blocked;
      }
    }
    for (final other in castle.crystals) {
      if (other.destroyed) continue;
      if ((other.position - position).distance < crystalRadius * 2 + 12) {
        return CrystalRebuildResult.blocked;
      }
    }
    return CrystalRebuildResult.ok;
  }

  /// Rebuilds the lowest missing crystal in [castle] at [position]. The caller
  /// must validate first and pay [rebuildCost].
  CrystalState? rebuild(CastleState castle, Offset position) {
    var slot = -1;
    for (var i = 0; i < castleCrystalCount; i++) {
      final crystal = castle.crystals.firstWhere((c) => c.slot == i);
      if (crystal.destroyed) {
        slot = i;
        break;
      }
    }
    if (slot < 0) return null;
    final old = castle.crystals.firstWhere((c) => c.slot == slot);
    final rebuilt = CrystalState(
      id: '${castle.ownerId}_crystal_${slot}_r${castle.rebuilds + 1}',
      ownerId: castle.ownerId,
      slot: slot,
      position: position,
      exposed: (position - castle.anchor).distance > castleWallRadius,
      maxHp: old.maxHp,
    );
    castle.crystals.removeWhere((c) => c.slot == slot);
    castle.crystals.add(rebuilt);
    castle.fallen = false;
    castle.rebuilds++;
    return rebuilt;
  }
}
