import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../hero/hero_assets.dart';
import 'combat/hero_kit.dart';
import 'monsters/monster_models.dart';
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
    _paintMonsters(canvas);
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
      } else if (effect.kind == 'bolt') {
        // Lightning arc: a jagged line from the source toward [facing]
        // spanning [radius] units, flickering out over the lifetime.
        final dir = effect.facing;
        final len = dir.distance;
        if (len > 1) {
          final unit = dir / len;
          final normal = Offset(-unit.dy, unit.dx);
          final path = Path()..moveTo(effect.position.dx, effect.position.dy);
          const joints = 6;
          for (var j = 1; j <= joints; j++) {
            final along = effect.radius * j / joints;
            final jag = (j == joints ? 0.0 : (j.isOdd ? 1.0 : -1.0) * 7);
            final p = effect.position + unit * along + normal * jag;
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5 * (1 - t * 0.5)
              ..strokeCap = StrokeCap.round,
          );
        }
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
    for (final monster in [...world.enemies, ...world.army]) {
      if (monster.hp <= 0) continue;
      final size = monster.radius * 2.6;
      canvas.drawOval(
        Rect.fromCenter(
          center: monster.position + Offset(0, monster.radius * 1.35),
          width: size * 0.9,
          height: size * 0.28,
        ),
        shadow,
      );
    }
  }

  /// Draws corpses, then both armies sorted by depth so lower monsters
  /// overlap higher ones naturally.
  void _paintMonsters(Canvas canvas) {
    for (final corpse in world.corpses) {
      _paintCorpse(canvas, corpse);
    }
    final monsters = [...world.enemies, ...world.army]
      ..sort((a, b) => a.position.dy.compareTo(b.position.dy));
    for (final monster in monsters) {
      if (monster.hp <= 0) continue;
      _paintMonster(canvas, monster);
    }
  }

  void _paintMonster(Canvas canvas, EnemyState monster) {
    final def = MonsterCatalog.def(monster.type);
    final now = world.nowMs;
    final anim = monster.animStateAt(now);
    final flashing = now < monster.hitFlashUntilMs;
    final ally = monster.team == MonsterTeam.player;
    final bodyColor = flashing ? Colors.white : Color(def.color);
    final accent = flashing ? Colors.white : Color(def.accent);
    final dark = Color.lerp(bodyColor, Colors.black, 0.35)!;
    final size = monster.radius * 2.35;
    final face = monster.facing.dx < -0.08 ? -1.0 : 1.0;

    final walking = anim == MonsterAnimState.walk;
    final phase = monster.walkPhase;
    final bob =
        walking ? math.sin(phase * 2).abs() * 1.5 : math.sin(now / 520 + monster.id.hashCode) * 0.7;
    final swing = walking ? math.sin(phase) * 0.62 : 0.10;
    final attackT = anim == MonsterAnimState.attack
        ? (1 - ((monster.attackAnimUntilMs - now) / 320).clamp(0.0, 1.0))
        : 0.0;
    final lunge = math.sin(attackT * math.pi) * size * 0.34;

    canvas.save();
    // Origin at the feet; all body parts are negative-Y.
    canvas.translate(
      monster.position.dx + face * lunge,
      monster.position.dy + monster.radius * 0.95 - bob * 0.35,
    );
    canvas.scale(face, 1);

    // Team ring under the feet.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0),
        width: size * 0.95,
        height: size * 0.3,
      ),
      Paint()
        ..color = (ally ? const Color(0xFF7CFF9B) : const Color(0xFFFF6A5A))
            .withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    final legColor = Color.lerp(bodyColor, Colors.black, 0.22)!;
    final hipY = -size * 0.44;
    _monsterLimb(
      canvas,
      Offset(-size * 0.16, hipY),
      -swing,
      size * 0.46,
      size * 0.15,
      legColor,
    );
    _monsterLimb(
      canvas,
      Offset(size * 0.16, hipY),
      swing,
      size * 0.46,
      size * 0.15,
      legColor,
    );

    // Back arm (swings opposite the legs).
    _monsterLimb(
      canvas,
      Offset(-size * 0.26, -size * 0.72),
      -swing * 0.8 + 0.25,
      size * 0.34,
      size * 0.12,
      dark,
    );

    switch (monster.type) {
      case MonsterType.tank:
        _paintTankBody(canvas, size, bodyColor, dark, accent);
      case MonsterType.runner:
        _paintRunnerBody(canvas, size, bodyColor, dark, accent);
      case MonsterType.stalker:
        _paintStalkerBody(canvas, size, bodyColor, dark, accent);
      case MonsterType.ranged:
        _paintRangedBody(canvas, size, bodyColor, dark, accent);
    }

    // Front arm + weapon. It drives the attack lunge.
    final armSwing = attackT > 0
        ? -0.9 + math.sin(attackT * math.pi) * 1.5
        : swing * 0.9;
    _monsterLimb(
      canvas,
      Offset(size * 0.26, -size * 0.72),
      armSwing,
      size * 0.36,
      size * 0.12,
      accent,
    );
    _paintMonsterWeapon(canvas, monster, size, accent, attackT);

    // Hit spark.
    if (flashing) {
      canvas.drawCircle(
        Offset(0, -size * 0.6),
        size * 0.5,
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
    }

    canvas.restore();

    // Burning indicator (hostile monsters only; Flame's DoT).
    if (monster.burnTicksLeft > 0) {
      final flicker = math.sin(now / 90 + monster.id.hashCode) * 2;
      final base = monster.position - Offset(0, size * 1.15);
      final flame = Paint()..color = const Color(0xFFFF7A33);
      canvas.drawCircle(base + Offset(-5, flicker * 0.4), 3.5, flame);
      canvas.drawCircle(base + Offset(5, -flicker * 0.4), 3.0, flame);
      canvas.drawCircle(
        base + const Offset(0, -4),
        2.4,
        Paint()..color = const Color(0xFFFFD9A8),
      );
    }

    _paintMonsterBar(
      canvas,
      monster,
      ally ? const Color(0xFF7CFF9B) : const Color(0xFFFF6A5A),
      topY: monster.position.dy - size * 1.42,
      width: size * 1.25,
    );
  }

  void _monsterLimb(
    Canvas canvas,
    Offset joint,
    double angle,
    double length,
    double width,
    Color color,
  ) {
    canvas.save();
    canvas.translate(joint.dx, joint.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2, 0, width, length),
        Radius.circular(width / 2),
      ),
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(0, length),
      width * 0.62,
      Paint()..color = Color.lerp(color, Colors.black, 0.18)!,
    );
    canvas.restore();
  }

  void _paintTankBody(
    Canvas canvas,
    double size,
    Color body,
    Color dark,
    Color accent,
  ) {
    final rect = Rect.fromLTWH(-size * 0.44, -size * 0.86, size * 0.88, size * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.16)),
      Paint()..color = body,
    );
    // Shoulder plates.
    canvas.drawCircle(
      Offset(-size * 0.36, -size * 0.76),
      size * 0.17,
      Paint()..color = accent,
    );
    canvas.drawCircle(
      Offset(size * 0.36, -size * 0.76),
      size * 0.17,
      Paint()..color = accent,
    );
    // Belt.
    canvas.drawRect(
      Rect.fromLTWH(-size * 0.4, -size * 0.5, size * 0.8, size * 0.08),
      Paint()..color = dark,
    );
    _monsterHead(canvas, size, body, dark, accent, horned: true);
  }

  void _paintRunnerBody(
    Canvas canvas,
    double size,
    Color body,
    Color dark,
    Color accent,
  ) {
    final rect = Rect.fromLTWH(-size * 0.3, -size * 0.88, size * 0.6, size * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.2)),
      Paint()..color = body,
    );
    // Scarf trailing behind the run direction.
    final scarf = Path()
      ..moveTo(-size * 0.22, -size * 0.74)
      ..lineTo(-size * 0.62, -size * 0.58)
      ..lineTo(-size * 0.2, -size * 0.58)
      ..close();
    canvas.drawPath(scarf, Paint()..color = accent);
    _monsterHead(canvas, size, body, dark, accent, earred: true);
  }

  void _paintStalkerBody(
    Canvas canvas,
    double size,
    Color body,
    Color dark,
    Color accent,
  ) {
    // Hooded cloak: wide at the hem, narrow at the shoulders.
    final cloak = Path()
      ..moveTo(-size * 0.3, -size * 0.82)
      ..lineTo(size * 0.3, -size * 0.82)
      ..lineTo(size * 0.46, -size * 0.06)
      ..lineTo(-size * 0.46, -size * 0.06)
      ..close();
    canvas.drawPath(cloak, Paint()..color = body);
    canvas.drawPath(
      Path()
        ..moveTo(-size * 0.3, -size * 0.82)
        ..lineTo(0, -size * 0.8)
        ..lineTo(-size * 0.46, -size * 0.06)
        ..close(),
      Paint()..color = dark,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, -size * 0.86),
        width: size * 0.52,
        height: size * 0.5,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = accent,
    );
    _monsterHead(canvas, size, body, dark, accent, hooded: true);
  }

  void _paintRangedBody(
    Canvas canvas,
    double size,
    Color body,
    Color dark,
    Color accent,
  ) {
    final rect = Rect.fromLTWH(-size * 0.34, -size * 0.86, size * 0.68, size * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.14)),
      Paint()..color = body,
    );
    canvas.drawRect(
      Rect.fromLTWH(-size * 0.05, -size * 0.86, size * 0.1, size * 0.5),
      Paint()..color = accent,
    );
    _monsterHead(canvas, size, body, dark, accent, hooded: true);
  }

  void _monsterHead(
    Canvas canvas,
    double size,
    Color body,
    Color dark,
    Color accent, {
    bool horned = false,
    bool earred = false,
    bool hooded = false,
  }) {
    final center = Offset(0, -size * 1.0);
    final radius = size * 0.23;
    canvas.drawCircle(center, radius, Paint()..color = body);
    if (hooded) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 1.18),
        math.pi,
        math.pi,
        true,
        Paint()..color = dark,
      );
    }
    if (horned) {
      for (final sign in const [-1.0, 1.0]) {
        final horn = Path()
          ..moveTo(center.dx + sign * radius * 0.7, center.dy - radius * 0.6)
          ..lineTo(center.dx + sign * radius * 1.35, center.dy - radius * 1.5)
          ..lineTo(center.dx + sign * radius * 0.35, center.dy - radius * 0.85)
          ..close();
        canvas.drawPath(horn, Paint()..color = accent);
      }
    }
    if (earred) {
      for (final sign in const [-1.0, 1.0]) {
        final ear = Path()
          ..moveTo(center.dx + sign * radius * 0.55, center.dy - radius * 0.55)
          ..lineTo(center.dx + sign * radius * 1.15, center.dy - radius * 1.3)
          ..lineTo(center.dx + sign * radius * 0.2, center.dy - radius * 0.75)
          ..close();
        canvas.drawPath(ear, Paint()..color = dark);
      }
    }
    // Eyes: two highlights, always looking forward.
    canvas.drawCircle(
      center + Offset(radius * 0.34, -radius * 0.06),
      radius * 0.16,
      Paint()..color = const Color(0xFFFFF4D8),
    );
    canvas.drawCircle(
      center + Offset(radius * 0.72, -radius * 0.02),
      radius * 0.1,
      Paint()..color = const Color(0xFFFFF4D8),
    );
  }

  void _paintMonsterWeapon(
    Canvas canvas,
    EnemyState monster,
    double size,
    Color accent,
    double attackT,
  ) {
    final hand = Offset(size * 0.28, size * 0.12);
    switch (monster.type) {
      case MonsterType.tank:
        canvas.drawCircle(hand, size * 0.17, Paint()..color = accent);
        canvas.drawCircle(
          hand + Offset(0, -size * 0.02),
          size * 0.1,
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );
      case MonsterType.runner:
        canvas.drawLine(
          hand,
          hand + Offset(size * 0.42, -size * 0.28),
          Paint()
            ..color = accent
            ..strokeWidth = size * 0.08
            ..strokeCap = StrokeCap.round,
        );
      case MonsterType.stalker:
        canvas.drawLine(
          hand,
          hand + Offset(size * 0.36, -size * 0.24),
          Paint()
            ..color = accent
            ..strokeWidth = size * 0.06
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(-hand.dx, hand.dy),
          Offset(-hand.dx - size * 0.36, hand.dy - size * 0.24),
          Paint()
            ..color = accent.withValues(alpha: 0.7)
            ..strokeWidth = size * 0.06
            ..strokeCap = StrokeCap.round,
        );
      case MonsterType.ranged:
        // Staff with a fire orb that flares while attacking.
        canvas.drawLine(
          Offset(size * 0.2, -size * 0.2),
          Offset(size * 0.52, -size * 1.0),
          Paint()
            ..color = accent
            ..strokeWidth = size * 0.06
            ..strokeCap = StrokeCap.round,
        );
        final flare = 0.5 + attackT * 0.8;
        canvas.drawCircle(
          Offset(size * 0.52, -size * 1.0),
          size * 0.12 * flare,
          Paint()..color = const Color(0xFFFF8A3C).withValues(alpha: 0.8),
        );
        canvas.drawCircle(
          Offset(size * 0.52, -size * 1.0),
          size * 0.06 * flare,
          Paint()..color = const Color(0xFFFFE0A8),
        );
    }
  }

  void _paintMonsterBar(
    Canvas canvas,
    EnemyState monster,
    Color color, {
    required double topY,
    required double width,
  }) {
    final ratio = monster.hpRatio;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(monster.position.dx - width / 2, topY, width, 4.5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xAA000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          monster.position.dx - width / 2,
          topY,
          width * ratio,
          4.5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
  }

  void _paintCorpse(Canvas canvas, MonsterCorpse corpse) {
    final def = MonsterCatalog.def(corpse.type);
    final progress = corpse.progressAt(world.nowMs);
    final alpha = (1 - progress).clamp(0.0, 1.0);
    final size = def.radius * 2.35;
    final face = corpse.facing.dx < -0.08 ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(corpse.position.dx, corpse.position.dy);
    canvas.scale(face, 1);
    canvas.rotate(progress * math.pi * 0.42);
    final paint = Paint()
      ..color = Color(def.color).withValues(alpha: alpha * 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-size * 0.42, -size * 0.4, size * 0.84, size * 0.36),
        Radius.circular(size * 0.16),
      ),
      paint,
    );
    canvas.drawCircle(
      Offset(size * 0.36, -size * 0.3),
      size * 0.18,
      Paint()
        ..color = Color(def.accent).withValues(alpha: alpha * 0.8),
    );
    canvas.restore();
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
