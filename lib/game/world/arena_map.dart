import 'dart:math' as math;
import 'dart:ui';

/// Match-world generation: one large map whose size and the placement of
/// castles, mines, biomes, rivers, bridges, trees, rocks, resources and chests
/// are randomized every match.
///
/// The numbers below are **provisional balancing values** (see
/// `PROJECT_STATUS.md` §5): they describe a playable first pass, not approved
/// final design.

/// World-size bounds in logical units. The camera shows a 960×540 window, so
/// even the smallest map is roughly 4× the visible area.
const double arenaMapMinWidth = 1920;
const double arenaMapMaxWidth = 2400;
const double arenaMapMinHeight = 1080;
const double arenaMapMaxHeight = 1440;

/// Confirmed counts from the gameplay requirements.
const int mapCastleCount = 4;
const int mapMineCount = 8;
const int mapBiomeKinds = 4;

/// Provisional world-decoration counts.
const int mapTreeCount = 52;
const int mapRockCount = 20;
const int mapResourcePickupCount = 6;
const int mapChestPickupCount = 2;

/// Provisional movement value for shallow water (rivers). Water slows whoever
/// walks in it; bridges are dry crossings.
const double waterSpeedFactor = 0.6;

/// Provisional camera-independent reveal values used by the fog of war and by
/// the "enemy monsters are shown only when nearby" rule.
const double fogCellSize = 64;
const double fogRevealRadius = 260;
const double enemyVisibleRadius = 420;

const double _castleEdgeMargin = 220;
const double _castleMinSpacing = 560;

/// Biomes listed in the requirements: forests, deserts, snow and volcanic.
enum TerrainKind { forest, desert, snow, volcanic }

class BiomePatch {
  const BiomePatch({
    required this.kind,
    required this.center,
    required this.radius,
  });

  final TerrainKind kind;
  final Offset center;
  final double radius;

  bool contains(Offset point) =>
      (point - center).distanceSquared <= radius * radius;
}

/// Indestructible world obstacles: trees and rocks.
enum ObstacleKind { tree, rock }

class MapObstacle {
  const MapObstacle({
    required this.position,
    required this.radius,
    required this.kind,
  });

  final Offset position;
  final double radius;
  final ObstacleKind kind;
}

/// Mine sites are generated with the map; the mine economy (capture,
/// production, collection) is built in the mines step.
enum MineSize { small, medium, large }

extension MineSizeRadius on MineSize {
  double get radius => switch (this) {
        MineSize.small => 72,
        MineSize.medium => 100,
        MineSize.large => 132,
      };
}

class MineSite {
  const MineSite({required this.position, required this.size});

  final Offset position;
  final MineSize size;

  double get radius => size.radius;
}

/// Extra resources and chests that can appear on the map.
enum PickupKind { resource, chest }

class MapPickup {
  const MapPickup({required this.position, required this.kind});

  final Offset position;
  final PickupKind kind;
}

/// A dry crossing over a river.
class Bridge {
  const Bridge({
    required this.center,
    required this.width,
    required this.depth,
  });

  final Offset center;

  /// Size along X.
  final double width;

  /// Size along Y (river width plus banks).
  final double depth;

  Rect get rect =>
      Rect.fromCenter(center: center, width: width, height: depth);

  bool contains(Offset point) {
    final rect = this.rect;
    return point.dx >= rect.left &&
        point.dx <= rect.right &&
        point.dy >= rect.top &&
        point.dy <= rect.bottom;
  }
}

/// A river is a polyline of water with bridges across it.
class River {
  River({
    required this.points,
    required this.width,
    required this.bridges,
  });

  final List<Offset> points;
  final double width;
  final List<Bridge> bridges;

  double get halfWidth => width / 2;

  bool bridgeAt(Offset point) => bridges.any((bridge) => bridge.contains(point));

  bool contains(Offset point) => _distanceTo(point) <= halfWidth;

  double _distanceTo(Offset point) {
    var best = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final distance = _segmentDistance(point, points[i], points[i + 1]);
      if (distance < best) best = distance;
    }
    return best;
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.distanceSquared;
    if (lengthSquared <= 0.0001) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) /
            lengthSquared)
        .clamp(0.0, 1.0);
    final closest = a + ab * t;
    return (p - closest).distance;
  }
}

/// The generated battle world.
class ArenaMap {
  ArenaMap._({
    required this.size,
    required this.biomes,
    required this.rivers,
    required this.obstacles,
    required this.mines,
    required this.pickups,
    required this.castleAnchors,
  });

  final Size size;
  final List<BiomePatch> biomes;
  final List<River> rivers;
  final List<MapObstacle> obstacles;
  final List<MineSite> mines;
  final List<MapPickup> pickups;

  /// Four random castle positions sharing the same design (castles are built
  /// in a later step; the map reserves their anchors).
  final List<Offset> castleAnchors;

  /// The local player starts just outside the south wall of their own castle.
  /// Keep the spawn beyond the wall radius plus the hero collision radius so
  /// the opening camera frame never stacks the hero inside crystals/walls.
  Offset get playerSpawn => castleAnchors.first + const Offset(0, 220);

  Offset get center => Offset(size.width / 2, size.height / 2);

  double get halfWidth => size.width / 2;
  double get halfHeight => size.height / 2;

  /// True for river water that is not covered by a bridge.
  bool isWater(Offset point) {
    for (final river in rivers) {
      if (river.contains(point) && !river.bridgeAt(point)) return true;
    }
    return false;
  }

  bool isBridge(Offset point) => rivers.any((r) => r.bridgeAt(point));

  /// 1.0 on dry land/bridges, [waterSpeedFactor] in shallow water.
  double movementFactorAt(Offset point) =>
      isWater(point) ? waterSpeedFactor : 1.0;

  BiomePatch? biomeAt(Offset point) {
    for (final patch in biomes) {
      if (patch.contains(point)) return patch;
    }
    return null;
  }

  MapObstacle? obstacleBlocking(Offset point, double radius) {
    for (final obstacle in obstacles) {
      if ((obstacle.position - point).distance < obstacle.radius + radius) {
        return obstacle;
      }
    }
    return null;
  }

  bool isBlocked(Offset point, double radius) {
    if (point.dx < radius ||
        point.dy < radius ||
        point.dx > size.width - radius ||
        point.dy > size.height - radius) {
      return true;
    }
    return obstacleBlocking(point, radius) != null;
  }

  Offset clampToBounds(Offset point, double radius) => Offset(
        point.dx.clamp(radius, size.width - radius).toDouble(),
        point.dy.clamp(radius, size.height - radius).toDouble(),
      );

  /// Steps [from] by [step], sliding along obstacles/walls instead of sticking.
  Offset slideMove(Offset from, Offset step, double radius) {
    final target = clampToBounds(from + step, radius);
    if (!isBlocked(target, radius)) return target;
    final xOnly = clampToBounds(Offset(from.dx + step.dx, from.dy), radius);
    if (!isBlocked(xOnly, radius)) return xOnly;
    final yOnly = clampToBounds(Offset(from.dx, from.dy + step.dy), radius);
    if (!isBlocked(yOnly, radius)) return yOnly;
    return from;
  }

  /// Deterministic generation from [rng].
  static ArenaMap generate(math.Random rng) {
    final size = Size(
      _lerp(arenaMapMinWidth, arenaMapMaxWidth, rng.nextDouble()),
      _lerp(arenaMapMinHeight, arenaMapMaxHeight, rng.nextDouble()),
    );

    final castles = _generateCastles(rng, size);
    final rivers = _generateRivers(rng, size, castles);
    final mines = _generateMines(rng, size, castles, rivers);
    final biomes = _generateBiomes(rng, size);
    final pickups = _generatePickups(rng, size, castles, mines, rivers);
    final obstacles =
        _generateObstacles(rng, size, castles, mines, rivers, pickups);

    return ArenaMap._(
      size: size,
      biomes: biomes,
      rivers: rivers,
      obstacles: obstacles,
      mines: mines,
      pickups: pickups,
      castleAnchors: castles,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static const List<Offset> _castleQuadrants = [
    Offset(0.24, 0.28),
    Offset(0.76, 0.28),
    Offset(0.24, 0.74),
    Offset(0.76, 0.74),
  ];

  static List<Offset> _generateCastles(math.Random rng, Size size) {
    final anchors = <Offset>[];
    for (final quadrant in _castleQuadrants) {
      var placed = false;
      for (var attempt = 0; attempt < 80 && !placed; attempt++) {
        final jitter = Offset(
          (rng.nextDouble() - 0.5) * size.width * 0.14,
          (rng.nextDouble() - 0.5) * size.height * 0.14,
        );
        final candidate = Offset(
          quadrant.dx * size.width + jitter.dx,
          quadrant.dy * size.height + jitter.dy,
        );
        if (candidate.dx < _castleEdgeMargin ||
            candidate.dy < _castleEdgeMargin ||
            candidate.dx > size.width - _castleEdgeMargin ||
            candidate.dy > size.height - _castleEdgeMargin) {
          continue;
        }
        final clear = anchors.every(
          (other) => (other - candidate).distance >= _castleMinSpacing,
        );
        if (!clear) continue;
        anchors.add(candidate);
        placed = true;
      }
      if (!placed) {
        // Guaranteed fallback keeps the count at four.
        anchors.add(
          Offset(quadrant.dx * size.width, quadrant.dy * size.height),
        );
      }
    }
    return anchors;
  }

  static List<River> _generateRivers(
    math.Random rng,
    Size size,
    List<Offset> castles,
  ) {
    final width = 80.0 + rng.nextDouble() * 34;
    const fractions = [-0.06, 0.22, 0.48, 0.74, 1.06];

    River buildRiver() {
      final baseX = size.width * (0.32 + rng.nextDouble() * 0.36);
      final points = <Offset>[];
      for (final fraction in fractions) {
        final meander = (rng.nextDouble() - 0.5) * size.width * 0.14;
        points.add(Offset(baseX + meander, size.height * fraction));
      }
      final bridges = <Bridge>[
        for (final fraction in const [0.34, 0.68])
          Bridge(
            center: _pointAlong(points, fraction),
            width: 120,
            depth: width + 56,
          ),
      ];
      return River(points: points, width: width, bridges: bridges);
    }

    // Re-draw the course until it stays clear of every castle clearing.
    for (var attempt = 0; attempt < 40; attempt++) {
      final river = buildRiver();
      final clear = castles.every(
        (castle) => river._distanceTo(castle) > river.halfWidth + 130,
      );
      if (clear) return [river];
    }
    // Guaranteed fallback: a straight river along the far edge.
    final fallbackX = size.width * 0.9;
    final points = [
      for (final fraction in fractions) Offset(fallbackX, size.height * fraction),
    ];
    return [
      River(
        points: points,
        width: width,
        bridges: [
          Bridge(
            center: _pointAlong(points, 0.34),
            width: 120,
            depth: width + 56,
          ),
          Bridge(
            center: _pointAlong(points, 0.68),
            width: 120,
            depth: width + 56,
          ),
        ],
      ),
    ];
  }

  static Offset _pointAlong(List<Offset> points, double t) {
    final lengths = <double>[];
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final length = (points[i + 1] - points[i]).distance;
      lengths.add(length);
      total += length;
    }
    var target = total * t.clamp(0.0, 1.0);
    for (var i = 0; i < lengths.length; i++) {
      if (target <= lengths[i] || i == lengths.length - 1) {
        final a = points[i];
        final b = points[i + 1];
        final local = lengths[i] <= 0 ? 0.0 : target / lengths[i];
        return Offset(
          a.dx + (b.dx - a.dx) * local.clamp(0.0, 1.0),
          a.dy + (b.dy - a.dy) * local.clamp(0.0, 1.0),
        );
      }
      target -= lengths[i];
    }
    return points.last;
  }

  static bool _inWater(List<River> rivers, Offset point) {
    for (final river in rivers) {
      if (river.contains(point)) return true;
    }
    return false;
  }

  static List<MineSite> _generateMines(
    math.Random rng,
    Size size,
    List<Offset> castles,
    List<River> rivers,
  ) {
    final sizes = <MineSize>[
      MineSize.small,
      MineSize.small,
      MineSize.small,
      MineSize.medium,
      MineSize.medium,
      MineSize.medium,
      MineSize.large,
      MineSize.large,
    ]..shuffle(rng);

    final sites = <MineSite>[];
    for (final mineSize in sizes) {
      final inset = 80 + mineSize.radius;
      for (var attempt = 0; attempt < 160; attempt++) {
        final point = Offset(
          inset + rng.nextDouble() * (size.width - inset * 2),
          inset + rng.nextDouble() * (size.height - inset * 2),
        );
        final clearOfCastles = castles.every(
          (castle) => (castle - point).distance >= 240,
        );
        final clearOfMines = sites.every(
          (site) => (site.position - point).distance >= site.radius + mineSize.radius + 90,
        );
        final clearOfWater =
            rivers.every((river) => !river.contains(point));
        if (!clearOfCastles || !clearOfMines || !clearOfWater) continue;
        sites.add(MineSite(position: point, size: mineSize));
        break;
      }
    }
    return sites;
  }

  static List<BiomePatch> _generateBiomes(math.Random rng, Size size) {
    final patches = <BiomePatch>[];
    for (final kind in TerrainKind.values) {
      final radius = 220.0 + rng.nextDouble() * 170;
      final point = Offset(
        radius * 0.6 + rng.nextDouble() * (size.width - radius * 1.2),
        radius * 0.6 + rng.nextDouble() * (size.height - radius * 1.2),
      );
      patches.add(BiomePatch(kind: kind, center: point, radius: radius));
    }
    return patches;
  }

  static List<MapPickup> _generatePickups(
    math.Random rng,
    Size size,
    List<Offset> castles,
    List<MineSite> mines,
    List<River> rivers,
  ) {
    final pickups = <MapPickup>[];
    void tryPlace(PickupKind kind) {
      for (var attempt = 0; attempt < 160; attempt++) {
        final point = Offset(
          90 + rng.nextDouble() * (size.width - 180),
          90 + rng.nextDouble() * (size.height - 180),
        );
        if (_inWater(rivers, point)) continue;
        if (castles.any((castle) => (castle - point).distance < 200)) continue;
        if (mines.any((mine) => (mine.position - point).distance < mine.radius + 60)) {
          continue;
        }
        if (pickups.any((other) => (other.position - point).distance < 120)) {
          continue;
        }
        pickups.add(MapPickup(position: point, kind: kind));
        return;
      }
    }

    for (var i = 0; i < mapResourcePickupCount; i++) {
      tryPlace(PickupKind.resource);
    }
    for (var i = 0; i < mapChestPickupCount; i++) {
      tryPlace(PickupKind.chest);
    }
    return pickups;
  }

  static List<MapObstacle> _generateObstacles(
    math.Random rng,
    Size size,
    List<Offset> castles,
    List<MineSite> mines,
    List<River> rivers,
    List<MapPickup> pickups,
  ) {
    final obstacles = <MapObstacle>[];
    final spawn = castles.first + const Offset(0, 220);

    void tryPlace(ObstacleKind kind) {
      for (var attempt = 0; attempt < 240; attempt++) {
        final radius = kind == ObstacleKind.tree
            ? 13 + rng.nextDouble() * 7
            : 11 + rng.nextDouble() * 8;
        final point = Offset(
          60 + rng.nextDouble() * (size.width - 120),
          60 + rng.nextDouble() * (size.height - 120),
        );
        if (_inWater(rivers, point)) continue;
        if ((point - spawn).distance < 220) continue;
        if (castles.any((castle) => (castle - point).distance < 250)) continue;
        if (mines.any((mine) => (mine.position - point).distance < mine.radius + 50)) {
          continue;
        }
        if (pickups.any((pickup) => (pickup.position - point).distance < 70)) {
          continue;
        }
        if (obstacles.any(
          (other) => (other.position - point).distance <
              other.radius + radius + 18,
        )) {
          continue;
        }
        obstacles.add(
          MapObstacle(position: point, radius: radius, kind: kind),
        );
        return;
      }
    }

    for (var i = 0; i < mapTreeCount; i++) {
      tryPlace(ObstacleKind.tree);
    }
    for (var i = 0; i < mapRockCount; i++) {
      tryPlace(ObstacleKind.rock);
    }
    return obstacles;
  }
}
