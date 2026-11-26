import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'monster_animation.dart';
import 'monster_assets.dart';
import 'monster_models.dart';
import 'monster3d.dart';

/// Renders a monster. Uses Monster3D (GLB-converted .bin) for the 4
/// integrated monsters. Keeps the same interface used by MonsterBattleLayer.
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
    this.animationManagedExternally = false,
    this.onCombatHit,
  }) : assert(size > 0);

  final MonsterAnimationController animation;
  final double size;
  final bool alive;
  final bool moving;
  final bool attacking;
  final double? healthFraction;
  final Color? healthColor;
  final VoidCallback? onDeathAnimationComplete;
  final bool animationManagedExternally;
  final void Function(Offset center, double radius, double damage)? onCombatHit;

  @override
  State<MonsterSpriteView> createState() => _MonsterSpriteViewState();
}

class _MonsterSpriteViewState extends State<MonsterSpriteView>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _deathCompletionNotified = false;
  Monster3D? _m3d;
  bool _loadStarted = false;

  MonsterType get _type => widget.animation.type;

  @override
  void initState() {
    super.initState();
    _ensureModel();
    if (!widget.animationManagedExternally) {
      _ticker = createTicker(_onTick);
    }
    _synchronize();
    _syncTicker();
  }

  void _ensureModel() {
    if (_loadStarted) return;
    _loadStarted = true;
    final a3 = MonsterAssetCatalog.forType3D(_type);
    final m = Monster3D(a3.id, height: a3.heightScale);
    m.isStealth = a3.role == 'stealth';
    m.isHeavyAoe = a3.role == 'heavy';
    m.onHit = widget.onCombatHit;
    m.load().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
    _m3d = m;
  }

  @override
  void didUpdateWidget(covariant MonsterSpriteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation || oldWidget.alive != widget.alive) {
      _deathCompletionNotified = false;
      _lastElapsed = Duration.zero;
    }
    if (oldWidget.animation.type != widget.animation.type) {
      _m3d?.dispose();
      _m3d = null;
      _loadStarted = false;
      _ensureModel();
    }
    _synchronize();
    _syncTicker();
    _notifyDeathComplete();
  }

  void _synchronize() {
    widget.animation.synchronize(
      alive: widget.alive,
      moving: widget.moving,
      attacking: widget.attacking,
    );
    final m = _m3d;
    if (m == null) return;
    m.onHit = widget.onCombatHit;
    if (!m.isReady) return;
    if (!widget.alive) {
      if (!m.isDead) m.takeHit(m.hp + 1);
    } else if (widget.attacking) {
      m.triggerAttack();
    } else if (widget.moving) {
      if (m.isFree && m.anim != 'Run' && m.anim != 'Walk') m.play('Walk');
    } else {
      if (m.isFree && m.anim != 'Idle') m.play('Idle');
    }
  }

  void _notifyDeathComplete() {
    final cb = widget.onDeathAnimationComplete;
    if (widget.alive || cb == null || _deathCompletionNotified) return;
    final m = _m3d;
    if (m == null) {
      _deathCompletionNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) cb(); });
      return;
    }
    // Death completion is handled in _onTick.
  }

  void _syncTicker() {
    if (widget.animationManagedExternally) {
      // battle layer manages animation controller ticks; we still need our own ticker for 3D
      _ticker ??= createTicker(_onTick);
      if (!_ticker!.isActive) { _lastElapsed = Duration.zero; _ticker!.start(); }
      return;
    }
    _ticker ??= createTicker(_onTick);
    if (!_ticker!.isActive) { _lastElapsed = Duration.zero; _ticker!.start(); }
  }

  double _deathElapsed = 0;
  bool _wasDead = false;
  double _roarCd = 3.0;

  void _onTick(Duration elapsed) {
    final rawDt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    final dt = rawDt.clamp(0.0, 0.05).toDouble();
    _lastElapsed = elapsed;

    widget.animation.synchronize(
      alive: widget.alive,
      moving: widget.moving,
      attacking: widget.attacking,
    );
    if (!widget.animationManagedExternally) {
      final controllerDt = rawDt.clamp(0.0, 5.0);
      widget.animation.advance(Duration(microseconds: (controllerDt * 1e6).round()));
    }

    final m = _m3d;
    if (m != null && m.isReady) {
      if (!widget.alive) {
        if (!_wasDead) { _wasDead = true; _deathElapsed = 0; }
        _deathElapsed += dt;
        if (!m.isDead) m.takeHit(m.hp + 1);
        m.update(dt);
      } else {
        _wasDead = false;
        _deathElapsed = 0;
        final moving = widget.moving;
        final attacking = widget.attacking;
        _roarCd -= dt;
        final wantRoar = !moving && !attacking && _roarCd <= 0 && m.isFree;
        if (wantRoar) { m.triggerRoar(); _roarCd = 5.0 + (m.id.hashCode % 4); }
        final speed = m.height * (m.id == 'werewolf' || m.id == 'blind-stalker' ? 1.6 : (m.id == 'stone-golem' ? 0.8 : 1.0));
        m.update(dt,
          moveDir: moving ? m.aim : null,
          moveSpeed: moving ? speed : 0,
          attacking: attacking,
          roaring: false,
        );
      }
    }

    if (!widget.alive && !_deathCompletionNotified) {
      final controllerDone = widget.animation.state == MonsterAnimationState.death
          ? widget.animation.isAnimationFinished
          : _deathElapsed > 2.3;
      final modelDone = m == null ? true : (m.isDead && _deathElapsed > 2.3);
      if (controllerDone || modelDone) {
        _deathCompletionNotified = true;
        widget.onDeathAnimationComplete?.call();
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _m3d?.dispose();
    super.dispose();
  }

  Widget _buildHealthBar(double health) {
    final fraction = health.isFinite ? health.clamp(0.0, 1.0).toDouble() : 0.0;
    return SizedBox(
      width: widget.size * 0.78,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(children: [
          const Positioned.fill(child: ColoredBox(color: Color.fromARGB(140, 0, 0, 0))),
          FractionallySizedBox(
            key: const ValueKey('monster-health-fill'),
            widthFactor: fraction,
            child: ColoredBox(color: widget.healthColor ?? const Color(0xFFB2FF59)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _m3d;
    // track death elapsed
    if (!widget.alive && !_wasDead) { _wasDead = true; _deathElapsed = 0; }
    if (_wasDead && !widget.alive) { /* incremented in tick via setState; approximate */ }

    final sprite = SizedBox(
      width: widget.size,
      height: widget.size,
      child: m != null && m.isReady
          ? CustomPaint(painter: _Monster3DPainter(m, widget.size))
          : const SizedBox.shrink(),
    );

    final health = widget.healthFraction;
    if (health == null) return sprite;
    return SizedBox(
      width: widget.size,
      height: widget.size + 7,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildHealthBar(health),
        const SizedBox(height: 3),
        sprite,
      ]),
    );
  }
}

class _Monster3DPainter extends CustomPainter {
  _Monster3DPainter(this.m, this.size);
  final Monster3D m;
  final double size;
  @override
  void paint(Canvas canvas, Size s) {
    m.position = Offset(s.width * 0.5, s.height * 0.88);
    m.height = size * 0.85;
    m.paint(canvas);
  }
  @override
  bool shouldRepaint(covariant _Monster3DPainter old) => true;
}
