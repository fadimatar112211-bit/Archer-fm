import 'dart:math' as math;
import 'dart:ui';

import 'arena_map.dart';

/// Mines and the match resource economy.
///
/// Confirmed rules (from `PROJECT_STATUS.md` §Mines and match resources):
/// capturing a mine needs 10 uninterrupted seconds inside its area, capture
/// pauses while more than one player is inside, an owned mine can be taken by
/// an opponent who completes the same capture, owned mines keep producing while
/// the owner is elsewhere, mines cannot be destroyed, a player may hold several
/// mines, produced resources are picked up only by touching them, and one match
/// resource is the currency for monsters/crystals/carry upgrades.
///
/// Production rates, amounts, pickup lifetime and carry-capacity progression
/// are **provisional balancing values** (see `PROJECT_STATUS.md` §5).

/// Confirmed capture time.
const int mineCaptureDurationMs = 10000;

/// Starting carry capacity from the requirements.
const int startingCarryCapacity = 500;

/// Provisional lifetime for an uncollected resource pickup.
const int minePickupLifetimeMs = 24000;

/// Provisional amount of a loose resource group generated with the map.
const int mapResourcePickupAmount = 30;

/// Provisional production numbers per mine size.
extension MineSizeProduction on MineSize {
  int get productionIntervalMs => switch (this) {
        MineSize.small => 4000,
        MineSize.medium => 3000,
        MineSize.large => 2000,
      };

  int get pickupAmount => switch (this) {
        MineSize.small => 12,
        MineSize.medium => 20,
        MineSize.large => 32,
      };
}

/// One collectable pile of match resources on the ground.
class ResourcePickup {
  const ResourcePickup({
    required this.id,
    required this.position,
    required this.amount,
    required this.bornAtMs,
    this.fromMine = true,
  });

  final String id;
  final Offset position;
  final int amount;
  final int bornAtMs;

  /// True for mine output, false for the loose resources placed by the map
  /// generator.
  final bool fromMine;
}

/// Runtime state of one neutral/owned mine.
class MineState {
  MineState({required this.site});

  final MineSite site;

  /// `null` while neutral, otherwise the owning player id.
  String? ownerId;

  /// Player currently accumulating capture progress (null when idle).
  String? capturerId;

  /// Elapsed capture time for [capturerId].
  double captureProgressMs = 0;

  int _productionCarryMs = 0;

  Offset get position => site.position;
  double get radius => site.radius;
  MineSize get size => site.size;
  bool get isNeutral => ownerId == null;

  bool owns(String playerId) => ownerId == playerId;

  bool contains(Offset point) => (point - position).distance <= radius;

  /// 0..1 capture progress for the HUD.
  double get captureFraction =>
      (captureProgressMs / mineCaptureDurationMs).clamp(0.0, 1.0);
}

/// Owns all mine state and the resource pickups lying on the ground.
///
/// The controller is widget-free and multiplayer-ready: [update] receives the
/// positions of every player in the match, so the same rule (one player inside
/// captures, several players pause it) already works for 2–4 players.
class MineController {
  MineController({required this.map, math.Random? random})
      : _rng = random ?? math.Random() {
    mines = [for (final site in map.mines) MineState(site: site)];
    var id = 0;
    for (final pickup in map.pickups) {
      if (pickup.kind != PickupKind.resource) continue;
      pickups.add(
        ResourcePickup(
          id: 'loose_${id++}',
          position: pickup.position,
          amount: mapResourcePickupAmount,
          bornAtMs: 0,
          fromMine: false,
        ),
      );
    }
  }

  /// The local hero's player id until the online layer supplies real ids.
  static const String localPlayerId = 'player';

  final ArenaMap map;
  final math.Random _rng;
  late final List<MineState> mines;

  /// Resources waiting to be walked over.
  final List<ResourcePickup> pickups = [];

  /// Maximum match resources the hero can carry from pickups (confirmed start:
  /// 500; permanent upgrades arrive with the progression system).
  int carryCapacity = startingCarryCapacity;

  int _pickupSeq = 0;

  Iterable<MineState> get ownedMines =>
      mines.where((mine) => !mine.isNeutral);

  int ownedMineCount(String playerId) =>
      mines.where((mine) => mine.owns(playerId)).length;

  MineState? mineContaining(Offset point) {
    for (final mine in mines) {
      if (mine.contains(point)) return mine;
    }
    return null;
  }

  /// Advances capture timers, mine production and pickup lifetimes.
  void update({
    required int deltaMs,
    required int nowMs,
    required Map<String, Offset> players,
  }) {
    _updateCaptures(deltaMs, players);
    _updateProduction(deltaMs, nowMs);
    _prunePickups(nowMs);
  }

  void _updateCaptures(int deltaMs, Map<String, Offset> players) {
    for (final mine in mines) {
      final inside = <String>[
        for (final entry in players.entries)
          if (mine.contains(entry.value)) entry.key,
      ];

      if (inside.isEmpty) {
        // Capture requires remaining inside the area: leaving resets it.
        mine.capturerId = null;
        mine.captureProgressMs = 0;
        continue;
      }
      if (inside.length > 1) {
        // Several players contest the mine: progress pauses until one remains.
        continue;
      }

      final playerId = inside.single;
      if (mine.owns(playerId)) {
        mine.capturerId = null;
        mine.captureProgressMs = 0;
        continue;
      }
      if (mine.capturerId != playerId) {
        mine.capturerId = playerId;
        mine.captureProgressMs = 0;
      }
      mine.captureProgressMs += deltaMs;
      if (mine.captureProgressMs >= mineCaptureDurationMs) {
        mine.ownerId = playerId;
        mine.capturerId = null;
        mine.captureProgressMs = 0;
      }
    }
  }

  void _updateProduction(int deltaMs, int nowMs) {
    for (final mine in mines) {
      if (mine.isNeutral) {
        mine._productionCarryMs = 0;
        continue;
      }
      mine._productionCarryMs += deltaMs;
      final interval = mine.size.productionIntervalMs;
      while (mine._productionCarryMs >= interval) {
        mine._productionCarryMs -= interval;
        pickups.add(
          ResourcePickup(
            id: 'mine_${_pickupSeq++}',
            position: _pickupSpotFor(mine),
            amount: mine.size.pickupAmount,
            bornAtMs: nowMs,
          ),
        );
      }
    }
  }

  /// A clear, dry spot on the mine's edge so created pickups are walkable.
  Offset _pickupSpotFor(MineState mine) {
    for (var attempt = 0; attempt < 12; attempt++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final distance = mine.radius * (0.35 + _rng.nextDouble() * 0.4);
      final spot = mine.position +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);
      if (map.isWater(spot) || map.isBlocked(spot, 10)) continue;
      if (pickups.any((pickup) => (pickup.position - spot).distance < 24)) {
        continue;
      }
      return spot;
    }
    return mine.position;
  }

  void _prunePickups(int nowMs) {
    pickups.removeWhere(
      (pickup) => nowMs - pickup.bornAtMs > minePickupLifetimeMs,
    );
  }

  /// Pickups the hero is touching that fit in the remaining carry capacity.
  /// The returned pickups are removed from the ground; the caller credits the
  /// resources so the world stays the single owner of the wallet.
  ///
  /// [touchRadius] keeps the legacy `CoinPickupResolver.isCollected` proximity
  /// rule and its tested 34-unit default (reviewed in §27); the legacy file is
  /// a 10-line pure check, so the rule is applied here instead of copied.
  List<ResourcePickup> collectAt(
    Offset position, {
    required int currentResources,
    int? capacity,
    double touchRadius = 34,
  }) {
    final limit = capacity ?? carryCapacity;
    var free = limit - currentResources;
    if (free <= 0) return const [];
    final collected = <ResourcePickup>[];
    for (final pickup in List<ResourcePickup>.of(pickups)) {
      if ((pickup.position - position).distance > touchRadius) continue;
      if (pickup.amount > free) continue;
      pickups.remove(pickup);
      free -= pickup.amount;
      collected.add(pickup);
      if (free <= 0) break;
    }
    return collected;
  }
}
