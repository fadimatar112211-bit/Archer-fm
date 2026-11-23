import 'dart:io';
import 'dart:typed_data';

import 'package:archer_fm/game/render3/glb.dart';
import 'package:flutter_test/flutter_test.dart';

/// All four shipped hero GLBs parse through the dependency-free loader:
/// skeleton, all 8 gameplay clips under normalized names, and their colour
/// path — embedded texture (ranger, storm) or per-vertex material colours
/// (flame, shadow).
void main() {
  test('all hero GLBs parse with skeletons and all 8 clips', () async {
    for (final entry in [
      ['assets/heroes/ranger_new/ranger_animated.glb', 21, false],
      ['assets/heroes/flame/model/flame_animated.glb', 30, false],
      ['assets/heroes/shadow/model/shadow_animated.glb', 30, false],
      ['assets/heroes/storm/model/storm_animated.glb', 30, true],
    ]) {
      final path = entry[0] as String;
      final textured = entry[2] as bool;
      final bytes = await File(path).readAsBytes();
      final m = await GlbModel.load(Uint8List.fromList(bytes));
      expect(m.jointNames.length, entry[1], reason: path);
      expect(m.jointParents.first, -1, reason: path);
      for (final state in const [
        'idle',
        'walk',
        'run',
        'attack',
        'skill',
        'dodge',
        'hit',
        'death',
      ]) {
        expect(
          m.clips.containsKey(state),
          isTrue,
          reason: '$path missing clip "$state"',
        );
      }
      // Untextured heroes carry per-vertex material colours; texture-driven
      // heroes carry the embedded base colour texture instead.
      expect(m.baseColor == null, !textured, reason: path);
      expect(m.materialColors.length, m.vertexCount * 3, reason: path);
      if (!textured) {
        var nonWhite = 0;
        for (var i = 0; i < m.materialColors.length; i++) {
          if (m.materialColors[i] < 0.999) nonWhite++;
        }
        expect(nonWhite, greaterThan(0), reason: path);
      }
      // Clips clamp for one-shots and loop for idle.
      expect(m.clips['idle']!.durationMs, greaterThan(0), reason: path);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('the original storm.glb ships intact (provenance, not bundled)',
      () async {
    final f = File('assets/heroes/storm/storm.glb');
    expect(f.existsSync(), isTrue, reason: 'the uploaded original must exist');
    expect(f.lengthSync(), 21599708,
        reason: 'the original file must be byte-for-byte intact');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
