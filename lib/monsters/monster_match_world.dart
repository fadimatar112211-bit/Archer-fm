import 'monster_combat_resolver.dart';
import 'monster_match_combat_loop.dart';
import 'monster_models.dart';
import 'monster_projectiles.dart';

/// A fresh bridge between authoritative match entities and the monster loop.
///
/// The match host creates this snapshot each simulation tick from current
/// hero/crystal adapters and the live monster units. It provides one consistent
/// target-candidate snapshot plus authoritative damage/position lookups.
class MonsterMatchWorldSnapshot {
  factory MonsterMatchWorldSnapshot({
    required Iterable<MonsterUnit> units,
    Iterable<MonsterPositionedDamageTarget> externalEntities = const [],
  }) {
    final unitList = List<MonsterUnit>.unmodifiable(units);
    final targets = <String, MonsterPositionedDamageTarget>{};

    for (final entity in externalEntities) {
      _validateEntity(entity);
      if (targets.containsKey(entity.id)) {
        throw ArgumentError('Duplicate match entity id: ' + entity.id);
      }
      targets[entity.id] = entity;
    }

    for (final unit in unitList) {
      if (unit.id.isEmpty ||
          unit.ownerId.isEmpty ||
          !unit.positionX.isFinite ||
          !unit.positionY.isFinite) {
        throw ArgumentError('Monster world units require valid identities and positions.');
      }
      if (targets.containsKey(unit.id)) {
        throw ArgumentError('Duplicate match entity id: ' + unit.id);
      }
      targets[unit.id] = _MonsterUnitWorldTarget(unit);
    }

    return MonsterMatchWorldSnapshot._(
      units: unitList,
      targets: Map.unmodifiable(targets),
    );
  }

  const MonsterMatchWorldSnapshot._({
    required this.units,
    required Map<String, MonsterPositionedDamageTarget> targets,
  }) : _targets = targets;

  final List<MonsterUnit> units;
  final Map<String, MonsterPositionedDamageTarget> _targets;

  /// Creates fresh target values from the current positions and health flags.
  List<MonsterTarget> candidatesFor(MonsterUnit source) {
    final candidates = <MonsterTarget>[];
    for (final target in _targets.values) {
      if (target.id == source.id ||
          !target.positionX.isFinite ||
          !target.positionY.isFinite) {
        continue;
      }
      candidates.add(MonsterTarget(
        id: target.id,
        ownerId: target.ownerId,
        kind: target.kind,
        x: target.positionX,
        y: target.positionY,
        isAlive: target.isAlive,
      ));
    }
    return List.unmodifiable(candidates);
  }

  MonsterDamageTarget? resolveDamageTarget(String id) => _targets[id];

  MonsterPositionedDamageTarget? resolvePositionedTarget(String id) {
    final target = _targets[id];
    if (target == null ||
        !target.positionX.isFinite ||
        !target.positionY.isFinite) {
      return null;
    }
    return target;
  }

  /// Runs one authoritative monster tick against this world snapshot.
  MonsterMatchTickResult step({
    required MonsterMatchCombatLoop loop,
    required DateTime now,
    required Duration elapsed,
  }) =>
      loop.update(
        units: units,
        candidatesFor: candidatesFor,
        resolveDamageTarget: resolveDamageTarget,
        resolvePositionedTarget: resolvePositionedTarget,
        now: now,
        elapsed: elapsed,
      );

  static void _validateEntity(MonsterPositionedDamageTarget entity) {
    if (entity.id.isEmpty ||
        entity.ownerId.isEmpty ||
        !entity.positionX.isFinite ||
        !entity.positionY.isFinite) {
      throw ArgumentError(
        'External match entities require valid identities and positions.',
      );
    }
  }
}

class _MonsterUnitWorldTarget implements MonsterPositionedDamageTarget {
  const _MonsterUnitWorldTarget(this.unit);

  final MonsterUnit unit;

  @override
  String get id => unit.id;

  @override
  String get ownerId => unit.ownerId;

  @override
  MonsterTargetKind get kind => MonsterTargetKind.monster;

  @override
  bool get isAlive => unit.isAlive;

  @override
  double get positionX => unit.positionX;

  @override
  double get positionY => unit.positionY;

  @override
  bool applyDamage(double amount) => unit.applyDamage(amount);
}
