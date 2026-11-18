import 'dart:math' as math;
import 'dart:ui';

import 'match_models.dart';

/// Server-side state for one player. Clients never write these fields
/// directly: every mutation goes through [MatchAuthority].
class AuthorityPlayer {
  AuthorityPlayer({
    required this.id,
    required this.username,
    required this.heroId,
    required this.maxHp,
    required this.position,
    required this.colorValue,
    this.carryCapacity = 500,
  }) : hp = maxHp;

  final String id;
  final String username;
  final String heroId;
  final double maxHp;
  final int colorValue;
  final int carryCapacity;

  double hp;
  int resources = 0;
  int score = 0;
  int kills = 0;
  int crystals = 7;
  Offset position;

  MatchPlayer toMatchPlayer() => MatchPlayer(
        id: id,
        username: username,
        heroId: heroId,
        colorValue: colorValue,
        score: score,
        kills: kills,
        crystals: crystals,
        hp: hp,
        maxHp: maxHp,
      );
}

/// Host-authoritative validation for the confirmed cheating-sensitive state:
/// damage, kills, score, resources, health and movement (PROJECT_STATUS.md
/// §Networking). Values invented by a client are clamped or rejected here.
class MatchAuthority {
  MatchAuthority({
    required List<AuthorityPlayer> players,
    required Rect mapBounds,
    this.moveSpeed = 260,
    this.attackRange = 480,
    this.collectRadius = 34,
  })  : _players = {for (final player in players) player.id: player},
        _bounds = mapBounds;

  final Map<String, AuthorityPlayer> _players;
  final Rect _bounds;

  final double moveSpeed;
  final double attackRange;
  final double collectRadius;

  int _nowMs = 0;
  final List<String> violations = <String>[];

  int get nowMs => _nowMs;

  Iterable<AuthorityPlayer> get players => _players.values;

  AuthorityPlayer? player(String id) => _players[id];

  void advanceTo(int nowMs) {
    if (nowMs > _nowMs) _nowMs = nowMs;
  }

  bool _reject(String message) {
    violations.add(message);
    return false;
  }

  /// Movement is rate-limited and clamped to the generated map. Clients send
  /// intent/position; the authority never accepts teleports.
  bool move(String id, Offset requested, int atMs) {
    final player = _players[id];
    if (player == null) return _reject('unknown player $id');
    if (atMs < _nowMs) return _reject('stale movement from $id');
    final elapsed = math.max(0, atMs - _nowMs) / 1000.0;
    _nowMs = atMs;
    final delta = requested - player.position;
    final maxDistance = moveSpeed * elapsed + 1.0;
    if (delta.distance > maxDistance) return _reject('teleport by $id');
    player.position = Offset(
      requested.dx.clamp(_bounds.left, _bounds.right),
      requested.dy.clamp(_bounds.top, _bounds.bottom),
    );
    return true;
  }

  /// The authority applies damage itself and never trusts a client-reported
  /// HP value. Kills and score are credited only by this method or by
  /// [destroyCrystal].
  bool applyDamage({
    required String attackerId,
    required String targetId,
    required double amount,
    required double maximumDamage,
    double? distance,
  }) {
    final attacker = _players[attackerId];
    final target = _players[targetId];
    if (attacker == null || target == null) return false;
    if (attackerId == targetId) return _reject('self damage');
    if (amount <= 0 || amount > maximumDamage) {
      return _reject('invalid damage amount');
    }
    if (distance != null && distance > attackRange) {
      return _reject('attack out of range');
    }
    if (target.hp <= 0) return _reject('target already dead');
    target.hp = math.max(0, target.hp - amount);
    if (target.hp == 0) {
      attacker.kills += 1;
      attacker.score += 1;
    }
    return true;
  }

  /// Health may only decrease through [applyDamage]; respawn restores it to
  /// the authoritative maximum and is controlled by the host.
  bool respawn(String id) {
    final player = _players[id];
    if (player == null) return false;
    player.hp = player.maxHp;
    return true;
  }

  /// Crystals and the score they grant are server-owned. Destroying the last
  /// crystal is reported through [lastStanding] so the match rules can close
  /// the match.
  bool destroyCrystal(String attackerId, String ownerId) {
    final attacker = _players[attackerId];
    final owner = _players[ownerId];
    if (attacker == null || owner == null || attackerId == ownerId) return false;
    if (owner.crystals <= 0) return _reject('no crystals left');
    owner.crystals -= 1;
    attacker.score += 1;
    return true;
  }

  bool lastStanding() =>
      _players.values.where((player) => player.crystals > 0).length <= 1;

  /// Resource pickups are credited only when the collecting player is inside
  /// the confirmed touch radius. Resource values never come from the client.
  bool collectResource({
    required String id,
    required Offset pickupPosition,
    required int amount,
  }) {
    final player = _players[id];
    if (player == null || amount <= 0) return false;
    if ((player.position - pickupPosition).distance > collectRadius) {
      return _reject('pickup out of reach');
    }
    player.resources = math.min(
      player.carryCapacity,
      player.resources + amount,
    );
    return true;
  }

  /// Server-owned resource spending (e.g. rebuilding a crystal).
  bool spendResources(String id, int amount) {
    final player = _players[id];
    if (player == null || amount < 0 || player.resources < amount) return false;
    player.resources -= amount;
    return true;
  }

  List<MatchPlayer> snapshot() =>
      [for (final player in _players.values) player.toMatchPlayer()];
}
