import 'monster_models.dart';
import 'monster_projectiles.dart';

/// Adapter for authoritative hero/crystal state supplied by the match layer.
///
/// Snapshot values are convenient for immutable entities. When an entity can
/// move or die during the same simulation tick, provide the live getter
/// callbacks so later attacks/projectiles observe its updated state.
class MonsterExternalEntityAdapter
    implements MonsterPositionedDamageTarget {
  const MonsterExternalEntityAdapter({
    required this.id,
    required this.ownerId,
    required this.kind,
    required bool isAlive,
    required double positionX,
    required double positionY,
    required bool Function(double amount) applyDamage,
    bool Function()? isAliveNow,
    double Function()? positionXNow,
    double Function()? positionYNow,
  })  : _isAliveSnapshot = isAlive,
        _positionXSnapshot = positionX,
        _positionYSnapshot = positionY,
        _applyDamage = applyDamage,
        _isAliveNow = isAliveNow,
        _positionXNow = positionXNow,
        _positionYNow = positionYNow;

  @override
  final String id;
  @override
  final String ownerId;
  @override
  final MonsterTargetKind kind;

  final bool _isAliveSnapshot;
  final double _positionXSnapshot;
  final double _positionYSnapshot;
  final bool Function(double amount) _applyDamage;
  final bool Function()? _isAliveNow;
  final double Function()? _positionXNow;
  final double Function()? _positionYNow;

  @override
  bool get isAlive => _isAliveNow?.call() ?? _isAliveSnapshot;

  @override
  double get positionX => _positionXNow?.call() ?? _positionXSnapshot;

  @override
  double get positionY => _positionYNow?.call() ?? _positionYSnapshot;

  @override
  bool applyDamage(double amount) => _applyDamage(amount);
}
