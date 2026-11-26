import 'dart:math' as math;

import 'package:flutter/material.dart';

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
              ? CustomPaint(
                  painter: _ArenaPainter(snapshot, localPlayerId),
                  child: const SizedBox.expand(),
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

    canvas.drawRect(bounds, Paint()..color = const Color(0xFF263C2C));
    _drawBiomes(canvas, world, project);
    _drawRivers(canvas, world, project);
    _drawObstacles(canvas, world, project);
    _drawPickups(canvas, world, project);
    _drawMines(canvas, world, project);
    _drawCastles(canvas, world, project);
    _drawMonsters(canvas, snapshot, project);
    _drawProjectiles(canvas, snapshot, project);
    _drawHeroes(canvas, snapshot, world, project);
    _drawMinimap(canvas, snapshot, worldSize);
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
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF286F9A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = projectedWidth
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
      for (final bridgeRaw in _list(river['bridges'])) {
        final bridge = _map(bridgeRaw);
        final point = _point(bridge);
        if (bridge == null || point == null) continue;
        final p = project(point);
        final bridgeWidth = _number(bridge['width']) ?? 100;
        final bridgeDepth = _number(bridge['depth']) ?? 120;
        final a = project(point + Offset(bridgeWidth / 2, bridgeDepth / 2));
        final b = project(point - Offset(bridgeWidth / 2, bridgeDepth / 2));
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = const Color(0xFFB99A70)
            ..strokeWidth = math.max(8.0, projectedWidth * 0.5)
            ..strokeCap = StrokeCap.round,
        );
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
      canvas.drawCircle(p + const Offset(0, 3), r, Paint()..color = const Color(0x66000000));
      canvas.drawCircle(
        p,
        r,
        Paint()..color = tree ? const Color(0xFF315B37) : const Color(0xFF777C78),
      );
      canvas.drawCircle(
        p + Offset(-r * 0.25, -r * 0.25),
        r * 0.58,
        Paint()..color = tree ? const Color(0xFF54864B) : const Color(0xFFADB0A8),
      );
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
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 12, height: 10),
          const Radius.circular(2),
        ),
        Paint()..color = chest ? const Color(0xFFE4B34D) : const Color(0xFF68D9C4),
      );
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
      canvas.drawCircle(p, 13, Paint()..color = const Color(0xFF292B2A));
      canvas.drawCircle(p, 9, Paint()..color = color);
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
        final path = Path()
          ..moveTo(p.dx, p.dy - 7)
          ..lineTo(p.dx + 6, p.dy)
          ..lineTo(p.dx, p.dy + 7)
          ..lineTo(p.dx - 6, p.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = hp > 0 ? color : const Color(0xFF4A4540));
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

  void _drawMonsters(
    Canvas canvas,
    Map<String, dynamic> state,
    Offset Function(Offset) project,
  ) {
    final combat = _map(state['combat']);
    for (final raw in _list(combat?['monsters'])) {
      final monster = _map(raw);
      if (monster == null) continue;
      final point = _point(monster);
      if (point == null) continue;
      final p = project(point);
      final color = _ownerColor(monster['ownerId']?.toString(), state);
      final radius = switch (monster['type']) {
        'tank' => 8.0,
        'ranged' => 6.5,
        _ => 5.5,
      };
      canvas.drawCircle(p + const Offset(0, 2), radius + 1, Paint()..color = const Color(0x77000000));
      canvas.drawCircle(p, radius, Paint()..color = color);
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color = const Color(0xFF222222)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final hp = _number(monster['health']);
      final maxHp = _number(monster['maxHealth']);
      if (hp != null && maxHp != null && maxHp > 0) {
        final rect = Rect.fromLTWH(p.dx - 8, p.dy - radius - 5, 16, 2);
        canvas.drawRect(rect, Paint()..color = const Color(0xFF241E1B));
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width * (hp / maxHp).clamp(0.0, 1.0), 2),
          Paint()..color = const Color(0xFF8DE36A),
        );
      }
    }
  }

  void _drawMinimap(Canvas canvas, Map<String, dynamic> state, Size worldSize) {
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
    final positions = _map(world['playerPositions']) ?? const {};
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
      final point = _point(raw);
      if (point == null) continue;
      canvas.drawCircle(
        miniPoint(point),
        1.5,
        Paint()..color = const Color(0xFFFF6D5F),
      );
    }
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

  void _drawHeroes(
    Canvas canvas,
    Map<String, dynamic> state,
    Map world,
    Offset Function(Offset) project,
  ) {
    final combat = _map(state['combat']);
    final heroes = _map(combat?['heroes']) ?? const {};
    final positions = _map(world['playerPositions']) ?? const {};
    for (final entry in heroes.entries) {
      final playerId = entry.key.toString();
      final hero = _map(entry.value);
      final point = _point(positions[playerId]);
      if (hero == null || point == null) continue;
      final p = project(point);
      final color = _ownerColor(playerId, state);
      final alive = hero['isAlive'] == true;
      canvas.drawCircle(p + const Offset(0, 3), 12, Paint()..color = const Color(0x77000000));
      canvas.drawCircle(
        p,
        alive ? 10 : 7,
        Paint()..color = alive ? color : const Color(0xFF777777),
      );
      canvas.drawCircle(
        p,
        alive ? 10 : 7,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = playerId == localPlayerId ? 2.5 : 1,
      );
      final hp = _number(hero['health']);
      final maxHp = _number(hero['maxHealth']);
      if (hp != null && maxHp != null && maxHp > 0) {
        final rect = Rect.fromLTWH(p.dx - 13, p.dy - 17, 26, 3);
        canvas.drawRect(rect, Paint()..color = const Color(0xFF211F1D));
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width * (hp / maxHp).clamp(0.0, 1.0), 3),
          Paint()..color = const Color(0xFF8DE36A),
        );
      }
      _drawText(canvas, playerId == localPlayerId ? 'أنت' : 'خصم', p + const Offset(0, 13), 8);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, 0));
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
