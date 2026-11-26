import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../world/arena_map.dart' show enemyVisibleRadius;
import 'arena_3d_asset_layer.dart';

/// Snapshot-driven oblique arena projection.
///
/// The server owns all world positions and map geometry. This widget only
/// projects and paints those values; it never simulates movement or combat.
class ArenaBattlefield extends StatelessWidget {
  const ArenaBattlefield({
    super.key,
    required this.snapshot,
    required this.localPlayerId,
  });

  final Map<String, dynamic> snapshot;
  final String localPlayerId;

  @override
  Widget build(BuildContext context) {
    final world = snapshot['world'];
    final hasWorld = world is Map &&
        world['size'] is Map &&
        (world['size']['width'] is num) &&
        (world['size']['height'] is num) &&
        (world['size']['width'] as num) > 0 &&
        (world['size']['height'] as num) > 0;
    final waitingLabel = world == null
        ? 'بانتظار بيانات ساحة المعركة'
        : 'بيانات الخريطة غير مكتملة';
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF17271F)),
          child: hasWorld
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _ArenaPainter(snapshot, localPlayerId),
                      child: const SizedBox.expand(),
                    ),
                    Positioned.fill(
                      child: Arena3DAssetLayer(
                        snapshot: snapshot,
                        localPlayerId: localPlayerId,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    waitingLabel,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter(this.snapshot, this.localPlayerId);

  final Map<String, dynamic> snapshot;
  final String localPlayerId;

  static const _playerColors = <String, Color>{
    'ranger': Color(0xFF9BE845),
    'flame': Color(0xFFFF8A24),
    'shadow': Color(0xFFB98CF0),
    'storm': Color(0xFF48C8FF),
  };

  Map? _map(Object? value) => value is Map ? value : null;
  List _list(Object? value) => value is List ? value : const [];

  double? _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  Offset? _point(Object? value) {
    final map = _map(value);
    if (map == null) return null;
    final x = _number(map['x']);
    final y = _number(map['y']);
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Color _ownerColor(String? id, Map<String, dynamic> state) {
    final players = _list(state['players']);
    for (final player in players) {
      final data = _map(player);
      if (data?['id'] == id || data?['playerId'] == id) {
        return _playerColors[data?['heroId']] ?? const Color(0xFFE7D7B5);
      }
    }
    final index = players.indexWhere((p) =>
        _map(p)?['id'] == id || _map(p)?['playerId'] == id);
    const palette = [
      Color(0xFF9BE845),
      Color(0xFFFF8A24),
      Color(0xFFB98CF0),
      Color(0xFF48C8FF),
    ];
    return index >= 0 ? palette[index % palette.length] : const Color(0xFFE7D7B5);
  }

  Offset _screen(
    Offset world,
    Size size,
    Size worldSize,
    Offset cameraOrigin,
  ) {
    // The arena map is larger than the visible camera window. Follow the
    // local hero with a 960x540 world-unit viewport, matching the game's
    // landscape battle camera rather than shrinking the entire map to fit.
    const cameraWidth = 960.0;
    const cameraHeight = 540.0;
    final scale = math.min(
      size.width / cameraWidth,
      size.height / (cameraHeight * 0.82),
    );
    final projectedX = (world.dx - cameraOrigin.dx) * scale;
    final projectedY = (world.dy - cameraOrigin.dy) * scale * 0.82;
    return Offset(projectedX, projectedY);
  }

  Offset _cameraOrigin(Map world, Size worldSize, Size viewport) {
    const cameraWidth = 960.0;
    const projectionYScale = 0.82;
    final scale = math.min(
      viewport.width / cameraWidth,
      viewport.height / (540.0 * projectionYScale),
    );
    final visibleWidth = viewport.width / scale;
    final visibleHeight = viewport.height / (scale * projectionYScale);
    final positions = _map(world['playerPositions']);
    final localPosition = _point(positions?[localPlayerId]);
    final focus = localPosition ?? Offset(worldSize.width / 2, worldSize.height / 2);
    final left = (focus.dx - visibleWidth / 2)
        .clamp(0.0, math.max(0.0, worldSize.width - visibleWidth))
        .toDouble();
    final top = (focus.dy - visibleHeight / 2)
        .clamp(0.0, math.max(0.0, worldSize.height - visibleHeight))
        .toDouble();
    return Offset(left, top);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final world = _map(snapshot['world']);
    if (world == null) {
      _drawCenteredLabel(canvas, size, 'بانتظار بيانات ساحة المعركة');
      return;
    }
    final mapSize = _map(world['size']);
    final width = _number(mapSize?['width']);
    final height = _number(mapSize?['height']);
    if (width == null || height == null || width <= 0 || height <= 0) {
      _drawCenteredLabel(canvas, size, 'بيانات الخريطة غير مكتملة');
      return;
    }
    final worldSize = Size(width, height);
    final cameraOrigin = _cameraOrigin(world, worldSize, size);
    Offset project(Offset point) =>
        _screen(point, size, worldSize, cameraOrigin);
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF344F38),
            Color(0xFF263F30),
            Color(0xFF1D3429),
          ],
        ).createShader(bounds),
    );
    // Real elevated mesh facets are rendered before gameplay overlays so
    // rivers, bridges, castles and actors remain readable and authoritative.
    _drawBaseTerrainMesh(canvas, world, worldSize, cameraOrigin, size, project);
    _drawTerrain3D(canvas, world, project);
    _drawBiomes(canvas, world, project);
    _drawTerrainTexture(canvas, world, cameraOrigin, project);
    _drawRivers(canvas, world, project);
    _drawObstacles(canvas, world, project);
    _drawPickups(canvas, world, project);
    _drawMines(canvas, world, project);
    _drawCastles(canvas, world, project);
    _drawFogOfWar(canvas, world, project, bounds);
    _drawProjectiles(canvas, snapshot, project);
    _drawMinimap(canvas, snapshot, worldSize, cameraOrigin, size);
    canvas.restore();
  }



  /// Continuous triangulated ground surface across the full procedural map.
  /// The height function is deterministic and derived from world coordinates
  /// plus the authored biome patches, so it never changes gameplay positions.
  void _drawBaseTerrainMesh(
    Canvas canvas,
    Map world,
    Size worldSize,
    Offset cameraOrigin,
    Size viewport,
    Offset Function(Offset) project,
  ) {
    const cell = 64.0;
    const base = Color(0xFF426B43);
    const light = Color(0xFF52794A);
    const shade = Color(0xFF345B3C);
    const palettes = <String, List<Color>>{
      'forest': [Color(0xFF426B43), Color(0xFF52794A), Color(0xFF345B3C)],
      'desert': [Color(0xFFB9955C), Color(0xFFD1B477), Color(0xFF8E7048)],
      'snow': [Color(0xFFB8D0D7), Color(0xFFE1EDF0), Color(0xFF8EAAB4)],
      'volcanic': [Color(0xFF69483E), Color(0xFF8B5B48), Color(0xFF493832)],
    };
    final biomes = _list(world['biomes']).map(_map).whereType<Map>().toList();
    double heightAt(Offset point) {
      var height = 3.0 +
          math.sin(point.dx * 0.0061) * 3.0 +
          math.cos(point.dy * 0.0073) * 2.6 +
          math.sin((point.dx + point.dy) * 0.0037) * 2.0;
      for (final biome in biomes) {
        final center = _point(biome);
        final radius = _number(biome['radius']);
        if (center == null || radius == null || radius <= 0) continue;
        final distance = (point - center).distance / radius;
        if (distance >= 1) continue;
        final ridge = math.cos(distance * math.pi * 0.5);
        height += 8.0 * ridge * ridge;
      }
      return height.clamp(0.0, 20.0).toDouble();
    }


    Path triangle(Offset a, Offset b, Offset d) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
    Offset vertex(double x, double y) {
      final point = Offset(x, y);
      return project(point) + Offset(0, -heightAt(point));
    }

    const projectionYScale = 0.82;
    final scale = math.min(
      viewport.width / 960.0,
      viewport.height / (540.0 * projectionYScale),
    );
    final visibleWidth = viewport.width / scale;
    final visibleHeight = viewport.height / (scale * projectionYScale);
    final firstX = math.max(0, (cameraOrigin.dx / cell).floor() - 1).toInt();
    final firstY = math.max(0, (cameraOrigin.dy / cell).floor() - 1).toInt();
    final lastX = math.min((worldSize.width / cell).ceil(),
        ((cameraOrigin.dx + visibleWidth) / cell).ceil() + 1).toInt();
    final lastY = math.min((worldSize.height / cell).ceil(),
        ((cameraOrigin.dy + visibleHeight) / cell).ceil() + 1).toInt();
    for (var row = firstY; row < lastY; row++) {
      for (var column = firstX; column < lastX; column++) {
        final x = (column * cell).toDouble();
        final y = (row * cell).toDouble();
        final x1 = math.min(x + cell, worldSize.width).toDouble();
        final y1 = math.min(y + cell, worldSize.height).toDouble();
        final a = vertex(x, y);
        final b = vertex(x1, y);
        final d = vertex(x1, y1);
        final e = vertex(x, y1);
        final center = Offset((x + x1) * 0.5, (y + y1) * 0.5);
        final palette = palettes.entries.firstWhere(
          (entry) => entry.key == _biomeKindAt(center, biomes),
          orElse: () => MapEntry('forest', [base, light, shade]),
        ).value;
        final slope = (heightAt(Offset(x1, y1)) - heightAt(Offset(x, y))) / cell;
        final first = slope > 0.06 ? palette[2] : palette[0];
        final second = slope < -0.06 ? palette[2] : palette[1];
        canvas.drawPath(triangle(a, b, d), Paint()..color = first);
        canvas.drawPath(triangle(a, d, e), Paint()..color = second);
        canvas.drawPath(triangle(a, b, d), Paint()
          ..color = const Color(0x12312A22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.45);
      }
    }
  }

  String _biomeKindAt(Offset point, List<Map> biomes) {
    for (final biome in biomes) {
      final center = _point(biome);
      final radius = _number(biome['radius']);
      if (center != null && radius != null &&
          (point - center).distance <= radius) {
        return biome['kind']?.toString() ?? 'forest';
      }
    }
    return 'forest';
  }

  /// Software-rendered 3D terrain mesh. Each biome is built from lit triangular
  /// faces with explicit world height; it is not a flat tinted circle.
  /// Simulation coordinates stay unchanged and all gameplay overlays are
  /// painted afterwards using the same ground projection.
  void _drawTerrain3D(
    Canvas canvas,
    Map world,
    Offset Function(Offset) project,
  ) {
    const segmentCount = 28;
    const palettes = <String, List<Color>>{
      'forest': [Color(0xFF557C43), Color(0xFF315D3B), Color(0xFF24452F)],
      'desert': [Color(0xFFD5B16C), Color(0xFFB8874D), Color(0xFF8B603D)],
      'snow': [Color(0xFFDDEAF0), Color(0xFF9FBCC9), Color(0xFF718E9D)],
      'volcanic': [Color(0xFF805044), Color(0xFF563A35), Color(0xFF342B2A)],
    };
    Offset elevated(Offset point, double height) =>
        project(point) + Offset(0, -height);
    Path triangle(Offset a, Offset b, Offset c) =>
        Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy)..close();

    for (final raw in _list(world['biomes'])) {
      final biome = _map(raw);
      if (biome == null) continue;
      final center = _point(biome);
      final radius = _number(biome['radius']);
      if (center == null || radius == null || radius < 48) continue;
      final kind = biome['kind']?.toString() ?? 'forest';
      final palette = palettes[kind] ?? palettes['forest']!;
      final phase = (biome['seed'] is num ? (biome['seed'] as num).toDouble() : center.dx * 0.013 + center.dy * 0.017);
      final heights = <double>[0, radius * 0.075, radius * 0.13, radius * 0.045];
      final radii = <double>[0.0, 0.34, 0.72, 1.0];

      // Exposed cliff wall: dark vertical side faces create real depth.
      for (var i = 0; i < segmentCount; i++) {
        final a0 = i * math.pi * 2 / segmentCount;
        final a1 = (i + 1) * math.pi * 2 / segmentCount;
        final wobble0 = 1 + 0.035 * math.sin(a0 * 5 + phase);
        final wobble1 = 1 + 0.035 * math.sin(a1 * 5 + phase);
        final p0 = center + Offset(math.cos(a0), math.sin(a0)) * radius * wobble0;
        final p1 = center + Offset(math.cos(a1), math.sin(a1)) * radius * wobble1;
        final top0 = elevated(p0, heights.last);
        final top1 = elevated(p1, heights.last);
        final foot0 = project(p0);
        final foot1 = project(p1);
        final side = Path()
          ..moveTo(foot0.dx, foot0.dy)
          ..lineTo(foot1.dx, foot1.dy)
          ..lineTo(top1.dx, top1.dy)
          ..lineTo(top0.dx, top0.dy)
          ..close();
        final shade = i % 3 == 0 ? palette[2] : palette[1];
        canvas.drawPath(side, Paint()..color = shade);
        canvas.drawLine(top0, top1, Paint()
          ..color = palette[0].withAlpha(0xAA)
          ..strokeWidth = 1.1);
      }

      // Concentric triangulated rings. Each vertex has a distinct elevation;
      // directional face shading makes the mesh read as a sculpted landform.
      for (var ring = 0; ring < radii.length - 1; ring++) {
        for (var i = 0; i < segmentCount; i++) {
          final a0 = i * math.pi * 2 / segmentCount;
          final a1 = (i + 1) * math.pi * 2 / segmentCount;
          Offset vertex(double angle, double radial, double baseHeight) {
            final ridge = 1 + 0.035 * math.sin(angle * 5 + phase) +
                0.018 * math.cos(angle * 9 - phase);
            final point = center + Offset(math.cos(angle), math.sin(angle)) *
                (radius * radial * ridge);
            final local = (math.sin(angle * 3 + phase) + 1) * 0.5;
            return elevated(point, baseHeight * (0.82 + local * 0.18));
          }
          final a = vertex(a0, radii[ring], heights[ring]);
          final b = vertex(a1, radii[ring], heights[ring]);
          final c0 = vertex(a0, radii[ring + 1], heights[ring + 1]);
          final d = vertex(a1, radii[ring + 1], heights[ring + 1]);
          final tint = (i + ring * 2) % 5;
          final faceColor = tint == 0 ? palette[0] : tint == 1 ? palette[1] : palette[0].withBlue((palette[0].blue + 8).clamp(0,255).toInt());
          canvas.drawPath(triangle(a, c0, d), Paint()..color = faceColor);
          canvas.drawPath(triangle(a, d, b), Paint()..color = palette[1].withAlpha(0xD8));
          canvas.drawPath(triangle(a, c0, d), Paint()
            ..color = const Color(0x183D3025)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.65);
        }
      }

      // Small raised stone outcrops sit on the landform as faceted mesh peaks.
      for (var rock = 0; rock < 7; rock++) {
        final angle = rock * 2.399963229728653 + phase;
        final distance = radius * (0.25 + (rock % 3) * 0.19);
        final point = center + Offset(math.cos(angle), math.sin(angle)) * distance;
        final base = project(point);
        final scale = math.max(2.5, radius * 0.035);
        final peak = base + Offset(0, -scale * (1.7 + (rock % 3) * 0.35));
        final left = base + Offset(-scale, -scale * 0.45);
        final right = base + Offset(scale, -scale * 0.45);
        final back = base + Offset(0, -scale * 0.9);
        canvas.drawPath(triangle(left, back, peak), Paint()..color = palette[0]);
        canvas.drawPath(triangle(back, right, peak), Paint()..color = palette[1]);
        canvas.drawPath(triangle(left, right, base), Paint()..color = palette[2]);
      }
    }
  }

  void _drawBiomes(Canvas canvas, Map world, Offset Function(Offset) project) {
    // Biomes tint the terrain subtly instead of appearing as hard-edged
    // translucent discs. Their falloff keeps the battlefield readable while
    // still distinguishing forest, desert, snow and volcanic regions.
    const colors = {
      'forest': Color(0x263B7846),
      'desert': Color(0x24C59A52),
      'snow': Color(0x259AB9C7),
      'volcanic': Color(0x267A3830),
    };
    for (final raw in _list(world['biomes'])) {
      final biome = _map(raw);
      if (biome == null) continue;
      final center = _point(biome);
      final radius = _number(biome['radius']);
      if (center == null || radius == null || radius <= 0) continue;
      final p = project(center);
      final scaleRadius = (project(center + Offset(radius, 0)) - p).distance;
      if (!scaleRadius.isFinite || scaleRadius <= 0) continue;
      final color = colors[biome['kind']] ?? const Color(0x223F6044);
      final bounds = Rect.fromCircle(center: p, radius: scaleRadius);
      canvas.drawCircle(
        p,
        scaleRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color,
              color.withAlpha(0x18),
              color.withAlpha(0),
            ],
            stops: const [0, 0.72, 1],
          ).createShader(bounds),
      );
      // Small biome-specific ground marks make each region feel distinct
      // without drawing a solid colored boundary over tactical objects.
      final kind = biome['kind']?.toString();
      for (var mark = 0; mark < 14; mark++) {
        final angle = mark * 2.399963229728653;
        final distance = scaleRadius * (0.18 + (mark % 5) * 0.13);
        final point = p + Offset(math.cos(angle), math.sin(angle)) * distance;
        switch (kind) {
          case 'forest':
            canvas.drawOval(
              Rect.fromCenter(
                center: point,
                width: 5.5,
                height: 2.6,
              ),
              Paint()..color = const Color(0x335A9654),
            );
            break;
          case 'desert':
            canvas.drawLine(
              point.translate(-3, 1),
              point.translate(3, -1),
              Paint()
                ..color = const Color(0x447E6540)
                ..strokeWidth = 1.2
                ..strokeCap = StrokeCap.round,
            );
            break;
          case 'snow':
            canvas.drawCircle(
              point,
              1.5,
              Paint()..color = const Color(0x66E4F2F5),
            );
            break;
          case 'volcanic':
            canvas.drawCircle(
              point,
              1.6,
              Paint()..color = const Color(0x669A5137),
            );
            break;
        }
      }
    }
  }

  /// Adds deterministic, camera-stable ground detail without introducing
  /// textures, random state, or per-frame allocations outside the visible map.
  /// Every mark is derived from its world-grid coordinate, so the terrain
  /// appears anchored while the follow camera moves.
  void _drawTerrainTexture(
    Canvas canvas,
    Map world,
    Offset cameraOrigin,
    Offset Function(Offset) project,
  ) {
    // A deterministic 32-unit ground grid keeps biome detail anchored to
    // world space while remaining stable as the follow camera moves.
    const cell = 32.0;
    const columns = 34;
    const rows = 22;
    final biomes = _list(world['biomes'])
        .map(_map)
        .whereType<Map>()
        .map((biome) => (
              kind: biome['kind']?.toString() ?? 'forest',
              center: _point(biome),
              radius: _number(biome['radius']) ?? 0,
            ))
        .where((biome) => biome.center != null && biome.radius > 0)
        .toList(growable: false);
    final startX = (cameraOrigin.dx / cell).floor() - 1;
    final startY = (cameraOrigin.dy / cell).floor() - 1;
    for (var gy = startY; gy < startY + rows; gy++) {
      for (var gx = startX; gx < startX + columns; gx++) {
        final seed = (gx * 73856093) ^ (gy * 19349663);
        final x = gx * cell + 5 + (seed.abs() % 21).toDouble();
        final y = gy * cell + 5 + ((seed >> 5).abs() % 21).toDouble();
        final worldPoint = Offset(x, y);
        final point = project(worldPoint);
        final variant = seed.abs() % 9;
        var biomeKind = 'forest';
        var nearestDistance = double.infinity;
        for (final biome in biomes) {
          final center = biome.center!;
          final distance = (worldPoint - center).distanceSquared;
          if (distance <= biome.radius * biome.radius &&
              distance < nearestDistance) {
            nearestDistance = distance;
            biomeKind = biome.kind;
          }
        }
        final patchRect = Rect.fromCenter(
          center: point,
          width: 18 + (variant % 4) * 4.0,
          height: 8 + (variant % 3) * 3.0,
        );

        switch (biomeKind) {
          case 'desert':
            if (variant == 0 || variant == 4 || variant == 7) {
              canvas.drawOval(
                patchRect,
                Paint()..color = const Color(0x2BC9A66A),
              );
            }
            if (variant == 1 || variant == 5) {
              for (var ripple = 0; ripple < 2; ripple++) {
                final yOffset = (ripple - 0.5) * 3.2;
                canvas.drawLine(
                  point.translate(-5, yOffset),
                  point.translate(4, yOffset - 1.2),
                  Paint()
                    ..color = const Color(0x557B6748)
                    ..strokeWidth = 0.8
                    ..strokeCap = StrokeCap.round,
                );
              }
            } else if (variant == 2 || variant == 8) {
              canvas.drawOval(
                Rect.fromCenter(
                  center: point.translate(1, 1),
                  width: 5.5,
                  height: 3.0,
                ),
                Paint()..color = const Color(0x887D7462),
              );
            }
            break;
          case 'snow':
            if (variant == 0 || variant == 4 || variant == 7) {
              canvas.drawOval(
                patchRect,
                Paint()..color = const Color(0x338BC2D4),
              );
            }
            if (variant == 1 || variant == 5 || variant == 8) {
              canvas.drawCircle(
                point,
                1.5 + (variant % 2) * 0.6,
                Paint()..color = const Color(0x99E8F7FC),
              );
              canvas.drawLine(
                point.translate(-3, 0),
                point.translate(3, 0),
                Paint()
                  ..color = const Color(0x668BC5D8)
                  ..strokeWidth = 0.8,
              );
            }
            break;
          case 'volcanic':
            if (variant == 0 || variant == 4 || variant == 7) {
              canvas.drawOval(
                patchRect,
                Paint()..color = const Color(0x443E302C),
              );
            }
            if (variant == 1 || variant == 5) {
              final crack = Path()
                ..moveTo(point.dx - 5, point.dy - 2)
                ..lineTo(point.dx - 1, point.dy + 1)
                ..lineTo(point.dx + 1, point.dy - 1)
                ..lineTo(point.dx + 5, point.dy + 2);
              canvas.drawPath(
                crack,
                Paint()
                  ..color = const Color(0x887D5140)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.1
                  ..strokeCap = StrokeCap.round,
              );
            } else if (variant == 2 || variant == 8) {
              canvas.drawCircle(
                point,
                1.4,
                Paint()..color = const Color(0xAAE18A48),
              );
            }
            break;
          default:
            if (variant == 0 || variant == 4 || variant == 7) {
              canvas.drawOval(
                patchRect,
                Paint()
                  ..shader = RadialGradient(
                    colors: [
                      const Color(0x554A9654),
                      const Color(0x004A9654),
                    ],
                  ).createShader(patchRect),
              );
            }
            if (variant == 1 || variant == 5) {
              for (var blade = 0; blade < 4; blade++) {
                final bx = point.dx + (blade - 1.5) * 2.6;
                canvas.drawLine(
                  Offset(bx, point.dy + 2),
                  Offset(bx - 1.0, point.dy - 2.5 - (blade % 2)),
                  Paint()
                    ..color = const Color(0x775C9656)
                    ..strokeWidth = 1.0
                    ..strokeCap = StrokeCap.round,
                );
              }
            } else if (variant == 2) {
              canvas.drawLine(
                point.translate(0, 2),
                point.translate(0, -2),
                Paint()
                  ..color = const Color(0x775E8A4D)
                  ..strokeWidth = 1,
              );
              canvas.drawCircle(
                point.translate(-2, -2),
                1.2,
                Paint()..color = const Color(0xBBF0D58B),
              );
              canvas.drawCircle(
                point.translate(2, -2),
                1.2,
                Paint()..color = const Color(0xBBE7B9C5),
              );
            } else if (variant == 3 || variant == 6 || variant == 8) {
              canvas.drawOval(
                Rect.fromCenter(
                  center: point.translate(1, 1),
                  width: 5.5,
                  height: 3.2,
                ),
                Paint()..color = const Color(0x557C806F),
              );
            }
            break;
        }
      }
    }
  }

  void _drawRivers(Canvas canvas, Map world, Offset Function(Offset) project) {
    for (final raw in _list(world['rivers'])) {
      final river = _map(raw);
      if (river == null) continue;
      final points = _list(river['points']).map(_point).whereType<Offset>().toList();
      if (points.length < 2) continue;
      final path = Path()..moveTo(project(points.first).dx, project(points.first).dy);
      for (final point in points.skip(1)) {
        final p = project(point);
        path.lineTo(p.dx, p.dy);
      }
      final width = _number(river['width']) ?? 70;
      final start = project(points.first);
      final end = project(points.last);
      final projectedWidth = (project(points.first + Offset(width, 0)) - start).distance;
      // Raised banks follow each river segment as shallow extruded channel
      // walls. They sit below the water fill and create a readable shoreline.
      for (var bankSegment = 0; bankSegment < points.length - 1; bankSegment++) {
        final bankA = project(points[bankSegment]);
        final bankB = project(points[bankSegment + 1]);
        final bankDelta = bankB - bankA;
        final bankLength = bankDelta.distance;
        if (bankLength < 1) continue;
        final normal = Offset(-bankDelta.dy / bankLength, bankDelta.dx / bankLength);
        for (final side in [-1.0, 1.0]) {
          final innerA = bankA + normal * (projectedWidth * 0.47 * side);
          final innerB = bankB + normal * (projectedWidth * 0.47 * side);
          final outerA = bankA + normal * (projectedWidth * 0.68 * side);
          final outerB = bankB + normal * (projectedWidth * 0.68 * side);
          final topA = outerA.translate(0, -5.5);
          final topB = outerB.translate(0, -5.5);
          final bankFace = Path()
            ..moveTo(innerA.dx, innerA.dy)
            ..lineTo(innerB.dx, innerB.dy)
            ..lineTo(topB.dx, topB.dy)
            ..lineTo(topA.dx, topA.dy)
            ..close();
          canvas.drawPath(bankFace, Paint()
            ..color = side < 0
                ? const Color(0xFF6F7650)
                : const Color(0xFF536B46));
          canvas.drawLine(topA, topB, Paint()
            ..color = const Color(0xFF9AA16A)
            ..strokeWidth = 1.6);
        }
      }
      // A darker, soft bank separates the water from grass and stone.
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x66302F27)
          ..style = PaintingStyle.stroke
          ..strokeWidth = projectedWidth * 1.32
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF205B7B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = projectedWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF367FA0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = projectedWidth * 0.72
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF62B6D0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, projectedWidth * 0.12)
          ..strokeCap = StrokeCap.round,
      );
      // Wet shoreline stones and pale foam seams add scale and depth to
      // the river channel without covering the bridge deck.
      for (var segment = 0; segment < points.length - 1; segment++) {
        final a = project(points[segment]);
        final b = project(points[segment + 1]);
        final delta = b - a;
        final length = delta.distance;
        if (length < 1) continue;
        final normal = Offset(-delta.dy / length, delta.dx / length);
        for (var stone = 0; stone < 3; stone++) {
          final t = (stone * 0.31 + 0.17) % 0.86 + 0.07;
          final side = stone.isEven ? -1.0 : 1.0;
          final center = Offset.lerp(a, b, t)! +
              normal * (projectedWidth * (0.55 + (stone % 2) * 0.08) * side);
          final stoneRect = Rect.fromCenter(
            center: center.translate(0, -1.2),
            width: 3.2 + stone * 1.1,
            height: 1.8 + stone * 0.6,
          );
          canvas.drawOval(stoneRect, Paint()
            ..color = stone.isEven
                ? const Color(0xFF9A9B80)
                : const Color(0xFF6F806D));
        }
        final foamA = Offset.lerp(a, b, 0.22)! + normal * projectedWidth * 0.43;
        final foamB = Offset.lerp(a, b, 0.61)! + normal * projectedWidth * 0.43;
        canvas.drawLine(foamA, foamB, Paint()
          ..color = const Color(0x668AD8E2)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round);
      }
      // Fine, offset glints make the water read as flowing rather than a flat
      // blue stripe. Their positions are deterministic along each river.
      for (var segment = 0; segment < points.length - 1; segment++) {
        final a = project(points[segment]);
        final b = project(points[segment + 1]);
        final delta = b - a;
        final length = delta.distance;
        if (length < 1) continue;
        final normal = Offset(-delta.dy / length, delta.dx / length);
        for (var ripple = 1; ripple <= 4; ripple++) {
          final t = (segment * 0.37 + ripple * 0.19) % 0.82 + 0.08;
          final center = Offset.lerp(a, b, t)! +
              normal * ((ripple.isEven ? 1 : -1) * projectedWidth * 0.18);
          final rippleLength = math.max(3.0, projectedWidth * (0.08 + ripple * 0.012));
          canvas.drawLine(
            center - delta / length * rippleLength,
            center + delta / length * rippleLength,
            Paint()
              ..color = const Color(0x665FD0DF)
              ..strokeWidth = 1.1
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      for (final bridgeRaw in _list(river['bridges'])) {
        final bridge = _map(bridgeRaw);
        final point = _point(bridge);
        if (bridge == null || point == null) continue;
        final p = project(point);
        final bridgeWidth = _number(bridge['width']) ?? 100;
        final bridgeDepth = _number(bridge['depth']) ?? 120;
        final a = project(point + Offset(bridgeWidth / 2, bridgeDepth / 2));
        final b = project(point - Offset(bridgeWidth / 2, bridgeDepth / 2));
        final bridgeAxis = b - a;
        final bridgeLength = bridgeAxis.distance;
        final bridgeNormal = bridgeLength == 0
            ? Offset.zero
            : Offset(-bridgeAxis.dy / bridgeLength, bridgeAxis.dx / bridgeLength);
        // Extruded timber deck: four side faces and a raised top surface
        // give the crossing a visible thickness above the river.
        final halfDeck = math.max(6.0, projectedWidth * 0.24);
        final leftA = a + bridgeNormal * halfDeck;
        final rightA = a - bridgeNormal * halfDeck;
        final leftB = b + bridgeNormal * halfDeck;
        final rightB = b - bridgeNormal * halfDeck;
        Path quad(Offset p0, Offset p1, Offset p2, Offset p3) => Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();
        canvas.drawPath(
          quad(leftA.translate(0, 5), rightA.translate(0, 5),
              rightB.translate(0, 5), leftB.translate(0, 5)),
          Paint()..color = const Color(0xFF493628),
        );
        canvas.drawPath(
          quad(leftA, leftA.translate(0, 5), leftB.translate(0, 5), leftB),
          Paint()..color = const Color(0xFF60452F),
        );
        canvas.drawPath(
          quad(rightA, rightB, rightB.translate(0, 5), rightA.translate(0, 5)),
          Paint()..color = const Color(0xFF3F3026),
        );
        canvas.drawPath(
          quad(leftA, rightA, rightB, leftB),
          Paint()..color = const Color(0xFFB18455),
        );
        canvas.drawLine(leftA, leftB, Paint()
          ..color = const Color(0xFFE0BD88)
          ..strokeWidth = 1.8);
        canvas.drawLine(rightA, rightB, Paint()
          ..color = const Color(0xFF745137)
          ..strokeWidth = 1.8);
        // A dark under-shadow, timber deck, raised side rails and cross-planks
        // make bridges read as traversable structures over the river.
        canvas.drawLine(
          a.translate(0, 3),
          b.translate(0, 3),
          Paint()
            ..color = const Color(0x88302620)
            ..strokeWidth = math.max(12.0, projectedWidth * 0.58)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = const Color(0xFF8B6748)
            ..strokeWidth = math.max(10.0, projectedWidth * 0.48)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = const Color(0xFFD0AD7B)
            ..strokeWidth = math.max(6.0, projectedWidth * 0.28)
            ..strokeCap = StrokeCap.round,
        );
        if (bridgeLength > 0) {
          for (var plank = 1; plank < 8; plank++) {
            final t = plank / 8;
            final center = Offset.lerp(a, b, t)!;
            canvas.drawLine(
              center - bridgeNormal * math.max(3.0, projectedWidth * 0.19),
              center + bridgeNormal * math.max(3.0, projectedWidth * 0.19),
              Paint()
                ..color = const Color(0xAA704D35)
                ..strokeWidth = 1.1,
            );
          }
          canvas.drawLine(
            a + bridgeNormal * math.max(3.0, projectedWidth * 0.2),
            b + bridgeNormal * math.max(3.0, projectedWidth * 0.2),
            Paint()
              ..color = const Color(0xFFE0C394)
              ..strokeWidth = 1.4,
          );
          canvas.drawLine(
            a - bridgeNormal * math.max(3.0, projectedWidth * 0.2),
            b - bridgeNormal * math.max(3.0, projectedWidth * 0.2),
            Paint()
              ..color = const Color(0xFF684B35)
              ..strokeWidth = 1.4,
          );
        }
        canvas.drawCircle(p, 3, Paint()..color = const Color(0xFFE7D7B5));
      }
      // Keep local variables used for path diagnostics and avoid a false
      // assumption that river end points are screen-aligned.
      assert(start.dx.isFinite && end.dy.isFinite);
    }
  }

  void _drawObstacles(Canvas canvas, Map world, Offset Function(Offset) project) {
    for (final raw in _list(world['obstacles'])) {
      final obstacle = _map(raw);
      if (obstacle == null) continue;
      final point = _point(obstacle);
      final radius = _number(obstacle['radius']);
      if (point == null || radius == null) continue;
      final p = project(point);
      final r = math.max(4.0, (project(point + Offset(radius, 0)) - p).distance).toDouble();
      final tree = obstacle['kind'] == 'tree';
      canvas.drawOval(
        Rect.fromCenter(
          center: p + Offset(r * 0.12, r * 0.72),
          width: r * 2.15,
          height: r * 0.82,
        ),
        Paint()..color = const Color(0x55302D24),
      );
      if (tree) {
        // Faceted conifer mesh: tapered trunk, stacked polygon crowns and
        // directional light/shadow faces give the obstacle real volume.
        final trunkTop = p + Offset(0, -r * 0.95);
        final trunkBase = p + Offset(0, r * 0.28);
        final trunk = Path()
          ..moveTo(trunkBase.dx - r * 0.16, trunkBase.dy)
          ..lineTo(trunkBase.dx - r * 0.10, trunkTop.dy)
          ..lineTo(trunkBase.dx + r * 0.12, trunkTop.dy)
          ..lineTo(trunkBase.dx + r * 0.18, trunkBase.dy)
          ..close();
        canvas.drawPath(trunk, Paint()..color = const Color(0xFF63452F));
        canvas.drawPath(
          Path()
            ..moveTo(trunkTop.dx - r * 0.10, trunkTop.dy)
            ..lineTo(trunkTop.dx + r * 0.12, trunkTop.dy)
            ..lineTo(trunkBase.dx + r * 0.18, trunkBase.dy)
            ..lineTo(trunkBase.dx + r * 0.02, trunkBase.dy)
            ..close(),
          Paint()..color = const Color(0xFF9A7048),
        );
        void crown(double centerY, double width, double height, Color light, Color mid, Color shade) {
          final apex = p + Offset(0, centerY - height);
          final left = p + Offset(-width, centerY + height * 0.32);
          final right = p + Offset(width, centerY + height * 0.32);
          final front = p + Offset(0, centerY + height * 0.55);
          final crownPath = Path()
            ..moveTo(apex.dx, apex.dy)
            ..lineTo(left.dx, left.dy)
            ..lineTo(front.dx, front.dy)
            ..lineTo(right.dx, right.dy)
            ..close();
          canvas.drawPath(crownPath, Paint()..color = mid);
          canvas.drawPath(
            Path()
              ..moveTo(apex.dx, apex.dy)
              ..lineTo(left.dx, left.dy)
              ..lineTo(front.dx, front.dy)
              ..close(),
            Paint()..color = light,
          );
          canvas.drawPath(
            Path()
              ..moveTo(apex.dx, apex.dy)
              ..lineTo(front.dx, front.dy)
              ..lineTo(right.dx, right.dy)
              ..close(),
            Paint()..color = shade,
          );
          canvas.drawLine(left, front, Paint()
            ..color = light.withAlpha(0x88)
            ..strokeWidth = 1.1);
        }
        crown(-r * 0.18, r * 0.76, r * 0.92,
            const Color(0xFF78A95A), const Color(0xFF477A43), const Color(0xFF244A32));
        crown(-r * 0.62, r * 0.62, r * 0.82,
            const Color(0xFF8BBE68), const Color(0xFF568B4A), const Color(0xFF2D5A37));
        crown(-r * 1.02, r * 0.45, r * 0.72,
            const Color(0xFFA0CB78), const Color(0xFF679A54), const Color(0xFF38673D));
        canvas.drawCircle(p + Offset(-r * 0.22, -r * 1.18), r * 0.07,
            Paint()..color = const Color(0xFFD0E6A1));
      } else {
        // Angular rock mesh with separately lit facets and a darker side wall.
        final apex = p + Offset(-r * 0.12, -r * 1.12);
        final ridge = p + Offset(r * 0.42, -r * 0.58);
        final left = p + Offset(-r * 0.92, -r * 0.12);
        final right = p + Offset(r * 0.94, -r * 0.02);
        final front = p + Offset(r * 0.12, r * 0.52);
        final back = p + Offset(-r * 0.18, -r * 0.48);
        Path face(Offset a, Offset b, Offset d) => Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(d.dx, d.dy)
          ..close();
        canvas.drawPath(face(apex, left, back),
            Paint()..color = const Color(0xFFB7C0B9));
        canvas.drawPath(face(apex, back, ridge),
            Paint()..color = const Color(0xFFD4D9D3));
        canvas.drawPath(face(apex, ridge, right),
            Paint()..color = const Color(0xFF8E9992));
        canvas.drawPath(face(left, back, front),
            Paint()..color = const Color(0xFF78847D));
        canvas.drawPath(face(back, ridge, front),
            Paint()..color = const Color(0xFF69756E));
        canvas.drawPath(face(ridge, right, front),
            Paint()..color = const Color(0xFF4F5C56));
        canvas.drawLine(apex, ridge, Paint()
          ..color = const Color(0xFFE5EAE4)
          ..strokeWidth = 1.2);
      }
    }
  }

  void _drawPickups(Canvas canvas, Map world, Offset Function(Offset) project) {
    for (final raw in _list(world['mapPickups'])) {
      final pickup = _map(raw);
      if (pickup == null) continue;
      final point = _point(pickup);
      if (point == null) continue;
      final p = project(point);
      final chest = pickup['kind'] == 'chest';
      if (chest) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p.translate(0, 1), width: 14, height: 11),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0x77372A1D),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 13, height: 9),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF9A5D2D),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p.translate(0, -3), width: 14, height: 5),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFE4B34D),
        );
        canvas.drawLine(
          p.translate(-6, 0),
          p.translate(6, 0),
          Paint()..color = const Color(0xFFFFD77B)..strokeWidth = 1.3,
        );
        canvas.drawCircle(p.translate(0, 1), 1.4, Paint()..color = const Color(0xFF68401F));
      } else {
        canvas.drawCircle(p, 8, Paint()..color = const Color(0x4468D9C4));
        canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF68D9C4));
        canvas.drawCircle(p.translate(-1, -1), 1.4, Paint()..color = Colors.white);
      }
    }
    for (final raw in _list(world['resourcePickups'])) {
      final pickup = _map(raw);
      if (pickup == null) continue;
      final point = _point(pickup);
      if (point == null) continue;
      final p = project(point);
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFF67E3CE));
    }
  }

  void _drawMines(Canvas canvas, Map world, Offset Function(Offset) project) {
    for (final raw in _list(world['mines'])) {
      final mine = _map(raw);
      if (mine == null) continue;
      final point = _point(mine);
      if (point == null) continue;
      final p = project(point);
      final color = _ownerColor(mine['ownerId']?.toString(), snapshot);
      final glowRect = Rect.fromCircle(center: p, radius: 19);
      canvas.drawCircle(
        p,
        19,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withOpacity(0.30), color.withOpacity(0)],
          ).createShader(glowRect),
      );
      canvas.drawCircle(p.translate(0, 1.5), 13, Paint()..color = const Color(0x77302B25));
      canvas.drawCircle(
        p,
        10,
        Paint()
          ..color = const Color(0xFF292B2A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(p, 7.5, Paint()..color = color.withOpacity(0.75));
      canvas.drawCircle(p.translate(-2, -2), 2.2, Paint()..color = const Color(0xAAFFFFFF));
      final capture = (_number(mine['captureFraction']) ?? 0).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: 12),
        -math.pi / 2,
        math.pi * 2 * capture,
        false,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }


  void _drawStoneTurret(Canvas canvas, Offset base, double halfSize, double height) {
    final top = base.translate(0, -height);
    final leftBase = base + Offset(-halfSize, -halfSize * 0.35);
    final rightBase = base + Offset(halfSize, -halfSize * 0.35);
    final backBase = base + Offset(0, -halfSize * 0.72);
    final frontBase = base + Offset(0, halfSize * 0.42);
    final leftTop = top + Offset(-halfSize, -halfSize * 0.35);
    final rightTop = top + Offset(halfSize, -halfSize * 0.35);
    final backTop = top + Offset(0, -halfSize * 0.72);
    final frontTop = top + Offset(0, halfSize * 0.42);
    Path polygon(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      return path..close();
    }
    canvas.drawOval(
      Rect.fromCenter(center: base.translate(0, 2), width: halfSize * 3.2, height: halfSize * 1.25),
      Paint()..color = const Color(0x66302620),
    );
    canvas.drawPath(polygon([leftBase, frontBase, frontTop, leftTop]),
        Paint()..color = const Color(0xFF746B5D));
    canvas.drawPath(polygon([frontBase, rightBase, rightTop, frontTop]),
        Paint()..color = const Color(0xFF514B43));
    canvas.drawPath(polygon([leftTop, frontTop, rightTop, backTop]),
        Paint()..color = const Color(0xFFD1C3A8));
    canvas.drawPath(polygon([leftBase, backBase, backTop, leftTop]),
        Paint()..color = const Color(0xFF958A76));
    canvas.drawPath(polygon([backBase, rightBase, rightTop, backTop]),
        Paint()..color = const Color(0xFF665E52));
    // crenellated crown blocks sit above the roof line
    for (var merlon = 0; merlon < 4; merlon++) {
      final x = -halfSize + merlon * (halfSize * 0.66);
      final block = Rect.fromLTWH(
        top.dx + x,
        top.dy - halfSize * 0.7,
        halfSize * 0.42,
        halfSize * 0.58,
      );
      canvas.drawRect(block, Paint()..color = const Color(0xFFE0D2B8));
      canvas.drawRect(
        Rect.fromLTWH(block.left, block.top, block.width, 1.2),
        Paint()..color = const Color(0xFFFFFFFF).withAlpha(0x88),
      );
    }
    canvas.drawLine(leftTop, frontTop, Paint()
      ..color = const Color(0xFFE5D9C2)
      ..strokeWidth = 1.1);
  }

  void _drawCastles(Canvas canvas, Map world, Offset Function(Offset) project) {
    for (final raw in _list(world['castles'])) {
      final castle = _map(raw);
      if (castle == null) continue;
      final anchor = _point(castle['anchor']);
      if (anchor == null) continue;
      if (castle['fallen'] == true) continue;
      final center = project(anchor);
      final color = _ownerColor(castle['ownerId']?.toString(), snapshot);
      canvas.drawCircle(
        center,
        38,
        Paint()..color = color.withOpacity(0.12),
      );
      for (final wallRaw in _list(castle['walls'])) {
        final wall = _map(wallRaw);
        if (wall == null) continue;
        final radius = _number(wall['radius']);
        final start = _number(wall['startAngle']);
        final sweep = _number(wall['sweep']);
        if (radius == null || start == null || sweep == null) continue;
        final edge = (project(anchor + Offset(radius, 0)) - center).distance;
        final rect = Rect.fromCircle(center: center, radius: edge);
        // Extruded stone curtain wall: render a shaded vertical face beneath
        // the parapet, segmented into masonry panels along the curved rampart.
        final wallSegments = math.max(4, (sweep.abs() * radius / 24).round());
        for (var segment = 0; segment < wallSegments; segment++) {
          final a0 = start + sweep * segment / wallSegments;
          final a1 = start + sweep * (segment + 1) / wallSegments;
          final base0 = project(anchor + Offset(math.cos(a0), math.sin(a0)) * radius);
          final base1 = project(anchor + Offset(math.cos(a1), math.sin(a1)) * radius);
          final top0 = base0.translate(0, -8);
          final top1 = base1.translate(0, -8);
          final face = Path()
            ..moveTo(base0.dx, base0.dy)
            ..lineTo(base1.dx, base1.dy)
            ..lineTo(top1.dx, top1.dy)
            ..lineTo(top0.dx, top0.dy)
            ..close();
          canvas.drawPath(face, Paint()
            ..color = segment.isEven
                ? const Color(0xFF6D685F)
                : const Color(0xFF777168));
          canvas.drawLine(top0, top1, Paint()
            ..color = const Color(0xFFD1C1A2)
            ..strokeWidth = 2.2);
          if (segment % 2 == 0) {
            canvas.drawLine(base0, top0, Paint()
              ..color = const Color(0x55332E28)
              ..strokeWidth = 0.8);
          }
        }
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = const Color(0xFF827D72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = const Color(0xFFD1C1A2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        // Small merlons and warm stone highlights give each castle a readable
        // fortified silhouette even at the zoomed-out mobile camera scale.
        final merlonCount = math.max(3, (sweep.abs() * radius / 34).round());
        for (var merlon = 0; merlon <= merlonCount; merlon++) {
          final angle = start + sweep * merlon / merlonCount;
          final worldPoint = anchor +
              Offset(math.cos(angle), math.sin(angle)) * radius;
          final p = project(worldPoint);
          canvas.drawCircle(
            p.translate(0, 1.5),
            3.1,
            Paint()..color = const Color(0x77352F29),
          );
          canvas.drawCircle(
            p,
            2.4,
            Paint()..color = const Color(0xFFD6C5A5),
          );
        }
      }
      canvas.drawCircle(
        center,
        18,
        Paint()
          ..color = const Color(0xFFB7A58B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      // Four raised corner turrets and a keep make the castle read as a
      // fortified 3D structure instead of a flat circular marker.
      for (final offset in const [
        Offset(-18, -18), Offset(18, -18),
        Offset(-18, 18), Offset(18, 18),
      ]) {
        final turret = project(anchor + offset);
        _drawStoneTurret(canvas, turret, 7.0, 19.0);
      }
      _drawStoneTurret(canvas, center + const Offset(0, -5), 10.0, 28.0);
      for (final crystalRaw in _list(castle['crystals'])) {
        final crystal = _map(crystalRaw);
        if (crystal == null) continue;
        final point = _point(crystal);
        if (point == null) continue;
        final p = project(point);
        final hp = _number(crystal['hp']) ?? 0;
        final maxHp = _number(crystal['maxHp']) ?? 1;
        final fraction = (hp / maxHp).clamp(0.0, 1.0);
        if (hp > 0) {
          final glow = Rect.fromCircle(center: p, radius: 15);
          canvas.drawCircle(
            p,
            15,
            Paint()
              ..shader = RadialGradient(
                colors: [color.withOpacity(0.38), color.withOpacity(0)],
              ).createShader(glow),
          );
        }
        final path = Path()
          ..moveTo(p.dx, p.dy - 9)
          ..lineTo(p.dx + 7, p.dy - 1)
          ..lineTo(p.dx + 4, p.dy + 8)
          ..lineTo(p.dx - 4, p.dy + 8)
          ..lineTo(p.dx - 7, p.dy - 1)
          ..close();
        // A darker offset silhouette beneath the crown creates a visible
        // crystal body thickness; side facets remain distinct from the lit face.
        final lowerBody = path.shift(const Offset(2.8, 4.2));
        canvas.drawPath(lowerBody, Paint()..color = const Color(0xFF273B4A));
        final crystalSide = Path()
          ..moveTo(p.dx + 7, p.dy - 1)
          ..lineTo(p.dx + 4.8, p.dy + 12.2)
          ..lineTo(p.dx - 1.2, p.dy + 12.2)
          ..lineTo(p.dx + 4, p.dy + 8)
          ..close();
        canvas.drawPath(crystalSide, Paint()
          ..color = hp > 0 ? color.withOpacity(0.72) : const Color(0xFF393B3A));
        final crystalPaint = Paint();
        if (hp > 0) {
          crystalPaint.shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.95),
              color,
              color.withOpacity(0.55),
            ],
          ).createShader(path.getBounds());
        } else {
          crystalPaint.color = const Color(0xFF4A4540);
        }
        canvas.drawPath(path, crystalPaint);
        final facet = Path()
          ..moveTo(p.dx, p.dy - 8)
          ..lineTo(p.dx, p.dy + 7)
          ..lineTo(p.dx - 6, p.dy - 1)
          ..close();
        canvas.drawPath(facet, Paint()..color = const Color(0x66FFFFFF));
        canvas.drawRect(
          Rect.fromLTWH(p.dx - 7, p.dy - 11, 14, 2),
          Paint()..color = const Color(0xFF211F1D),
        );
        canvas.drawRect(
          Rect.fromLTWH(p.dx - 7, p.dy - 11, 14 * fraction, 2),
          Paint()..color = const Color(0xFF8DE36A),
        );
      }
    }
  }

  bool _enemyMonsterVisible(Offset point, Map world, String? ownerId) {
    if (ownerId == localPlayerId) return true;
    final positions = _map(world['playerPositions']);
    final localPosition = _point(positions?[localPlayerId]);
    // Fail closed when a snapshot has no trusted local reveal center.
    // Otherwise enemy units could be painted over the fog overlay.
    return localPosition != null &&
        (point - localPosition).distance <= enemyVisibleRadius;
  }

  /// Visually obscures terrain outside the same reveal radius enforced by
  /// the server's player-scoped snapshots. Static map geometry is still sent
  /// to clients, but it is no longer fully visible during ordinary play.
  void _drawFogOfWar(
    Canvas canvas,
    Map world,
    Offset Function(Offset) project,
    Rect bounds,
  ) {
    final positions = _map(world['playerPositions']);
    final localPosition = _point(positions?[localPlayerId]);
    if (localPosition == null) {
      // Fail closed: without a trusted local position there is no safe
      // reveal center, so do not expose the battlefield.
      canvas.drawRect(
        bounds,
        Paint()..color = const Color(0xF0000807),
      );
      return;
    }

    final center = project(localPosition);
    final radius = (project(localPosition + Offset(enemyVisibleRadius, 0)) -
            center)
        .distance;
    if (!radius.isFinite || radius <= 0) return;

    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = const Color(0xB8000807));
    canvas.drawCircle(center, radius, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0x667DCB8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawMinimap(
    Canvas canvas,
    Map<String, dynamic> state,
    Size worldSize,
    Offset cameraOrigin,
    Size viewport,
  ) {
    final world = _map(state['world']);
    if (world == null) return;
    const width = 132.0;
    const height = 74.0;
    const margin = 10.0;
    final rect = Rect.fromLTWH(
      canvas.getLocalClipBounds().width - width - margin,
      margin,
      width,
      height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()..color = const Color(0xDD101A17),
    );
    final inner = rect.deflate(5);
    canvas.drawRect(inner, Paint()..color = const Color(0xFF36513A));
    Offset miniPoint(Offset point) => Offset(
          inner.left + point.dx / worldSize.width * inner.width,
          inner.top + point.dy / worldSize.height * inner.height,
        );
    for (final raw in _list(world['rivers'])) {
      final river = _map(raw);
      if (river == null) continue;
      final points = _list(river['points']).map(_point).whereType<Offset>().toList();
      if (points.length < 2) continue;
      final path = Path()..moveTo(miniPoint(points.first).dx, miniPoint(points.first).dy);
      for (final point in points.skip(1)) {
        final p = miniPoint(point);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF4A9EC4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    for (final raw in _list(world['castles'])) {
      final castle = _map(raw);
      final anchor = _point(_map(castle)?['anchor']);
      if (castle == null || anchor == null || castle['fallen'] == true) continue;
      canvas.drawCircle(
        miniPoint(anchor),
        3.5,
        Paint()..color = _ownerColor(castle['ownerId']?.toString(), state),
      );
    }
    // Keep the minimap's terrain and castle markers under the same
    // local reveal radius as the main battlefield view.
    final playerPositions = _map(world['playerPositions']);
    final localPosition = _point(playerPositions?[localPlayerId]);
    if (localPosition == null) {
      // Match the main view's fail-closed behavior when local position is
      // missing from a partial or stale snapshot.
      canvas.drawRect(inner, Paint()..color = const Color(0xF0000807));
    } else {
      final revealX = enemyVisibleRadius / worldSize.width * inner.width;
      final revealY = enemyVisibleRadius / worldSize.height * inner.height;
      final revealRadius = math.min(revealX, revealY);
      final center = miniPoint(localPosition);
      canvas.saveLayer(inner, Paint());
      canvas.drawRect(inner, Paint()..color = const Color(0xB8000807));
      canvas.drawCircle(
        center,
        revealRadius,
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.restore();
      canvas.drawCircle(
        center,
        revealRadius,
        Paint()
          ..color = const Color(0x667DCB8A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final positions = playerPositions ?? const {};
    for (final entry in positions.entries) {
      final point = _point(entry.value);
      if (point == null) continue;
      final p = miniPoint(point);
      canvas.drawCircle(
        p,
        entry.key == localPlayerId ? 3.5 : 2.5,
        Paint()..color = entry.key == localPlayerId
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFFFC36A),
      );
    }
    final combat = _map(state['combat']);
    for (final raw in _list(combat?['monsters'])) {
      final monster = _map(raw);
      final point = _point(monster);
      if (monster == null ||
          point == null ||
          !_enemyMonsterVisible(
            point,
            world,
            monster['ownerId']?.toString(),
          )) {
        continue;
      }
      canvas.drawCircle(
        miniPoint(point),
        1.5,
        Paint()..color = const Color(0xFFFF6D5F),
      );
    }
    const projectionYScale = 0.82;
    final cameraScale = math.min(
      viewport.width / 960.0,
      viewport.height / (540.0 * projectionYScale),
    );
    final visibleWorld = Size(
      viewport.width / cameraScale,
      viewport.height / (cameraScale * projectionYScale),
    );
    final cameraRect = Rect.fromPoints(
      miniPoint(cameraOrigin),
      miniPoint(cameraOrigin + Offset(visibleWorld.width, visibleWorld.height)),
    );
    canvas.drawRect(
      cameraRect,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawProjectiles(
    Canvas canvas,
    Map<String, dynamic> state,
    Offset Function(Offset) project,
  ) {
    final combat = _map(state['combat']);
    for (final raw in _list(combat?['projectiles'])) {
      final projectile = _map(raw);
      if (projectile == null) continue;
      final point = _point(projectile);
      if (point == null) continue;
      final p = project(point);
      final color = _ownerColor(projectile['ownerId']?.toString(), state);
      canvas.drawCircle(
        p,
        7,
        Paint()..color = color.withOpacity(0.22),
      );
      canvas.drawCircle(
        p,
        3.2,
        Paint()
          ..color = const Color(0xFFFFF3C4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(p, 2, Paint()..color = color);
    }
  }

  void _drawCenteredLabel(Canvas canvas, Size size, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: size.width);
    painter.paint(canvas, Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.localPlayerId != localPlayerId;
}
