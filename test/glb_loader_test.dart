import 'dart:io';
import 'dart:typed_data';

import 'package:archer_fm/game/render3/glb.dart';
import 'package:flutter_test/flutter_test.dart';

Future<GlbModel> loadRanger() async {
  final bytes = await File(
    'assets/heroes/ranger_new/ranger_animated.glb',
  ).readAsBytes();
  return GlbModel.load(Uint8List.fromList(bytes));
}

void main() {
  test('ranger GLB parses with a full skeleton and all 8 clips', () async {
    final model = await loadRanger();
    expect(model.jointNames.length, 21);
    expect(model.jointParents.first, -1); // root
    expect(model.clips.keys, containsAll([
      'idle',
      'run',
      'walk',
      'attack',
      'skill',
      'hit',
      'dodge',
      'death',
    ]));
    expect(model.clips['attack']!.durationMs, closeTo(1667, 1));
    expect(model.vertexCount, greaterThan(1000));
    expect(model.triangleCount, greaterThan(1000));
    expect(model.baseColor, isNotNull,
        reason: 'the embedded base-colour texture must decode');
    model.baseColor!.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('poses actually move the skeleton over time', () async {
    final model = await loadRanger();
    final poser = Poser(model);
    // upperArm_L (joint 9) drives the bow arm through the attack clip.
    const arm = 9 * 16;
    poser.poseAt('attack', 0, loop: false);
    final armAtT0 = Float32List.fromList(
      poser.skin.sublist(arm, arm + 16),
    );
    poser.poseAt('attack', 800, loop: false);
    var delta = 0.0;
    for (var i = 0; i < 16; i++) {
      delta += (poser.skin[arm + i] - armAtT0[i]).abs();
    }
    expect(delta, greaterThan(0.01),
        reason: 'the bow arm must move through the attack clip');
    // Attack holds its final frame when not looping.
    final finalPose = Float32List.fromList(poser.skin);
    poser.poseAt('attack', model.clips['attack']!.durationMs, loop: false);
    expect(poser.skin, finalPose);
    poser.poseAt('attack', 99999, loop: false);
    expect(poser.skin, finalPose,
        reason: 'one-shot clips must clamp at their last frame');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
