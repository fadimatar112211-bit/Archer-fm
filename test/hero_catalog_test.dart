import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the playable roster contains exactly four unique heroes', () {
    expect(heroCatalog.map((hero) => hero.id).toSet(), {
      'ranger_new',
      'flame',
      'shadow',
      'storm',
    });
    expect(heroCatalog, hasLength(4));
  });

  test('Ranger resolves only to the canonical ranger_new assets', () {
    final ranger = heroById('ranger_new');
    expect(ranger.nameEn, 'Ranger');
    expect(ranger.assetRoot, 'assets/heroes/ranger_new/renders');
    expect(ranger.manifestPath,
        'assets/heroes/ranger_new/renders/ranger_new_manifest.json');
  });

  test('the retired legacy ranger id cannot resolve to another hero', () {
    expect(() => heroById('ranger'), throwsArgumentError);
  });
}
