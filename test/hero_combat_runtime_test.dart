import 'package:archer_fm/game/heroes/hero_roster.dart';
import 'package:archer_fm/game/heroes/hero_combat_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, int> _energyCosts({int cost = 20}) => {
      for (final hero in archerFmHeroes)
        for (final ultimate in hero.ultimates) ultimate.id: cost,
    };

void main() {
  group('HeroCombatRuntime', () {
    test('manual attacks form a five-hit combo and respect weapon cooldown', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.ranger), comboResetWindowMs: 1200,
          maxEnergy: 100,
          energyRegenerationPerSecond: 1,
          ultimateEnergyCosts: _energyCosts(),
        );
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

    test('missed combo timing window resets the sequence before the next tap', () {
      final runtime = HeroCombatRuntime(
        hero: heroCombatById(HeroId.ranger),
        comboResetWindowMs: 1000,
        maxEnergy: 100,
        energyRegenerationPerSecond: 1,
        ultimateEnergyCosts: _energyCosts(),
      );
      expect(runtime.attack().comboIndex, 1);
      runtime.advance(const Duration(milliseconds: 520));
      expect(runtime.attack().comboIndex, 2);
      runtime.advance(const Duration(milliseconds: 1000));
      expect(runtime.comboIndex, 0);
      final restarted = runtime.attack();
      expect(restarted.comboIndex, 1);
      expect(restarted.damage, 54);
    });

    test('weapon selection changes attack cooldown and damage profile', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.flame), comboResetWindowMs: 1200,
          maxEnergy: 100,
          energyRegenerationPerSecond: 1,
          ultimateEnergyCosts: _energyCosts(),
        );
      final first = runtime.attack();
      runtime.advance(const Duration(seconds: 1));
      runtime.selectWeapon(1);
      final heavy = runtime.attack();
      expect(heavy.damage, greaterThan(first.damage));
      expect(heavy.cooldownRemainingMs, 820);
    });

    test('all four Ultimates unlock at levels 1, 10, 20 and 30 for every hero', () {
      for (final hero in archerFmHeroes) {
        expect(
          hero.ultimates.map((ultimate) => ultimate.unlockLevel).toList(),
          [1, 10, 20, 30],
          reason: '${hero.nameAr} must keep the four agreed unlock milestones.',
        );
        for (var index = 0; index < hero.ultimates.length; index++) {
          final unlockLevel = hero.ultimates[index].unlockLevel;
          final runtime = HeroCombatRuntime(
            hero: heroCombatById(hero.id),
            level: unlockLevel,
            comboResetWindowMs: 1200,
            maxEnergy: 100,
            energyRegenerationPerSecond: 1,
            ultimateEnergyCosts: _energyCosts(cost: 1),
          );
          expect(
            runtime.useUltimate(index).accepted,
            isTrue,
            reason: '${hero.nameAr} Ultimate $index should unlock at level $unlockLevel.',
          );
        }
      }
    });

    test('Ultimate buttons enforce unlock level and independent cooldowns', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.shadow), comboResetWindowMs: 1200,
          maxEnergy: 100,
          energyRegenerationPerSecond: 1,
          ultimateEnergyCosts: _energyCosts(),
        );
      expect(runtime.useUltimate(1).accepted, isFalse);
      expect(runtime.useUltimate(0).accepted, isTrue);
      expect(runtime.useUltimate(0).accepted, isFalse);
      expect(runtime.useUltimate(1).accepted, isFalse);

      runtime.advance(const Duration(seconds: 18));
      expect(runtime.useUltimate(0).accepted, isTrue);
    });

    test('Ultimates spend configured energy and regenerate independently of cooldowns', () {
      final runtime = HeroCombatRuntime(
        hero: heroCombatById(HeroId.ranger),
        level: 10,
        comboResetWindowMs: 1200,
        maxEnergy: 50,
        energyRegenerationPerSecond: 10,
        ultimateEnergyCosts: _energyCosts(cost: 40),
      );
      expect(runtime.energy, 50);
      expect(runtime.useUltimate(0).accepted, isTrue);
      expect(runtime.energy, 10);
      expect(runtime.useUltimate(1).accepted, isFalse);
      expect(runtime.energy, 10);
      runtime.advance(const Duration(seconds: 2));
      expect(runtime.energy, 30);
      runtime.advance(const Duration(seconds: 2));
      expect(runtime.energy, 50);
      expect(runtime.useUltimate(1).accepted, isTrue);
      expect(runtime.energy, 10);
    });

    test('Ultimate is independent and does not consume the five-hit combo', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.ranger), comboResetWindowMs: 1200,
          maxEnergy: 100,
          energyRegenerationPerSecond: 1,
          ultimateEnergyCosts: _energyCosts(),
        );
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

    test('trusted permanent weapon upgrades scale attacks and Ultimates', () {
      final runtime = HeroCombatRuntime(
        hero: heroCombatById(HeroId.ranger),
        level: 10,
        comboResetWindowMs: 1200,
        maxEnergy: 100,
        energyRegenerationPerSecond: 1,
        ultimateEnergyCosts: _energyCosts(),
        weaponUpgradeLevel: 2,
        weaponUpgradeDamagePerLevel: 0.05,
      );
      final base = HeroCombatRuntime(
        hero: heroCombatById(HeroId.ranger),
        level: 10,
        comboResetWindowMs: 1200,
        maxEnergy: 100,
        energyRegenerationPerSecond: 1,
        ultimateEnergyCosts: _energyCosts(),
      );
      expect(runtime.attack().damage, (base.attack().damage * 1.1).round());
      runtime.advance(const Duration(seconds: 2));
      base.advance(const Duration(seconds: 2));
      expect(
        runtime.useUltimate(0).damage,
        (base.useUltimate(0).damage * 1.1).round(),
      );
    });

    test('XP levels the hero and stops at level 40', () {
      final runtime = HeroCombatRuntime(hero: heroCombatById(HeroId.storm), comboResetWindowMs: 1200,
          maxEnergy: 100,
          energyRegenerationPerSecond: 1,
          ultimateEnergyCosts: _energyCosts(),
        );
      expect(runtime.gainExperience(150), 1);
      expect(runtime.level, 2);
      expect(runtime.health, 618);
      expect(runtime.gainExperience(100000000), 38);
      expect(runtime.level, heroLevelCap);
      expect(runtime.gainExperience(1000), 0);
    });

    test('all heroes have equal health and retain their distinct movement speed', () {
      final runtimes = HeroId.values
          .map((id) => HeroCombatRuntime(
              hero: heroCombatById(id),
              level: 12,
              comboResetWindowMs: 1200,
              maxEnergy: 100,
              energyRegenerationPerSecond: 1,
              ultimateEnergyCosts: _energyCosts(),
            ))
          .toList();
      expect(runtimes.map((runtime) => runtime.health).toSet(), hasLength(1));
      expect(runtimes.map((runtime) => runtime.moveSpeed).toSet(), hasLength(4));
    });

    test('target can be reset without resetting progression', () {
      final runtime = HeroCombatRuntime(
        hero: heroCombatById(HeroId.ranger),
        targetMaxHealth: 500,
        comboResetWindowMs: 1200,
        maxEnergy: 100,
        energyRegenerationPerSecond: 1,
        ultimateEnergyCosts: _energyCosts(),
      );
      runtime.attack();
      runtime.resetTarget();
      expect(runtime.targetHealth, 500);
      expect(runtime.level, 1);
      expect(runtime.comboIndex, 0);
    });
  });
}
