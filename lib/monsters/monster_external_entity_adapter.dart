import 'monster_combat_resolver.dart';
import 'monster_projectiles.dart';
import 'monster_models.dart';

/// Adapter for authoritative hero/crystal state supplied by the match layer.
/// The caller must construct it from current server-owned state each tick;
/// this package intentionally has no dependency on hero or crystal modules.
class MonsterExternalEntityAdapter
    implements MonsterPositionedDamageTarget {
  const MonsterExternalEntityAdapter({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.isAlive,
    required this.positionX,
    required this.positionY,
    required bool Function(double amount) applyDamage,
  }) : _applyDamage = applyDamage;

  @override
  final String id;
  @override
  final String ownerId;
  @override
  final MonsterTargetKind kind;
  @override
  final bool isAlive;
  @override
  final double positionX;
  @override
  final double positionY;

  final bool Function(double amount) _applyDamage;

  @override
  bool applyDamage(double amount) => _applyDamage(amount);
}
