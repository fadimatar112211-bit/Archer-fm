import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/monsters/file_monster_progress_store.dart';
import 'package:archer_fm/monsters/monster_models.dart';
import 'package:archer_fm/monsters/monster_progression.dart';

MonsterCatalog _catalog() => MonsterCatalog({
      for (final type in MonsterType.values)
        type: MonsterDefinition(
          type: type,
          baseStats: const MonsterStats(
            maxHealth: 100,
            damage: 10,
            moveSpeed: 10,
            attackRange: 20,
            attackCooldown: Duration(seconds: 1),
            purchaseCost: 10,
          ),
        ),
    });

MonsterProgression _progression(
  MonsterCatalog catalog, {
  required int runnerLevel,
}) =>
    MonsterProgression(
      catalog: catalog,
      growth: {
        for (final type in MonsterType.values)
          type: const MonsterUpgradeGrowth(
            healthPerLevel: 0.1,
            damagePerLevel: 0.05,
            speedPerLevel: 0.02,
          ),
      },
      costForLevel: (_, level) => level * 10,
      levels: {MonsterType.runner: runnerLevel},
    );

void main() {
  late Directory directory;
  late FileMonsterProgressStore store;
  late MonsterCatalog catalog;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('archer-monsters-');
    store = FileMonsterProgressStore(directory);
    catalog = _catalog();
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('new account receives all four monster types at level one', () async {
    final data = await store.loadData('account-one');
    final restored = MonsterProgression.fromSaveData(
      catalog: catalog,
      growth: {
        for (final type in MonsterType.values)
          type: const MonsterUpgradeGrowth(
            healthPerLevel: 0.1,
            damagePerLevel: 0.05,
            speedPerLevel: 0.02,
          ),
      },
      costForLevel: (_, level) => level * 10,
      data: data,
    );

    expect(restored.levels.values, everyElement(1));
  });

  test('saves and restores all permanent monster levels', () async {
    final original = _progression(catalog, runnerLevel: 12);
    await store.save('account-one', original);

    final restored = MonsterProgression.fromSaveData(
      catalog: catalog,
      growth: {
        for (final type in MonsterType.values)
          type: const MonsterUpgradeGrowth(
            healthPerLevel: 0.1,
            damagePerLevel: 0.05,
            speedPerLevel: 0.02,
          ),
      },
      costForLevel: (_, level) => level * 10,
      data: await store.loadData('account-one'),
    );

    expect(restored.levelOf(MonsterType.runner), 12);
    expect(restored.levelOf(MonsterType.tank), 1);
    expect(restored.levelOf(MonsterType.stalker), 1);
    expect(restored.levelOf(MonsterType.ranged), 1);
  });

  test('keeps account progression isolated', () async {
    await store.save('account-one', _progression(catalog, runnerLevel: 9));
    await store.save('account-two', _progression(catalog, runnerLevel: 2));

    final one = await store.loadData('account-one');
    final two = await store.loadData('account-two');

    expect((one['levels'] as Map)['runner'], 9);
    expect((two['levels'] as Map)['runner'], 2);
  });

  test('rejects malformed persisted progression data', () async {
    final key = base64Url.encode(utf8.encode('broken-account')).replaceAll('=', '');
    final file = File('${directory.path}${Platform.pathSeparator}$key.monsters.json');
    await file.writeAsString(jsonEncode({
      'version': MonsterProgression.saveSchemaVersion,
      'levels': {'runner': 41, 'tank': 1, 'stalker': 1, 'ranged': 1},
    }));

    await expectLater(store.loadData('broken-account'), throwsFormatException);
  });

  test('rejects invalid account identifiers', () async {
    await expectLater(store.loadData(' '), throwsArgumentError);
    await expectLater(
      store.save('', _progression(catalog, runnerLevel: 1)),
      throwsArgumentError,
    );
  });
}
