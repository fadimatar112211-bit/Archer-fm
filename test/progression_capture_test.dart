import 'dart:io';

import 'package:archer_fm/game/progress/equipment.dart';
import 'package:archer_fm/game/progress/hero_progress.dart';
import 'package:archer_fm/game/progress/progression.dart';
import 'package:archer_fm/game/progress/progression_screen.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual evidence for the permanent progression step: the hero page (power,
/// currency, four materials, hero/capacity upgrades) with a loaded profile.
/// The baseline golden is kept under `test/goldens/progression.png` and is also
/// copied to `/tmp/opencode/merge/captures/35_progression.png` for inspection.
void main() {
  testWidgets('captures the progression hub', (tester) async {
    final store = MemoryProgressStore();
    await store.save(
      'ranger_new',
      HeroProgress(
        level: 12,
        xp: 40,
        kills: 7,
        essence: 2450,
        materials: {
          ProgressionMaterial.hero.name: 18,
          ProgressionMaterial.monster.name: 11,
          ProgressionMaterial.equipment.name: 9,
          ProgressionMaterial.capacity.name: 14,
        },
        equipment: [
          const EquipmentItem(
            id: 'w1',
            slot: EquipmentSlot.weapon,
            rarity: EquipmentRarity.legendary,
            level: 12,
          ),
          const EquipmentItem(
            id: 'h1',
            slot: EquipmentSlot.helmet,
            rarity: EquipmentRarity.epic,
            level: 8,
          ),
          const EquipmentItem(
            id: 'a1',
            slot: EquipmentSlot.armor,
            rarity: EquipmentRarity.rare,
            level: 6,
          ),
          const EquipmentItem(
            id: 'b1',
            slot: EquipmentSlot.boots,
            rarity: EquipmentRarity.mythic,
            level: 15,
          ),
        ],
        equipped: const {
          'weapon': 'w1',
          'helmet': 'h1',
          'armor': 'a1',
          'boots': 'b1',
        },
        capacityLevel: 3,
        heroUpgradeLevel: 5,
        armyLevels: const {'runner': 4, 'tank': 7},
      ),
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B1A10),
          ),
          home: ProgressionScreen(
            hero: heroById('ranger_new'),
            store: store,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/progression.png'),
    );

    // Keep the same image in the shared capture folder used by earlier steps.
    final baseline = File('test/goldens/progression.png').readAsBytesSync();
    final dir = Directory('/tmp/opencode/merge/captures');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('${dir.path}/35_progression.png').writeAsBytesSync(baseline);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
