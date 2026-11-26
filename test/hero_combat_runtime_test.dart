import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/heroes/hero_combat_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeroCombatRuntime', () {
    test('manual attacks form a five-hit combo and respect weapon cooldown', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.ranger));
      final first = runtime.attack();
      expect(first.accepted, isTrue);
      expect(first.comboIndex, 1);
      expect(runtime.attack().accepted, isFalse);

      runtime.advance(const Duration(milliseconds: 520));
      final second = runtime.attack();
      expect(second.accepted, isTrue);
      expect(second.comboIndex, 2);
      expect(second.damage, greaterThan(first.damage));
    });

    test('weapon selection changes attack cooldown and damage profile', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.flame));
      final first = runtime.attack();
      runtime.advance(const Duration(seconds: 1));
      runtime.selectWeapon(1);
      final heavy = runtime.attack();
      expect(heavy.damage, greaterThan(first.damage));
      expect(heavy.cooldownRemainingMs, 820);
    });

    test('Ultimate buttons enforce unlock level and independent cooldowns', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.shadow));
      expect(runtime.useUltimate(1).accepted, isFalse);
      expect(runtime.useUltimate(0).accepted, isTrue);
      expect(runtime.useUltimate(0).accepted, isFalse);
      expect(runtime.useUltimate(1).accepted, isFalse);

      runtime.advance(const Duration(seconds: 18));
      expect(runtime.useUltimate(0).accepted, isTrue);
    });

    test('Ultimate is independent and does not consume the five-hit combo', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.ranger));
      runtime.attack();
      expect(runtime.comboIndex, 1);

      runtime.advance(const Duration(milliseconds: 520));
      expect(runtime.useUltimate(0).accepted, isTrue);
      expect(runtime.comboIndex, 1);

      runtime.advance(const Duration(milliseconds: 520));
      final nextHit = runtime.attack();
      expect(nextHit.accepted, isTrue);
      expect(nextHit.comboIndex, 2);
    });

    test('XP levels the hero and stops at level 40', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.storm));
      expect(runtime.gainExperience(150), 1);
      expect(runtime.level, 2);
      expect(runtime.health, 618);
      expect(runtime.gainExperience(100000000), 38);
      expect(runtime.level, heroLevelCap);
      expect(runtime.gainExperience(1000), 0);
    });

    test('all heroes have equal health and retain their distinct movement speed', () {
      final runtimes = HeroId.values
          .map((id) => HeroCombatRuntime(hero: heroCombatById(id), level: 12))
          .toList();
      expect(runtimes.map((runtime) => runtime.health).toSet(), hasLength(1));
      expect(runtimes.map((runtime) => runtime.moveSpeed).toSet(), hasLength(4));
    });

    test('target can be reset without resetting progression', () {
      final runtime = HeroCombatRuntime(
        hero: heroCombatById(HeroId.ranger),
        targetMaxHealth: 500,
      );
      runtime.attack();
      runtime.resetTarget();
      expect(runtime.targetHealth, 500);
      expect(runtime.level, 1);
      expect(runtime.comboIndex, 0);
    });
  });
}
