import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/progress/hero_progress.dart';
import 'package:archer_fm/game/progress/match_xp.dart';
import 'package:archer_fm/game/progress/progression_screen.dart';
import 'package:archer_fm/game/progress/xp.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hero XP formula 1–40', () {
    test('matches 100 + 25 × (L - 1) + 3 × (L - 1)² for every level', () {
      for (var level = 1; level <= heroMaxLevel; level++) {
        final step = level - 1;
        final expected = 100 + 25 * step + 3 * step * step;
        expect(heroXpRequired(level), expected, reason: 'level $level');
      }
    });

    test('cumulative total to level 40 matches the unified formula', () {
      var total = 0;
      for (var level = 1; level <= 39; level++) {
        total += heroXpRequired(level);
      }
      expect(total, 79482);
      expect(heroTotalXpToLevel(40), total);
      expect(heroTotalXpToLevel(1), 0);
    });

    test('HeroXpState progresses, reports remaining, and stops at 40', () {
      final start = HeroXpState.fromTotal(0);
      expect(start.level, 1);
      expect(start.xp, 0);
      expect(start.required, heroXpRequired(1));
      expect(start.remaining, heroXpRequired(1));

      final mid = HeroXpState.fromTotal(heroXpRequired(1) + 10);
      expect(mid.level, 2);
      expect(mid.xp, 10);
      expect(mid.remaining, heroXpRequired(2) - 10);

      final capped = HeroXpState.fromTotal(heroTotalXpToLevel(40) + 9999);
      expect(capped.level, 40);
      expect(capped.isMax, isTrue);
      expect(capped.xp, 0);
      expect(capped.remaining, 0);
      expect(capped.progress, 1.0);
      expect(capped.apply(500).totalXp, capped.totalXp);
    });
  });

  group('monster XP formula', () {
    test('uses the separate gentler curve 60 + 14 × (L - 1) + (L - 1)²', () {
      var total = 0;
      for (var level = 1; level <= 39; level++) {
        final step = level - 1;
        final expected = 60 + 14 * step + step * step;
        expect(monsterXpRequired(level), expected, reason: 'level $level');
        expect(monsterXpRequired(level), lessThan(heroXpRequired(level)));
        total += monsterXpRequired(level);
      }
      expect(total, 31733);
      expect(monsterTotalXpToLevel(40), 31733);
    });

    test('MonsterXpState tracks level and progress independently', () {
      final runner = MonsterXpState(0).apply(monsterXpRequired(1) + 5);
      expect(runner.level, 2);
      expect(runner.currentXp, 5);
      expect(runner.remaining, monsterXpRequired(2) - 5);

      final capped = MonsterXpState(monsterTotalXpToLevel(40) + 100);
      expect(capped.level, monsterXpMaxLevel);
      expect(capped.isMax, isTrue);
      expect(capped.currentXp, 0);
    });
  });

  group('ability unlocks 1/10/20/30', () {
    test('every hero kit defines four abilities at 1, 10, 20, 30', () {
      const expected = [1, 10, 20, 30];
      for (final hero in heroCatalog) {
        final kit = kitForHero(hero.id);
        final levels = kit.abilities.map((a) => a.unlockLevel).toList()..sort();
        expect(levels, expected, reason: hero.id);
        expect(kit.abilitiesUnlockedAt(1).length, 1, reason: hero.id);
        expect(kit.abilitiesUnlockedAt(9).length, 1, reason: hero.id);
        expect(kit.abilitiesUnlockedAt(10).length, 2, reason: hero.id);
        expect(kit.abilitiesUnlockedAt(20).length, 3, reason: hero.id);
        expect(kit.abilitiesUnlockedAt(30).length, 4, reason: hero.id);
      }
    });

    test('applying XP persists unlocked abilities for the reached level', () {
      final award = XpAward(
        matchId: 'm1',
        heroXp: heroTotalXpToLevel(10),
        sources: const {'participation': 0},
        monsterXp: const {},
        monsterSources: const {},
        heroDamage: 0,
        activities: 1,
        won: false,
        earlyLeave: false,
      );
      final updated = HeroProgress.initial.applyXpAward(
        award,
        heroId: 'ranger_new',
      );
      expect(updated.level, 10);
      expect(updated.unlockedAbilityIds, contains('piercing_shot'));
      expect(updated.unlockedAbilityIds, contains('multi_shot'));
    });
  });

  group('hero and monster independence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('different heroes keep separate XP, levels and histories', () async {
      final store = SharedPreferencesProgressStore();
      final rangerAward = XpAward(
        matchId: 'r1',
        heroXp: 400,
        sources: const {'participation': 150, 'monsterKill': 250},
        monsterXp: const {MonsterType.runner: 30},
        monsterSources: const {},
        heroDamage: 0,
        activities: 5,
        won: false,
        earlyLeave: false,
      );
      final stormAward = XpAward(
        matchId: 's1',
        heroXp: 80,
        sources: const {'participation': 80},
        monsterXp: const {MonsterType.tank: 20},
        monsterSources: const {},
        heroDamage: 0,
        activities: 5,
        won: false,
        earlyLeave: false,
      );

      final ranger = HeroProgress.initial
          .applyXpAward(rangerAward, heroId: 'ranger_new');
      final storm = HeroProgress.initial.applyXpAward(stormAward, heroId: 'storm');
      await store.save('ranger_new', ranger);
      await store.save('storm', storm);

      final loadedRanger = await store.load('ranger_new');
      final loadedStorm = await store.load('storm');
      expect(loadedRanger!.heroXp.totalXp, 400);
      expect(loadedStorm!.heroXp.totalXp, 80);
      expect(loadedRanger.heroXp.level, greaterThan(1));
      expect(loadedStorm.heroXp.level, 1);
      expect(loadedRanger.monsterXpState(MonsterType.runner).xp, 30);
      expect(loadedRanger.monsterXpState(MonsterType.tank).xp, 0);
      expect(loadedStorm.monsterXpState(MonsterType.tank).xp, 20);
      expect(loadedStorm.monsterXpState(MonsterType.runner).xp, 0);
    });

    test('monster types earn XP independently from each other and hero', () {
      final ledger = MatchXpLedger(matchId: 'm', heroId: 'ranger_new');
      ledger.recordMonsterDamage(type: MonsterType.runner, unitId: 'u1', amount: 30);
      ledger.recordMonsterKill(type: MonsterType.tank, unitId: 'u2');
      final award = ledger.finalize(won: false, earlyLeave: false);
      expect(award.monsterXp[MonsterType.runner], greaterThan(0));
      expect(award.monsterXp[MonsterType.tank], greaterThan(0));
      expect(award.monsterXp[MonsterType.stalker], 0);
      expect(award.monsterXp[MonsterType.ranged], 0);
      // Hero XP remains 0 here: only participation (no real actions recorded via
      // hero events except activity marks inside monster calls? markActivity is
      // called) but participation depends on activities; monster actions mark
      // activity, so hero gets reduced/full participation only, not monster XP.
      expect(award.heroXp, lessThanOrEqualTo(HeroXpRewards.participation));
      expect(award.totalMonsterXp, greaterThan(0));
    });
  });

  group('persistence and restart safety', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists hero XP, abilities, monster XP, weapons and last gain', () async {
      final store = SharedPreferencesProgressStore();
      final award = XpAward(
        matchId: 'persist_1',
        heroXp: 260,
        sources: const {
          'participation': 150,
          'monsterKill': 10,
          'win': 100,
        },
        monsterXp: const {
          MonsterType.runner: 12,
          MonsterType.tank: 8,
          MonsterType.stalker: 0,
          MonsterType.ranged: 4,
        },
        monsterSources: const {},
        heroDamage: 0,
        activities: 4,
        won: true,
        earlyLeave: false,
      );
      final progress = HeroProgress.initial.copyWith(
        weaponLevels: const {'starter_bow': 3},
        unlockedWeaponIds: const ['starter_bow', 'longbow'],
      ).applyXpAward(award, heroId: 'ranger_new');

      await store.save('ranger_new', progress);
      final loaded = await store.load('ranger_new');
      expect(loaded, isNotNull);
      expect(loaded!.heroXp.totalXp, 260);
      expect(loaded.heroXp.level, progress.heroXp.level);
      expect(loaded.unlockedAbilityIds, contains('multi_shot'));
      expect(loaded.monsterXpState(MonsterType.runner).xp, 12);
      expect(loaded.monsterXpState(MonsterType.ranged).xp, 4);
      expect(loaded.weaponLevels['starter_bow'], 3);
      expect(loaded.unlockedWeaponIds, contains('longbow'));
      expect(loaded.lastXpGain, isNotNull);
      expect(loaded.lastXpGain!.heroXp, 260);
      expect(loaded.lastXpGain!.matchId, 'persist_1');
      expect(loaded.settledMatchIds, contains('persist_1'));
    });

    test('the same match cannot be settled twice after restart', () async {
      final store = SharedPreferencesProgressStore();
      final award = XpAward(
        matchId: 'same_match',
        heroXp: 155,
        sources: const {'participation': 150, 'monsterKill': 5},
        monsterXp: const {MonsterType.runner: 6},
        monsterSources: const {},
        heroDamage: 0,
        activities: 3,
        won: false,
        earlyLeave: false,
      );
      var progress = HeroProgress.initial.applyXpAward(award, heroId: 'ranger_new');
      await store.save('ranger_new', progress);
      progress = (await store.load('ranger_new'))!;
      final again = progress.applyXpAward(award, heroId: 'ranger_new');
      expect(again.heroXp.totalXp, progress.heroXp.totalXp);
      expect(again.monsterXpState(MonsterType.runner).xp,
          progress.monsterXpState(MonsterType.runner).xp);
      expect(again.xpHistory.length, progress.xpHistory.length);
    });
  });

  group('duplicate and exploit prevention', () {
    test('ledger deduplicates repeated confirmed events', () {
      final ledger = MatchXpLedger(matchId: 'dedup', heroId: 'ranger_new');
      ledger.recordEnemyKill('e1');
      ledger.recordEnemyKill('e1');
      ledger.recordCrystal('rival', 2);
      ledger.recordCrystal('rival', 2);
      ledger.recordCastle('rival');
      ledger.recordCastle('rival');
      ledger.recordMineCapture('mineA', neutral: true);
      ledger.recordMineCapture('mineA', neutral: true);
      ledger.recordMineCollection('pickupA');
      ledger.recordMineCollection('pickupA');
      ledger.recordHeroDamage(damageId: 'd1', targetId: 'hero2', amount: 20);
      ledger.recordHeroDamage(damageId: 'd1', targetId: 'hero2', amount: 20);
      ledger.recordMonsterDamage(type: MonsterType.runner, unitId: 'u1', amount: 30);
      ledger.recordMonsterDamage(type: MonsterType.runner, unitId: 'u1', amount: 30);
      ledger.recordMonsterKill(type: MonsterType.runner, unitId: 'u1');
      ledger.recordMonsterKill(type: MonsterType.runner, unitId: 'u1');

      final award = ledger.finalize(won: false, earlyLeave: false);
      expect(
        award.heroXp,
        HeroXpRewards.participation +
            HeroXpRewards.monsterKill +
            HeroXpRewards.crystal +
            HeroXpRewards.castle +
            HeroXpRewards.neutralMine +
            HeroXpRewards.mineCollection +
            10, // 20 damage / 2
      );
      expect(award.monsterXp[MonsterType.runner], 10 + MonsterXpRewards.kill);
    });

    test('hero damage and performance rewards are capped per match', () {
      final ledger = MatchXpLedger(matchId: 'cap', heroId: 'ranger_new');
      for (var i = 0; i < 40; i++) {
        ledger.recordHeroDamage(
          damageId: 'd$i',
          targetId: 'hero2',
          amount: 20,
        );
      }
      for (var i = 0; i < 20; i++) {
        ledger.recordCastle('rival$i');
      }
      final award = ledger.finalize(won: false, earlyLeave: false);
      expect(award.source('heroDamage'), HeroXpRewards.heroDamageMax);
      // Participation is added separately; all other sources are capped at 500.
      final performance = award.heroXp - award.source('participation');
      expect(performance, HeroXpRewards.performanceCap);
    });

    test('participation and win follow activity and early-leave rules', () {
      final idle = MatchXpLedger(matchId: 'idle', heroId: 'ranger_new');
      expect(idle.finalize(won: false, earlyLeave: false).heroXp, 0);

      final reduced = MatchXpLedger(matchId: 'reduced', heroId: 'ranger_new')
        ..recordEnemyKill('e1'); // 1 real action
      expect(
        reduced.finalize(won: false, earlyLeave: false).source('participation'),
        HeroXpRewards.reducedParticipation,
      );

      final full = MatchXpLedger(matchId: 'full', heroId: 'ranger_new')
        ..recordEnemyKill('e1')
        ..recordMineCollection('p1')
        ..recordMineCapture('m1', neutral: true);
      final fullAward = full.finalize(won: true, earlyLeave: false);
      expect(fullAward.source('participation'), HeroXpRewards.participation);
      expect(fullAward.source('win'), HeroXpRewards.win);

      final early = MatchXpLedger(matchId: 'early', heroId: 'ranger_new')
        ..recordEnemyKill('e1')
        ..recordEnemyKill('e2')
        ..recordEnemyKill('e3');
      final earlyAward = early.finalize(won: false, earlyLeave: true);
      expect(earlyAward.source('participation'), 0);
      expect(earlyAward.source('win'), 0);
      expect(earlyAward.earlyLeave, isTrue);
    });

    test('enemy mine capture and no-op actions never grant free XP', () {
      final ledger = MatchXpLedger(matchId: 'noop', heroId: 'ranger_new');
      ledger.recordMineCapture('enemyMine', neutral: false);
      ledger.recordHeroDamage(damageId: 'bad', targetId: 'h', amount: 0);
      final award = ledger.finalize(won: false, earlyLeave: false);
      // Capturing an enemy mine is a real action, so reduced participation may
      // apply, but there is no neutral-mine reward.
      expect(award.source('neutralMine'), 0);
      expect(award.source('heroDamage'), 0);
      expect(award.heroXp, HeroXpRewards.reducedParticipation);
    });
  });

  group('progression UI', () {
    testWidgets('shows hero XP, four abilities, monster XP and weapon unlocks',
        (tester) async {
      final store = MemoryProgressStore();
      final base = HeroProgress.initial.applyXpAward(
        XpAward(
          matchId: 'ui_1',
          heroXp: heroTotalXpToLevel(10) + 30,
          sources: const {'participation': 30},
          monsterXp: {
            MonsterType.runner: monsterXpRequired(1) + 5,
            MonsterType.tank: 12,
            MonsterType.stalker: 0,
            MonsterType.ranged: 3,
          },
          monsterSources: const {},
          heroDamage: 0,
          activities: 3,
          won: false,
          earlyLeave: false,
        ),
        heroId: 'ranger_new',
      );
      await store.save('ranger_new', base);

      await tester.pumpWidget(
        MaterialApp(
          home: ProgressionScreen(
            hero: heroById('ranger_new'),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('progression_hero_xp_bar')), findsOneWidget);
      expect(find.textContaining('المستوى 10/$heroMaxLevel'), findsOneWidget);
      expect(find.textContaining('المتبقي'), findsOneWidget);
      expect(find.text('القدرات الأربع'), findsOneWidget);

      final kit = kitForHero('ranger_new');
      for (final ability in kit.abilities) {
        expect(find.textContaining(ability.nameAr), findsWidgets);
        expect(find.textContaining('المستوى ${ability.unlockLevel}'), findsWidgets);
      }

      await tester.tap(find.text('الوحوش'));
      await tester.pumpAndSettle();
      final monstersList = find.byType(Scrollable).last;
      for (final type in MonsterType.values) {
        final key = find.byKey(ValueKey('monster_xp_${type.name}'));
        await tester.scrollUntilVisible(key, 200, scrollable: monstersList);
        await tester.pumpAndSettle();
        expect(key, findsOneWidget);
        expect(find.textContaining(MonsterCatalog.def(type).nameAr), findsWidgets);
      }

      await tester.tap(find.text('الأسلحة'));
      await tester.pumpAndSettle();
      final heroLevel = (await store.load('ranger_new'))!.heroXp.level;
      for (final weapon in kit.weapons) {
        final tile = find.byKey(ValueKey('hero_weapon_${weapon.id}'));
        await tester.scrollUntilVisible(
          tile,
          250,
          scrollable: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          ).last,
        );
        await tester.pumpAndSettle();
        expect(tile, findsOneWidget);
        if (weapon.unlockedAt(heroLevel)) {
          expect(find.textContaining('مفتوح'), findsWidgets);
        } else {
          expect(find.textContaining('يُفتح في المستوى ${weapon.unlockLevel}'),
              findsWidgets);
        }
      }
    });
  });
}
