import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'monster_animation.dart';

/// Crops and displays the active cell of a horizontal SVG sprite sheet.
/// Positioning, facing direction and simulation remain owned by the match view.
class MonsterSpriteView extends StatelessWidget {
  const MonsterSpriteView({
    super.key,
    required this.animation,
    this.size = 64,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final MonsterAnimationController animation;
  final double size;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final sheet = animation.activeSheet;
    final frame = animation.frameIndex.clamp(0, sheet.frameCount - 1);
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: FittedBox(
          fit: fit,
          alignment: alignment,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: sheet.frameWidth * sheet.frameCount.toDouble(),
            height: sheet.frameHeight.toDouble(),
            child: Transform.translate(
              offset: Offset(-sheet.frameWidth * frame.toDouble(), 0),
              child: SvgPicture.asset(
                sheet.asset,
                width: sheet.frameWidth * sheet.frameCount.toDouble(),
                height: sheet.frameHeight.toDouble(),
                fit: BoxFit.fill,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
