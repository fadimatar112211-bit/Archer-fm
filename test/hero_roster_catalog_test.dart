import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the selectable roster contains exactly the four canonical heroes', () {
    expect(
      heroCatalog.map((hero) => hero.id).toList(),
      ['flame', 'shadow', 'storm', 'ranger_new'],
    );
    expect(heroCatalog.map((hero) => hero.id).toSet(), hasLength(4));
    expect(heroCatalog.where((hero) => hero.nameEn == 'Ranger'), hasLength(1));
    expect(heroCatalog.any((hero) => hero.id == 'ranger'), isFalse);
  });

  test('legacy Ranger id is retired and the canonical Ranger remains selectable', () {
    expect(() => heroById('ranger'), throwsArgumentError);
    expect(heroById('ranger_new').nameEn, 'Ranger');
    expect(heroCatalog.any((hero) => hero.id == 'ranger'), isFalse);
  });
}
