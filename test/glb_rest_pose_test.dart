import 'dart:io';
import 'dart:typed_data';

import 'package:archer_fm/game/render3/glb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sparse GLB animation channels preserve unanimated bind-pose joints',
      () async {
    const assets = [
      'assets/heroes/ranger_new/ranger_animated.glb',
      'assets/heroes/flame/model/flame_animated.glb',
      'assets/heroes/shadow/model/shadow_animated.glb',
      'assets/heroes/storm/model/storm_animated.glb',
    ];

    for (final path in assets) {
      final bytes = File(path).readAsBytesSync();
      final model = await GlbModel.load(Uint8List.fromList(bytes));
      expect(model.jointNames, isNotEmpty, reason: path);
      expect(model.restLocal.length, model.jointNames.length * 16, reason: path);

      for (final entry in model.clips.entries) {
        final poser = Poser(model);
        poser.poseAt(entry.key, 0, loop: true);
        for (var joint = 0; joint < model.jointNames.length; joint++) {
          if (entry.value.jointTracks.containsKey(joint)) continue;
          final offset = joint * 16;
          for (var component = 0; component < 16; component++) {
            expect(
              poser.local[offset + component],
              closeTo(model.restLocal[offset + component], 0.0001),
              reason: '$path clip ${entry.key}, unanimated joint '
                  '${model.jointNames[joint]}, matrix component $component',
            );
          }
        }
      }
    }
  });
}
