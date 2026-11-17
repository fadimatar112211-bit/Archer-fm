import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  }) : assert(size > 0);

  final MonsterAnimationController animation;
  final double size;
  final bool alive;
  final bool moving;
  final bool attacking;
  final double? healthFraction;
  final Color? healthColor;

  @override
  State<MonsterSpriteView> createState() => _MonsterSpriteViewState();
}

class _MonsterSpriteViewState extends State<MonsterSpriteView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _synchronize();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant MonsterSpriteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _ticker.stop();
      _lastElapsed = Duration.zero;
    }
    _synchronize();
    _syncTicker();
  }

  void _synchronize() {
    widget.animation.synchronize(
      alive: widget.alive,
      moving: widget.moving,
      attacking: widget.attacking,
    );
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
          SizedBox(
            width: widget.size * 0.78,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: health.clamp(0.0, 1.0).toDouble(),
                backgroundColor: const Color.fromRGBO(0, 0, 0, 0.55),
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.healthColor ?? Colors.lightGreenAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          sprite,
        ],
      ),
    );
  }
}
