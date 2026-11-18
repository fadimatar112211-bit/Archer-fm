import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../hero/hero_assets.dart';
import 'combat/hero_kit.dart';
import 'monsters/monster_models.dart';
import 'render3/hero3d_controller.dart';
import 'world/arena_map.dart';
import 'world/castle_system.dart';
import 'world/game_world.dart';
import 'world/mine_system.dart';

/// Top-left corner of the camera window in map coordinates, centered on the
/// hero and clamped to the map edges. Shared by the painter and tap input so a
/// tap maps back to the same world point the player sees.
Offset arenaCameraOrigin(GameWorld world) {
  final map = world.map;
  final maxX = math.max(0.0, map.size.width - arenaWidth);
  final maxY = math.max(0.0, map.size.height - arenaHeight);
  return Offset(
    (world.player.position.dx - arenaWidth / 2).clamp(0.0, maxX).toDouble(),
    (world.player.position.dy - arenaHeight / 2).clamp(0.0, maxY).toDouble(),
  );
}

/// Converts a tap inside the arena widget to map coordinates. Uses the
/// instant (unclamped-by-smoothing) camera origin so taps map back to the
/// exact world point under the tap, matching what the renderer draws.
Offset arenaToWorld(Offset local, Size size, GameWorld world) {
  final scale = math.min(
    size.width / arenaWidth,
    size.height / arenaHeight,
  );
  final origin = Offset(
    (size.width - arenaWidth * scale) / 2,
    (size.height - arenaHeight * scale) / 2,
  );
  return (local - origin) / scale + arenaCameraOrigin(world);
}

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
    final camera = _cameraOrigin();
    canvas.translate(-camera.dx, -camera.dy);

    _paintTerrain(canvas);
    _paintZones(canvas);
    _paintFireWaves(canvas);
    _paintGroundShadows(canvas);
    _paintMonsters(canvas);
    _paintProjectiles(canvas);
    _paintFx(canvas);
    _paintFog(canvas, camera);
    _paintHero(canvas);
    _paintLabels(canvas, scale);

    canvas.restore();
  }

  Offset _cameraOrigin() => world.cameraOrigin;

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
    // Map border glow.
    canvas.drawRect(
      rect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = presentation.accent.withValues(alpha: 0.25),
    );
  }

  // ---- Terrain ----------------------------------------------------------------

  static const Color _groundColor = Color(0xFF365231);
  static const Color _waterColor = Color(0xFF2E6E8E);
  static const Color _waterDeepColor = Color(0xFF22566F);
  static const Color _treeColor = Color(0xFF1F4A2B);
  static const Color _treeLightColor = Color(0xFF2C6236);
  static const Color _trunkColor = Color(0xFF4A3220);
  static const Color _rockColor = Color(0xFF6E7376);
  static const Color _rockLightColor = Color(0xFF8C9194);
  static const Color _bridgeColor = Color(0xFF7A5430);
  static const Color _bridgePlankColor = Color(0xFF5C3E24);
  static const Color _goldColor = Color(0xFFFFC845);
  static const Color _chestColor = Color(0xFF8A5A2B);

  Color _biomeColor(TerrainKind kind) => switch (kind) {
        TerrainKind.forest => const Color(0xFF2E5A33),
        TerrainKind.desert => const Color(0xFFB08A55),
        TerrainKind.snow => const Color(0xFFD9E8F2),
        TerrainKind.volcanic => const Color(0xFF6B3A34),
      };

  void _paintTerrain(Canvas canvas) {
    final map = world.map;
    // Base ground.
    canvas.drawRect(Offset.zero & map.size, Paint()..color = _groundColor);

    // Gentle grid so movement reads on the large map.
    final grid = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    const spacing = 120.0;
    for (var x = 0.0; x <= map.size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, map.size.height), grid);
    }
    for (var y = 0.0; y <= map.size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(map.size.width, y), grid);
    }

    // Biomes.
    for (final patch in map.biomes) {
      final color = _biomeColor(patch.kind);
      canvas.drawCircle(
        patch.center,
        patch.radius,
        Paint()
          ..shader = ui.Gradient.radial(
            patch.center,
            patch.radius,
            [color.withValues(alpha: 0.9), color.withValues(alpha: 0.0)],
            const [0.45, 1.0],
          ),
      );
    }

    // River banks, water and bridges.
    for (final river in map.rivers) {
      final path = Path()
        ..moveTo(river.points.first.dx, river.points.first.dy);
      for (final point in river.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = river.width + 18
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF24402C),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = river.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(
            river.points.first,
            river.points.last,
            const [_waterColor, _waterDeepColor, _waterColor],
            const [0.0, 0.5, 1.0],
          ),
      );
      // Moving highlights make the water read as water.
      final shimmer = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x66FFFFFF);
      final phase = (presentation.timeMs / 900) % 1.0;
      for (var i = 1; i < river.points.length - 1; i++) {
        final a = river.points[i];
        final b = river.points[i + 1];
        final t = phase.clamp(0.0, 1.0);
        final start = Offset(
          a.dx + (b.dx - a.dx) * t,
          a.dy + (b.dy - a.dy) * t,
        );
        canvas.drawLine(
          start - Offset(0, 12),
          start + Offset(0, 12),
          shimmer,
        );
      }
      for (final bridge in river.bridges) {
        final rect = bridge.rect;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(7)),
          Paint()..color = _bridgeColor,
        );
        final planks = Paint()
          ..color = _bridgePlankColor
          ..strokeWidth = 2;
        for (var x = rect.left + 8; x < rect.right; x += 12) {
          canvas.drawLine(
            Offset(x, rect.top + 4),
            Offset(x, rect.bottom - 4),
            planks,
          );
        }
      }
    }

    _paintMines(canvas);
    _paintCastles(canvas);

    // Pickups: mine output, loose resources and chests.
    for (final pickup in world.mineSystem.pickups) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          pickup.position + Offset((i - 1) * 8.0, i.isEven ? -3 : 3),
          5,
          Paint()..color = _goldColor,
        );
      }
    }
    for (final pickup in map.pickups) {
      if (pickup.kind == PickupKind.resource) {
        continue;
      } else {
        final rect = Rect.fromCenter(
          center: pickup.position,
          width: 24,
          height: 17,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = _chestColor,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: pickup.position + const Offset(0, -7),
            width: 26,
            height: 6,
          ),
          Paint()..color = const Color(0xFF5C3A1C),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: pickup.position,
            width: 5,
            height: 8,
          ),
          Paint()..color = _goldColor,
        );
      }
    }

    // Indestructible trees and rocks.
    for (final obstacle in map.obstacles) {
      if (obstacle.kind == ObstacleKind.tree) {
        canvas.drawOval(
          Rect.fromCenter(
            center: obstacle.position + const Offset(0, 8),
            width: obstacle.radius * 2.3,
            height: obstacle.radius * 0.9,
          ),
          Paint()..color = const Color(0x33000000),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: obstacle.position + Offset(0, obstacle.radius * 0.4),
            width: obstacle.radius * 0.45,
            height: obstacle.radius * 0.9,
          ),
          Paint()..color = _trunkColor,
        );
        canvas.drawCircle(
          obstacle.position - Offset(0, obstacle.radius * 0.35),
          obstacle.radius,
          Paint()..color = _treeColor,
        );
        canvas.drawCircle(
          obstacle.position - Offset(obstacle.radius * 0.35, obstacle.radius * 0.6),
          obstacle.radius * 0.55,
          Paint()..color = _treeLightColor,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: obstacle.position + const Offset(0, 7),
            width: obstacle.radius * 2.1,
            height: obstacle.radius * 0.8,
          ),
          Paint()..color = const Color(0x33000000),
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromCenter(
              center: obstacle.position,
              width: obstacle.radius * 1.9,
              height: obstacle.radius * 1.5,
            ),
            topLeft: Radius.circular(obstacle.radius * 0.5),
            topRight: Radius.circular(obstacle.radius * 0.7),
            bottomRight: Radius.circular(obstacle.radius * 0.4),
            bottomLeft: Radius.circular(obstacle.radius * 0.6),
          ),
          Paint()..color = _rockColor,
        );
        canvas.drawCircle(
          obstacle.position - Offset(obstacle.radius * 0.3, obstacle.radius * 0.25),
          obstacle.radius * 0.35,
          Paint()..color = _rockLightColor,
        );
      }
    }
  }

  void _paintMines(Canvas canvas) {
    for (final mine in world.mineSystem.mines) {
      final owned = mine.ownerId != null;
      final mineColor = !owned
          ? _rockColor
          : mine.owns(MineController.localPlayerId)
              ? const Color(0xFF5E8F35)
              : const Color(0xFF8E3F34);
      final ringColor = !owned
          ? const Color(0xFFB9C0C4)
          : mine.owns(MineController.localPlayerId)
              ? const Color(0xFF9BE845)
              : const Color(0xFFFF7A5A);

      // Sunken pit under the ore.
      canvas.drawOval(
        Rect.fromCenter(
          center: mine.position + const Offset(0, 6),
          width: mine.radius * 2.1,
          height: mine.radius * 1.1,
        ),
        Paint()..color = const Color(0x44000000),
      );
      canvas.drawCircle(
        mine.position,
        mine.radius,
        Paint()..color = mineColor.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        mine.position,
        mine.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = ringColor,
      );

      // Ore chunks: three gold crystals inside the pit.
      for (var i = 0; i < 3; i++) {
        final angle = -math.pi / 2 + i * (math.pi * 2 / 3);
        final offset = Offset(
          math.cos(angle) * mine.radius * 0.42,
          math.sin(angle) * mine.radius * 0.3,
        );
        final chunk = mine.position + offset;
        final size = mine.radius * 0.2;
        canvas.drawPath(
          Path()
            ..moveTo(chunk.dx, chunk.dy - size)
            ..lineTo(chunk.dx + size * 0.7, chunk.dy)
            ..lineTo(chunk.dx, chunk.dy + size)
            ..lineTo(chunk.dx - size * 0.7, chunk.dy)
            ..close(),
          Paint()..color = _goldColor,
        );
      }

      // Size pips: one, two or three marks along the bottom of the ring.
      final pips = switch (mine.size) {
        MineSize.small => 1,
        MineSize.medium => 2,
        MineSize.large => 3,
      };
      final pipPaint = Paint()..color = ringColor;
      for (var i = 0; i < pips; i++) {
        canvas.drawCircle(
          mine.position +
              Offset((i - (pips - 1) / 2) * 9, mine.radius * 0.62),
          2.6,
          pipPaint,
        );
      }

      // Capture progress ring for the player standing inside.
      if (mine.capturerId != null && mine.captureFraction > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: mine.position, radius: mine.radius + 7),
          -math.pi / 2,
          math.pi * 2 * mine.captureFraction,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..color = ringColor,
        );
      }
    }
  }

  void _paintCastles(Canvas canvas) {
    for (final castle in world.castleSystem.castles) {
      if (!castle.standing) continue; // A fallen castle disappears.
      final accent = castle.isLocal
          ? const Color(0xFF9BE845)
          : const Color(0xFFFF7A5A);
      final anchor = castle.anchor;

      // Courtyard.
      canvas.drawCircle(
        anchor,
        castleWallRadius + 36,
        Paint()..color = const Color(0x55304A33),
      );
      canvas.drawCircle(
        anchor,
        castleWallRadius + 30,
        Paint()..color = const Color(0xFF3C4B3E),
      );

      // Stone wall arcs with four gates (one per exposed crystal).
      for (final wall in castle.walls) {
        final rect = Rect.fromCircle(center: wall.center, radius: wall.radius);
        canvas.drawArc(
          rect,
          wall.startAngle,
          wall.sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF6E7376),
        );
        canvas.drawArc(
          rect,
          wall.startAngle,
          wall.sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF8C9194),
        );
        // Crenellations.
        final steps = math.max(2, (wall.sweep / 0.24).floor());
        for (var i = 0; i <= steps; i++) {
          final angle = wall.startAngle + wall.sweep * (i / steps);
          final point = wall.center +
              Offset(
                math.cos(angle) * (wall.radius + 9),
                math.sin(angle) * (wall.radius + 9),
              );
          canvas.drawCircle(
            point,
            3,
            Paint()..color = const Color(0xFF9AA0A3),
          );
        }
      }

      // Keep and banner.
      final keep = Rect.fromCenter(center: anchor, width: 56, height: 46);
      canvas.drawRRect(
        RRect.fromRectAndRadius(keep, const Radius.circular(6)),
        Paint()..color = const Color(0xFF4D5A50),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(keep.deflate(6), const Radius.circular(4)),
        Paint()..color = const Color(0xFF5E6C60),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: anchor + const Offset(0, -6),
          width: 10,
          height: 20,
        ),
        Paint()..color = const Color(0xFF20261F),
      );
      canvas.drawLine(
        anchor + const Offset(0, -26),
        anchor + const Offset(0, -52),
        Paint()
          ..color = const Color(0xFFD8DED9)
          ..strokeWidth = 2,
      );
      final flag = Path()
        ..moveTo(anchor.dx, anchor.dy - 52)
        ..lineTo(anchor.dx + 22, anchor.dy - 46)
        ..lineTo(anchor.dx, anchor.dy - 38)
        ..close();
      canvas.drawPath(flag, Paint()..color = accent);

      // Crystals: diamonds with a glow, owner color and an HP bar when hurt.
      for (final crystal in castle.alive) {
        _paintCrystal(canvas, crystal, accent, castle.isLocal);
      }
    }
  }

  /// Draws each objective as a tall crystal monolith, not a small pickup gem.
  /// The visual footprint is intentionally larger while gameplay positions,
  /// HP, targeting and collision rules remain unchanged.
  void _paintCrystal(
    Canvas canvas,
    CrystalState crystal,
    Color accent,
    bool isLocal,
  ) {
    final base = crystal.position;
    final pulse = 0.5 + 0.5 * math.sin(presentation.timeMs / 420);
    final body = crystal.exposed
        ? accent
        : Color.lerp(accent, const Color(0xFFFFFFFF), 0.35)!;
    const halfWidth = 22.0;
    const height = 88.0;
    const topY = -height;
    const barWidth = 54.0;

    // Ground shadow and a substantial stone/metal plinth establish scale.
    canvas.drawOval(
      Rect.fromCenter(
        center: base + const Offset(0, 7),
        width: 72,
        height: 25,
      ),
      Paint()..color = const Color(0x66000000),
    );
    final plinth = Path()
      ..moveTo(base.dx - 31, base.dy - 1)
      ..lineTo(base.dx - 24, base.dy - 13)
      ..lineTo(base.dx + 24, base.dy - 13)
      ..lineTo(base.dx + 31, base.dy - 1)
      ..lineTo(base.dx + 24, base.dy + 8)
      ..lineTo(base.dx - 24, base.dy + 8)
      ..close();
    canvas.drawPath(plinth, Paint()..color = const Color(0xFF343F3B));
    canvas.drawPath(
      plinth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.8),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: base + const Offset(0, -5),
        width: 49,
        height: 13,
      ),
      Paint()..color = accent.withValues(alpha: 0.22 + pulse * 0.12),
    );

    // Tall internal energy bloom, visible at normal gameplay zoom.
    canvas.drawCircle(
      base + const Offset(0, -43),
      65 + pulse * 5,
      Paint()
        ..shader = ui.Gradient.radial(
          base + const Offset(0, -43),
          65 + pulse * 5,
          [
            accent.withValues(alpha: 0.42 + pulse * 0.10),
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.0),
          ],
          const [0.0, 0.48, 1.0],
        ),
    );

    // Main faceted monolith silhouette.
    final top = base + const Offset(0, topY);
    final upperLeft = base + const Offset(-halfWidth * 0.58, -height * 0.72);
    final upperRight = base + const Offset(halfWidth * 0.58, -height * 0.72);
    final leftShoulder = base + const Offset(-halfWidth, -height * 0.43);
    final rightShoulder = base + const Offset(halfWidth, -height * 0.43);
    final lowerLeft = base + const Offset(-halfWidth * 0.62, -height * 0.12);
    final lowerRight = base + const Offset(halfWidth * 0.62, -height * 0.12);
    final crystalPath = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(upperRight.dx, upperRight.dy)
      ..lineTo(rightShoulder.dx, rightShoulder.dy)
      ..lineTo(lowerRight.dx, lowerRight.dy)
      ..lineTo(base.dx, base.dy - 4)
      ..lineTo(lowerLeft.dx, lowerLeft.dy)
      ..lineTo(leftShoulder.dx, leftShoulder.dy)
      ..lineTo(upperLeft.dx, upperLeft.dy)
      ..close();
    canvas.drawPath(
      crystalPath,
      Paint()
        ..shader = ui.Gradient.linear(
          top,
          base,
          [
            Color.lerp(body, Colors.white, 0.68)!,
            body,
            Color.lerp(body, Colors.black, 0.42)!,
          ],
          const [0.0, 0.48, 1.0],
        ),
    );
    canvas.drawPath(
      crystalPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xE6FFFFFF),
    );

    // Large readable facets and a bright energy core.
    final leftFacet = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(upperLeft.dx, upperLeft.dy)
      ..lineTo(leftShoulder.dx, leftShoulder.dy)
      ..lineTo(base.dx, base.dy - 4)
      ..close();
    canvas.drawPath(
      leftFacet,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    final rightFacet = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(upperRight.dx, upperRight.dy)
      ..lineTo(rightShoulder.dx, rightShoulder.dy)
      ..lineTo(base.dx, base.dy - 4)
      ..close();
    canvas.drawPath(
      rightFacet,
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawLine(
      top,
      base + const Offset(0, -5),
      Paint()
        ..strokeWidth = 2.4
        ..color = Colors.white.withValues(alpha: 0.78),
    );
    canvas.drawLine(
      base + const Offset(-halfWidth * 0.58, -height * 0.72),
      base + const Offset(halfWidth * 0.62, -height * 0.12),
      Paint()
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Damage cracks become progressively more visible as HP falls.
    if (crystal.hpRatio < 0.72) {
      final damage = ((0.72 - crystal.hpRatio) / 0.72).clamp(0.0, 1.0);
      final crackPaint = Paint()
        ..color = const Color(0xFFFFE6D8).withValues(alpha: 0.35 + damage * 0.6)
        ..strokeWidth = 1.2 + damage
        ..strokeCap = StrokeCap.round;
      final crack = Path()
        ..moveTo(base.dx + 2, base.dy - 58)
        ..lineTo(base.dx - 7, base.dy - 48)
        ..lineTo(base.dx + 1, base.dy - 39)
        ..lineTo(base.dx - 5, base.dy - 27);
      canvas.drawPath(crack, crackPaint);
      if (crystal.hpRatio < 0.38) {
        final secondCrack = Path()
          ..moveTo(base.dx - 8, base.dy - 69)
          ..lineTo(base.dx + 4, base.dy - 61)
          ..lineTo(base.dx + 9, base.dy - 49);
        canvas.drawPath(secondCrack, crackPaint);
      }
    }

    // HP is always visible so the crystal reads as a battle objective.
    final bar = Rect.fromCenter(
      center: base + const Offset(0, -height - 12),
      width: barWidth,
      height: 7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar.inflate(2), const Radius.circular(4)),
      Paint()..color = const Color(0xCC101510),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      Paint()..color = const Color(0xFF242B26),
    );
    final hpColor = Color.lerp(
      const Color(0xFFFF5148),
      const Color(0xFF9CFF75),
      crystal.hpRatio,
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width * crystal.hpRatio,
          bar.height,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = hpColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _paintFog(Canvas canvas, Offset camera) {
    final view = Rect.fromLTWH(
      camera.dx,
      camera.dy,
      arenaWidth,
      arenaHeight,
    ).inflate(fogCellSize);
    final fogPaint = Paint()..color = const Color(0xF007110A);
    for (final cell in world.fog.hiddenCellsIn(view)) {
      canvas.drawRect(cell.inflate(0.5), fogPaint);
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
        final arc = Rect.fromCircle(
          center: effect.position - const Offset(0, 10),
          radius: radius,
        );
        final start = _angleOf(effect.facing) - 1.15;
        // Three-pass energy blade: soft bloom, saturated edge, bright core.
        canvas.drawArc(
          arc,
          start,
          2.3,
          false,
          Paint()
            ..color = color.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 22 * (1 - t * 0.55)
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawArc(
          arc,
          start,
          2.3,
          false,
          Paint()
            ..color = color.withValues(alpha: 0.72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11 * (1 - t * 0.5)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawArc(
          arc,
          start,
          2.3,
          false,
          Paint()
            ..color = Color.lerp(color, Colors.white, 0.58)!
                .withValues(alpha: 0.95 * (1 - t))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2 * (1 - t * 0.45)
            ..strokeCap = StrokeCap.round,
        );
      } else if (effect.kind == 'burst') {
        final radius = effect.radius * (0.35 + 0.65 * t);
        final burstColor = Color(effect.color);
        canvas.drawCircle(
          effect.position,
          radius * 1.12,
          Paint()
            ..shader = ui.Gradient.radial(
              effect.position,
              radius * 1.12,
              [
                burstColor.withValues(alpha: 0.30 * (1 - t)),
                burstColor.withValues(alpha: 0.10 * (1 - t)),
                burstColor.withValues(alpha: 0),
              ],
              const [0.0, 0.62, 1.0],
            ),
        );
        canvas.drawCircle(
          effect.position,
          radius,
          Paint()
            ..color = burstColor.withValues(alpha: 0.18 * (1 - t))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18 * (1 - t * 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        canvas.drawCircle(
          effect.position,
          radius,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - t),
        );
        canvas.drawCircle(
          effect.position,
          radius * 0.72,
          Paint()
            ..color = Color.lerp(burstColor, Colors.white, 0.65)!
                .withValues(alpha: 0.52 * (1 - t))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * (1 - t),
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
              ..color = color.withValues(alpha: 0.30 * (1 - t))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 17 * (1 - t * 0.45)
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6 * (1 - t * 0.5)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.95 * (1 - t))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8 * (1 - t * 0.5)
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
    // Enemy monsters are only rendered when they are near the hero.
    final monsters = [...world.visibleEnemies, ...world.army]
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
      final tint = Color(projectile.tint);
      final glow = Paint()
        ..color = tint.withValues(alpha: 0.28)
        ..strokeWidth = projectile.big ? 18 : 13
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawLine(tail, projectile.position, glow);
      final edge = Paint()
        ..color = tint.withValues(alpha: 0.92)
        ..strokeWidth = projectile.big ? 7 : 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, projectile.position, edge);
      final core = Paint()
        ..color = Color.lerp(tint, Colors.white, 0.68)!
        ..strokeWidth = projectile.big ? 2.8 : 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, projectile.position, core);
      // Arrow head.
      final head = Paint()..color = tint;
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
      // Soft team-colored ground halo helps the hero remain readable over
      // bright biome patches without hiding the actual floor or enemies.
      final heroHalo = Paint()
        ..color = presentation.accent.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawOval(
        Rect.fromCenter(
          center: player.position + const Offset(0, 30),
          width: 78,
          height: 25,
        ),
        heroHalo,
      );
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
        scale: hero3d.scaleForPixelHeight(120),
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

    const drawHeight = 92.0;
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
