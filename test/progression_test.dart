import 'dart:math' as math;

import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/progress/equipment.dart';
import 'package:archer_fm/game/progress/hero_progress.dart';
import 'package:archer_fm/game/progress/progression.dart';
import 'package:archer_fm/game/progress/progression_screen.dart';
import 'package:archer_fm/game/world/arena_map.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

EquipmentItem item({
  String id = 'item_1',
  EquipmentSlot slot = EquipmentSlot.weapon,
  EquipmentRarity rarity = EquipmentRarity.rare,
  int level = 1,
}) =>
    EquipmentItem(id: id, slot: slot, rarity: rarity, level: level);

GameWorld makeWorld({int seed = 11}) {
  final world = GameWorld(
    kit: rangerNewKit,
    random: math.Random(seed),
    spawnWaves: false,
  );
  world.enemies.clear();
  world.projectiles.clear();
  return world;
}

void main() {
  group('equipment model', () {
    test('six slots, five rarities and the confirmed level cap of 40', () {
      expect(EquipmentSlot.values.length, equipmentSlotCount);
      expect(equipmentSlotCount, 6);
      expect(EquipmentRarity.values.length, equipmentRarityCount);
      expect(equipmentRarityCount, 5);
      expect(equipmentMaxLevel, 40);
      final weapon = item(level: 99);
      expect(weapon.cappedLevel, 40);
      expect(weapon.isMaxLevel, isTrue);
      expect(weapon.withLevel(0).level, 1);
      expect(item().isMaxLevel, isFalse);
    });

    test('rarities get stronger, rarer in chests and worth more', () {
      for (var i = 1; i < EquipmentRarity.values.length; i++) {
        final previous = EquipmentRarity.values[i - 1];
        final current = EquipmentRarity.values[i];
        expect(current.power, greaterThan(previous.power));
        expect(current.chestWeight, lessThan(previous.chestWeight));
        expect(current.baseSellValue, greaterThan(previous.baseSellValue));
        expect(current.duplicateMaterialValue,
            greaterThanOrEqualTo(previous.duplicateMaterialValue));
      }
      final total = EquipmentRarity.values
          .fold<int>(0, (sum, rarity) => sum + rarity.chestWeight);
      expect(total, 100);
    });

    test('slot bonuses and the neutral default', () {
      expect(const EquipmentBonuses().hpMultiplier, 1.0);
      expect(const EquipmentBonuses().damageMultiplier, 1.0);
      expect(const EquipmentBonuses().moveMultiplier, 1.0);

      final helmet = item(slot: EquipmentSlot.helmet);
      final armor = item(slot: EquipmentSlot.armor);
      final necklace = item(slot: EquipmentSlot.necklace);
      expect(helmet.hpBonusFraction, greaterThan(0));
      expect(armor.hpBonusFraction, greaterThan(0));
      expect(necklace.hpBonusFraction, greaterThan(0));
      expect(helmet.damageBonusFraction, 0);
      expect(helmet.moveBonusFraction, 0);

      final weapon = item(slot: EquipmentSlot.weapon);
      final ring = item(slot: EquipmentSlot.ring);
      final boots = item(slot: EquipmentSlot.boots);
      expect(weapon.damageBonusFraction, greaterThan(0));
      expect(ring.damageBonusFraction, greaterThan(0));
      expect(boots.moveBonusFraction, greaterThan(0));
      expect(weapon.hpBonusFraction, 0);

      final combined = EquipmentBonuses.forItems([weapon, helmet, boots]);
      expect(combined.hpMultiplier, greaterThan(1));
      expect(combined.damageMultiplier, greaterThan(1));
      expect(combined.moveMultiplier, greaterThan(1));
    });

    test('duplicates compare the template, not the instance id', () {
      expect(
        item(id: 'a').isDuplicateOf(item(id: 'b')),
        isTrue,
      );
      expect(
        item(id: 'a', rarity: EquipmentRarity.epic)
            .isDuplicateOf(item(id: 'b')),
        isFalse,
      );
      expect(
        item(id: 'a', slot: EquipmentSlot.ring)
            .isDuplicateOf(item(id: 'b')),
        isFalse,
      );
      expect(
        item(id: 'a', level: 9).isDuplicateOf(item(id: 'b')),
        isTrue,
      );
    });

    test('sell and upgrade prices grow with the level', () {
      final low = item(level: 1);
      final high = item(level: 20);
      expect(high.sellValue, greaterThan(low.sellValue));
      expect(high.upgradeCurrencyCost, greaterThan(low.upgradeCurrencyCost));
      expect(high.upgradeMaterialCost,
          greaterThanOrEqualTo(low.upgradeMaterialCost));
    });

    test('chest rolls only equipment and weapons of the five rarities', () {
      final random = math.Random(42);
      for (var i = 0; i < 500; i++) {
        final rolled = rollChestItem(random, id: 'roll_$i');
        expect(EquipmentSlot.values, contains(rolled.slot));
        expect(EquipmentRarity.values, contains(rolled.rarity));
        expect(rolled.level, 1);
      }
    });
  });

  group('progression controller', () {
    test('starts empty with the confirmed capacity and neutral stats', () {
      final controller = ProgressionController(heroId: 'ranger_new');
      expect(controller.currency, 0);
      expect(controller.equipment, isEmpty);
      expect(controller.carryCapacity, baseCarryCapacity);
      expect(controller.carryCapacity, 500);
      expect(controller.capacityLevel, 0);
      expect(controller.heroUpgradeLevel, 0);
      expect(controller.bonuses.hpMultiplier, 1.0);
      expect(controller.bonuses.damageMultiplier, 1.0);
      expect(controller.bonuses.moveMultiplier, 1.0);
      expect(controller.accountPower, 1);
    });

    test('new items are stored and auto-equipped, duplicates become materials',
        () {
      final controller = ProgressionController(heroId: 'ranger_new');
      final first = controller.addEquipment(item(id: 'a'));
      expect(first.result, EquipmentAddResult.added);
      expect(controller.equipment.length, 1);
      expect(controller.equippedIn(EquipmentSlot.weapon)?.id, 'a');

      final duplicate = controller.addEquipment(item(id: 'b'));
      expect(duplicate.isDuplicate, isTrue);
      expect(duplicate.materialGained,
          EquipmentRarity.rare.duplicateMaterialValue);
      expect(controller.equipment.length, 1);
      expect(
        controller.materialOf(ProgressionMaterial.equipment),
        duplicate.materialGained,
      );

      // A different rarity is a different template, so it is kept.
      final epic = controller.addEquipment(
        item(id: 'c', rarity: EquipmentRarity.epic),
      );
      expect(epic.result, EquipmentAddResult.added);
      expect(controller.equipment.length, 2);
      // The slot is already filled by the first item.
      expect(controller.equippedIn(EquipmentSlot.weapon)?.id, 'a');
    });

    test('equip, unequip and sell rules', () {
      final controller = ProgressionController(heroId: 'ranger_new');
      controller.addEquipment(item(id: 'a', slot: EquipmentSlot.helmet));
      controller.addEquipment(item(id: 'b', slot: EquipmentSlot.boots));
      expect(controller.equippedIn(EquipmentSlot.helmet)?.id, 'a');
      expect(controller.equippedIn(EquipmentSlot.boots)?.id, 'b');

      expect(controller.sell('a'), isFalse); // equipped items are protected
      expect(controller.unequip(EquipmentSlot.helmet), isTrue);
      expect(controller.equippedIn(EquipmentSlot.helmet), isNull);
      final value = controller.itemById('a')!.sellValue;
      expect(controller.sell('a'), isTrue);
      expect(controller.itemById('a'), isNull);
      expect(controller.currency, value);
      expect(controller.sell('missing'), isFalse);
      expect(controller.equip('missing'), isFalse);
    });

    test('item upgrades spend currency and equipment materials up to 40', () {
      final controller = ProgressionController(
        heroId: 'ranger_new',
        currency: 100000,
        materials: {ProgressionMaterial.equipment: 1000},
      );
      controller.addEquipment(item(id: 'a', level: 39));
      expect(controller.canUpgradeItem(controller.itemById('a')!), isTrue);
      expect(controller.upgradeItem('a'), isTrue);
      expect(controller.itemById('a')!.cappedLevel, 40);
      expect(controller.upgradeItem('a'), isFalse);
      expect(controller.currency, lessThan(100000));
      expect(
        controller.materialOf(ProgressionMaterial.equipment),
        lessThan(1000),
      );
    });

    test('every upgrade category needs its own material, not just currency',
        () {
      final poor = ProgressionController(heroId: 'ranger_new', currency: 9999);
      expect(poor.canUpgradeHero, isFalse);
      expect(poor.upgradeHero(), isFalse);
      expect(poor.canUpgradeCapacity, isFalse);
      expect(poor.upgradeCapacity(), isFalse);

      poor.addMaterial(ProgressionMaterial.hero, 10);
      expect(poor.upgradeHero(), isTrue);
      expect(poor.heroUpgradeLevel, 1);
      expect(poor.bonuses.hpMultiplier, greaterThan(1.0));
      expect(poor.bonuses.damageMultiplier, greaterThan(1.0));

      poor.addMaterial(ProgressionMaterial.capacity, 10);
      expect(poor.upgradeCapacity(), isTrue);
      expect(poor.capacityLevel, 1);
      expect(poor.carryCapacity, baseCarryCapacity + capacityUpgradeStep);
    });

    test('capacity stops at level 20 and the hero stat at level 40', () {
      final controller = ProgressionController(
        heroId: 'ranger_new',
        currency: 10000000,
        materials: {
          ProgressionMaterial.hero: 10000,
          ProgressionMaterial.capacity: 10000,
        },
      );
      for (var i = 0; i < maxCapacityLevel + 3; i++) {
        controller.upgradeCapacity();
      }
      expect(controller.capacityLevel, maxCapacityLevel);
      expect(controller.carryCapacity, 1500);
      for (var i = 0; i < maxHeroUpgradeLevel + 3; i++) {
        controller.upgradeHero();
      }
      expect(controller.heroUpgradeLevel, maxHeroUpgradeLevel);
      expect(controller.canUpgradeHero, isFalse);
      expect(controller.canUpgradeCapacity, isFalse);
    });

    test('account power grows with upgrades and equipment', () {
      final controller = ProgressionController(
        heroId: 'ranger_new',
        currency: 100000,
        materials: {
          ProgressionMaterial.hero: 10,
          ProgressionMaterial.capacity: 10,
        },
      );
      final initial = controller.accountPower;
      controller.upgradeHero();
      controller.upgradeCapacity();
      controller.addEquipment(item(rarity: EquipmentRarity.legendary, level: 5));
      expect(controller.accountPower, greaterThan(initial));
    });

    test('fromProgress maps a saved profile back into the controller', () {
      final saved = HeroProgress(
        level: 11,
        xp: 20,
        kills: 4,
        essence: 1234,
        materials: {
          ProgressionMaterial.hero.name: 3,
          ProgressionMaterial.monster.name: 4,
          ProgressionMaterial.equipment.name: 5,
          ProgressionMaterial.capacity.name: 6,
          'unknown': 9,
        },
        equipment: [item(id: 'a', rarity: EquipmentRarity.epic)],
        equipped: {'weapon': 'a', 'unknown': 'x'},
        capacityLevel: 3,
        heroUpgradeLevel: 2,
      );
      final controller = ProgressionController.fromProgress('ranger_new', saved);
      expect(controller.currency, 1234);
      expect(controller.materialOf(ProgressionMaterial.hero), 3);
      expect(controller.materialOf(ProgressionMaterial.monster), 4);
      expect(controller.materialOf(ProgressionMaterial.equipment), 5);
      expect(controller.materialOf(ProgressionMaterial.capacity), 6);
      expect(controller.equipment.single.id, 'a');
      expect(controller.equippedIn(EquipmentSlot.weapon)?.id, 'a');
      expect(controller.capacityLevel, 3);
      expect(controller.heroUpgradeLevel, 2);
      expect(controller.bonuses.hpMultiplier, greaterThan(1.0));
    });
  });

  group('persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    TestWidgetsFlutterBinding.ensureInitialized();

    test('full progression survives a save/load round trip', () async {
      final store = SharedPreferencesProgressStore();
      final saved = HeroProgress(
        level: 7,
        xp: 50,
        kills: 2,
        armyLevels: {'tank': 3},
        essence: 900,
        materials: {
          ProgressionMaterial.hero.name: 1,
          ProgressionMaterial.monster.name: 2,
          ProgressionMaterial.equipment.name: 3,
          ProgressionMaterial.capacity.name: 4,
        },
        equipment: [
          item(id: 'a', slot: EquipmentSlot.helmet, level: 9),
          item(id: 'b', slot: EquipmentSlot.weapon, level: 40),
        ],
        equipped: {'helmet': 'a'},
        capacityLevel: 5,
        heroUpgradeLevel: 6,
      );
      await store.save('ranger_new', saved);
      final loaded = await store.load('ranger_new');
      expect(loaded, isNotNull);
      expect(loaded!.level, 7);
      expect(loaded.xp, 50);
      expect(loaded.kills, 2);
      expect(loaded.armyLevels['tank'], 3);
      expect(loaded.essence, 900);
      expect(loaded.materials[ProgressionMaterial.hero.name], 1);
      expect(loaded.materials[ProgressionMaterial.equipment.name], 3);
      expect(loaded.equipment.length, 2);
      expect(loaded.equipment.last.cappedLevel, 40);
      expect(loaded.equipped['helmet'], 'a');
      expect(loaded.capacityLevel, 5);
      expect(loaded.heroUpgradeLevel, 6);
    });

    test('old saves without progression fields still load', () async {
      SharedPreferences.setMockInitialValues({
        'archer_fm.progress.ranger_new':
            '{"level":3,"xp":8,"kills":1,"armyLevels":{"tank":2},"essence":40}',
      });
      final loaded = await SharedPreferencesProgressStore().load('ranger_new');
      expect(loaded, isNotNull);
      expect(loaded!.level, 3);
      expect(loaded.essence, 40);
      expect(loaded.materials, isEmpty);
      expect(loaded.equipment, isEmpty);
      expect(loaded.equipped, isEmpty);
      expect(loaded.capacityLevel, 0);
      expect(loaded.heroUpgradeLevel, 0);
    });

    test('invalid equipment entries are skipped, not fatal', () async {
      SharedPreferences.setMockInitialValues({
        'archer_fm.progress.ranger_new':
            '{"level":1,"xp":0,"kills":0,"essence":0,'
                '"equipment":[{"id":"ok","slot":"ring","rarity":"rare",'
                '"level":2},{"id":"bad","slot":"crown","rarity":"rare"},'
                '{"id":42,"slot":"ring","rarity":"rare"}],'
                '"equipped":{"ring":"ok"}}',
      });
      final loaded = await SharedPreferencesProgressStore().load('ranger_new');
      expect(loaded!.equipment.single.id, 'ok');
      expect(loaded.equipped['ring'], 'ok');
    });
  });

  group('world integration', () {
    test('touching a chest rolls equipment and removes the chest', () {
      final world = makeWorld();
      world.map.pickups.clear();
      world.map.pickups.add(
        MapPickup(position: world.player.position, kind: PickupKind.chest),
      );
      world.update(16);
      final events = world.drainEvents().whereType<ChestOpenedEvent>().toList();
      expect(events.length, 1);
      expect(world.map.pickups.where((p) => p.kind == PickupKind.chest), isEmpty);
      final rolled = events.single.item;
      expect(EquipmentSlot.values, contains(rolled.slot));
      expect(EquipmentRarity.values, contains(rolled.rarity));
      expect(rolled.level, 1);
    });

    test('a distant chest is not opened', () {
      final world = makeWorld();
      world.map.pickups.clear();
      world.map.pickups.add(
        MapPickup(
          position: world.player.position + const Offset(200, 0),
          kind: PickupKind.chest,
        ),
      );
      world.update(16);
      expect(world.drainEvents().whereType<ChestOpenedEvent>(), isEmpty);
      expect(world.map.pickups.length, 1);
    });

    test('chest contents stay within equipment and weapons', () {
      final world = makeWorld(seed: 5);
      world.map.pickups.clear();
      for (var i = 0; i < 3; i++) {
        world.map.pickups.add(
          MapPickup(position: world.player.position, kind: PickupKind.chest),
        );
        world.update(16);
      }
      final events = world.drainEvents().whereType<ChestOpenedEvent>().toList();
      expect(events.length, 3);
      final ids = events.map((event) => event.item.id).toSet();
      expect(ids.length, 3);
    });

    test('settleMatch credits pending currency and materials exactly once', () {
      final world = makeWorld();
      world.pendingEssence = 75;
      world.pendingMaterials[ProgressionMaterial.hero] = 2;
      world.settleMatch();
      expect(world.essence, 75);
      expect(world.materials[ProgressionMaterial.hero], 2);
      expect(world.pendingEssence, 0);
      expect(world.pendingMaterials, isEmpty);
      world.settleMatch();
      expect(world.essence, 75);
      expect(world.materials[ProgressionMaterial.hero], 2);
    });

    test('equipment bonuses change max HP, damage and speed', () {
      final neutral = makeWorld();
      final boosted = GameWorld(
        kit: rangerNewKit,
        random: math.Random(11),
        spawnWaves: false,
        bonuses: const EquipmentBonuses(
          hpMultiplier: 1.5,
          damageMultiplier: 1.4,
          moveMultiplier: 1.2,
        ),
      );
      neutral.enemies.clear();
      boosted.enemies.clear();
      expect(boosted.maxHp, neutral.maxHp * 1.5);
      expect(boosted.player.hp, boosted.maxHp);
      expect(boosted.currentDamageMult(),
          closeTo(neutral.currentDamageMult() * 1.4, 0.0001));
      expect(boosted.currentMoveSpeed(),
          closeTo(neutral.currentMoveSpeed() * 1.2, 0.0001));
    });

    test('applyProgression raises HP and capacity without changing a hurt hero',
        () {
      final world = makeWorld();
      final startingHp = world.player.hp;
      world.applyProgression(
        bonuses: const EquipmentBonuses(hpMultiplier: 2.0),
        carryCapacity: 700,
      );
      expect(world.maxHp, startingHp * 2);
      expect(world.player.hp, world.maxHp);
      expect(world.mineSystem.carryCapacity, 700);

      world.player.hp = world.maxHp * 0.25;
      world.applyProgression(
        bonuses: const EquipmentBonuses(hpMultiplier: 3.0),
        carryCapacity: 800,
      );
      expect(world.maxHp, startingHp * 3);
      // A hurt hero keeps their current HP; the new maximum only raises the cap.
      expect(world.player.hp, startingHp * 0.5);
      expect(world.mineSystem.carryCapacity, 800);
    });

    test('a duplicate chest item becomes equipment materials', () {
      final controller = ProgressionController(
        heroId: 'ranger_new',
        equipment: [
          item(id: 'owned', rarity: EquipmentRarity.legendary),
        ],
        equipped: {EquipmentSlot.weapon: 'owned'},
      );
      final outcome = controller.addEquipment(
        item(id: 'new', rarity: EquipmentRarity.legendary),
      );
      expect(outcome.isDuplicate, isTrue);
      expect(
        controller.materialOf(ProgressionMaterial.equipment),
        EquipmentRarity.legendary.duplicateMaterialValue,
      );
    });
  });

  group('progression screen', () {
    testWidgets('shows heroes, monsters, equipment, weapons and chests',
        (tester) async {
      final store = MemoryProgressStore();
      await store.save(
        'ranger_new',
        HeroProgress(
          level: 5,
          xp: 10,
          kills: 2,
          essence: 500,
          materials: {
            ProgressionMaterial.hero.name: 10,
            ProgressionMaterial.capacity.name: 10,
          },
          equipment: [item(id: 'w', level: 4)],
          equipped: {'weapon': 'w'},
          armyLevels: {'tank': 3},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressionScreen(
            hero: heroById('ranger_new'),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('الأبطال'), findsOneWidget);
      expect(find.text('الوحوش'), findsOneWidget);
      expect(find.text('المعدات'), findsOneWidget);
      expect(find.text('الأسلحة'), findsOneWidget);
      expect(find.text('الصناديق'), findsOneWidget);
      expect(find.textContaining('القوة'), findsOneWidget);
      expect(find.textContaining('الجوهر 500'), findsOneWidget);
    });

    testWidgets('hero and capacity upgrades persist their own materials',
        (tester) async {
      final store = MemoryProgressStore();
      await store.save(
        'ranger_new',
        HeroProgress(
          level: 5,
          xp: 10,
          kills: 2,
          essence: 500,
          materials: {
            ProgressionMaterial.hero.name: 10,
            ProgressionMaterial.capacity.name: 10,
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressionScreen(
            hero: heroById('ranger_new'),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder vertical() => find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          ).last;
      final heroUpgrade = find.byKey(const ValueKey('upgrade_hero'));
      await tester.scrollUntilVisible(heroUpgrade, 200, scrollable: vertical());
      await tester.pumpAndSettle();
      await tester.tap(heroUpgrade);
      await tester.pumpAndSettle();
      final capacityUpgrade = find.byKey(const ValueKey('upgrade_capacity'));
      await tester.scrollUntilVisible(
        capacityUpgrade,
        200,
        scrollable: vertical(),
      );
      await tester.pumpAndSettle();
      await tester.tap(capacityUpgrade);
      await tester.pumpAndSettle();
      final saved = await store.load('ranger_new');
      expect(saved!.heroUpgradeLevel, 1);
      expect(saved.capacityLevel, 1);
      expect(saved.essence, lessThan(500));
      expect(saved.materials[ProgressionMaterial.hero.name], lessThan(10));
      expect(saved.materials[ProgressionMaterial.capacity.name], lessThan(10));
    });

    testWidgets('weapons can be unequipped, upgraded and sold', (tester) async {
      final store = MemoryProgressStore();
      await store.save(
        'ranger_new',
        HeroProgress(
          level: 1,
          xp: 0,
          kills: 0,
          essence: 10000,
          materials: {ProgressionMaterial.equipment.name: 100},
          equipment: [item(id: 'w', level: 3, rarity: EquipmentRarity.epic)],
          equipped: {'weapon': 'w'},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressionScreen(
            hero: heroById('ranger_new'),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Switch to the weapons tab.
      await tester.tap(find.text('الأسلحة'));
      await tester.pumpAndSettle();
      Finder verticalList() => find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          ).last;
      final row = find.byKey(const ValueKey('equipment_row_w'));
      await tester.scrollUntilVisible(row, 300, scrollable: verticalList());
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      final upgrade = find.byKey(const ValueKey('upgrade_item_w'));
      await tester.scrollUntilVisible(upgrade, 200, scrollable: verticalList());
      await tester.pumpAndSettle();
      await tester.tap(upgrade);
      await tester.pumpAndSettle();
      var saved = await store.load('ranger_new');
      expect(saved!.equipment.single.cappedLevel, 4);

      final unequip = find.byKey(const ValueKey('unequip_w'));
      await tester.scrollUntilVisible(unequip, 200, scrollable: verticalList());
      await tester.pumpAndSettle();
      await tester.tap(unequip);
      await tester.pumpAndSettle();
      final sell = find.byKey(const ValueKey('sell_w'));
      await tester.scrollUntilVisible(sell, 200, scrollable: verticalList());
      await tester.pumpAndSettle();
      await tester.tap(sell);
      await tester.pumpAndSettle();
      saved = await store.load('ranger_new');
      expect(saved!.equipment, isEmpty);
      expect(saved.essence, greaterThan(0));
    });

    testWidgets('each hero keeps a separate progression profile',
        (tester) async {
      final store = MemoryProgressStore();
      await store.save(
        'ranger_new',
        HeroProgress(
          level: 2,
          xp: 0,
          kills: 0,
          essence: 111,
          heroUpgradeLevel: 3,
        ),
      );
      await store.save(
        'storm',
        HeroProgress(level: 1, xp: 0, kills: 0, essence: 222),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressionScreen(
            hero: heroById('ranger_new'),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('الجوهر 111'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('progression_hero_storm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('الجوهر 222'), findsOneWidget);
      expect(find.textContaining('الجوهر 111'), findsNothing);
    });

    testWidgets('monster upgrades spend monster materials and save the level',
        (tester) async {
      final store = MemoryProgressStore();
      await store.save(
        'ranger_new',
        HeroProgress(
          level: 1,
          xp: 0,
          kills: 0,
          essence: 1000,
          materials: {ProgressionMaterial.monster.name: 10},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressionScreen(
            hero: heroById('ranger_new'),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('الوحوش'));
      await tester.pumpAndSettle();
      final list = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      ).last;
      final upgrade = find.byKey(const ValueKey('progression_upgrade_runner'));
      await tester.scrollUntilVisible(upgrade, 200, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(upgrade);
      await tester.pumpAndSettle();
      final saved = await store.load('ranger_new');
      expect(saved!.armyLevels['runner'], 2);
      expect(saved.materials[ProgressionMaterial.monster.name], 9);
      expect(saved.essence, lessThan(1000));
    });
  });
}
