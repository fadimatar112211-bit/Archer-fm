import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_animation.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_sprite_view.dart';

void main() {
  group('Monster sprite view', () {
    testWidgets('walk frames advance from Flutter ticker time', (tester) async {
      final animation =
          MonsterAnimationCatalog.createController(MonsterType.runner);
      await tester.pumpWidget(MaterialApp(
        home: MonsterSpriteView(
          animation: animation,
          alive: true,
          moving: true,
          size: 72,
        ),
      ));

      expect(animation.state, MonsterAnimationState.walk);
      expect(animation.frameIndex, 0);
      await tester.pump(const Duration(milliseconds: 110));
      expect(animation.frameIndex, 1);
    });

    testWidgets('idle remains on its stable frame without a running ticker',
        (tester) async {
      final animation =
          MonsterAnimationCatalog.createController(MonsterType.tank);
      await tester.pumpWidget(MaterialApp(
        home: MonsterSpriteView(
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
      final animation =
          MonsterAnimationCatalog.createController(MonsterType.stalker);
      await tester.pumpWidget(MaterialApp(
        home: MonsterSpriteView(
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
      final animation =
          MonsterAnimationCatalog.createController(MonsterType.runner);
      await tester.pumpWidget(MaterialApp(
        home: MonsterSpriteView(
          animation: animation,
          alive: true,
          moving: false,
          attacking: true,
        ),
      ));

      await tester.pump(const Duration(milliseconds: 500));
      expect(animation.state, MonsterAnimationState.attack);
      expect(animation.frameIndex, animation.currentSheet.frameCount - 1);
      expect(animation.isAnimationFinished, isTrue);
      expect(animation.needsTicks, isFalse);
    });

    testWidgets('optional health bar reflects supplied health fraction',
        (tester) async {
      final animation =
          MonsterAnimationCatalog.createController(MonsterType.ranged);
      await tester.pumpWidget(MaterialApp(
        home: MonsterSpriteView(
          animation: animation,
          alive: true,
          moving: false,
          healthFraction: 0.5,
        ),
      ));

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
    });
  });
}
