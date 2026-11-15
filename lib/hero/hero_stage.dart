import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hero_assets.dart';

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
  });

  final AtlasSheet? sheet;
  final String? frameId;
  final double pivotX;
  final double pivotY;
  final List<StageEffect> effects;
  final int timeMs;
  final String placeholder;

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
  });

  final AtlasSheet? sheet;
  final String? frameId;
  final double pivotX;
  final double pivotY;
  final List<StageEffect> effects;
  final int timeMs;
  final String placeholder;

  static const Color _lime = Color(0xFF9BE845);

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
        ..color = const Color(0x3357F02A),
    );
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1A12), Color(0xFF123024), Color(0xFF07110C)],
        ).createShader(bounds),
    );

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [_lime.withAlpha(38), _lime.withAlpha(0)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.46),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawRect(bounds, glow);

    final groundY = size.height * 0.84;
    final grid = Paint()
      ..color = const Color(0x1A9BE845)
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
        ..color = const Color(0x559BE845)
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
        _ring(canvas, focus, 10 + 66 * t, _lime, fade, 3.4);
        _ring(canvas, focus, 4 + 38 * t, Colors.white, fade * 0.85, 2);
        break;
      case 'volley':
        for (var i = 0; i < 3; i++) {
          final offset = Offset(
            math.cos(-math.pi / 2 + i * 0.55) * 22 * t,
            math.sin(-math.pi / 2 + i * 0.55) * 22 * t,
          );
          _ring(canvas, focus + offset, 8 + 52 * t, _lime, fade, 3);
        }
        break;
      case 'charge':
        final radius = 18 + 30 * (0.5 + 0.5 * math.sin(age / 90));
        canvas.drawCircle(
          focus,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [_lime.withAlpha((120 * fade).round()), _lime.withAlpha(0)],
            ).createShader(Rect.fromCircle(center: focus, radius: radius)),
        );
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
        _ring(canvas, focus, 8 + 44 * t, _lime, fade, 2.5);
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
