import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'monster_animation.dart';

/// Crops the active horizontal SVG sprite cell without owning world movement.
class MonsterSpriteView extends StatelessWidget {
  const MonsterSpriteView({
    super.key,
    required this.animation,
    this.size = 64,
  });

  final MonsterAnimationController animation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final sheet = animation.currentSheet;
    final frame = animation.frameIndex.clamp(0, sheet.frameCount - 1);
    final stripWidth = size * sheet.frameCount;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: stripWidth,
          maxWidth: stripWidth,
          minHeight: size,
          maxHeight: size,
          child: Transform.translate(
            offset: Offset(-size * frame.toDouble(), 0),
            child: SvgPicture.asset(
              sheet.asset,
              width: stripWidth,
              height: size,
              fit: BoxFit.fill,
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
      ),
    );
  }
}
