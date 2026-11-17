import 'package:flutter/scheduler.dart';
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
    this.dyingUnits = const [],
    required this.projectiles,
    required this.worldToScreen,
    required this.simulationTick,
    this.attackingUnitIds = const {},
    this.unitSize = 64,
    this.projectileSize = 9,
    this.projectileColor = const Color(0xFF7DEBFF),
    this.onDeathAnimationComplete,
  })  : assert(unitSize > 0),
        assert(projectileSize > 0);

  /// Live units plus any recently defeated units retained for their death animation.
  final List<MonsterUnit> units;
  final List<MonsterUnit> dyingUnits;
  final List<MonsterProjectile> projectiles;
  final MonsterWorldToScreen worldToScreen;

  /// Increment once per authoritative simulation tick, not per widget rebuild.
  final int simulationTick;
  final Set<String> attackingUnitIds;
  final double unitSize;
  final double projectileSize;
  final Color projectileColor;
  final ValueChanged<String>? onDeathAnimationComplete;

  @override
  State<MonsterBattleLayer> createState() => _MonsterBattleLayerState();
}

class _MonsterBattleLayerState extends State<MonsterBattleLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final Map<String, MonsterAnimationController> _animations = {};
  final Map<String, (double, double)> _previousPositions = {};
  Set<String> _movingUnitIds = const {};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
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

    for (final unit in [...widget.units, ...widget.dyingUnits]) {
      if (!currentIds.add(unit.id)) {
        throw ArgumentError('Duplicate monster visual ID: ' + unit.id);
      }
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
    for (final unit in [...widget.units, ...widget.dyingUnits]) {
      _animations[unit.id]!.synchronize(
        alive: unit.isAlive,
        moving: _movingUnitIds.contains(unit.id),
        attacking: unit.isAlive && widget.attackingUnitIds.contains(unit.id),
      );
    }
    _syncTicker();
  }

  void _syncTicker() {
    final needsTicks = _animations.values.any((animation) => animation.needsTicks);
    if (needsTicks) {
      if (!_ticker.isActive) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    var frameChanged = false;
    for (final animation in _animations.values) {
      final previousFrame = animation.frameIndex;
      animation.advance(delta);
      if (previousFrame != animation.frameIndex) frameChanged = true;
    }
    if (frameChanged && mounted) setState(() {});
    if (!_animations.values.any((animation) => animation.needsTicks)) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderedUnits = [...widget.units, ...widget.dyingUnits]
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
          animationManagedExternally: true,
          size: widget.unitSize,
          alive: unit.isAlive,
          moving: _movingUnitIds.contains(unit.id),
          attacking: unit.isAlive && widget.attackingUnitIds.contains(unit.id),
          healthFraction: unit.health / unit.stats.maxHealth,
          onDeathAnimationComplete: unit.isAlive
              ? null
              : () => widget.onDeathAnimationComplete?.call(unit.id),
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
