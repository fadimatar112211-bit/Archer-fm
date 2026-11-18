import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'world/arena_map.dart';
import 'world/castle_system.dart';
import 'world/game_world.dart';
import 'world/mine_system.dart';

/// A marker drawn on the minimap. Crystals and mines stay visible even when
/// they are far away.
enum MinimapMarkerKind { player, castle, mine, crystal }

class MinimapMarker {
  const MinimapMarker(
    this.kind,
    this.position, {
    this.radius = 0,
    this.ownerId,
  });

  final MinimapMarkerKind kind;
  final Offset position;
  final double radius;

  /// Owner of a mine/crystal marker; null for mines while neutral.
  final String? ownerId;
}

/// Markers that the minimap always renders: the hero, the four castles and
/// the eight mine sites (regardless of distance).
List<MinimapMarker> minimapMarkers(GameWorld world) {
  return [
    MinimapMarker(MinimapMarkerKind.player, world.player.position),
    for (final castle in world.castleSystem.standingCastles)
      MinimapMarker(
        MinimapMarkerKind.castle,
        castle.anchor,
        ownerId: castle.ownerId,
      ),
    for (final mine in world.mineSystem.mines)
      MinimapMarker(
        MinimapMarkerKind.mine,
        mine.position,
        radius: mine.radius,
        ownerId: mine.ownerId,
      ),
    for (final crystal in world.castleSystem.mappedCrystals)
      MinimapMarker(
        MinimapMarkerKind.crystal,
        crystal.position,
        ownerId: crystal.ownerId,
      ),
  ];
}

/// Compact match minimap. Explored terrain is drawn lighter; unexplored cells
/// stay dark. Mines and castles remain visible everywhere.
class ArenaMinimap extends StatelessWidget {
  const ArenaMinimap({
    super.key,
    required this.world,
    this.width = 156,
    this.height = 92,
  });

  final GameWorld world;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'الخريطة المصغرة',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x809BE845), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 8),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: MinimapPainter(world: world),
          size: Size(width, height),
        ),
      ),
    );
  }
}

class MinimapPainter extends CustomPainter {
  MinimapPainter({required this.world});

  final GameWorld world;

  @override
  void paint(Canvas canvas, Size size) {
    final map = world.map;
    final scale = math.min(size.width / map.size.width, size.height / map.size.height);
    final view = Size(map.size.width * scale, map.size.height * scale);
    final origin = Offset(
      (size.width - view.width) / 2,
      (size.height - view.height) / 2,
    );

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF07110A));

    canvas.save();
    canvas.clipRect(origin & view);

    // Explored terrain.
    final cell = map.size.width / world.fog.cols;
    final baseCell = Paint()..color = const Color(0xFF4C6B45);
    for (var row = 0; row < world.fog.rows; row++) {
      for (var col = 0; col < world.fog.cols; col++) {
        if (!world.fog.cellRevealed(col, row)) continue;
        final center = Offset((col + 0.5) * cell, (row + 0.5) * (map.size.height / world.fog.rows));
        final biome = map.biomeAt(center);
        final color = biome == null
            ? baseCell.color
            : _biomeTint(biome.kind);
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + col * cell * scale,
            origin.dy + row * (map.size.height / world.fog.rows) * scale,
            cell * scale + 0.6,
            (map.size.height / world.fog.rows) * scale + 0.6,
          ),
          Paint()..color = color,
        );
      }
    }

    // Rivers.
    final water = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF3E86A8);
    for (final river in map.rivers) {
      final path = Path()
        ..moveTo(
          origin.dx + river.points.first.dx * scale,
          origin.dy + river.points.first.dy * scale,
        );
      for (final point in river.points.skip(1)) {
        path.lineTo(
          origin.dx + point.dx * scale,
          origin.dy + point.dy * scale,
        );
      }
      water.strokeWidth = math.max(1.5, river.width * scale);
      canvas.drawPath(path, water);
    }

    // Castles (same design; the local player's castle is highlighted). A
    // fallen castle disappears here too, like it does in the world.
    for (final castle in world.castleSystem.standingCastles) {
      final center = origin + castle.anchor * scale;
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 7, height: 7),
        Paint()
          ..color = castle.isLocal
              ? const Color(0xFFFFD257)
              : const Color(0xFFB9D3BF),
      );
    }

    // Mines stay visible at any distance, in their three sizes, colored by
    // owner (neutral amber, local player green, opponent red).
    for (final mine in world.mineSystem.mines) {
      final center = origin + mine.position * scale;
      final color = mine.ownerId == null
          ? const Color(0xFFFFB52E)
          : mine.owns(MineController.localPlayerId)
              ? const Color(0xFF9BE845)
              : const Color(0xFFFF7A5A);
      canvas.drawCircle(
        center,
        math.max(2.2, mine.radius * scale * 0.55),
        Paint()..color = color,
      );
    }

    // Crystals stay visible at any distance, seven per standing castle.
    for (final crystal in world.castleSystem.mappedCrystals) {
      final center = origin + crystal.position * scale;
      final color = crystal.ownerId == world.castleSystem.localPlayerId
          ? const Color(0xFF9BE845)
          : const Color(0xFFFF7A5A);
      final size = math.max(1.6, crystalRadius * scale * 0.9);
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - size)
          ..lineTo(center.dx + size * 0.7, center.dy)
          ..lineTo(center.dx, center.dy + size)
          ..lineTo(center.dx - size * 0.7, center.dy)
          ..close(),
        Paint()..color = color,
      );
    }

    // Hero.
    final hero = origin + world.player.position * scale;
    canvas.drawCircle(hero, 3.4, Paint()..color = Colors.white);
    canvas.drawCircle(
      hero,
      5.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF9BE845),
    );

    canvas.restore();
  }

  Color _biomeTint(TerrainKind kind) => switch (kind) {
        TerrainKind.forest => const Color(0xFF3F7346),
        TerrainKind.desert => const Color(0xFFB79463),
        TerrainKind.snow => const Color(0xFFBFD8E6),
        TerrainKind.volcanic => const Color(0xFF7C4A42),
      };

  @override
  bool shouldRepaint(covariant MinimapPainter oldDelegate) => true;
}
