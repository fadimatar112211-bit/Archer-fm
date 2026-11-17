import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'monster_animation.dart';
import 'monster_sprite_view.dart';

/// Drives a monster's visual clock from Flutter's frame ticker.
///
/// World position and combat remain owned by the match simulation. The host
/// only supplies the current alive/moving/attacking state; this widget advances
/// sprite frames and paints the selected cell.
class MonsterAnimatedSprite extends StatefulWidget {
  const MonsterAnimatedSprite({
    super.key,
    required this.animation,
    required this.alive,
    required this.moving,
    this.attacking = false,
    this.size = 64,
  }) : assert(size > 0);

  final MonsterAnimationController animation;
  final bool alive;
  final bool moving;
  final bool attacking;
  final double size;

  @override
  State<MonsterAnimatedSprite> createState() => _MonsterAnimatedSpriteState();
}

class _MonsterAnimatedSpriteState extends State<MonsterAnimatedSprite>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _previousElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _synchronize();
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant MonsterAnimatedSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.alive != widget.alive ||
        oldWidget.moving != widget.moving ||
        oldWidget.attacking != widget.attacking) {
      _synchronize();
      _updateTicker();
    }
  }

  void _synchronize() {
    widget.animation.synchronize(
      alive: widget.alive,
      moving: widget.moving,
      attacking: widget.attacking,
    );
  }

  void _updateTicker() {
    final animation = widget.animation;
    final shouldAnimate = animation.state != MonsterAnimationState.idle &&
        !animation.isComplete;
    if (!shouldAnimate) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (!_ticker.isActive) {
      _previousElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _previousElapsed;
    _previousElapsed = elapsed;
    if (delta > Duration.zero) {
      widget.animation.advance(delta);
      if (mounted) setState(() {});
    }
    if (widget.animation.isComplete && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) => MonsterSpriteView(
        animation: widget.animation,
        size: widget.size,
      );

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
