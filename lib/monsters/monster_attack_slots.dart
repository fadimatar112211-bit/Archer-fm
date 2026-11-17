import 'dart:math' as math;

import 'monster_models.dart';

/// Maintains stable, unique approach reservations around each current target.
///
/// Reservations are pruned every tick, so dead units and units that changed
/// targets release their slots automatically. New units take the first free
/// slot, keeping the remaining formation stable.
class MonsterAttackSlotCoordinator {
  MonsterAttackSlotCoordinator({this.desiredSpacing = 18}) {
    if (!desiredSpacing.isFinite || desiredSpacing <= 0) {
      throw ArgumentError.value(desiredSpacing, 'desiredSpacing');
    }
  }

  final double desiredSpacing;
  final Map<String, _TargetReservations> _reservations = {};

  int get activeReservationCount => _reservations.values.fold<int>(
        0,
        (sum, reservation) => sum + reservation.slotByUnit.length,
      );

  Map<String, (double, double)> assignForTargets({
    required Map<String, List<MonsterUnit>> unitsByTarget,
    required Map<String, MonsterTarget> targetsById,
  }) {
    _reservations.removeWhere(
      (targetId, _) =>
          !unitsByTarget.containsKey(targetId) || !targetsById.containsKey(targetId),
    );

    final result = <String, (double, double)>{};
    for (final entry in unitsByTarget.entries) {
      final target = targetsById[entry.key];
      if (target == null ||
          target.id.isEmpty ||
          !target.x.isFinite ||
          !target.y.isFinite) {
        continue;
      }
      final living = entry.value.where((unit) => unit.isAlive).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      final activeIds = living.map((unit) => unit.id).toSet();
      final reservation = _reservations.putIfAbsent(
        entry.key,
        _TargetReservations.new,
      );
      reservation.slotByUnit.removeWhere((id, _) => !activeIds.contains(id));

      final used = reservation.slotByUnit.values.toSet();
      for (final unit in living) {
        if (reservation.slotByUnit.containsKey(unit.id)) continue;
        var slot = 0;
        while (used.contains(slot)) {
          slot++;
        }
        reservation.slotByUnit[unit.id] = slot;
        used.add(slot);
      }

      for (final unit in living) {
        final slot = reservation.slotByUnit[unit.id]!;
        final range = unit.stats.attackRange;
        final radius = range * 0.82;
        final slotsPerRing = math.max(
          1,
          (2 * math.pi * math.max(radius, desiredSpacing) / desiredSpacing)
              .floor(),
        );
        final ring = slot ~/ slotsPerRing;
        final positionInRing = slot % slotsPerRing;
        final ringRadius = math.max(0, radius - ring * desiredSpacing * 0.85);
        final angle = -math.pi / 2 +
            2 * math.pi * positionInRing / slotsPerRing;
        result[unit.id] = (
          target.x + math.cos(angle) * ringRadius,
          target.y + math.sin(angle) * ringRadius,
        );
      }
    }
    return Map.unmodifiable(result);
  }

  void releaseUnit(String unitId) {
    for (final reservation in _reservations.values) {
      reservation.slotByUnit.remove(unitId);
    }
    _reservations.removeWhere((_, value) => value.slotByUnit.isEmpty);
  }

  void clear() => _reservations.clear();
}

class _TargetReservations {
  final Map<String, int> slotByUnit = {};
}
