import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hero_assets.dart';
import 'hero_catalog.dart';

/// A short-lived gameplay flourish triggered by an animation event.
class StageEffect {
  const StageEffect({required this.kind, required this.startMs});

  final String kind;
  final int startMs;

  bool isAlive(int timeMs) {
    final age = timeMs - startMs;
    return age >= 0 && age <= 900;
  }
}

class HeroStage extends StatelessWidget {
  const HeroStage({
    super.key,
    required this.sheet,
    required this.frameId,
    required this.pivotX,
    required this.pivotY,
    required this.effects,
    required this.timeMs,
    required this.placeholder,
    this.theme = rangerTheme,
  });

  final AtlasSheet? sheet;
  final String? frameId;
  final double pivotX;
  final double pivotY;
  final List<StageEffect> effects;
  final int timeMs;
  final String placeholder;
  final HeroTheme theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: HeroStagePainter(
            sheet: sheet,
            frameId: frameId,
            pivotX: pivotX,
            pivotY: pivotY,
            effects: effects,
            timeMs: timeMs,
            placeholder: placeholder,
            theme: theme,
          ),
        );
      },
    );
  }
}

class HeroStagePainter extends CustomPainter {
  HeroStagePainter({
    required this.sheet,
    required this.frameId,
    required this.pivotX,
    required this.pivotY,
    required this.effects,
    required this.timeMs,
    required this.placeholder,
    required this.theme,
  });

  final AtlasSheet? sheet;
  final String? frameId;
  final double pivotX;
  final double pivotY;
  final List<StageEffect> effects;
  final int timeMs;
  final String placeholder;
  final HeroTheme theme;

  Color get _accent => theme.accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    final body = RRect.fromRectAndRadius(
      bounds.deflate(1),
      const Radius.circular(22),
    );
    canvas.save();
    canvas.clipRRect(body);
    _paintBackdrop(canvas, size);

    final image = sheet?.image;
    final rect = frameId == null ? null : sheet?.rectFor(frameId!);
    if (image == null || rect == null) {
      _paintPlaceholder(canvas, size);
      canvas.restore();
      return;
    }

    final scale = math.min(
          size.width / rect.width,
          size.height / rect.height,
        ) *
        0.94;
    final dstWidth = rect.width * scale;
    final dstHeight = rect.height * scale;
    final anchor = Offset(size.width / 2, size.height * 0.84);
    final dst = Rect.fromLTWH(
      anchor.dx - dstWidth * pivotX,
      anchor.dy - dstHeight * pivotY,
      dstWidth,
      dstHeight,
    );

    _paintShadow(canvas, anchor, dstWidth);
    for (final effect in effects) {
      if (!effect.isAlive(timeMs)) continue;
      _paintEffect(canvas, size, dst, anchor, effect, timeMs);
    }
    canvas.drawImageRect(
      image,
      rect,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _accent.withAlpha(51),
    );
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.stageTop, theme.stageMid, theme.stageBottom],
        ).createShader(bounds),
    );

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [_accent.withAlpha(46), _accent.withAlpha(0)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.46),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawRect(bounds, glow);

    final groundY = size.height * 0.84;
    final grid = Paint()
      ..color = _accent.withAlpha(28)
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = groundY + (size.height - groundY) * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 0; i <= 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(
        Offset(x, groundY),
        Offset(x + (x - size.width / 2) * 0.25, size.height),
        grid,
      );
    }
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = _accent.withAlpha(90)
        ..strokeWidth = 1.4,
    );
  }

  void _paintShadow(Canvas canvas, Offset anchor, double width) {
    final shadow = Rect.fromCenter(
      center: Offset(anchor.dx, anchor.dy + 2),
      width: width * 0.42,
      height: width * 0.075,
    );
    canvas.drawOval(
      shadow,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.black.withAlpha(150), Colors.black.withAlpha(0)],
        ).createShader(shadow),
    );
  }

  void _paintEffect(
    Canvas canvas,
    Size size,
    Rect dst,
    Offset anchor,
    StageEffect effect,
    int now,
  ) {
    final age = now - effect.startMs;
    final t = (age / 900).clamp(0.0, 1.0);
    final fade = 1.0 - t;
    final focus = Offset(
      dst.left + dst.width * 0.62,
      dst.top + dst.height * 0.55,
    );
    switch (effect.kind) {
      case 'release':
        _ring(canvas, focus, 10 + 66 * t, _accent, fade, 3.4);
        _ring(canvas, focus, 4 + 38 * t, Colors.white, fade * 0.85, 2);
        break;
      case 'volley':
        for (var i = 0; i < 3; i++) {
          final offset = Offset(
            math.cos(-math.pi / 2 + i * 0.55) * 22 * t,
            math.sin(-math.pi / 2 + i * 0.55) * 22 * t,
          );
          _ring(canvas, focus + offset, 8 + 52 * t, _accent, fade, 3);
        }
        break;
      case 'charge':
        final radius = 18 + 30 * (0.5 + 0.5 * math.sin(age / 90));
        canvas.drawCircle(
          focus,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                _accent.withAlpha((120 * fade).round()),
                _accent.withAlpha(0),
              ],
            ).createShader(Rect.fromCircle(center: focus, radius: radius)),
        );
        break;
      case 'impact':
        _ring(canvas, focus, 12 + 58 * t, theme.effect, fade, 4);
        _ring(canvas, focus, 6 + 34 * t, Colors.white, fade * 0.9, 2);
        final slash = Paint()
          ..color = Colors.white.withAlpha((220 * fade).round())
          ..strokeWidth = 5 * fade + 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(focus.dx - 46, focus.dy - 34 + 18 * t),
          Offset(focus.dx + 34, focus.dy + 40 - 18 * t),
          slash,
        );
        break;
      case 'burst':
        for (var i = 0; i < 4; i++) {
          _ring(
            canvas,
            focus,
            8 + (58 + i * 12) * t,
            theme.effect,
            fade * (1 - i * 0.12),
            3.2,
          );
        }
        canvas.drawCircle(
          focus,
          26 + 40 * t,
          Paint()
            ..shader = RadialGradient(
              colors: [
                theme.effect.withAlpha((110 * fade).round()),
                theme.effect.withAlpha(0),
              ],
            ).createShader(Rect.fromCircle(center: focus, radius: 26 + 40 * t)),
        );
        break;
      case 'thunder':
        final bolt = Paint()
          ..color = Colors.white.withAlpha((230 * fade).round())
          ..strokeWidth = 4.2 * fade + 1
          ..strokeCap = StrokeCap.round;
        final halo = Paint()
          ..color = theme.effect.withAlpha((150 * fade).round())
          ..strokeWidth = 9 * fade + 2
          ..strokeCap = StrokeCap.round;
        final start = Offset(focus.dx + 8, dst.top + 4);
        final end = Offset(focus.dx - 4, anchor.dy);
        final points = <Offset>[];
        const steps = 6;
        for (var i = 0; i <= steps; i++) {
          final v = i / steps;
          final jitter = i == 0 || i == steps
              ? 0.0
              : (i.isEven ? 16.0 : -16.0) * (1 - t * 0.4);
          points.add(Offset(
            start.dx + (end.dx - start.dx) * v + jitter,
            start.dy + (end.dy - start.dy) * v,
          ));
        }
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, halo);
        canvas.drawPath(path, bolt);
        _ring(canvas, end, 10 + 46 * t, theme.effect, fade, 3);
        break;
      case 'hit':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = const Color(0xFFFF4D4D).withAlpha((80 * fade).round()),
        );
        _ring(canvas, Offset(anchor.dx, dst.top + dst.height * 0.38),
            18 + 52 * t, const Color(0xFFFF6B5E), fade, 3);
        break;
      case 'starfall':
        for (var i = 0; i < 5; i++) {
          final x = size.width * (0.18 + i * 0.16);
          final y = -20 + (size.height * 0.72 + 20) * t + (i % 2) * 18;
          final p = Paint()
            ..color = theme.effect.withAlpha((220 * fade).round())
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(x - 8, y - 30), Offset(x, y), p);
          canvas.drawCircle(Offset(x, y), 4 + 3 * fade, p);
        }
        break;
      case 'piercing':
        final beam = Paint()
          ..shader = LinearGradient(colors: [
            Colors.white.withAlpha((240 * fade).round()),
            theme.effect.withAlpha((210 * fade).round()),
            theme.effect.withAlpha(0),
          ]).createShader(Rect.fromLTWH(0, focus.dy - 8, size.width, 16))
          ..strokeWidth = 10 * fade + 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(focus.dx - size.width * 0.46, focus.dy),
            Offset(focus.dx + size.width * 0.42, focus.dy), beam);
        _ring(canvas, focus, 12 + 44 * t, Colors.white, fade, 3);
        break;
      case 'nature':
        for (var i = 0; i < 4; i++) {
          _ring(canvas, anchor, 18 + (24 + i * 10) * t,
              theme.effect, fade * (1 - i * 0.12), 2.5);
          final angle = i * math.pi / 2 + t;
          final leaf = Offset(anchor.dx + math.cos(angle) * (26 + 40 * t),
              anchor.dy + math.sin(angle) * (12 + 18 * t));
          canvas.drawOval(Rect.fromCenter(center: leaf, width: 12, height: 6),
              Paint()..color = theme.effect.withAlpha((190 * fade).round()));
        }
        break;
      case 'apex':
        final sizeMark = 18 + 30 * t;
        final p = Paint()
          ..color = Colors.white.withAlpha((235 * fade).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawRect(Rect.fromCenter(center: focus, width: sizeMark * 2,
            height: sizeMark * 2), p);
        canvas.drawLine(Offset(focus.dx - sizeMark * 1.5, focus.dy),
            Offset(focus.dx + sizeMark * 1.5, focus.dy), p);
        canvas.drawLine(Offset(focus.dx, focus.dy - sizeMark * 1.5),
            Offset(focus.dx, focus.dy + sizeMark * 1.5), p);
        _ring(canvas, focus, 8 + 24 * t, theme.effect, fade, 4);
        break;
      case 'eruption':
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          final start = Offset(anchor.dx + math.cos(a) * 8,
              anchor.dy + math.sin(a) * 4);
          final end = Offset(anchor.dx + math.cos(a) * (30 + 60 * t),
              anchor.dy + math.sin(a) * (12 + 24 * t));
          final flame = Path()
            ..moveTo(start.dx, start.dy)
            ..lineTo(end.dx - 5, end.dy - 12 * fade)
            ..lineTo(end.dx, end.dy)
            ..close();
          canvas.drawPath(flame,
              Paint()..color = theme.effect.withAlpha((190 * fade).round()));
        }
        _ring(canvas, anchor, 20 + 58 * t, Colors.white, fade, 2.5);
        break;
      case 'comet':
        final start = Offset(size.width * 0.12, size.height * 0.08);
        final end = Offset(focus.dx, focus.dy);
        final p = Paint()
          ..color = theme.effect.withAlpha((220 * fade).round())
          ..strokeWidth = 7 * fade + 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(start, Offset.lerp(start, end, t)!, p);
        canvas.drawCircle(Offset.lerp(start, end, t)!, 8 + 8 * fade,
            Paint()..color = Colors.white.withAlpha((220 * fade).round()));
        _ring(canvas, end, 12 + 40 * t, theme.effect, fade, 3);
        break;
      case 'brand':
        final mark = Path()
          ..moveTo(focus.dx, focus.dy - 34 * (1 - t * 0.3))
          ..lineTo(focus.dx + 24, focus.dy)
          ..lineTo(focus.dx, focus.dy + 34 * (1 - t * 0.3))
          ..lineTo(focus.dx - 24, focus.dy)
          ..close();
        canvas.drawPath(mark, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = theme.effect.withAlpha((220 * fade).round()));
        _ring(canvas, focus, 16 + 38 * t, theme.effect, fade, 2);
        break;
      case 'phoenix':
        for (var side in [-1.0, 1.0]) {
          final wing = Path()
            ..moveTo(focus.dx, focus.dy + 20)
            ..cubicTo(focus.dx + side * 20, focus.dy - 42,
                focus.dx + side * 54, focus.dy - 34,
                focus.dx + side * 78 * t, focus.dy - 70 * t);
          canvas.drawPath(wing, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * fade + 1
            ..strokeCap = StrokeCap.round
            ..color = theme.effect.withAlpha((230 * fade).round()));
        }
        _ring(canvas, focus, 18 + 50 * t, Colors.white, fade, 2.5);
        break;
      case 'vanish':
        canvas.drawCircle(focus, 22 + 58 * t, Paint()
          ..shader = RadialGradient(colors: [
            theme.effect.withAlpha((150 * fade).round()),
            theme.effect.withAlpha(0),
          ]).createShader(Rect.fromCircle(center: focus, radius: 22 + 58 * t)));
        _ring(canvas, focus, 18 + 60 * t, theme.effect, fade, 3);
        break;
      case 'cross':
        final slash = Paint()
          ..color = Colors.white.withAlpha((230 * fade).round())
          ..strokeWidth = 7 * fade + 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(focus.dx - 52 * t, focus.dy - 42),
            Offset(focus.dx + 52 * t, focus.dy + 42), slash);
        canvas.drawLine(Offset(focus.dx + 52 * t, focus.dy - 42),
            Offset(focus.dx - 52 * t, focus.dy + 42), slash);
        _ring(canvas, focus, 16 + 44 * t, theme.effect, fade, 2.5);
        break;
      case 'poison':
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final center = Offset(focus.dx + math.cos(a) * (18 + 54 * t),
              focus.dy + math.sin(a) * (12 + 36 * t));
          canvas.drawCircle(center, 4 + 5 * fade, Paint()
            ..color = theme.effect.withAlpha((190 * fade).round()));
        }
        _ring(canvas, focus, 20 + 55 * t, theme.effect, fade, 2.5);
        break;
      case 'execution':
        final blade = Paint()
          ..color = Colors.white.withAlpha((245 * fade).round())
          ..strokeWidth = 9 * fade + 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(focus.dx + 36, focus.dy - 70 * t),
            Offset(focus.dx - 30, focus.dy + 60 * t), blade);
        _ring(canvas, focus, 12 + 34 * t, theme.effect, fade, 3);
        break;
      case 'chain':
        final chain = Path()..moveTo(focus.dx - 58, focus.dy - 26);
        for (var i = 0; i < 6; i++) {
          chain.lineTo(focus.dx - 58 + i * 23,
              focus.dy + (i.isEven ? -24 : 24) * (0.4 + t * 0.6));
        }
        canvas.drawPath(chain, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white.withAlpha((230 * fade).round()));
        _ring(canvas, focus, 14 + 46 * t, theme.effect, fade, 3);
        break;
      case 'field':
        _ring(canvas, anchor, 28 + 60 * t, theme.effect, fade, 4);
        _ring(canvas, anchor, 18 + 42 * t, Colors.white, fade * 0.8, 2);
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + t * 2;
          final point = Offset(anchor.dx + math.cos(a) * (32 + 52 * t),
              anchor.dy + math.sin(a) * (12 + 20 * t));
          canvas.drawCircle(point, 5, Paint()
            ..color = Colors.white.withAlpha((220 * fade).round()));
        }
        break;
      case 'tempest':
        final spiral = Path();
        for (var i = 0; i <= 36; i++) {
          final a = i / 36 * math.pi * 4;
          final r = 5 + i / 36 * (46 + 26 * t);
          final point = Offset(focus.dx + math.cos(a) * r,
              focus.dy + math.sin(a) * r * 0.55);
          if (i == 0) {
            spiral.moveTo(point.dx, point.dy);
          } else {
            spiral.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(spiral, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = theme.effect.withAlpha((220 * fade).round()));
        break;
      case 'streak':
        final paint = Paint()
          ..color = Colors.white.withAlpha((110 * fade).round())
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final dy = dst.top + dst.height * (0.42 + i * 0.13);
          canvas.drawLine(
            Offset(dst.left + dst.width * 0.15, dy),
            Offset(dst.left + dst.width * (0.3 - 0.1 * t), dy),
            paint,
          );
        }
        break;
      default:
        _ring(canvas, focus, 8 + 44 * t, _accent, fade, 2.5);
    }
  }

  void _ring(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double fade,
    double stroke,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withAlpha((255 * fade).round()),
    );
  }

  void _paintPlaceholder(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: placeholder,
        style: const TextStyle(
          color: Color(0xFFB8CDBD),
          fontSize: 14,
          height: 1.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: size.width - 40);
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, size.height * 0.42),
    );
  }

  @override
  bool shouldRepaint(covariant HeroStagePainter oldDelegate) => true;
}
