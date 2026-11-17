import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'monster_animation.dart';

/// Animated, cropped SVG frame renderer for one monster.
///
/// The match renderer supplies authoritative alive/moving/attacking state and
/// positions this widget in world space. An optional health bar is displayed
/// above the monster; movement and damage remain outside this visual widget.
class MonsterSpriteView extends StatefulWidget {
  const MonsterSpriteView({
    super.key,
    required this.animation,
    this.size = 64,
    this.alive = true,
    this.moving = false,
    this.attacking = false,
    this.healthFraction,
    this.healthColor,
    this.onDeathAnimationComplete,
  }) : assert(size > 0);

  final MonsterAnimationController animation;
  final double size;
  final bool alive;
  final bool moving;
  final bool attacking;
  final double? healthFraction;
  final Color? healthColor;
  final VoidCallback? onDeathAnimationComplete;

  @override
  State<MonsterSpriteView> createState() => _MonsterSpriteViewState();
}

class _MonsterSpriteViewState extends State<MonsterSpriteView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _deathCompletionNotified = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _synchronize();
    _syncTicker();
    _notifyDeathAnimationComplete();
  }

  @override
  void didUpdateWidget(covariant MonsterSpriteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.alive != widget.alive) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
      _deathCompletionNotified = false;
    }
    _synchronize();
    _syncTicker();
    _notifyDeathAnimationComplete();
  }

  void _synchronize() {
    widget.animation.synchronize(
      alive: widget.alive,
      moving: widget.moving,
      attacking: widget.attacking,
    );
  }

  void _notifyDeathAnimationComplete() {
    final callback = widget.onDeathAnimationComplete;
    if (widget.alive ||
        callback == null ||
        _deathCompletionNotified ||
        !widget.animation.isComplete) {
      return;
    }
    _deathCompletionNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  void _syncTicker() {
    if (widget.animation.needsTicks) {
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
    final previousFrame = widget.animation.frameIndex;
    widget.animation.advance(delta);
    _notifyDeathAnimationComplete();
    if (previousFrame != widget.animation.frameIndex && mounted) {
      setState(() {});
    }
    if (!widget.animation.needsTicks) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Widget _buildSprite() {
    final sheet = widget.animation.currentSheet;
    final frame = widget.animation.frameIndex.clamp(0, sheet.frameCount - 1);
    final scale = widget.size / sheet.frameWidth;
    final stripWidth = sheet.sheetWidth * scale;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: stripWidth,
          maxWidth: stripWidth,
          minHeight: sheet.frameHeight * scale,
          maxHeight: sheet.frameHeight * scale,
          child: Transform.translate(
            offset: Offset(-sheet.frameWidth * scale * frame.toDouble(), 0),
            child: SvgPicture.asset(
              sheet.asset,
              width: stripWidth,
              height: sheet.frameHeight * scale,
              fit: BoxFit.fill,
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthBar(double health) {
    final fraction = health.isFinite ? health.clamp(0.0, 1.0).toDouble() : 0.0;
    return SizedBox(
      width: widget.size * 0.78,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Color.fromARGB(140, 0, 0, 0)),
            ),
            FractionallySizedBox(
              key: const ValueKey('monster-health-fill'),
              widthFactor: fraction,
              child: ColoredBox(
                color: widget.healthColor ?? const Color(0xFFB2FF59),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sprite = _buildSprite();
    final health = widget.healthFraction;
    if (health == null) return sprite;

    return SizedBox(
      width: widget.size,
      height: widget.size + 7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHealthBar(health),
          const SizedBox(height: 3),
          sprite,
        ],
      ),
    );
  }
}
