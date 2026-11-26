import 'monster_combat_resolver.dart';
import 'monster_projectiles.dart';

/// Owns active projectiles for one authoritative match simulation.
class MonsterProjectileManager {
  MonsterProjectileManager({required this.maxActiveProjectiles})
      : assert(maxActiveProjectiles > 0) {
    if (maxActiveProjectiles <= 0) {
      throw ArgumentError.value(maxActiveProjectiles, 'maxActiveProjectiles');
    }
  }

  final int maxActiveProjectiles;
  final Map<String, MonsterProjectile> _active = {};

  int get activeCount => _active.length;
  List<MonsterProjectile> get active =>
      List.unmodifiable(_active.values);

  /// Returns false for duplicate IDs or when the configured safety budget is full.
  bool add(MonsterProjectile projectile) {
    if (projectile.isResolved ||
        _active.containsKey(projectile.id) ||
        _active.length >= maxActiveProjectiles) {
      return false;
    }
    _active[projectile.id] = projectile;
    return true;
  }

  /// Updates a stable snapshot, then removes every projectile that has resolved.
  Map<String, MonsterProjectileResult> update({
    required Duration elapsed,
    required MonsterDamageTarget? Function(String targetId) resolveTarget,
  }) {
    final results = <String, MonsterProjectileResult>{};
    for (final projectile in _active.values.toList(growable: false)) {
      results[projectile.id] = projectile.update(
        elapsed: elapsed,
        target: resolveTarget(projectile.targetId),
      );
    }
    _active.removeWhere((_, projectile) => projectile.isResolved);
    return Map.unmodifiable(results);
  }

  void clear() => _active.clear();
}
