import 'package:flutter_test/flutter_test.dart';

import 'package:archer_fm/monsters/monster3d.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Monster3D loads every launch monster and plays core clips', () async {
    for (final id in const [
      'werewolf',
      'stone-golem',
      'blind-stalker',
      'bog-monster',
    ]) {
      final monster = Monster3D(id, height: 40);
      await monster.load();
      expect(monster.isReady, isTrue, reason: '$id mesh should load');
      expect(monster.anim, 'Idle', reason: '$id should start idle');

      monster.update(
        0.05,
        moveDir: const Offset(1, 0),
        moveSpeed: 20,
      );
      expect(monster.anim, isNot('Idle'), reason: '$id should animate movement');

      monster.update(0.05, attacking: true);
      expect(monster.anim, 'Attack', reason: '$id should support attacks');

      monster.takeHit(1);
      expect(monster.anim, 'Hit', reason: '$id should support hit reaction');

      monster.takeHit(100000);
      expect(monster.isDead, isTrue, reason: '$id should support death');
      monster.revive();
      expect(monster.isDead, isFalse, reason: '$id should revive');
      monster.dispose();
    }
  });
}
