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
