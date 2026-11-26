import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/monster_animation.dart';
import 'package:archer_fm/monsters/monster_models.dart';

void main() {
  const walk = MonsterSpriteSheet(
    asset: 'assets/monsters/legacy/enemy_runner.svg',
    frameWidth: 96,
    frameHeight: 96,
    frameCount: 4,
    frameDuration: Duration(milliseconds: 100),
  );
  const attack = MonsterSpriteSheet(
    asset: 'assets/monsters/legacy/enemy_runner_attack.svg',
    frameWidth: 96,
    frameHeight: 96,
    frameCount: 4,
    frameDuration: Duration(milliseconds: 80),
    loop: false,
  );
  const death = MonsterSpriteSheet(
    asset: 'assets/monsters/legacy/enemy_runner_death.svg',
    frameWidth: 96,
    frameHeight: 96,
    frameCount: 4,
    frameDuration: Duration(milliseconds: 90),
    loop: false,
  );

  group('MonsterAnimationController', () {
    test('walk advances feet frame-by-frame at the configured cadence', () {
      final animation = MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: walk,
        attackSheet: attack,
        deathSheet: death,
      );
      animation.synchronize(alive: true, moving: true);
      animation.advance(const Duration(milliseconds: 99));
      expect(animation.frameIndex, 0);
      animation.advance(const Duration(milliseconds: 1));
      expect(animation.frameIndex, 1);
      animation.advance(const Duration(milliseconds: 300));
      expect(animation.frameIndex, 0);
    });

    test('idle freezes on a stable frame and resets the walk clock', () {
      final animation = MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: walk,
      );
      animation.synchronize(alive: true, moving: true);
      animation.advance(const Duration(milliseconds: 250));
      animation.synchronize(alive: true, moving: false);
      expect(animation.state, MonsterAnimationState.idle);
      expect(animation.frameIndex, 0);
      animation.advance(const Duration(seconds: 2));
      expect(animation.frameIndex, 0);
    });

    test('attack uses its own cadence and returns to walk on next sync', () {
      final animation = MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: walk,
        attackSheet: attack,
      );
      animation.synchronize(alive: true, moving: false, attacking: true);
      animation.advance(const Duration(milliseconds: 80));
      expect(animation.frameIndex, 1);
      animation.synchronize(alive: true, moving: true);
      expect(animation.state, MonsterAnimationState.attack);
      expect(animation.frameIndex, 1);
      animation.advance(const Duration(milliseconds: 240));
      expect(animation.isAnimationFinished, isTrue);
      animation.synchronize(alive: true, moving: true);
      expect(animation.state, MonsterAnimationState.walk);
      expect(animation.frameIndex, 0);
    });

    test('attack animation finishes after the one-tick attack signal ends', () {
      final animation = MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: walk,
        attackSheet: attack,
      );
      animation.synchronize(alive: true, moving: false, attacking: true);
      animation.advance(const Duration(milliseconds: 85));
      expect(animation.state, MonsterAnimationState.attack);
      expect(animation.frameIndex, 1);

      animation.synchronize(alive: true, moving: true, attacking: false);
      expect(animation.state, MonsterAnimationState.attack);
      animation.advance(const Duration(milliseconds: 255));
      expect(animation.isAnimationFinished, isTrue);

      animation.synchronize(alive: true, moving: true, attacking: false);
      expect(animation.state, MonsterAnimationState.walk);
    });

    test('death is terminal and plays once without looping', () {
      final animation = MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: walk,
        deathSheet: death,
      );
      animation.synchronize(alive: false, moving: false);
      animation.advance(const Duration(milliseconds: 360));
      expect(animation.state, MonsterAnimationState.death);
      expect(animation.frameIndex, 3);
      expect(animation.isComplete, isTrue);
      animation.synchronize(alive: true, moving: true);
      expect(animation.state, MonsterAnimationState.death);
    });

    test('missing ranged attack sheet safely falls back to walk frames', () {
      final animation = MonsterAnimationController(
        type: MonsterType.ranged,
        walkSheet: walk,
      );
      animation.synchronize(alive: true, moving: false, attacking: true);
      expect(animation.state, MonsterAnimationState.idle);
    });

    test('large delta is handled without per-frame iteration', () {
      final animation = MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: walk,
      );
      animation.synchronize(alive: true, moving: true);
      animation.advance(const Duration(days: 1));
      expect(animation.frameIndex, inInclusiveRange(0, 3));
    });

    test('rejects invalid sprite-sheet metadata', () {
      expect(() => MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: const MonsterSpriteSheet(
          asset: '',
          frameWidth: 96,
          frameHeight: 96,
          frameCount: 4,
        ),
      ), throwsArgumentError);
      expect(() => MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: const MonsterSpriteSheet(
          asset: 'walk.svg',
          frameWidth: 96,
          frameHeight: 96,
          frameCount: 4,
          frameDuration: Duration(milliseconds: -1),
        ),
      ), throwsArgumentError);
    });

    test('negative elapsed time is rejected', () {
      final animation = MonsterAnimationController(
        type: MonsterType.runner,
        walkSheet: walk,
      );
      expect(() => animation.advance(-const Duration(milliseconds: 1)),
          throwsArgumentError);
    });
  });
}
