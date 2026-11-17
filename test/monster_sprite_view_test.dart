import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_animated_sprite.dart';
import 'package:archer_fm/monsters/monster_assets.dart';
import 'package:archer_fm/monsters/monster_animation.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_sprite_view.dart';

void main() {
  group('Monster animated sprite', () {
    testWidgets('walk frames advance from Flutter ticker time', (tester) async {
      final animation = MonsterAssetCatalog.createAnimation(MonsterType.runner);
      await tester.pumpWidget(MaterialApp(
        home: MonsterAnimatedSprite(
          animation: animation,
          alive: true,
          moving: true,
          size: 72,
        ),
      ));

      expect(find.byType(MonsterSpriteView), findsOneWidget);
      expect(animation.state, MonsterAnimationState.walk);
      expect(animation.frameIndex, 0);

      await tester.pump(const Duration(milliseconds: 110));
      expect(animation.frameIndex, 1);
    });

    testWidgets('idle remains on its stable frame without a running ticker',
        (tester) async {
      final animation = MonsterAssetCatalog.createAnimation(MonsterType.tank);
      await tester.pumpWidget(MaterialApp(
        home: MonsterAnimatedSprite(
          animation: animation,
          alive: true,
          moving: false,
        ),
      ));

      await tester.pump(const Duration(seconds: 2));
      expect(animation.state, MonsterAnimationState.idle);
      expect(animation.frameIndex, 0);
    });

    testWidgets('death animation plays once and stops on its final frame',
        (tester) async {
      final animation = MonsterAssetCatalog.createAnimation(MonsterType.stalker);
      await tester.pumpWidget(MaterialApp(
        home: MonsterAnimatedSprite(
          animation: animation,
          alive: false,
          moving: false,
        ),
      ));

      await tester.pump(const Duration(milliseconds: 500));
      expect(animation.state, MonsterAnimationState.death);
      expect(animation.frameIndex, animation.currentSheet.frameCount - 1);
      expect(animation.isComplete, isTrue);

      await tester.pump(const Duration(seconds: 2));
      expect(animation.frameIndex, animation.currentSheet.frameCount - 1);
    });

    testWidgets('non-looping attack stops on its final frame', (tester) async {
      final animation = MonsterAssetCatalog.createAnimation(MonsterType.runner);
      await tester.pumpWidget(MaterialApp(
        home: MonsterAnimatedSprite(
          animation: animation,
          alive: true,
          moving: false,
          attacking: true,
        ),
      ));

      await tester.pump(const Duration(milliseconds: 500));
      expect(animation.state, MonsterAnimationState.attack);
      expect(animation.frameIndex, animation.currentSheet.frameCount - 1);
      expect(animation.isComplete, isTrue);
    });
  });
}
