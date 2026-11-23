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
    this.angle = 0,
  });

  final Offset center;

  /// Deck width across the river (local X axis).
  final double width;

  /// Deck length along the river (local Y axis).
  final double depth;

  /// Rotation of the deck's local X axis in world radians.
  final double angle;

  /// Axis-aligned bounds, retained for shadows and broad-phase layout only.
  Rect get rect {
    final c = math.cos(angle).abs();
    final s = math.sin(angle).abs();
    final boundsWidth = width * c + depth * s;
    final boundsHeight = width * s + depth * c;
    return Rect.fromCenter(
      center: center,
      width: boundsWidth,
      height: boundsHeight,
    );
  }

  /// Exact oriented deck containment; never use [rect] as the walkable area.
  bool contains(Offset point) {
    final delta = point - center;
    final c = math.cos(angle);
    final s = math.sin(angle);
    final localX = delta.dx * c + delta.dy * s;
    final localY = -delta.dx * s + delta.dy * c;
    return localX.abs() <= width / 2 && localY.abs() <= depth / 2;
  }

  /// Dry approach corridor for a complete river crossing. The movement test
  /// traverses 20 world units beyond each deck edge; keep that bank-to-bank
  /// approach dry as well as the deck itself. This changes water classification
  /// only and does not enlarge the rendered or collision deck.
  bool coversCrossing(Offset point) {
    final delta = point - center;
    final c = math.cos(angle);
    final s = math.sin(angle);
    final localX = delta.dx * c + delta.dy * s;
    final localY = -delta.dx * s + delta.dy * c;
    return localX.abs() <= width / 2 + 22 && localY.abs() <= depth / 2;
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
    // The deck and its immediate bank-to-bank approach are one dry crossing.
    // At a river/tributary junction the owning bridge must also mask water
    // contributed by the intersecting channel, otherwise a unit slows midway
    // across a bridge even though it is following the bridge axis.
    if (rivers.any(
      (river) => river.bridges.any(
        (bridge) => bridge.coversCrossing(point),
      ),
    )) {
      return false;
    }
    return rivers.any((river) => river.contains(point));
  }

  bool isBridge(Offset point) => rivers.any((r) => r.bridgeAt(point));

  /// 1.0 on dry land/bridges, [waterSpeedFactor] in shallow water.
  double movementFactorAt(Offset point) =>
      isWater(point) ? waterSpeedFactor : 1.0;

  /// Average movement factor over a proposed movement segment.
  ///
  /// Sampling the whole segment prevents a large frame delta from skipping a
  /// narrow river because the hero/enemy happened to start on dry land. Bridge
  /// samples remain dry through [movementFactorAt].
  double movementFactorAlong(Offset from, Offset displacement) {
    final distance = displacement.distance;
    if (distance <= 0.0001) return 1.0;
    // Keep spatial sampling finer than narrow river edges so a fast movement
    // step cannot jump across a short water strip between two dry samples.
    const sampleSpacing = 8.0;
    final samples = math.max(1, (distance / sampleSpacing).ceil());
    var total = 0.0;
    for (var i = 0; i <= samples; i++) {
      final point = from + displacement * (i / samples);
      total += movementFactorAt(point);
    }
    return total / (samples + 1);
  }

  /// Returns the nearest biome among patches covering [point].
  ///
  /// Biome circles intentionally overlap to avoid bare seams between the
  /// four regions. Choosing the first matching patch made those overlap
  /// zones depend on list order, so one biome could visually dominate a
  /// neighbouring castle's territory. Nearest-centre ownership keeps the
  /// ground-detail palette spatially coherent while preserving soft painter
  /// gradients at the boundaries.
  BiomePatch? biomeAt(Offset point) {
    BiomePatch? nearest;
    var nearestDistanceSquared = double.infinity;
    for (final patch in biomes) {
      if (!patch.contains(point)) continue;
      final distanceSquared = (patch.center - point).distanceSquared;
      if (distanceSquared < nearestDistanceSquared) {
        nearest = patch;
        nearestDistanceSquared = distanceSquared;
      }
    }
    return nearest;
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

  /// Checks the complete movement segment, not only its endpoint. This
  /// prevents fast movement frames from tunnelling through thin obstacles.
  bool _pathBlocked(Offset from, Offset to, double radius) {
    final distance = (to - from).distance;
    final sampleStep = math.max(2.0, radius * 0.5);
    final samples = (distance / sampleStep).ceil();
    for (var i = 1; i <= samples; i++) {
      final point = Offset.lerp(from, to, i / samples)!;
      if (isBlocked(point, radius)) return true;
    }
    return false;
  }

  /// Steps [from] by [step], sliding along obstacles/walls instead of sticking.
  /// Every candidate axis is swept so a large frame delta cannot pass through
  /// a tree, rock, or map boundary unnoticed.
  Offset slideMove(Offset from, Offset step, double radius) {
    // Recover safely if a caller starts just outside the legal radius. Swept
    // collision must begin from a valid point or it can reject every candidate
    // and leave the actor stranded beyond the map edge.
    final safeFrom = clampToBounds(from, radius);
    final target = clampToBounds(safeFrom + step, radius);
    if (!_pathBlocked(safeFrom, target, radius)) return target;
    final xOnly = clampToBounds(
      Offset(safeFrom.dx + step.dx, safeFrom.dy),
      radius,
    );
    if (!_pathBlocked(safeFrom, xOnly, radius)) return xOnly;
    final yOnly = clampToBounds(
      Offset(safeFrom.dx, safeFrom.dy + step.dy),
      radius,
    );
    if (!_pathBlocked(safeFrom, yOnly, radius)) return yOnly;
    return safeFrom;
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
    // Place solid scenery first so pickups can reserve genuinely walkable,
    // unobstructed ground rather than landing under trees or rocks.
    final placementObstacles =
        _generateObstacles(rng, size, castles, mines, rivers, const []);
    final pickups = _generatePickups(
      rng, size, castles, mines, rivers, placementObstacles,
    );
    // Rebuild the final scenery against the chosen pickups as well. This
    // preserves pickup clearance without allowing the final obstacle pass
    // to place a tree or rock over a resource/chest.
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
            angle: _bridgeAngleAt(points, fraction),
            width: 120,
            depth: width + 56,
          ),
      ];
      return River(points: points, width: width, bridges: bridges);
    }

    // Re-draw the main course until it stays clear of every castle clearing.
    River? mainRiver;
    for (var attempt = 0; attempt < 40; attempt++) {
      final candidate = buildRiver();
      final clear = castles.every(
        (castle) => candidate._distanceTo(castle) > candidate.halfWidth + 130,
      );
      if (clear) {
        mainRiver = candidate;
        break;
      }
    }
    // Guaranteed fallback: a straight river along the far edge.
    mainRiver ??= (() {
      final fallbackX = size.width * 0.9;
      final points = [
        for (final fraction in fractions)
          Offset(fallbackX, size.height * fraction),
      ];
      return River(
        points: points,
        width: width,
        bridges: [
          Bridge(
            center: _pointAlong(points, 0.34),
            angle: _bridgeAngleAt(points, 0.34),
            width: 120,
            depth: width + 56,
          ),
          Bridge(
            center: _pointAlong(points, 0.68),
            angle: _bridgeAngleAt(points, 0.68),
            width: 120,
            depth: width + 56,
          ),
        ],
      );
    })();

    // Add a side stream that joins the main river near its middle. It is
    // deliberately narrower than the main channel and gets its own bridge.
    // Candidate paths are rejected if they cut through a castle clearing.
    River? tributary;
    final join = _pointAlong(mainRiver.points, 0.52);
    for (var attempt = 0; attempt < 48; attempt++) {
      final y = size.height * (0.42 + rng.nextDouble() * 0.16);
      final bend = (rng.nextDouble() - 0.5) * size.height * 0.10;
      final points = <Offset>[
        Offset(size.width * 0.015, y - bend * 0.25),
        Offset(size.width * 0.24, y + bend * 0.25),
        Offset(size.width * 0.43, y - bend * 0.35),
        Offset(join.dx, join.dy),
      ];
      const tributaryWidth = 58.0;
      final candidate = River(
        points: points,
        width: tributaryWidth,
        bridges: [
          Bridge(
            center: _pointAlong(points, 0.63),
            angle: _bridgeAngleAt(points, 0.63),
            width: 104,
            depth: tributaryWidth + 48,
          ),
        ],
      );
      final clearOfCastles = castles.every(
        (castle) => candidate._distanceTo(castle) >
            candidate.halfWidth + 112,
      );
      if (clearOfCastles) {
        tributary = candidate;
        break;
      }
    }

    tributary ??= (() {
      // Deterministic safety route through the open lane between the two
      // left-side castle clearings. This keeps a side channel present even
      // when randomized candidate curves are rejected.
      final safeY = (castles[0].dy + castles[2].dy) / 2;
      final points = <Offset>[
        Offset(size.width * 0.015, safeY),
        Offset(size.width * 0.22, safeY - 18),
        Offset(size.width * 0.40, safeY + 14),
        Offset(join.dx, join.dy),
      ];
      const tributaryWidth = 58.0;
      return River(
        points: points,
        width: tributaryWidth,
        bridges: [
          Bridge(
            center: _pointAlong(points, 0.63),
            angle: _bridgeAngleAt(points, 0.63),
            width: 104,
            depth: tributaryWidth + 48,
          ),
        ],
      );
    })();

    return [
      mainRiver,
      tributary,
    ];
  }

  static double _bridgeAngleAt(List<Offset> points, double t) {
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
        final tangent = points[i + 1] - points[i];
        // The deck's long axis follows the river; local X crosses it.
        return math.atan2(tangent.dy, tangent.dx) - math.pi / 2;
      }
      target -= lengths[i];
    }
    return 0;
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
    // Give each player quadrant a distinct biome so every match visibly
    // contains all four environments instead of scattering four small,
    // sometimes overlapping circles at arbitrary locations. Shuffle the
    // biome assignment per match while keeping each zone centered on its
    // corresponding castle quadrant.
    final kinds = TerrainKind.values.toList()..shuffle(rng);
    final centers = [
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      Offset(size.width * 0.75, size.height * 0.75),
    ];
    final radius = math.min(size.width, size.height) * 0.34;
    return [
      for (var i = 0; i < kinds.length; i++)
        BiomePatch(kind: kinds[i], center: centers[i], radius: radius),
    ];
  }

  static List<MapPickup> _generatePickups(
    math.Random rng,
    Size size,
    List<Offset> castles,
    List<MineSite> mines,
    List<River> rivers,
    List<MapObstacle> obstacles,
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
        if (obstacles.any(
          (obstacle) =>
              (obstacle.position - point).distance < obstacle.radius + 24,
        )) {
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
