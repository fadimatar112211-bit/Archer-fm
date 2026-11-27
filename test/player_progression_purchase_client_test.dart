import 'package:flutter_test/flutter_test.dart';
import 'package:archer_fm/game/auth/player_progression_purchase_client.dart';

void main() {
  test('parses a successful purchase receipt', () {
    final receipt = ProgressionPurchaseReceipt.fromJson({
      'type': 'purchase_result',
      'currency_balance': 850,
      'hero_revision': 4,
      'monster_revision': 2,
      'resulting_level': 3,
      'already_applied': false,
    });
    expect(receipt.currencyBalance, 850);
    expect(receipt.heroRevision, 4);
    expect(receipt.resultingLevel, 3);
    expect(receipt.alreadyApplied, isFalse);
  });

  test('rejects malformed purchase receipts', () {
    expect(
      () => ProgressionPurchaseReceipt.fromJson({
        'type': 'purchase_result',
        'currency_balance': -1,
        'hero_revision': 4,
        'monster_revision': 2,
        'resulting_level': 3,
        'already_applied': false,
      }),
      throwsFormatException,
    );
  });

  test('parses server quoted weapons and monsters', () {
    final catalog = ProgressionPurchaseCatalog.fromJson({
      'type': 'progression_catalog',
      'weapons': [
        {
          'id': 'ranger_longbow',
          'name': 'قوس الصقر',
          'hero': 'الرامي',
          'owned': false,
          'level': 0,
          'purchaseType': 'weapon_unlock',
          'cost': 120,
          'available': true,
        },
      ],
      'monsters': [
        {
          'id': 'runner',
          'name': 'العدّاء',
          'level': 2,
          'purchaseType': 'monster_upgrade',
          'cost': 60,
          'available': true,
        },
      ],
    });
    expect(catalog.weapons.single['cost'], 120);
    expect(catalog.monsters.single['purchaseType'], 'monster_upgrade');
  });

  test('rejects incomplete catalog payloads', () {
    expect(
      () => ProgressionPurchaseCatalog.fromJson({
        'type': 'progression_catalog',
        'weapons': [],
      }),
      throwsFormatException,
    );
  });
}
