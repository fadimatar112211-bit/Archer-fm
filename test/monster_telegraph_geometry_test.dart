import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:archer_fm/game/monsters/monster_telegraph_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monster attack telegraph orientation', () {
    test('all eight world directions map into mirrored body-local space', () {
      for (var direction = 0; direction < 8; direction++) {
        final angle = direction * math.pi / 4;
        final facing = Offset(math.cos(angle), math.sin(angle));
        final mirrored = facing.dx < -0.08;
        final expected = math.atan2(
          facing.dy,
          mirrored ? -facing.dx : facing.dx,
        );
        expect(
          monsterTelegraphAngle(facing, mirrored: mirrored),
          closeTo(expected, 1e-10),
          reason: 'direction $direction',
        );
      }
    });

    test('westward and diagonal warnings retain their vertical sign', () {
      for (final y in [-1.0, 1.0]) {
        final angle = monsterTelegraphAngle(
          Offset(-1, y),
          mirrored: true,
        );
        expect(angle.sign, y.sign);
      }
    });

    test('zero and non-finite facing vectors safely point east', () {
      expect(monsterTelegraphAngle(Offset.zero, mirrored: false), 0);
      expect(
        monsterTelegraphAngle(
          const Offset(double.nan, 1),
          mirrored: false,
        ),
        0,
      );
    });
  });
}
