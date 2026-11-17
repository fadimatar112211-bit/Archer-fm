import 'package:flutter/widgets.dart';

import 'monster_animation.dart';
import 'monster_models.dart';
import 'monster_projectiles.dart';
import 'monster_sprite_view.dart';

typedef MonsterWorldToScreen = Offset Function(double worldX, double worldY);

/// Draws the current monster army and homing projectiles in a world-space
/// overlay. Camera transforms remain owned by the map/game screen.
class MonsterBattleLayer extends StatefulWidget {
  const MonsterBattleLayer({
    super.key,
    required this.units,
    required this.projectiles,
    required this.worldToScreen,
    required this.simulationTick,
    this.attackingUnitIds = const {},
    this.unitSize = 64,
    this.projectileSize = 9,
    this.projectileColor = const Color(0xFF7DEBFF),
  })  : assert(unitSize > 0),
        assert(projectileSize > 0);

  final List<MonsterUnit> units;
  final List<MonsterProjectile> projectiles;
  final MonsterWorldToScreen worldToScreen;

  /// Increment once per authoritative simulation tick, not per widget rebuild.
  final int simulationTick;
  final Set<String> attackingUnitIds;
  final double unitSize;
  final double projectileSize;
  final Color projectileColor;

  @override
  State<MonsterBattleLayer> createState() => _MonsterBattleLayerState();
}

class _MonsterBattleLayerState extends State<MonsterBattleLayer> {
  final Map<String, MonsterAnimationController> _animations = {};
  final Map<String, (double, double)> _previousPositions = {};
  Set<String> _movingUnitIds = const {};

  @override
  void initState() {
    super.initState();
    _syncUnits(detectMovement: false);
  }

  @override
  void didUpdateWidget(covariant MonsterBattleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncUnits(
      detectMovement: oldWidget.simulationTick != widget.simulationTick,
    );
  }

  void _syncUnits({required bool detectMovement}) {
    final currentIds = <String>{};
    final moving = detectMovement ? <String>{} : {..._movingUnitIds};

    for (final unit in widget.units) {
      currentIds.add(unit.id);
      final controller = _animations[unit.id];
      if (controller == null || controller.type != unit.type) {
        _animations[unit.id] =
            MonsterAnimationCatalog.createController(unit.type);
      }

      final previous = _previousPositions[unit.id];
      if (detectMovement && previous != null) {
        final dx = unit.positionX - previous.$1;
        final dy = unit.positionY - previous.$2;
        if (dx * dx + dy * dy > 0.01) moving.add(unit.id);
      }
      _previousPositions[unit.id] = (unit.positionX, unit.positionY);
    }

    _animations.removeWhere((id, _) => !currentIds.contains(id));
    _previousPositions.removeWhere((id, _) => !currentIds.contains(id));
    moving.removeWhere((id) => !currentIds.contains(id));
    _movingUnitIds = moving;
  }

  @override
  Widget build(BuildContext context) {
    final orderedUnits = widget.units.toList()
      ..sort((a, b) => a.positionY.compareTo(b.positionY));
    final children = <Widget>[];

    for (final unit in orderedUnits) {
      final point = widget.worldToScreen(unit.positionX, unit.positionY);
      final animation = _animations[unit.id];
      if (animation == null || !point.dx.isFinite || !point.dy.isFinite) {
        continue;
      }
      final visualHeight = widget.unitSize + 7;
      children.add(Positioned(
        key: ValueKey('monster-layer-unit-${unit.id}'),
        left: point.dx - widget.unitSize / 2,
        top: point.dy - visualHeight / 2,
        child: MonsterSpriteView(
          key: ValueKey('monster-${unit.id}'),
          animation: animation,
          size: widget.unitSize,
          alive: unit.isAlive,
          moving: _movingUnitIds.contains(unit.id),
          attacking: widget.attackingUnitIds.contains(unit.id),
          healthFraction: unit.health / unit.stats.maxHealth,
        ),
      ));
    }

    for (final projectile in widget.projectiles) {
      final point = widget.worldToScreen(
        projectile.positionX,
        projectile.positionY,
      );
      if (!point.dx.isFinite || !point.dy.isFinite) continue;
      children.add(Positioned(
        key: ValueKey('monster-layer-projectile-${projectile.id}'),
        left: point.dx - widget.projectileSize / 2,
        top: point.dy - widget.projectileSize / 2,
        child: SizedBox(
          width: widget.projectileSize,
          height: widget.projectileSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.projectileColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.projectileColor.withValues(alpha: 0.65),
                  blurRadius: widget.projectileSize * 1.2,
                  spreadRadius: widget.projectileSize * 0.15,
                ),
              ],
            ),
          ),
        ),
      ));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: children,
    );
  }
}
