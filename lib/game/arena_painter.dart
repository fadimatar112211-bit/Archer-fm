import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../hero/hero_assets.dart';
import 'combat/hero_kit.dart';
import 'monsters/monster_models.dart';
import 'render3/hero3d_controller.dart';
import 'arena_camera.dart';
import 'world/arena_map.dart';
import 'world/arena_projection.dart';
import 'world/castle_system.dart';
import 'world/game_world.dart';
import 'world/mine_system.dart';

/// Compatibility helper: the authoritative camera origin is the same
/// smoothed origin consumed by the painter and all viewport input transforms.
Offset arenaCameraOrigin(GameWorld world) => world.cameraOrigin;

/// Converts a tap inside the arena widget to map coordinates using the exact
/// viewport and smoothed camera transform used by [ArenaPainter.paint].
Offset arenaToWorld(
  Offset local,
  Size size,
  GameWorld world, {
  ArenaCameraConfig config = defaultArenaCameraConfig,
  ArenaWorldProjection? projection,
}) =>
    ArenaCameraTransform.forViewport(
      size,
      world,
      config: config,
      projection: projection,
    ).localToWorld(local);

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
    this.heroSpriteApproved = true,
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

  /// Whether the current hero's atlas has passed reference-art acceptance.
  /// Defaults true for isolated painter previews/tests; production always
  /// supplies the explicit roster policy so a failed GLB cannot expose a
  /// rejected placeholder atlas.
  final bool heroSpriteApproved;

  Color get accent => Color(kit.accentColor);
}

/// Draws the whole battle arena: ground, hero sprite, enemies, projectiles,
/// AoE telegraphs and transient labels. The painter scales the logical arena
/// (`arenaWidth × arenaHeight`) to fit the widget, letterboxed.
class ArenaPainter extends CustomPainter {
  ArenaPainter({
    required this.world,
    required this.presentation,
    this.config = defaultArenaCameraConfig,
    ArenaWorldProjection? projection,
  }) : projection = projection ?? config.projection;

  final GameWorld world;
  final ArenaPresentation presentation;

  /// Camera settings shared with pointer transforms by the arena host.
  final ArenaCameraConfig config;

  /// Projection used by both painting and touch. Defaults to the one built
  /// from [config]; pass one only to override it.
  final ArenaWorldProjection projection;

  @override
  void paint(Canvas canvas, Size size) {
    final cameraTransform = ArenaCameraTransform.forViewport(
      size,
      world,
      config: config,
      projection: projection,
    );
    final scale = cameraTransform.scale;
    final origin = cameraTransform.viewportOrigin;
    final viewWidth = arenaWidth * scale;
    final viewHeight = arenaHeight * scale;
    canvas.drawColor(const Color(0xFF07110A), BlendMode.src);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _paintBackdrop(canvas, origin, viewWidth, viewHeight);

    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    final projectionCenter = const Offset(arenaWidth / 2, arenaHeight / 2);
    canvas.translate(projectionCenter.dx, projectionCenter.dy);
    // Same order as ArenaWorldProjection.projectGround: rotate first,
    // then compress depth. This is what makes painting == touch math.
    canvas.scale(
      cameraTransform.projection.scale,
      cameraTransform.projection.scale * cameraTransform.projection.groundScaleY,
    );
    canvas.rotate(cameraTransform.projection.yawRadians);
    canvas.translate(-projectionCenter.dx, -projectionCenter.dy);
    final camera = cameraTransform.cameraOrigin;
    final focus = cameraTransform.projection.focus;
    canvas.translate(-camera.dx - focus.dx, -camera.dy - focus.dy);

    _paintTerrain(canvas);
    _paintZones(canvas);
    _paintFireWaves(canvas);
    _paintGroundShadows(canvas);
    _paintActors(canvas);
    _paintFx(canvas);
    _paintFog(canvas, cameraTransform.visibleWorldRect);
    _paintLabels(canvas, scale);

    canvas.restore();
  }


  /// Draws an upright actor at a ground-projected anchor. The global ground
  /// plane rotates and compresses camera depth; inverse rotation and scale
  /// keep bodies, faces, weapons, health bars and labels upright.
  void _withUprightGroundActor(
    Canvas canvas,
    Offset anchor,
    VoidCallback draw,
  ) {
    // Reuse the painter's immutable projection; avoid constructing a
    // viewport transform for every actor on every frame.
    final depthScale = cameraProjection.groundScaleY;
    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(-cameraProjection.yawRadians);
    canvas.scale(1, 1 / depthScale);
    canvas.translate(-anchor.dx, -anchor.dy);
    draw();
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

    // Biome colour fields sit below ground texture so grass, sand ripples
    // and snow/volcanic details remain crisp instead of being washed out by
    // the translucent regional tint.
    for (final patch in map.biomes) {
      final color = _biomeColor(patch.kind);
      canvas.drawCircle(
        patch.center,
        patch.radius,
        Paint()
          ..shader = ui.Gradient.radial(
            patch.center,
            patch.radius,
            [
              color.withValues(alpha: 0.52),
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
            const [0.0, 0.72, 1.0],
          ),
      );
    }

    // Deterministic biome-specific ground details are painted after the tint
    // so sand ripples and grass blades retain their contrast at gameplay zoom.
    _paintGroundDetails(canvas);

    // Worn stone approaches visually connect castle clearings to the
    // nearest river crossing. These pavers are decoration only; navigation,
    // collision and bridge placement remain unchanged.
    _paintStoneApproaches(canvas);

    // River banks, water and bridges.
    for (final river in map.rivers) {
      final path = Path()
        ..moveTo(river.points.first.dx, river.points.first.dy);
      for (final point in river.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      // Three ground-plane shore layers create a readable bank edge and
      // a soft transition between terrain and water under the oblique camera.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = river.width + 34
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0x88402D22),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = river.width + 18
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF314B34),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = river.width + 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF536A43),
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
      // A darker central channel and two restrained edge glints give the
      // river depth at the isometric gameplay zoom without obscuring bridges.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = river.width * 0.42
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x22203F5D),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = river.width * 0.76
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x1C9AD8E8),
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
        final tangent = b - a;
        final tangentLength = tangent.distance;
        if (tangentLength <= 0.001) continue;
        final normal = Offset(
          -tangent.dy / tangentLength * 12,
          tangent.dx / tangentLength * 12,
        );
        canvas.drawLine(start - normal, start + normal, shimmer);
      }

      // Broken foam glints along both banks add depth without painting over
      // bridge decks. Their positions are deterministic; only the shimmer
      // offset moves, so the map does not flicker as the camera pans.
      final foam = Paint()
        ..color = const Color(0x668ED8E8)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < river.points.length - 1; i++) {
        final a = river.points[i];
        final b = river.points[i + 1];
        final tangent = b - a;
        final segmentLength = tangent.distance;
        if (segmentLength < 24) continue;
        final direction = tangent / segmentLength;
        final normal = Offset(-direction.dy, direction.dx);
        for (final side in const [-1.0, 1.0]) {
          for (final fraction in const [0.22, 0.48, 0.74]) {
            final drift = ((phase + fraction * 0.37) % 1.0) * 0.08;
            final t = (fraction + drift).clamp(0.08, 0.92);
            final center = a + tangent * t +
                normal * side * (river.width / 2 + 5);
            if (map.isBridge(center)) continue;
            final dash = center - direction * 4;
            canvas.drawLine(dash, dash + direction * 8, foam);
          }
        }
      }
    }
    _paintRiverBankDetails(canvas);
  }

  void _paintRiverBankDetails(Canvas canvas) {
    final map = world.map;
    for (final river in map.rivers) {
      for (var i = 0; i < river.points.length - 1; i += 2) {
        final a = river.points[i];
        final b = river.points[i + 1];
        final segment = b - a;
        final length = segment.distance;
        if (length < 28) continue;
        final direction = segment / length;
        final normal = Offset(-direction.dy, direction.dx);
        final midpoint = a + segment * 0.5;
        for (final side in const [-1.0, 1.0]) {
          final bank = midpoint + normal * side * (river.width * 0.5 + 17);
          if (bank.dx < 18 || bank.dy < 18 ||
              bank.dx > map.size.width - 18 || bank.dy > map.size.height - 18) continue;
          if (map.isWater(bank) || map.isBridge(bank) ||
              map.obstacleBlocking(bank, 18) != null ||
              map.mines.any((mine) => (mine.position - bank).distance < mine.radius + 18) ||
              map.pickups.any((pickup) => (pickup.position - bank).distance < 30) ||
              map.castleAnchors.any((castle) => (castle - bank).distance < castleWallRadius + 24)) continue;
          // Riverbank dressing must respect the generated biome ownership.
          // Outside all biome patches, leave the ground undecorated rather
          // than silently painting forest reeds across an unassigned seam.
          final biomeKind = map.biomeAt(bank)?.kind;
          if (biomeKind == null) continue;
          final biome = biomeKind;
          canvas.save();
          canvas.translate(bank.dx, bank.dy);
          canvas.rotate(math.atan2(direction.dy, direction.dx));
          switch (biome) {
            case TerrainKind.forest:
              for (var blade = 0; blade < 3; blade++) {
                final x = (blade - 1) * 4.0;
                final height = 7.0 + blade * 1.5;
                final reed = Path()
                  ..moveTo(x, 2)
                  ..quadraticBezierTo(x + (blade - 1) * 2, -height * 0.55,
                      x + (blade - 1) * 3, -height);
                canvas.drawPath(reed, Paint()
                  ..color = blade.isEven ? const Color(0xFF71934C) : const Color(0xFF9BB66A)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.0
                  ..strokeCap = StrokeCap.round);
              }
              break;
            case TerrainKind.desert:
              canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 13, height: 7),
                  Paint()..color = const Color(0xFF98754A));
              canvas.drawArc(Rect.fromCenter(center: const Offset(-1, -1), width: 10, height: 4),
                  math.pi, math.pi, false, Paint()
                    ..color = const Color(0x88F1D19A)
                    ..style = PaintingStyle.stroke..strokeWidth = 1.2);
              break;
            case TerrainKind.snow:
              final crystal = Path()
                ..moveTo(0, -6)..lineTo(3, 0)..lineTo(0, 6)..lineTo(-3, 0)..close();
              canvas.drawPath(crystal, Paint()..color = const Color(0xFFB9D9E8));
              canvas.drawLine(const Offset(0, -4), const Offset(0, 4),
                  Paint()..color = const Color(0xCCF5FCFF)..strokeWidth = 1.1);
              break;
            case TerrainKind.volcanic:
              canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 8),
                  Paint()..color = const Color(0xFF493B39));
              canvas.drawLine(const Offset(-3, 0), const Offset(3, 0),
                  Paint()..color = const Color(0x99FF8844)..strokeWidth = 1.4);
              break;
          }
          canvas.restore();
        }
      }
    }
  }

  void _paintStoneApproaches(Canvas canvas) {
    final map = world.map;
    final bridges = [
      for (final river in map.rivers) ...river.bridges,
    ];
    if (bridges.isEmpty) return;

    for (var castleIndex = 0; castleIndex < map.castleAnchors.length; castleIndex++) {
      final castle = map.castleAnchors[castleIndex];
      Bridge? nearest;
      var nearestDistance = double.infinity;
      for (final bridge in bridges) {
        final distance = (bridge.center - castle).distance;
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = bridge;
        }
      }
      if (nearest == null) continue;
      final delta = nearest.center - castle;
      final length = delta.distance;
      if (length < 1) continue;
      final direction = delta / length;
      final perpendicular = Offset(-direction.dy, direction.dx);
      final paverCount = (length / 28).floor();
      for (var i = 5; i < paverCount; i++) {
        final t = i / paverCount;
        final center = castle + delta * t +
            perpendicular * math.sin(i * 1.73 + castleIndex) * 13;
        if (map.isWater(center) && !map.isBridge(center)) continue;
        if (map.mines.any((mine) => (mine.position - center).distance < mine.radius + 24)) continue;
        // Keep decorative paving from hiding resource/chest interaction
        // markers or clipping through tree and rock silhouettes.
        if (map.pickups.any((pickup) => (pickup.position - center).distance < 28)) continue;
        if (map.obstacleBlocking(center, 10) != null) continue;
        if (map.castleAnchors.any((anchor) =>
            (anchor - center).distance < castleWallRadius + 18)) continue;
        final width = 15.0 + (i % 3) * 2;
        final height = 9.0 + (i % 2) * 2;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.atan2(direction.dy, direction.dx));
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(1, 2), width: width + 2, height: height + 2),
          Paint()..color = const Color(0x33201913),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(-width / 2, -height / 2),
              Offset(width / 2, height / 2),
              const [Color(0xFF92958B), Color(0xFF626A61), Color(0xFF444E47)],
              const [0.0, 0.52, 1.0],
            ),
        );
        canvas.drawArc(
          Rect.fromCenter(center: Offset.zero, width: width - 3, height: height - 3),
          math.pi * 1.05,
          math.pi * 0.72,
          false,
          Paint()
            ..color = const Color(0x559EA99A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        canvas.restore();
      }
    }
  }

  void _paintGroundDetails(Canvas canvas) {
    final map = world.map;
    const spacing = 74.0;
    final view = cameraProjection.visibleWorldBounds(
      const Rect.fromLTRB(-arenaWidth / 2, -arenaHeight / 2,
          arenaWidth / 2, arenaHeight / 2),
    ).shift(world.cameraOrigin + const Offset(arenaWidth / 2, arenaHeight / 2));
    final maxX = (map.size.width / spacing).ceil();
    final maxY = (map.size.height / spacing).ceil();
    final left = (view.left / spacing).floor().clamp(0, maxX).toInt();
    final right = (view.right / spacing).ceil().clamp(0, maxX).toInt();
    final top = (view.top / spacing).floor().clamp(0, maxY).toInt();
    final bottom = (view.bottom / spacing).ceil().clamp(0, maxY).toInt();

    for (var gy = top; gy <= bottom; gy++) {
      for (var gx = left; gx <= right; gx++) {
        // Stable integer hash: the same map cell always gets the same detail.
        var hash = (gx * 73856093) ^ (gy * 19349663) ^ 0x45D9F3B;
        hash = (hash ^ (hash >> 16)) * 0x45D9F3B;
        hash = hash ^ (hash >> 16);
        final unit = (hash & 0x7fffffff) / 0x7fffffff;
        if (unit < 0.34) continue;

        final point = Offset(
          gx * spacing + 18 + unit * 30,
          gy * spacing + 14 + ((hash >> 5) & 31),
        );
        if (point.dx >= map.size.width || point.dy >= map.size.height) continue;
        if (map.isWater(point) || map.isBridge(point)) continue;
        if (map.obstacleBlocking(point, 34) != null) continue;
        // Keep decorative grass/ice/embers off readable interactable markers.
        if (map.pickups.any(
          (pickup) => (pickup.position - point).distance < 38,
        )) continue;
        if (map.mines.any((mine) => (mine.position - point).distance < mine.radius + 22)) continue;
        if (map.castleAnchors.any((castle) => (castle - point).distance < castleWallRadius + 42)) continue;

        final biome = map.biomeAt(point)?.kind ?? TerrainKind.forest;
        final variation = ((hash >> 9) & 7).toDouble();
        final detail = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        switch (biome) {
          case TerrainKind.desert:
            // Short wind-carved sand ripples, staggered so they read as dunes
            // rather than a repeated grid.
            detail
              ..color = const Color(0x66F4D49A)
              ..strokeWidth = 1.7 + unit;
            final ripple = Rect.fromCenter(
              center: point,
              width: 18 + variation * 1.8,
              height: 8 + variation * 0.45,
            );
            canvas.drawArc(ripple, math.pi * 1.08, math.pi * 0.84, false, detail);
            if ((hash & 3) == 0) {
              canvas.drawArc(ripple.shift(const Offset(3, 5)),
                  math.pi * 1.08, math.pi * 0.72, false,
                  Paint()
                    ..color = const Color(0x44A77B42)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.2);
            }
            break;

          case TerrainKind.snow:
            // Small angular ice crystals with a cool highlight.
            final arm = 3.5 + variation * 0.55;
            detail
              ..color = const Color(0x99F1FBFF)
              ..strokeWidth = 1.5;
            canvas.drawLine(point + Offset(-arm, 0), point + Offset(arm, 0), detail);
            canvas.drawLine(point + Offset(0, -arm), point + Offset(0, arm), detail);
            canvas.drawLine(point + Offset(-arm * 0.68, -arm * 0.68),
                point + Offset(arm * 0.68, arm * 0.68), detail);
            if ((hash & 3) == 0) {
              canvas.drawCircle(point + Offset(arm + 3, -arm), 1.8,
                  Paint()..color = const Color(0x99B8E7F4));
            }
            break;

          case TerrainKind.volcanic:
            // Dark fissures with a narrow ember core; all marks are decals
            // and do not affect walkability or damage.
            final crack = Path()
              ..moveTo(point.dx - 8, point.dy - 3)
              ..lineTo(point.dx - 2, point.dy + 1)
              ..lineTo(point.dx + 2, point.dy - 2)
              ..lineTo(point.dx + 8, point.dy + 4);
            canvas.drawPath(
              crack,
              Paint()
                ..color = const Color(0x88502C28)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.2
                ..strokeCap = StrokeCap.round,
            );
            canvas.drawPath(
              crack,
              Paint()
                ..color = const Color(0x99FF7A32)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.1
                ..strokeCap = StrokeCap.round,
            );
            break;

          case TerrainKind.forest:
            // Dense, varied grass blades and occasional tiny wildflowers.
            final height = 4.0 + variation;
            final width = 2.0 + ((hash >> 13) & 2).toDouble();
            detail
              ..color = const Color(0x778EAF65)
              ..strokeWidth = width;
            canvas.drawLine(point, point + Offset(-width, -height), detail);
            canvas.drawLine(point + const Offset(1, 0),
                point + Offset(width, -height * 0.78), detail);
            if ((hash & 7) == 0) {
              canvas.drawCircle(point + const Offset(5, 2), 1.5,
                  Paint()..color = const Color(0x88D9C77A));
            }
            break;
        }
      }
    }
  }

  void _paintResourcePickup(Canvas canvas, ResourcePickup pickup) {
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        pickup.position + Offset((i - 1) * 8.0, i.isEven ? -3 : 3),
        5,
        Paint()..color = _goldColor,
      );
    }
  }

  void _paintChestPickup(Canvas canvas, MapPickup pickup) {
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

  void _paintMine(Canvas canvas, MineState mine) {
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

  void _paintCastleCourtyard(Canvas canvas, CastleState castle) {
    final anchor = castle.anchor;
    canvas.drawCircle(
      anchor + const Offset(0, 8),
      castleWallRadius + 40,
      Paint()..color = const Color(0x44301E18),
    );
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
    canvas.drawCircle(
      anchor,
      castleWallRadius + 24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x557F927A),
    );
  }

  /// One wall arc is a separate occluder. Its midpoint on the ground arc is
  /// the stable depth anchor; crenellations remain attached to that segment.
  void _paintCastleWall(Canvas canvas, CastleWall wall) {
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
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          const [
            Color(0xFF92999A),
            Color(0xFF747B7D),
            Color(0xFF555D60),
          ],
          const [0.0, 0.52, 1.0],
        ),
    );
    canvas.drawArc(
      rect,
      wall.startAngle,
      wall.sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x99D9E0DD),
    );
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

  void _paintCastleKeep(Canvas canvas, CastleState castle) {
    final anchor = castle.anchor;
    final accent = castle.isLocal
        ? const Color(0xFF9BE845)
        : const Color(0xFFFF7A5A);
    final keep = Rect.fromCenter(center: anchor, width: 56, height: 46);
    final keepShape = RRect.fromRectAndRadius(keep, const Radius.circular(6));
    canvas.drawRRect(
      keepShape.shift(const Offset(0, 8)),
      Paint()..color = const Color(0x66301F19),
    );
    canvas.drawRRect(keepShape, Paint()..color = const Color(0xFF4D5A50));
    final roof = Path()
      ..moveTo(keep.left - 4, keep.top + 5)
      ..lineTo(keep.center.dx, keep.top - 13)
      ..lineTo(keep.right + 4, keep.top + 5)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF7D887B));
    canvas.drawPath(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF9AA596),
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
    canvas.drawPath(
      plinth.shift(const Offset(0, 4)),
      Paint()..color = const Color(0x66301E18),
    );
    canvas.drawPath(plinth, Paint()..color = const Color(0xFF343F3B));
    final plinthTop = Path()
      ..moveTo(base.dx - 24, base.dy - 13)
      ..lineTo(base.dx + 24, base.dy - 13)
      ..lineTo(base.dx + 31, base.dy - 1)
      ..lineTo(base.dx - 31, base.dy - 1)
      ..close();
    canvas.drawPath(plinthTop, Paint()..color = const Color(0xFF58665D));
    canvas.drawLine(
      base + const Offset(-23, -11),
      base + const Offset(23, -11),
      Paint()
        ..color = const Color(0x8897A99A)
        ..strokeWidth = 2,
    );
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

  void _paintFog(Canvas canvas, Rect visibleWorld) {
    final view = visibleWorld.inflate(fogCellSize);
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

  void _paintContactShadow(
    Canvas canvas,
    Offset groundAnchor, {
    required double width,
    required double height,
    double offsetY = 0,
    int alpha = 102,
  }) {
    canvas.drawOval(
      Rect.fromCenter(
        center: groundAnchor + Offset(0, offsetY),
        width: width,
        height: height,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          groundAnchor + Offset(0, offsetY),
          math.max(width, height) * 0.62,
          [
            Color.fromARGB(alpha, 0, 0, 0),
            Color.fromARGB((alpha * 0.42).round(), 0, 0, 0),
            const Color(0x00000000),
          ],
          const [0.0, 0.68, 1.0],
        ),
    );
  }

  void _paintGroundShadows(Canvas canvas) {
    // A single soft contact-shadow treatment keeps actors and scenery on
    // the same projected floor while preserving their independent depth.
    _paintContactShadow(
      canvas,
      world.player.position,
      width: 56,
      height: 18,
      offsetY: 10,
      alpha: 112,
    );
    for (final monster in [...world.enemies, ...world.army]) {
      if (monster.hp <= 0) continue;
      final size = monster.radius * 2.6;
      _paintContactShadow(
        canvas,
        monster.position,
        width: size * 0.9,
        height: size * 0.28,
        offsetY: monster.radius * 0.95,
      );
    }
    // Obstacle shadows belong to the projected ground plane, not the
    // upright tree/rock artwork.
    for (final obstacle in world.map.obstacles) {
      final isTree = obstacle.kind == ObstacleKind.tree;
      _paintContactShadow(
        canvas,
        obstacle.position,
        width: obstacle.radius * (isTree ? 2.3 : 2.1),
        height: obstacle.radius * (isTree ? 0.9 : 0.8),
        offsetY: obstacle.radius * 0.14,
        alpha: 94,
      );
    }

    // Bridges, mines, loose resources and chests use the same soft
    // ground-contact treatment as actors instead of floating over the floor.
    for (final river in world.map.rivers) {
      for (final bridge in river.bridges) {
        _paintContactShadow(
          canvas,
          bridge.center,
          width: bridge.rect.width * 0.9,
          height: 15,
          offsetY: 5,
          alpha: 88,
        );
      }
    }
    for (final mine in world.mineSystem.mines) {
      _paintContactShadow(
        canvas,
        mine.position,
        width: mine.radius * 1.65,
        height: mine.radius * 0.62,
        offsetY: 5,
        alpha: 96,
      );
    }
    for (final pickup in world.mineSystem.pickups) {
      _paintContactShadow(
        canvas,
        pickup.position,
        width: 25,
        height: 9,
        offsetY: 3,
        alpha: 82,
      );
    }
    for (final pickup in world.map.pickups) {
      if (pickup.kind == PickupKind.resource) continue;
      _paintContactShadow(
        canvas,
        pickup.position,
        width: 34,
        height: 12,
        offsetY: 4,
        alpha: 90,
      );
    }

    // Castle mass, individual wall arcs and crystal plinths cast contact
    // shadows independently, matching their depth-sorted ground anchors.
    for (final castle in world.castleSystem.standingCastles) {
      _paintContactShadow(
        canvas,
        castle.anchor,
        width: castleWallRadius * 2.55,
        height: castleWallRadius * 1.05,
        offsetY: 12,
        alpha: 86,
      );
      for (final wall in castle.walls) {
        final angle = wall.startAngle + wall.sweep / 2;
        final anchor = wall.center +
            Offset(math.cos(angle) * wall.radius, math.sin(angle) * wall.radius);
        _paintContactShadow(
          canvas,
          anchor,
          width: 48,
          height: 17,
          offsetY: 5,
          alpha: 92,
        );
      }
      for (final crystal in castle.alive) {
        _paintContactShadow(
          canvas,
          crystal.position,
          width: 70,
          height: 23,
          offsetY: 8,
          alpha: 118,
        );
      }
    }
  }

  /// Draw every ground actor in one depth order. The hero, hostile units,
  /// owned units and corpses therefore occlude one another consistently as
  /// they cross on the projected ground plane.
  ArenaWorldProjection get cameraProjection => projection;

  void _paintActors(Canvas canvas) {
    final actors = <({double depth, int order, VoidCallback draw})>[];
    var order = 0;

    for (final corpse in world.corpses) {
      final currentOrder = order++;
      actors.add((
        depth: cameraProjection.depthOf(corpse.position),
        order: currentOrder,
        draw: () => _withUprightGroundActor(canvas, corpse.position, () {
          _paintCorpse(canvas, corpse);
        }),
      ));
    }

    // Bridges are elevated dry crossings. Draw each deck in the same
    // depth queue as actors so a hero can pass in front of or behind it.
    for (final river in world.map.rivers) {
      for (final bridge in river.bridges) {
        final bridgeOrder = order++;
        actors.add((
          depth: cameraProjection.depthOf(bridge.center),
          order: bridgeOrder,
          draw: () => _withUprightGroundActor(canvas, bridge.center, () {
            _paintBridge(canvas, bridge);
          }),
        ));
      }
    }

    // Mines are ground-level world objects, not a terrain overlay. Queue
    // them with heroes and obstacles so a character can pass in front of or
    // behind a mine according to the same camera depth.
    for (final mine in world.mineSystem.mines) {
      final mineOrder = order++;
      actors.add((
        depth: cameraProjection.depthOf(mine.position),
        order: mineOrder,
        draw: () => _withUprightGroundActor(canvas, mine.position, () {
          _paintMine(canvas, mine);
        }),
      ));
    }

    // Resource piles and chests are world pickups. Keep them in the shared
    // depth queue rather than painting them as a flat overlay above actors.
    for (final pickup in world.mineSystem.pickups) {
      final pickupOrder = order++;
      actors.add((
        depth: cameraProjection.depthOf(pickup.position),
        order: pickupOrder,
        draw: () => _withUprightGroundActor(canvas, pickup.position, () {
          _paintResourcePickup(canvas, pickup);
        }),
      ));
    }
    for (final pickup in world.map.pickups) {
      if (pickup.kind == PickupKind.resource) continue;
      final pickupOrder = order++;
      actors.add((
        depth: cameraProjection.depthOf(pickup.position),
        order: pickupOrder,
        draw: () => _withUprightGroundActor(canvas, pickup.position, () {
          _paintChestPickup(canvas, pickup);
        }),
      ));
    }

    // Enemy monsters are only rendered when they are near the hero.
    for (final monster in [...world.visibleEnemies, ...world.army]) {
      if (monster.hp <= 0) continue;
      final currentOrder = order++;
      actors.add((
        depth: cameraProjection.depthOf(monster.position),
        order: currentOrder,
        draw: () => _withUprightGroundActor(canvas, monster.position, () {
          _paintMonster(canvas, monster);
        }),
      ));
    }

    // Split tree geometry into independently depth-sorted ground/trunk and
    // canopy layers. A hero can pass behind the canopy while remaining in
    // front of the trunk (or vice versa) instead of the whole tree popping
    // in front/behind as one oversized sprite.
    for (final obstacle in world.map.obstacles) {
      if (obstacle.kind == ObstacleKind.tree) {
        final trunkOrder = order++;
        actors.add((
          depth: cameraProjection.depthOf(obstacle.position),
          order: trunkOrder,
          draw: () => _withUprightGroundActor(canvas, obstacle.position, () {
            _paintTreeTrunk(canvas, obstacle);
          }),
        ));
        final canopyAnchor =
            obstacle.position - Offset(0, obstacle.radius * 0.35);
        final canopyOrder = order++;
        actors.add((
          depth: cameraProjection.depthOf(canopyAnchor),
          order: canopyOrder,
          draw: () => _withUprightGroundActor(canvas, canopyAnchor, () {
            _paintTreeCanopy(canvas, obstacle);
          }),
        ));
        final upperLobeAnchor =
            obstacle.position - Offset(obstacle.radius * 0.35, obstacle.radius * 0.6);
        final upperLobeOrder = order++;
        actors.add((
          depth: cameraProjection.depthOf(upperLobeAnchor),
          order: upperLobeOrder,
          draw: () => _withUprightGroundActor(canvas, upperLobeAnchor, () {
            _paintTreeCanopyUpperLobe(canvas, obstacle);
          }),
        ));
      } else {
        final currentOrder = order++;
        actors.add((
          depth: cameraProjection.depthOf(obstacle.position),
          order: currentOrder,
          draw: () => _paintObstacle(canvas, obstacle),
        ));
      }
    }

    final playerPosition = world.player.position;
    final heroOrder = order++;
    actors.add((
      depth: cameraProjection.depthOf(playerPosition),
      order: heroOrder,
      draw: () => _withUprightGroundActor(canvas, playerPosition, () {
        _paintHero(canvas);
      }),
    ));

    // Castles and their crystal objectives participate in the same ground-depth
    // order as actors. Previously they were painted with the terrain pass, which
    // forced every hero and projectile to appear above every castle regardless
    // of which side of the structure they occupied.
    for (final castle in world.castleSystem.castles) {
      if (!castle.standing) continue;
      final castleAnchor = castle.anchor;
      final courtyardOrder = order++;
      actors.add((
        depth: cameraProjection.depthOf(castleAnchor),
        order: courtyardOrder,
        draw: () => _withUprightGroundActor(canvas, castleAnchor, () {
          _paintCastleCourtyard(canvas, castle);
        }),
      ));

      final keepOrder = order++;
      actors.add((
        depth: cameraProjection.depthOf(castleAnchor),
        order: keepOrder,
        draw: () => _withUprightGroundActor(canvas, castleAnchor, () {
          _paintCastleKeep(canvas, castle);
        }),
      ));

      for (final wall in castle.walls) {
        final middleAngle = wall.startAngle + wall.sweep / 2;
        final wallAnchor = wall.center +
            Offset(
              math.cos(middleAngle) * wall.radius,
              math.sin(middleAngle) * wall.radius,
            );
        final wallOrder = order++;
        actors.add((
          depth: cameraProjection.depthOf(wallAnchor),
          order: wallOrder,
          draw: () => _withUprightGroundActor(canvas, wallAnchor, () {
            _paintCastleWall(canvas, wall);
          }),
        ));
      }

      // Tall crystal objectives are independent occluders. Sorting them by
      // their own bases lets a hero pass behind one crystal while remaining
      // in front of the castle keep or another crystal.
      for (final crystal in castle.alive) {
        final crystalOrder = order++;
        actors.add((
          depth: cameraProjection.depthOf(crystal.position),
          order: crystalOrder,
          draw: () => _withUprightGroundActor(canvas, crystal.position, () {
            _paintCrystal(
              canvas,
              crystal,
              castle.isLocal
                  ? const Color(0xFF9BE845)
                  : const Color(0xFFFF7A5A),
              castle.isLocal,
            );
          }),
        ));
      }
    }

    // Projectiles share the same ground-depth queue as actors and obstacle
    // layers. Their current position is the depth anchor; the trail and head
    // are drawn together so they cannot pop above every foreground obstacle.
    for (final projectile in world.projectiles) {
      final projectileOrder = order++;
      actors.add((
        depth: cameraProjection.depthOf(projectile.position),
        order: projectileOrder,
        draw: () => _withUprightGroundActor(canvas, projectile.position, () {
          _paintProjectile(canvas, projectile);
        }),
      ));
    }

    actors.sort((a, b) {
      final byDepth = a.depth.compareTo(b.depth);
      return byDepth != 0 ? byDepth : a.order.compareTo(b.order);
    });
    for (final actor in actors) {
      actor.draw();
    }
  }

  void _paintBridge(Canvas canvas, Bridge bridge) {
    final rect = bridge.rect;
    final deck = RRect.fromRectAndRadius(
      rect,
      Radius.circular((rect.height * 0.12).clamp(4.0, 10.0).toDouble()),
    );
    canvas.drawRRect(
      deck.shift(const Offset(0, 5)),
      Paint()..color = const Color(0x660F1C18),
    );
    canvas.drawRRect(deck, Paint()..color = _bridgeColor);
    final rail = Paint()
      ..color = const Color(0xFF9A7045)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(rect.left + 3, rect.top + 4),
      Offset(rect.right - 3, rect.top + 4),
      rail,
    );
    canvas.drawLine(
      Offset(rect.left + 3, rect.bottom - 4),
      Offset(rect.right - 3, rect.bottom - 4),
      rail,
    );
    var plankIndex = 0;
    for (var x = rect.left + 8; x < rect.right; x += 12) {
      final shade = plankIndex.isEven
          ? _bridgePlankColor
          : Color.lerp(_bridgePlankColor, const Color(0xFFB18A5D), 0.18)!;
      canvas.drawLine(
        Offset(x, rect.top + 7),
        Offset(x, rect.bottom - 7),
        Paint()..color = shade..strokeWidth = 3,
      );
      // Small iron nail heads at both ends make each timber read as a plank.
      canvas.drawCircle(Offset(x, rect.top + 7), 1.5,
          Paint()..color = const Color(0xFFB5A58A));
      canvas.drawCircle(Offset(x, rect.bottom - 7), 1.5,
          Paint()..color = const Color(0xFFB5A58A));
      plankIndex++;
    }
    // A raised cross-beam at either river bank gives the deck a clear edge.
    final beam = Paint()
      ..color = const Color(0xFF9A7045)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(rect.left + 4, rect.top + 2),
        Offset(rect.left + 4, rect.bottom - 2), beam);
    canvas.drawLine(Offset(rect.right - 4, rect.top + 2),
        Offset(rect.right - 4, rect.bottom - 2), beam);
  }

  void _paintTreeTrunk(Canvas canvas, MapObstacle obstacle) {
    final trunk = Rect.fromCenter(
      center: obstacle.position + Offset(0, obstacle.radius * 0.4),
      width: obstacle.radius * 0.45,
      height: obstacle.radius * 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trunk, Radius.circular(obstacle.radius * 0.12)),
      Paint()..color = _trunkColor,
    );
    canvas.drawLine(
      Offset(trunk.center.dx - obstacle.radius * 0.07, trunk.top + 4),
      Offset(trunk.center.dx - obstacle.radius * 0.07, trunk.bottom - 3),
      Paint()
        ..color = const Color(0x668F6842)
        ..strokeWidth = (obstacle.radius * 0.055).clamp(1.5, 4.0).toDouble(),
    );
    canvas.drawLine(
      Offset(trunk.left + 1, trunk.bottom - 2),
      Offset(trunk.center.dx, trunk.bottom - obstacle.radius * 0.12),
      Paint()
        ..color = _trunkColor
        ..strokeWidth = (obstacle.radius * 0.13).clamp(3.0, 9.0).toDouble()
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintTreeCanopy(Canvas canvas, MapObstacle obstacle) {
    final center = obstacle.position - Offset(0, obstacle.radius * 0.35);
    canvas.drawCircle(center, obstacle.radius, Paint()..color = _treeColor);
    final canopyHighlight = Rect.fromCenter(
      center: center + Offset(-obstacle.radius * 0.22, -obstacle.radius * 0.18),
      width: obstacle.radius * 0.92,
      height: obstacle.radius * 0.48,
    );
    canvas.drawOval(
      canopyHighlight,
      Paint()
        ..shader = ui.Gradient.linear(
          canopyHighlight.topLeft,
          canopyHighlight.bottomRight,
          [
            Color.lerp(_treeColor, _treeLightColor, 0.62)!,
            Color.lerp(_treeColor, _treeLightColor, 0.22)!,
            Color.lerp(_treeColor, Colors.black, 0.12)!,
          ],
          const [0.0, 0.58, 1.0],
        ),
    );
    canvas.drawCircle(
      center + Offset(obstacle.radius * 0.48, obstacle.radius * 0.28),
      obstacle.radius * 0.19,
      Paint()..color = Color.lerp(_treeColor, Colors.black, 0.16)!,
    );
  }

  void _paintTreeCanopyUpperLobe(Canvas canvas, MapObstacle obstacle) {
    final center =
        obstacle.position - Offset(obstacle.radius * 0.35, obstacle.radius * 0.6);
    canvas.drawCircle(
      center,
      obstacle.radius * 0.55,
      Paint()..color = _treeLightColor,
    );
    canvas.drawCircle(
      center - Offset(obstacle.radius * 0.12, obstacle.radius * 0.13),
      obstacle.radius * 0.17,
      Paint()..color = Color.lerp(_treeLightColor, Colors.white, 0.16)!,
    );
  }

  void _paintObstacle(Canvas canvas, MapObstacle obstacle) {
    final rect = Rect.fromCenter(
      center: obstacle.position,
      width: obstacle.radius * 1.9,
      height: obstacle.radius * 1.5,
    );
    final rock = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(obstacle.radius * 0.5),
      topRight: Radius.circular(obstacle.radius * 0.7),
      bottomRight: Radius.circular(obstacle.radius * 0.4),
      bottomLeft: Radius.circular(obstacle.radius * 0.6),
    );
    canvas.drawRRect(
      rock.shift(Offset(0, obstacle.radius * 0.08)),
      Paint()..color = const Color(0x55301F19),
    );
    canvas.drawRRect(rock, Paint()..color = _rockColor);
    final facet = Path()
      ..moveTo(rect.left + obstacle.radius * 0.28, rect.top + obstacle.radius * 0.2)
      ..lineTo(rect.center.dx + obstacle.radius * 0.05, rect.top + obstacle.radius * 0.12)
      ..lineTo(rect.center.dx - obstacle.radius * 0.12, rect.center.dy)
      ..lineTo(rect.left + obstacle.radius * 0.18, rect.center.dy + obstacle.radius * 0.12)
      ..close();
    canvas.drawPath(
      facet,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left, rect.top),
          Offset(rect.right, rect.bottom),
          [
            Color.lerp(_rockLightColor, Colors.white, 0.12)!,
            _rockLightColor,
            Color.lerp(_rockLightColor, Colors.black, 0.18)!,
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    // Two smaller facets and a narrow highlight create a chipped stone face
    // while keeping the original obstacle footprint and collision radius.
    final lowerFacet = Path()
      ..moveTo(rect.left + obstacle.radius * 0.18, rect.center.dy + obstacle.radius * 0.12)
      ..lineTo(rect.center.dx - obstacle.radius * 0.12, rect.center.dy)
      ..lineTo(rect.right - obstacle.radius * 0.22, rect.bottom - obstacle.radius * 0.16)
      ..lineTo(rect.left + obstacle.radius * 0.34, rect.bottom - obstacle.radius * 0.12)
      ..close();
    canvas.drawPath(lowerFacet,
        Paint()..color = Color.lerp(_rockColor, Colors.black, 0.12)!);
    final glint = Path()
      ..moveTo(rect.left + obstacle.radius * 0.32, rect.top + obstacle.radius * 0.25)
      ..lineTo(rect.center.dx + obstacle.radius * 0.02, rect.top + obstacle.radius * 0.20)
      ..lineTo(rect.center.dx - obstacle.radius * 0.10, rect.center.dy - obstacle.radius * 0.05);
    canvas.drawPath(glint,
        Paint()..color = const Color(0x668F999A)..style = PaintingStyle.stroke
          ..strokeWidth = (obstacle.radius * 0.055).clamp(1.2, 2.5).toDouble()
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
      Offset(rect.center.dx + obstacle.radius * 0.05, rect.top + obstacle.radius * 0.12),
      Offset(rect.right - obstacle.radius * 0.16, rect.center.dy + obstacle.radius * 0.2),
      Paint()
        ..color = Color.lerp(_rockColor, Colors.black, 0.22)!
        ..strokeWidth = (obstacle.radius * 0.045).clamp(1.2, 3.0).toDouble(),
    );
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

    // Attack telegraph stays on the ground plane so nearby players can read
    // the threat without confusing it with the weapon trail.
    if (attackT > 0.04 && attackT < 0.96) {
      _paintMonsterAttackTelegraph(canvas, monster.type, size, accent, attackT);
    }

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

    // A short, type-coloured attack trail makes the active hit readable at
    // phone scale without changing damage timing or projectile simulation.
    if (attackT > 0.12 && attackT < 0.9) {
      _paintMonsterAttackTrail(canvas, monster.type, size, accent, attackT);
    }

    // Hit spark.
    if (flashing) {
      canvas.drawCircle(
        Offset(0, -size * 0.6),
        size * 0.5,
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
    }

    canvas.restore();

    // Ground-level motion accents make each monster role readable at the
    // same phone-scale silhouette without changing movement or hit logic.
    if (walking) {
      _paintMonsterMovementAccent(
        canvas, monster.type, monster.position, size, face, phase, accent,
      );
    }

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

  void _paintMonsterAttackTelegraph(
    Canvas canvas,
    MonsterType type,
    double size,
    Color accent,
    double attackT,
  ) {
    final windup = math.sin(attackT * math.pi).clamp(0.0, 1.0);
    final expansion = switch (type) {
      MonsterType.tank => 1.0 + windup * 0.42,
      MonsterType.runner => 0.82 + windup * 0.22,
      MonsterType.stalker => 0.92 + windup * 0.34,
      MonsterType.ranged => 1.08 + windup * 0.18,
    };
    final opacity = (0.12 + windup * 0.24).clamp(0.0, 0.36);
    final rect = Rect.fromCenter(
      center: Offset(0, size * 0.035),
      width: size * expansion,
      height: size * (0.22 + windup * 0.035),
    );
    final paint = Paint()
      ..color = Color.lerp(accent, Colors.white, 0.28)!
          .withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * (type == MonsterType.tank ? 0.045 : 0.028)
      ..strokeCap = StrokeCap.round;
    if (type == MonsterType.tank) {
      canvas.drawOval(rect, paint);
    } else {
      final sweep = type == MonsterType.stalker ? math.pi * 1.35 : math.pi * 0.92;
      final start = type == MonsterType.runner ? -0.35 : -math.pi * 0.72;
      canvas.drawArc(rect, start, sweep, false, paint);
      if (type == MonsterType.ranged) {
        canvas.drawArc(
          rect.deflate(size * 0.09),
          math.pi * 0.12,
          math.pi * 0.76,
          false,
          paint..strokeWidth = size * 0.018,
        );
      }
    }
  }

  void _paintMonsterAttackTrail(
    Canvas canvas,
    MonsterType type,
    double size,
    Color accent,
    double attackT,
  ) {
    final pulse = math.sin(attackT * math.pi).clamp(0.0, 1.0);
    final alpha = (pulse * 0.72).clamp(0.0, 0.72);
    final center = Offset(size * 0.12, -size * 0.62);
    final bounds = Rect.fromCenter(
      center: center,
      width: size * 1.02,
      height: size * 0.88,
    );
    final (sweep, stroke, copies) = switch (type) {
      MonsterType.tank => (1.55, size * 0.105, 1),
      MonsterType.runner => (1.25, size * 0.055, 1),
      MonsterType.stalker => (1.35, size * 0.06, 2),
      MonsterType.ranged => (1.1, size * 0.07, 1),
    };
    for (var index = 0; index < copies; index++) {
      final offset = index == 0 ? Offset.zero : Offset(-size * 0.12, size * 0.1);
      final rect = bounds.shift(offset);
      final start = -1.28 + index * 0.34;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = accent.withValues(alpha: alpha * (index == 0 ? 0.48 : 0.34))
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.9
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = Color.lerp(accent, Colors.white, 0.48)!
              .withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintMonsterMovementAccent(
    Canvas canvas,
    MonsterType type,
    Offset position,
    double size,
    double face,
    double phase,
    Color accent,
  ) {
    final pulse = (math.sin(phase * 2.0) + 1.0) * 0.5;
    final alpha = 0.10 + pulse * 0.10;
    switch (type) {
      case MonsterType.tank:
        // Heavy footfalls: a broad, low dust puff under the armored body.
        canvas.drawOval(
          Rect.fromCenter(
            center: position + Offset(0, size * 0.12),
            width: size * (0.72 + pulse * 0.12),
            height: size * 0.18,
          ),
          Paint()..color = const Color(0xFFB9A58B).withValues(alpha: alpha),
        );
      case MonsterType.runner:
        // Fast runner leaves two short streaks behind its travel direction.
        for (var i = 0; i < 2; i++) {
          final trail = position +
              Offset(-face * size * (0.28 + i * 0.18), size * (0.04 + i * 0.07));
          canvas.drawOval(
            Rect.fromCenter(
              center: trail,
              width: size * (0.22 - i * 0.045),
              height: size * 0.055,
            ),
            Paint()..color = accent.withValues(alpha: alpha * (1 - i * 0.28)),
          );
        }
      case MonsterType.stalker:
        // A faint cold wisp trails the skeletal blades.
        for (var i = 0; i < 3; i++) {
          final drift = math.sin(phase + i * 1.7) * size * 0.08;
          canvas.drawCircle(
            position + Offset(-face * size * (0.22 + i * 0.10) + drift,
                -size * (0.16 + i * 0.10)),
            size * (0.025 + i * 0.006),
            Paint()..color = accent.withValues(alpha: alpha * 0.8),
          );
        }
      case MonsterType.ranged:
        // Arcane hood glint marks the slower ranged unit's movement cadence.
        canvas.drawCircle(
          position + Offset(0, -size * 1.12),
          size * (0.035 + pulse * 0.018),
          Paint()..color = Color.lerp(accent, Colors.white, 0.45)!
              .withValues(alpha: alpha * 0.9),
        );
    }
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
    // Layered shoulder plates with a raised light-catching rim and rivets.
    for (final side in const [-1.0, 1.0]) {
      final plate = Offset(side * size * 0.36, -size * 0.76);
      canvas.drawCircle(plate, size * 0.17, Paint()..color = dark);
      canvas.drawCircle(
        plate.translate(0, -size * 0.012),
        size * 0.145,
        Paint()..color = accent,
      );
      canvas.drawArc(
        Rect.fromCircle(center: plate, radius: size * 0.125),
        math.pi * 1.12,
        math.pi * 0.82,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.025
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        plate + Offset(side * size * 0.075, size * 0.055),
        size * 0.022,
        Paint()..color = dark,
      );
    }
    // Belt.
    canvas.drawRect(
      Rect.fromLTWH(-size * 0.4, -size * 0.5, size * 0.8, size * 0.08),
      Paint()..color = dark,
    );
    _monsterHead(canvas, size, body, dark, accent, type: MonsterType.tank, horned: true);
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
    canvas.drawPath(scarf, Paint()..color = dark);
    final scarfTop = Path()
      ..moveTo(-size * 0.20, -size * 0.72)
      ..lineTo(-size * 0.54, -size * 0.59);
    canvas.drawPath(
      scarfTop,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.075
        ..strokeCap = StrokeCap.round,
    );
    // A small waist clasp breaks up the runner's long torso silhouette.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -size * 0.43),
          width: size * 0.13,
          height: size * 0.10,
        ),
        Radius.circular(size * 0.025),
      ),
      Paint()..color = accent,
    );
    _monsterHead(canvas, size, body, dark, accent, type: MonsterType.runner, earred: true);
  }

  void _paintStalkerBody(
    Canvas canvas,
    double size,
    Color body,
    Color dark,
    Color accent,
  ) {
    // Ivory skeleton: exposed rib cage and narrow pelvis, not a recoloured hood.
    final bone = Paint()..color = body;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -size * 0.60),
          width: size * 0.43,
          height: size * 0.30,
        ),
        Radius.circular(size * 0.11),
      ),
      bone,
    );
    canvas.drawLine(
      Offset(0, -size * 0.82),
      Offset(0, -size * 0.32),
      Paint()..color = accent..strokeWidth = size * 0.085..strokeCap = StrokeCap.round,
    );
    for (var rib = 0; rib < 3; rib++) {
      final y = -size * (0.76 - rib * 0.105);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(0, y), width: size * 0.40, height: size * 0.16),
        0, math.pi, false,
        Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = size * 0.055,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -size * 0.28), width: size * 0.26, height: size * 0.14),
      bone,
    );
    _monsterHead(canvas, size, body, dark, accent, type: MonsterType.stalker, skeletal: true);
    // A pair of short ivory blades remains visible even at arena zoom.
    for (final side in const [-1.0, 1.0]) {
      final blade = Path()
        ..moveTo(side * size * 0.24, -size * 0.47)
        ..lineTo(side * size * 0.47, -size * 0.94)
        ..lineTo(side * size * 0.34, -size * 0.42)
        ..close();
      canvas.drawPath(blade, Paint()..color = accent);
    }
  }

  void _paintRangedBody(
    Canvas canvas,
    double size,
    Color body,
    Color dark,
    Color accent,
  ) {
    final hood = Path()
      ..moveTo(-size * 0.42, -size * 0.72)
      ..quadraticBezierTo(-size * 0.48, -size * 1.22, 0, -size * 1.34)
      ..quadraticBezierTo(size * 0.48, -size * 1.22, size * 0.42, -size * 0.72)
      ..lineTo(size * 0.32, -size * 0.18)
      ..lineTo(-size * 0.32, -size * 0.18)
      ..close();
    canvas.drawPath(hood, Paint()..color = body);
    canvas.drawPath(
      Path()..moveTo(-size * 0.31, -size * 0.88)
        ..lineTo(0, -size * 1.28)..lineTo(size * 0.31, -size * 0.88)
        ..close(),
      Paint()..color = dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -size * 0.88), width: size * 0.46, height: size * 0.19),
        Radius.circular(size * 0.07),
      ),
      Paint()..color = dark,
    );
    _monsterHead(canvas, size, body, dark, accent, type: MonsterType.ranged, hooded: true);
    // A faceted hood sigil makes the caster readable from the elevated camera.
    final sigil = Path()
      ..moveTo(0, -size * 1.28)
      ..lineTo(size * 0.095, -size * 1.16)
      ..lineTo(0, -size * 1.04)
      ..lineTo(-size * 0.095, -size * 1.16)
      ..close();
    canvas.drawPath(sigil, Paint()..color = accent);
    canvas.drawCircle(
      Offset(0, -size * 1.16),
      size * 0.026,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    // Violet energy blades are the signature silhouette. Ranged combat still
    // launches the existing projectile; these blades are visual identity only.
    for (final side in const [-1.0, 1.0]) {
      final blade = Path()
        ..moveTo(side * size * 0.30, -size * 0.38)
        ..lineTo(side * size * 0.62, -size * 1.00)
        ..lineTo(side * size * 0.43, -size * 0.30)
        ..close();
      canvas.drawPath(blade, Paint()..color = accent);
      canvas.drawPath(blade, Paint()..color = accent.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  void _monsterHead(
    Canvas canvas,
    double size,
    Color body,
    Color dark,
    Color accent, {
    MonsterType type = MonsterType.runner,
    bool horned = false,
    bool earred = false,
    bool hooded = false,
    bool skeletal = false,
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
    // The skeleton has deep dark sockets; the other three keep bright eyes.
    if (skeletal) {
      canvas.drawOval(
        Rect.fromCenter(center: center + Offset(-radius * 0.34, 0), width: radius * 0.48, height: radius * 0.58),
        Paint()..color = dark,
      );
      canvas.drawOval(
        Rect.fromCenter(center: center + Offset(radius * 0.34, 0), width: radius * 0.48, height: radius * 0.58),
        Paint()..color = dark,
      );
      // A dim ember in each socket gives the skeleton a distinct face without
      // turning it into the bright-eyed living monster style.
      for (final side in const [-1.0, 1.0]) {
        canvas.drawCircle(
          center + Offset(side * radius * 0.34, 0),
          radius * 0.095,
          Paint()..color = accent.withValues(alpha: 0.92),
        );
      }
      canvas.drawArc(
        Rect.fromCenter(center: center + Offset(0, radius * 0.48), width: radius * 0.78, height: radius * 0.40),
        0, math.pi, false,
        Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = radius * 0.12,
      );
    } else {
      final eyeColor = switch (type) {
        MonsterType.runner => const Color(0xFFDDF5A8),
        MonsterType.tank => const Color(0xFFFFD58A),
        MonsterType.stalker => const Color(0xFFE7DCC8),
        MonsterType.ranged => const Color(0xFFD9A6FF),
      };
      for (final side in const [-1.0, 1.0]) {
        final eye = center + Offset(side * radius * 0.34, -radius * 0.06);
        // Brows give each small face a readable expression at arena zoom.
        final brow = Path()
          ..moveTo(eye.dx - radius * 0.19, eye.dy - radius * 0.20)
          ..quadraticBezierTo(
            eye.dx,
            eye.dy - radius * (horned ? 0.34 : 0.27),
            eye.dx + radius * 0.19,
            eye.dy - radius * 0.20,
          );
        canvas.drawPath(
          brow,
          Paint()
            ..color = dark.withValues(alpha: 0.92)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.095
            ..strokeCap = StrokeCap.round,
        );
        // Bright sclera + dark pupil + pinpoint catchlight keeps each
        // archetype's expression readable at the normal arena camera scale.
        canvas.drawCircle(eye, radius * 0.19, Paint()..color = eyeColor);
        canvas.drawCircle(
          eye + Offset(radius * 0.045, radius * 0.025),
          radius * 0.095,
          Paint()..color = const Color(0xFF24202A),
        );
        canvas.drawCircle(
          eye + Offset(-radius * 0.025, -radius * 0.035),
          radius * 0.035,
          Paint()..color = Colors.white.withValues(alpha: 0.96),
        );
        canvas.drawCircle(
          eye,
          radius * 0.34,
          Paint()
            ..color = eyeColor.withValues(alpha: 0.20)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
      // A tiny nose bridge and mouth separate the expression from the
      // hood/helmet silhouette without adding noisy face details.
      canvas.drawCircle(
        center + Offset(0, radius * 0.20),
        radius * 0.055,
        Paint()..color = Colors.white.withValues(alpha: 0.42),
      );
      canvas.drawLine(
        center + Offset(-radius * 0.20, radius * 0.43),
        center + Offset(radius * 0.20, radius * 0.43),
        Paint()
          ..color = dark.withValues(alpha: 0.90)
          ..strokeWidth = radius * 0.10
          ..strokeCap = StrokeCap.round,
      );
    }
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
        final grip = hand + Offset(size * 0.16, size * 0.02);
        final head = hand + Offset(size * 0.43, -size * 0.48);
        canvas.drawLine(grip, head, Paint()..color = const Color(0xFF4B3829)
          ..strokeWidth = size * 0.10..strokeCap = StrokeCap.round);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: head, width: size * 0.36, height: size * 0.30),
            Radius.circular(size * 0.07),
          ),
          Paint()..color = accent,
        );
        for (final side in const [-1.0, 1.0]) {
          final spike = Path()
            ..moveTo(head.dx + side * size * 0.12, head.dy - size * 0.06)
            ..lineTo(head.dx + side * size * 0.28, head.dy - size * 0.25)
            ..lineTo(head.dx + side * size * 0.22, head.dy + size * 0.04)
            ..close();
          canvas.drawPath(spike, Paint()..color = const Color(0xFFEEF0F4));
        }
      case MonsterType.runner:
        final tip = hand + Offset(size * 0.48, -size * 0.36);
        final hilt = hand + Offset(size * 0.06, size * 0.02);
        canvas.drawLine(hilt, tip, Paint()..color = const Color(0xFF6A4A2D)
          ..strokeWidth = size * 0.09..strokeCap = StrokeCap.round);
        final blade = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(hilt.dx + size * 0.06, hilt.dy - size * 0.04)
          ..lineTo(hilt.dx + size * 0.18, hilt.dy + size * 0.08)
          ..close();
        canvas.drawPath(blade, Paint()..color = const Color(0xFFE6F0E0));
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
        // Keep the reference's violet energy-blade weapon language. The
        // combat projectile is still spawned by GameWorld, not this painter.
        final blade = hand + Offset(size * 0.22, -size * 0.62);
        canvas.drawLine(hand, blade, Paint()..color = accent
          ..strokeWidth = size * 0.095..strokeCap = StrokeCap.round);
        canvas.drawLine(hand, blade, Paint()..color = const Color(0xFFF1D9FF)
          ..strokeWidth = size * 0.025..strokeCap = StrokeCap.round);
    }
    // A leather hand-wrap and metal cuff visually connect every weapon to
    // its wielder; these are purely painter details, not extra hitboxes.
    canvas.drawCircle(
      hand,
      size * 0.105,
      Paint()..color = const Color(0xFF382B28),
    );
    canvas.drawArc(
      Rect.fromCircle(center: hand, radius: size * 0.12),
      -math.pi * 0.82,
      math.pi * 0.64,
      false,
      Paint()
        ..color = Color.lerp(accent, Colors.white, 0.30)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.035,
    );
    canvas.drawLine(
      hand + Offset(-size * 0.055, -size * 0.025),
      hand + Offset(size * 0.055, size * 0.025),
      Paint()
        ..color = const Color(0xFFB99A70)
        ..strokeWidth = size * 0.018
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintMonsterBar(
    Canvas canvas,
    EnemyState monster,
    Color color, {
    required double topY,
    required double width,
  }) {
    final ratio = monster.hpRatio.clamp(0.0, 1.0).toDouble();
    final left = monster.position.dx - width / 2;
    // Critical health gets a restrained pulse outside the bar frame. Keep it
    // behind the dark border so it reads as a warning, not as extra HP fill.
    if (ratio > 0 && ratio <= 0.2) {
      final pulse = 0.14 + (math.sin(world.nowMs / 115).abs() * 0.12);
      final warning = RRect.fromRectAndRadius(
        Rect.fromLTWH(left - 3, topY - 3, width + 6, 10.5),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        warning,
        Paint()
          ..color = const Color(0xFFFF493F).withValues(alpha: pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(left - 1, topY - 1, width + 2, 6.5),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      outer,
      Paint()..color = const Color(0xE6000000),
    );
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, topY, width, 4.5),
      const Radius.circular(2),
    );
    canvas.drawRRect(track, Paint()..color = const Color(0xFF342C2B));
    if (ratio > 0) {
      final fillColor = Color.lerp(
        const Color(0xFFFF654F),
        color,
        (ratio / 0.35).clamp(0.0, 1.0).toDouble(),
      )!;
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, topY, width * ratio, 4.5),
        const Radius.circular(2),
      );
      canvas.drawRRect(fill, Paint()..color = fillColor);
      // A thin top glint gives the bar a beveled, game-UI finish.
      canvas.drawLine(
        Offset(left + 1, topY + 0.7),
        Offset(left + width * ratio - 1, topY + 0.7),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..strokeWidth = 0.65
          ..strokeCap = StrokeCap.round,
      );
      if (monster.type == MonsterType.tank) {
        // Three rivet marks make the heavy unit's long health bar read as
        // plated armour rather than a generic enemy bar.
        for (var plate = 1; plate <= 3; plate++) {
          final x = left + width * plate / 4;
          if (x > left + width * ratio) continue;
          canvas.drawLine(
            Offset(x, topY + 0.6),
            Offset(x, topY + 3.9),
            Paint()
              ..color = const Color(0xAA252D38)
              ..strokeWidth = 1.1,
          );
        }
      }
    }
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

  void _paintProjectile(Canvas canvas, ProjectileState projectile) {
      if (projectile.velocity.distance < 0.001) return;
      final dir = projectile.velocity / projectile.velocity.distance;
      final perpendicular = Offset(-dir.dy, dir.dx);
      final length = projectile.big ? 30.0 : 22.0;
      final visualPosition = projectile.visualPosition;
      final tail = visualPosition - dir * length;
      final tint = Color(projectile.tint);
      final glow = Paint()
        ..color = tint.withValues(alpha: 0.28)
        ..strokeWidth = projectile.big ? 18 : 13
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawLine(tail, visualPosition, glow);
      final edge = Paint()
        ..color = tint.withValues(alpha: 0.92)
        ..strokeWidth = projectile.big ? 7 : 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, visualPosition, edge);
      final core = Paint()
        ..color = Color.lerp(tint, Colors.white, 0.68)!
        ..strokeWidth = projectile.big ? 2.8 : 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, visualPosition, core);
      // Arrow head.
      final head = Paint()..color = tint;
      final tip = visualPosition + dir * 5;
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

    final image = presentation.heroSpriteApproved
        ? presentation.sheet?.image
        : null;
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

    // Keep the 2.5D sprite at the same 120 logical-pixel draw height used
    // by the approved arena composition; the full 800×450 capture confirms
    // this gives Shadow a readable on-screen size without crowding crystals.
    const drawHeight = 120.0;
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
      _withUprightGroundActor(canvas, position, () {
        canvas.drawParagraph(
          paragraph,
          position - const Offset(80, 0),
        );
      });
    }
  }

  static double _angleOf(Offset v) => math.atan2(v.dy, v.dx);

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
