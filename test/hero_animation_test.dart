import 'dart:io';
import 'dart:typed_data';

import 'package:archer_fm/game/render3/glb.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the export bug that shipped Flame/Shadow/Storm with
/// eight *constant* clips (armature forced to REST while exporting): every
/// gameplay clip must actually move the skeleton between two sampled times.
void main() {
  test('every shipped hero clip animates the skeleton (no frozen poses)',
      () async {
    for (final path in [
      'assets/heroes/ranger_new/ranger_animated.glb',
      'assets/heroes/flame/model/flame_animated.glb',
      'assets/heroes/shadow/model/shadow_animated.glb',
      'assets/heroes/storm/model/storm_animated.glb',
    ]) {
      final model = await GlbModel.load(
        Uint8List.fromList(await File(path).readAsBytes()),
      );
      final poser = Poser(model);
      expect(model.clips.length, 8, reason: '$path clip count');
      for (final entry in model.clips.entries) {
        final name = entry.key;
        final duration = entry.value.durationMs;
        expect(duration, greaterThan(0), reason: '$path $name duration');
        poser.poseAt(name, 0, loop: false);
        final first = Float32List.fromList(poser.skin);
        poser.poseAt(name, duration * 0.5, loop: false);
        var maxDelta = 0.0;
        for (var i = 0; i < first.length; i++) {
          final d = (first[i] - poser.skin[i]).abs();
          if (d > maxDelta) maxDelta = d;
        }
        expect(
          maxDelta,
          greaterThan(1e-3),
          reason: '$path "$name" is a frozen pose (maxDelta=$maxDelta)',
        );
      }
    }
  });
}
