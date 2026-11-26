import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/progression/file_hero_progress_store.dart';
import 'package:archer_fm/game/progression/hero_progress.dart';

void main() {
  late Directory directory;
  late FileHeroProgressStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('archer-progress-');
    store = FileHeroProgressStore(directory);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('loads a fresh profile and atomically persists progression', () async {
    final fresh = await store.load('account-123');
    expect(fresh.permanentCurrency, 0);

    fresh.awardCurrency(450);
    await store.save('account-123', fresh);

    final restored = await store.load('account-123');
    expect(restored.permanentCurrency, 450);
    expect(restored.unlockedWeaponIds, fresh.unlockedWeaponIds);
  });

  test('isolates account files and serializes concurrent writes', () async {
    final first = HeroProgress(permanentCurrency: 100);
    final second = HeroProgress(permanentCurrency: 900);

    await Future.wait([
      store.save('account/a', first),
      store.save('account/b', second),
      store.save('account/a', HeroProgress(permanentCurrency: 250)),
    ]);

    expect((await store.load('account/a')).permanentCurrency, 250);
    expect((await store.load('account/b')).permanentCurrency, 900);
  });

  test('rejects empty or oversized account identifiers', () async {
    expect(() => store.load(''), throwsArgumentError);
    expect(() => store.save('x' * 257, HeroProgress.fresh()), throwsArgumentError);
  });
}
