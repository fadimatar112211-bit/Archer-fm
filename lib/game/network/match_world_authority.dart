import 'dart:math' as math;
import 'dart:ui';

import '../world/arena_map.dart';
import '../world/castle_system.dart';
import '../world/mine_system.dart';

/// Server-side bridge over the canonical arena, castle, crystal and mine
/// controllers. It contains no duplicate map or economy rules.
class MatchWorldAuthority {
  MatchWorldAuthority({
    required this.map,
    required List<String> playerIds,
    math.Random? random,
  })  : playerIds = List.unmodifiable(playerIds),
        castles = CastleController(
          map: map,
          localPlayerId: playerIds.isEmpty ? '' : playerIds.first,
          playerIds: playerIds,
        ),
        mines = MineController(map: map, random: random) {
    if (playerIds.length != 4 ||
        playerIds.toSet().length != 4 ||
        playerIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError.value(
        playerIds,
        'playerIds',
        'A multiplayer world requires four unique, non-empty player IDs.',
      );
    }
    if (map.castleAnchors.length != 4) {
      throw ArgumentError.value(
        map.castleAnchors.length,
        'map.castleAnchors',
        'A four-player world requires exactly four castle anchors.',
      );
    }
    _resources = {for (final id in playerIds) id: 0};
    _positions = {
      for (var i = 0; i < playerIds.length; i++)
        playerIds[i]: map.castleAnchors[i] + const Offset(0, 220),
    };
  }

  final ArenaMap map;
  final List<String> playerIds;
  final CastleController castles;
  final MineController mines;
  late final Map<String, int> _resources;
  late final Map<String, Offset> _positions;

  Map<String, int> get resources => Map.unmodifiable(_resources);
  Map<String, Offset> get playerPositions => Map.unmodifiable(_positions);

  int livingCrystals(String playerId) =>
      castles.castleOf(playerId)?.aliveCount ?? 0;

  /// Atomic wallet debit used by authoritative unit purchases.
  bool trySpendResources(String playerId, int amount) {
    _requirePlayer(playerId);
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    final balance = _resources[playerId]!;
    if (balance < amount) return false;
    _resources[playerId] = balance - amount;
    return true;
  }

  /// Trusted refund/production credit. Clients cannot call this directly.
  void creditResources(String playerId, int amount) {
    _requirePlayer(playerId);
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    _resources[playerId] = _resources[playerId]! + amount;
  }

  /// Removes a fraction of the current wallet after a server-confirmed
  /// hero defeat. The amount is rounded down because resources are integral.
  int loseResourcesFraction(String playerId, double fraction) {
    _requirePlayer(playerId);
    if (!fraction.isFinite || fraction < 0 || fraction > 1) {
      throw ArgumentError.value(fraction, 'fraction');
    }
    final balance = _resources[playerId]!;
    final lost = (balance * fraction).floor();
    _resources[playerId] = balance - lost;
    return lost;
  }

  /// Teleports a respawning hero to its server-recorded spawn location.
  void setPlayerPosition(String playerId, Offset position) {
    _requirePlayer(playerId);
    if (!position.dx.isFinite || !position.dy.isFinite) {
      throw ArgumentError('Player position must be finite.');
    }
    _positions[playerId] = map.clampToBounds(position, 18);
  }

  /// Applies an authoritative movement result using the map's collision and
  /// shallow-water rules. Clients submit intent, never a trusted world pos.
  Offset movePlayer(String playerId, Offset desiredDelta, double radius) {
    _requirePlayer(playerId);
    if (!desiredDelta.dx.isFinite ||
        !desiredDelta.dy.isFinite ||
        !radius.isFinite ||
        radius <= 0) {
      throw ArgumentError('Movement delta and radius must be finite; radius must be positive.');
    }
    final current = _positions[playerId]!;
    final target = map.slideMove(current, desiredDelta, radius);
    _positions[playerId] = target;
    return target;
  }

  /// Advances mine capture/production, then collects only pickups the player
  /// physically touches. Wallet balances are owned by this authority.
  MatchWorldTickResult tick({
    required int deltaMs,
    required int nowMs,
    Map<String, Offset> authoritativePositions = const {},
  }) {
    if (deltaMs < 0 || nowMs < 0) {
      throw ArgumentError('World time cannot be negative.');
    }
    for (final entry in authoritativePositions.entries) {
      _requirePlayer(entry.key);
      if (!entry.value.dx.isFinite || !entry.value.dy.isFinite) {
        throw ArgumentError('Player position must be finite.');
      }
      _positions[entry.key] = map.clampToBounds(entry.value, 18);
    }
    mines.update(
      deltaMs: deltaMs,
      nowMs: nowMs,
      players: Map.unmodifiable(_positions),
    );

    final collected = <String, int>{};
    for (final id in playerIds) {
      final pickups = mines.collectAt(
        _positions[id]!,
        currentResources: _resources[id]!,
      );
      final amount = pickups.fold<int>(0, (sum, pickup) => sum + pickup.amount);
      if (amount > 0) {
        _resources[id] = _resources[id]! + amount;
        collected[id] = amount;
      }
    }
    return MatchWorldTickResult(
      collectedResources: collected,
      livingCrystals: {
        for (final id in playerIds) id: livingCrystals(id),
      },
      walletBalances: resources,
    );
  }

  /// Only server-side combat resolution should call this method.
  CrystalDamageResult damageCrystal({
    required String attackerId,
    required String crystalId,
    required double amount,
  }) {
    _requirePlayer(attackerId);
    CrystalState? target;
    for (final castle in castles.castles) {
      for (final crystal in castle.crystals) {
        if (crystal.id == crystalId) target = crystal;
      }
    }
    if (target == null) return const CrystalDamageResult.unknownCrystal();
    if (target.ownerId == attackerId) {
      return const CrystalDamageResult.friendlyTarget();
    }
    final targetCastle = castles.castleOf(target.ownerId);
    if (target.destroyed || targetCastle == null || targetCastle.fallen) {
      return const CrystalDamageResult.alreadyDestroyed();
    }
    if (amount <= 0 || !amount.isFinite) {
      return const CrystalDamageResult.invalidDamage();
    }
    final wasAlive = !target.destroyed;
    final destroyed = castles.damageCrystal(target, amount);
    return CrystalDamageResult.applied(
      ownerId: target.ownerId,
      remainingHp: target.hp,
      destroyedNow: wasAlive && destroyed,
      livingCrystals: livingCrystals(target.ownerId),
    );
  }

  /// Rebuilding consumes the authoritative wallet only after every canonical
  /// territory, collision, capacity and cost check passes.
  CrystalRebuildResult rebuildCrystal({
    required String ownerId,
    required Offset position,
  }) {
    _requirePlayer(ownerId);
    final castle = castles.castleOf(ownerId);
    if (castle == null) return CrystalRebuildResult.blocked;
    final cost = castles.rebuildCost(castle);
    final validation = castles.validateRebuild(
      castle,
      position,
      resources: _resources[ownerId]!,
    );
    if (validation != CrystalRebuildResult.ok) return validation;
    _resources[ownerId] = _resources[ownerId]! - cost;
    final rebuilt = castles.rebuild(castle, position);
    if (rebuilt == null) {
      _resources[ownerId] = _resources[ownerId]! + cost;
      return CrystalRebuildResult.blocked;
    }
    return CrystalRebuildResult.ok;
  }

  void _requirePlayer(String playerId) {
    if (!_resources.containsKey(playerId)) {
      throw ArgumentError.value(playerId, 'playerId', 'Unknown match player.');
    }
  }
}

class MatchWorldTickResult {
  const MatchWorldTickResult({
    required this.collectedResources,
    required this.livingCrystals,
    required this.walletBalances,
  });

  final Map<String, int> collectedResources;
  final Map<String, int> livingCrystals;
  final Map<String, int> walletBalances;
}

class CrystalDamageResult {
  const CrystalDamageResult._({
    required this.accepted,
    this.ownerId,
    this.remainingHp,
    this.destroyedNow = false,
    this.livingCrystals,
    this.error,
  });

  const CrystalDamageResult.unknownCrystal()
      : this._(accepted: false, error: 'unknown_crystal');
  const CrystalDamageResult.friendlyTarget()
      : this._(accepted: false, error: 'friendly_target');
  const CrystalDamageResult.alreadyDestroyed()
      : this._(accepted: false, error: 'already_destroyed');
  const CrystalDamageResult.invalidDamage()
      : this._(accepted: false, error: 'invalid_damage');

  const CrystalDamageResult.applied({
    required String ownerId,
    required double remainingHp,
    required bool destroyedNow,
    required int livingCrystals,
  }) : this._(
          accepted: true,
          ownerId: ownerId,
          remainingHp: remainingHp,
          destroyedNow: destroyedNow,
          livingCrystals: livingCrystals,
        );

  final bool accepted;
  final String? ownerId;
  final double? remainingHp;
  final bool destroyedNow;
  final int? livingCrystals;
  final String? error;
}
