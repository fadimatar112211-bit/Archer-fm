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
    _drawBiomes(canvas, world, project);
    _drawTerrainTexture(canvas, cameraOrigin, project);
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

  void _drawBiomes(Canvas canvas, Map world, Offset Function(Offset) project) {
    const colors = {
      'forest': Color(0x553B7846),
      'desert': Color(0x55C59A52),
      'snow': Color(0x559AB9C7),
      'volcanic': Color(0x557A3830),
    };
    for (final raw in _list(world['biomes'])) {
      final biome = _map(raw);
      if (biome == null) continue;
      final center = _point(biome);
      final radius = _number(biome['radius']);
      if (center == null || radius == null) continue;
      final p = project(center);
      final scaleRadius = (project(center + Offset(radius, 0)) - p).distance;
      canvas.drawCircle(
        p,
        scaleRadius,
        Paint()..color = colors[biome['kind']] ?? const Color(0x443F6044),
      );
    }
  }

  /// Adds deterministic, camera-stable ground detail without introducing
  /// textures, random state, or per-frame allocations outside the visible map.
  /// Every mark is derived from its world-grid coordinate, so the terrain
  /// appears anchored while the follow camera moves.
  void _drawTerrainTexture(
    Canvas canvas,
    Offset cameraOrigin,
    Offset Function(Offset) project,
  ) {
    // A deterministic 48-unit ground grid gives the battlefield a richer
    // hand-painted texture while keeping every detail anchored to world space.
    const cell = 48.0;
    const columns = 22;
    const rows = 15;
    final startX = (cameraOrigin.dx / cell).floor() - 1;
    final startY = (cameraOrigin.dy / cell).floor() - 1;
    for (var gy = startY; gy < startY + rows; gy++) {
      for (var gx = startX; gx < startX + columns; gx++) {
        final seed = (gx * 73856093) ^ (gy * 19349663);
        final x = gx * cell + 8 + (seed.abs() % 31).toDouble();
        final y = gy * cell + 7 + ((seed >> 5).abs() % 29).toDouble();
        final point = project(Offset(x, y));
        final variant = seed.abs() % 7;
        final patchRect = Rect.fromCenter(
          center: point,
          width: 13 + (variant % 3) * 4.0,
          height: 6 + (variant % 2) * 3.0,
        );
        if (variant == 0 || variant == 4) {
          // Soft moss/grass patches break up the flat base without obscuring
          // tactical silhouettes or the fog-of-war layer.
          canvas.drawOval(
            patchRect,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  const Color(0x443F8050),
                  const Color(0x003F8050),
                ],
              ).createShader(patchRect),
          );
          for (var blade = 0; blade < 3; blade++) {
            final bx = point.dx + (blade - 1) * 2.8;
            canvas.drawLine(
              Offset(bx, point.dy + 2),
              Offset(bx - 1.1, point.dy - 2.5 - (blade % 2)),
              Paint()
                ..color = const Color(0x665C9656)
                ..strokeWidth = 0.9
                ..strokeCap = StrokeCap.round,
            );
          }
        } else if (variant == 1 || variant == 5) {
          // Tiny pebbles with a lit upper edge create a more tactile ground.
          canvas.drawOval(
            Rect.fromCenter(
              center: point.translate(1, 1),
              width: 5.5,
              height: 3.2,
            ),
            Paint()..color = const Color(0x44302720),
          );
          canvas.drawOval(
            Rect.fromCenter(center: point, width: 5, height: 2.8),
            Paint()..color = const Color(0x557C806F),
          );
          canvas.drawLine(
            point.translate(-1.2, -0.6),
            point.translate(1.2, -0.6),
            Paint()
              ..color = const Color(0x667E927B)
              ..strokeWidth = 0.7,
          );
        } else if (variant == 2) {
          // A sparse flower cluster adds color at ground level only.
          canvas.drawLine(
            point.translate(0, 2),
            point.translate(0, -2),
            Paint()
              ..color = const Color(0x665E8A4D)
              ..strokeWidth = 1,
          );
          canvas.drawCircle(
            point.translate(-2, -2),
            1.15,
            Paint()..color = const Color(0x99F0D58B),
          );
          canvas.drawCircle(
            point.translate(2, -2),
            1.15,
            Paint()..color = const Color(0x99E7B9C5),
          );
        } else {
          canvas.drawCircle(
            point,
            1.1,
            Paint()..color = const Color(0x334D7650),
          );
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
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p + Offset(0, r * 0.42),
              width: r * 0.34,
              height: r * 0.95,
            ),
            Radius.circular(r * 0.12),
          ),
          Paint()..color = const Color(0xFF76543A),
        );
        canvas.drawCircle(
          p + Offset(-r * 0.32, -r * 0.12),
          r * 0.72,
          Paint()..color = const Color(0xFF315B37),
        );
        canvas.drawCircle(
          p + Offset(r * 0.3, -r * 0.18),
          r * 0.68,
          Paint()..color = const Color(0xFF3C7040),
        );
        canvas.drawCircle(
          p + Offset(-r * 0.08, -r * 0.48),
          r * 0.72,
          Paint()..color = const Color(0xFF54864B),
        );
        canvas.drawCircle(
          p + Offset(-r * 0.28, -r * 0.68),
          r * 0.2,
          Paint()..color = const Color(0xFF79A95D),
        );
      } else {
        canvas.drawCircle(
          p,
          r,
          Paint()..color = const Color(0xFF666F6B),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: p + Offset(-r * 0.2, -r * 0.28),
            width: r * 1.05,
            height: r * 0.58,
          ),
          Paint()..color = const Color(0xFFADB0A8),
        );
        canvas.drawCircle(
          p + Offset(r * 0.34, r * 0.18),
          r * 0.2,
          Paint()..color = const Color(0xFF858B83),
        );
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
