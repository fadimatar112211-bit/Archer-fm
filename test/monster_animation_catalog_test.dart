import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_animation.dart';
import 'package:archer_fm/monsters/monster_models.dart';

void main() {
  group('Monster animation asset catalog', () {
    test('defines frame metadata for all four original monster types', () {
      for (final type in MonsterType.values) {
        final controller = MonsterAnimationCatalog.createController(type);
        expect(controller.type, type);
        expect(controller.walkSheet.frameWidth, 96);
        expect(controller.walkSheet.frameHeight, 96);
        expect(controller.walkSheet.frameCount, 4);
        expect(controller.walkSheet.sheetWidth, 384);
        expect(controller.walkSheet.asset, contains('assets/monsters/legacy/'));
      }
    });

    test('does not invent ranged attack or death sheets', () {
      final ranged =
          MonsterAnimationCatalog.createController(MonsterType.bogMonster);
      expect(ranged.attackSheet, isNull);
      expect(ranged.deathSheet, isNull);
    });

    test('one-shot attack animation stops ticking at its final frame', () {
      final controller =
          MonsterAnimationCatalog.createController(MonsterType.werewolf);
      controller.synchronize(
        alive: true,
        moving: false,
        attacking: true,
      );
      expect(controller.needsTicks, isTrue);
      controller.advance(const Duration(seconds: 1));
      expect(controller.frameIndex, 3);
      expect(controller.isAnimationFinished, isTrue);
      expect(controller.needsTicks, isFalse);
    });
  });
}
