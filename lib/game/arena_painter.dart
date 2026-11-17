import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../hero/hero_assets.dart';
import 'combat/hero_kit.dart';
import 'render3/hero3d_controller.dart';
import 'world/game_world.dart';

/// One transient screen-space label ("+10 XP", "Level Up!", …).
class FloatLabel {
  FloatLabel({
    required this.text,
    required this.worldPosition,
    required this.bornAtMs,
    this.color = const Color(0xFFEAF7DF),
  });

  final String text;
  final Offset worldPosition;
  final int bornAtMs;
  final Color color;

  static const lifetimeMs = 1100;
}

/// Everything the arena painter needs besides the world itself.
class ArenaPresentation {
  ArenaPresentation({
    required this.kit,
    required this.theme,
    required this.sheet,
    required this.frameId,
    required this.pivotX,
    required this.pivotY,
    required this.frameWidth,
    required this.frameHeight,
    required this.labels,
    required this.timeMs,
    required this.comboText,
    this.hero3d,
  });

  final HeroKit kit;
  final ThemeData theme;
  final AtlasSheet? sheet;
  final String? frameId;
  final double pivotX;
  final double pivotY;
  final int frameWidth;
  final int frameHeight;
  final List<FloatLabel> labels;
  final int timeMs;

  /// e.g. "الضربة 3/5 · 120%"
  final String? comboText;

  /// The in-game 3D hero; when non-null the hero is drawn as the real skinned
  /// model instead of the atlas frame (enemies keep their sprites).
  final Hero3DController? hero3d;

  Color get accent => Color(kit.accentColor);
}

/// Draws the whole battle arena: ground, hero sprite, enemies, projectiles,
/// AoE telegraphs and transient labels. The painter scales the logical arena
/// (`arenaWidth × arenaHeight`) to fit the widget, letterboxed.
class ArenaPainter extends CustomPainter {
  ArenaPainter({required this.world, required this.presentation});

  final GameWorld world;
  final ArenaPresentation presentation;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / arenaWidth,
      size.height / arenaHeight,
    );
    final viewWidth = arenaWidth * scale;
    final viewHeight = arenaHeight * scale;
    final origin = Offset(
      (size.width - viewWidth) / 2,
      (size.height - viewHeight) / 2,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _paintBackdrop(canvas, origin, viewWidth, viewHeight);

    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    _paintZones(canvas);
    _paintFireWaves(canvas);
    _paintGroundShadows(canvas);
    _paintEnemies(canvas);
    _paintProjectiles(canvas);
    _paintFx(canvas);
    _paintHero(canvas);
    _paintLabels(canvas, scale);

    canvas.restore();
  }

  // ---- Backdrop ---------------------------------------------------------------

  void _paintBackdrop(
    Canvas canvas,
    Offset origin,
    double width,
    double height,
  ) {
    final rect = origin & Size(width, height);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        const [Color(0xFF14301C), Color(0xFF0B1A10), Color(0xFF07110A)],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(rect, paint);
    // Ground grid.
    final grid = Paint()
      ..color = presentation.accent.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    const spacing = 60.0;
    for (var x = 0.0; x <= arenaWidth; x += spacing) {
      canvas.drawLine(
        origin + Offset(x * (width / arenaWidth), 0),
        origin + Offset(x * (width / arenaWidth), height),
        grid,
      );
    }
    for (var y = 0.0; y <= arenaHeight; y += spacing) {
      canvas.drawLine(
        origin + Offset(0, y * (height / arenaHeight)),
        origin + Offset(width, y * (height / arenaHeight)),
        grid,
      );
    }
  }

  // ---- Entities -----------------------------------------------------------------

  /// Traveling fire waves: a glowing crescent band across the ground.
  void _paintFireWaves(Canvas canvas) {
    for (final wave in world.waves) {
      final velocity = wave.velocity;
      final dir = velocity / velocity.distance;
      final perpendicular = Offset(-dir.dy, dir.dx);
      final center = wave.position;
      final halfWidth = wave.halfWidth;
      final paint = Paint()
        ..color = const Color(0x55FF7A33)
        ..style = PaintingStyle.fill;
      final path = ui.Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx - dir.dx * 26 + perpendicular.dx * halfWidth,
          center.dy - dir.dy * 26 + perpendicular.dy * halfWidth,
        )
        ..lineTo(
          center.dx + dir.dx * 34 + perpendicular.dx * halfWidth,
          center.dy + dir.dy * 34 + perpendicular.dy * halfWidth,
        )
        ..lineTo(
          center.dx + dir.dx * 34 - perpendicular.dx * halfWidth,
          center.dy + dir.dy * 34 - perpendicular.dy * halfWidth,
        )
        ..lineTo(
          center.dx - dir.dx * 26 - perpendicular.dx * halfWidth,
          center.dy - dir.dy * 26 - perpendicular.dy * halfWidth,
        )
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFF7A33)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      // Inner hot core.
      canvas.drawPath(
        ui.Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + dir.dx * 24 + perpendicular.dx * halfWidth * 0.55,
            center.dy + dir.dy * 24 + perpendicular.dy * halfWidth * 0.55,
          )
          ..lineTo(
            center.dx + dir.dx * 24 - perpendicular.dx * halfWidth * 0.55,
            center.dy + dir.dy * 24 - perpendicular.dy * halfWidth * 0.55,
          )
          ..close(),
        Paint()..color = const Color(0x99FFD9A8),
      );
    }
  }

  /// Transient swing arcs and burst rings emitted by the world.
  void _paintFx(Canvas canvas) {
    for (final effect in world.fx) {
      final age = (world.nowMs - effect.bornAtMs) / GameFx.lifetimeMs;
      if (age > 1) continue;
      final t = age.clamp(0.0, 1.0);
      final color = Color(effect.color).withValues(alpha: 1 - t);
      if (effect.kind == 'slash') {
        final radius = effect.radius * (0.7 + 0.3 * t);
        canvas.drawArc(
          Rect.fromCircle(
            center: effect.position - const Offset(0, 10),
            radius: radius,
          ),
          _angleOf(effect.facing) - 1.15,
          2.3,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7 * (1 - t * 0.5)
            ..strokeCap = StrokeCap.round,
        );
      } else if (effect.kind == 'burst') {
        final radius = effect.radius * (0.35 + 0.65 * t);
        canvas.drawCircle(
          effect.position,
          radius,
          Paint()..color = Color(effect.color).withValues(alpha: 0.28 * (1 - t)),
        );
        canvas.drawCircle(
          effect.position,
          radius,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * (1 - t),
        );
      }
    }
  }

  void _paintGroundShadows(Canvas canvas) {
    final shadow = Paint()..color = const Color(0x66000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: world.player.position + const Offset(0, 30),
        width: 52,
        height: 16,
      ),
      shadow,
    );
    for (final enemy in world.enemies) {
      canvas.drawOval(
        Rect.fromCenter(
          center: enemy.position + const Offset(0, 22),
          width: _enemySize(enemy) * 0.8,
          height: _enemySize(enemy) * 0.26,
        ),
        shadow,
      );
    }
  }

  double _enemySize(EnemyState enemy) {
    switch (enemy.kind) {
      case 'brute':
        return 46;
      case 'archer':
        return 32;
      default:
        return 34;
    }
  }

  void _paintZones(Canvas canvas) {
    for (final zone in world.zones) {
      final phase = zone.ticksLeft / 8;
      final paint = Paint()
        ..color = presentation.accent.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(zone.center, zone.radius, paint);
      canvas.drawCircle(
        zone.center,
        zone.radius,
        Paint()
          ..color = Color.lerp(
            presentation.accent,
            presentation.accent.withValues(alpha: 0),
            1 - phase,
          )!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      // Falling arrow hints.
      final random = math.Random(zone.center.dx.round() * 7 + 3);
      for (var i = 0; i < 6; i++) {
        final hint = zone.center +
            Offset(
              (random.nextDouble() - 0.5) * zone.radius * 1.4,
              (random.nextDouble() - 0.5) * zone.radius * 1.4,
            );
        canvas.drawLine(
          hint - const Offset(0, 46),
          hint - const Offset(0, 30),
          Paint()
            ..color = const Color(0xAA9BE845)
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  void _paintEnemies(Canvas canvas) {
    for (final enemy in world.enemies) {
      final size = _enemySize(enemy);
      final flashing = world.nowMs < enemy.hitFlashUntilMs;
      final baseColor = switch (enemy.kind) {
        'brute' => const Color(0xFFC2472E),
        'archer' => const Color(0xFFE88A3C),
        _ => const Color(0xFFE05A48),
      };
      final color = flashing ? Colors.white : baseColor;
      final paint = Paint()..color = color;

      if (enemy.kind == 'slime') {
        final wobble = math.sin(world.nowMs / 120 + enemy.id.hashCode) * 2;
        final rect = Rect.fromCenter(
          center: enemy.position - Offset(0, 6 + wobble),
          width: size,
          height: size * 0.85,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(14)),
          paint,
        );
        _paintEyes(canvas, enemy.position - Offset(0, 10), dark: true);
      } else if (enemy.kind == 'archer') {
        final rect = Rect.fromCenter(
          center: enemy.position - Offset(0, 10),
          width: size * 0.7,
          height: size * 1.05,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          paint,
        );
        // Bow arc facing the player.
        canvas.drawArc(
          Rect.fromCenter(
            center: enemy.position - Offset(0, 12),
            width: 26,
            height: 26,
          ),
          -math.pi / 2 - 0.8,
          1.6,
          false,
          Paint()
            ..color = const Color(0xFFFFD9A8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      } else {
        final rect = Rect.fromCenter(
          center: enemy.position - Offset(0, 12),
          width: size,
          height: size * 1.15,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          paint,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: enemy.position - Offset(0, 12) + Offset(0, 6),
            width: size * 0.3,
            height: size * 0.55,
          ),
          Paint()..color = const Color(0x33000000),
        );
      }

      // Burning indicator: small flames over a burning enemy.
      if (enemy.burnTicksLeft > 0) {
        final flicker = math.sin(world.nowMs / 90 + enemy.id.hashCode) * 2;
        final base = enemy.position - Offset(0, 26 + size * 0.5);
        final flame = Paint()..color = const Color(0xFFFF7A33);
        canvas.drawCircle(base + Offset(-5, flicker * 0.4), 3.5, flame);
        canvas.drawCircle(base + Offset(5, -flicker * 0.4), 3.0, flame);
        canvas.drawCircle(
          base + const Offset(0, -4),
          2.4,
          Paint()..color = const Color(0xFFFFD9A8),
        );
      }

      // HP bar, shown once the enemy is damaged.
      if (enemy.hp < enemy.maxHp) {
        final barWidth = size + 8;
        final ratio = (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
        final barTop = enemy.position - Offset(0, 28 + size * 0.5);
        canvas.drawRect(
          Rect.fromLTWH(
            enemy.position.dx - barWidth / 2,
            barTop.dy,
            barWidth,
            4.5,
          ),
          Paint()..color = const Color(0x88000000),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            enemy.position.dx - barWidth / 2,
            barTop.dy,
            barWidth * ratio,
            4.5,
          ),
          Paint()..color = const Color(0xFFFF5A4A),
        );
      }
    }
  }

  void _paintEyes(Canvas canvas, Offset center, {required bool dark}) {
    final eye = Paint()..color = dark ? const Color(0xFF25301F) : Colors.white;
    canvas.drawCircle(center - const Offset(5, 0), 2.6, eye);
    canvas.drawCircle(center + const Offset(5, 0), 2.6, eye);
  }

  void _paintProjectiles(Canvas canvas) {
    for (final projectile in world.projectiles) {
      final dir = projectile.velocity / projectile.velocity.distance;
      final perpendicular = Offset(-dir.dy, dir.dx);
      final length = projectile.big ? 30.0 : 22.0;
      final tail = projectile.position - dir * length;
      final glow = Paint()
        ..color = Color(projectile.tint).withValues(alpha: 0.35)
        ..strokeWidth = projectile.big ? 9 : 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, projectile.position, glow);
      final core = Paint()
        ..color = Color(projectile.tint)
        ..strokeWidth = projectile.big ? 4.5 : 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, projectile.position, core);
      // Arrow head.
      final head = Paint()..color = Color(projectile.tint);
      final tip = projectile.position + dir * 5;
      final path = ui.Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tail.dx + perpendicular.dx * 3.5,
          tail.dy + perpendicular.dy * 3.5,
        )
        ..lineTo(
          tail.dx - perpendicular.dx * 3.5,
          tail.dy - perpendicular.dy * 3.5,
        )
        ..close();
      canvas.drawPath(path, head);
      // Motion trail.
      final trail = Paint()
        ..color = Color(projectile.tint).withValues(alpha: 0.18)
        ..strokeWidth = projectile.big ? 5 : 3.5;
      canvas.drawLine(
        tail - dir * 16,
        tail,
        trail,
      );
    }
  }

  void _paintHero(Canvas canvas) {
    final player = world.player;

    // In-game 3D hero: draw the real skinned model (bones + animation),
    // anchored at the gameplay position like the sprite was.
    final hero3d = presentation.hero3d;
    if (hero3d != null) {
      // Invulnerability ring while dodging.
      if (player.invulnerableUntilMs > world.nowMs && !player.dead) {
        canvas.drawCircle(
          player.position - const Offset(0, 14),
          34,
          Paint()
            ..color = const Color(0x33FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      final veilActive = player.speedBoostUntilMs > world.nowMs;
      hero3d.paint(
        canvas,
        anchor: player.position + const Offset(0, 14),
        facing: player.facing,
        scale: hero3d.scaleForPixelHeight(122),
        alpha: veilActive ? 0.55 : 1,
        tint: player.dead ? const Color(0xFF888888) : null,
      );
      return;
    }

    final image = presentation.sheet?.image;
    final frameId = presentation.frameId;
    final rect =
        image == null || frameId == null ? null : presentation.sheet!.rectFor(frameId);

    // Invulnerability ring while dodging.
    if (player.invulnerableUntilMs > world.nowMs && !player.dead) {
      canvas.drawCircle(
        player.position - const Offset(0, 14),
        34,
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    if (image == null || rect == null) {
      // Placeholder while the atlas decodes.
      canvas.drawCircle(
        player.position,
        18,
        Paint()..color = presentation.accent.withValues(alpha: 0.2),
      );
      return;
    }

    const drawHeight = 116.0;
    final drawWidth = drawHeight *
        presentation.frameWidth /
        presentation.frameHeight;
    final anchor = player.position;
    final dst = Rect.fromLTWH(
      anchor.dx - drawWidth * presentation.pivotX,
      anchor.dy - drawHeight * presentation.pivotY,
      drawWidth,
      drawHeight,
    );
    canvas.drawImageRect(
      image,
      rect,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = player.dead
            ? const Color(0xFF888888)
            // Shadow's veil: the hero renders translucent while hidden.
            : Color.fromRGBO(
                255,
                255,
                255,
                world.player.speedBoostUntilMs > world.nowMs ? 0.55 : 1,
              ),
    );
  }

  void _paintLabels(Canvas canvas, double scale) {
    for (final label in presentation.labels) {
      final age = presentation.timeMs - label.bornAtMs;
      if (age > FloatLabel.lifetimeMs) continue;
      final t = age / FloatLabel.lifetimeMs;
      final opacity = (1 - t).clamp(0.0, 1.0);
      final position = label.worldPosition - Offset(0, 26 + t * 30);
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontSize: 15 / scale * scale, // world-space text, keep 15px
          fontFamily: 'Roboto',
        ),
      )
        ..pushStyle(
          ui.TextStyle(
            color: label.color.withValues(alpha: opacity),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        )
        ..addText(label.text);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: 160));
      canvas.drawParagraph(
        paragraph,
        position - const Offset(80, 0),
      );
    }
  }

  static double _angleOf(Offset v) => math.atan2(v.dy, v.dx);

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
