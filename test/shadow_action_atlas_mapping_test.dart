import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Shadow non-walk clips use their own authored directional atlases', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString(
        'assets/heroes/shadow/renders/shadow_manifest.json',
      ),
    ) as Map<String, dynamic>;
    final animations = manifest['animations'] as Map<String, dynamic>;
    final atlases = (manifest['atlases'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    const directions = ['e', 'n', 'ne', 'nw', 's', 'se', 'sw', 'w'];
    const frameCounts = {
      'idle': 5,
      'run': 9,
      'attack': 7,
      'skill': 9,
      'dodge': 9,
      'hit': 5,
      'death': 9,
    };

    for (final state in frameCounts.keys) {
      for (final direction in directions) {
        final key = '${state}_${direction}';
        final clip = animations[key] as Map<String, dynamic>;
        final frames = (clip['frames'] as List<dynamic>).cast<String>();
        final atlas = atlases.singleWhere((entry) => entry['animation'] == key);

        expect(frames, hasLength(frameCounts[state]!), reason: key);
        expect(frames.toSet(), hasLength(frames.length), reason: '$key must not repeat a held frame');
        expect(
          frames.every((frame) => frame.startsWith('shadow_${state}_${direction}_')),
          isTrue,
          reason: '$key must reference its own action frames',
        );
        expect(atlas['image'], 'atlases/${state}_${direction}.png', reason: key);
        expect(atlas['meta'], 'atlases/${state}_${direction}.json', reason: key);

        final metadata = jsonDecode(
          await rootBundle.loadString(
            'assets/heroes/shadow/renders/${atlas['meta']}',
          ),
        ) as Map<String, dynamic>;
        final metadataFrames = metadata['frames'] as Map<String, dynamic>;
        for (final frame in frames) {
          expect(metadataFrames.containsKey(frame), isTrue, reason: '$key/$frame');
        }
      }
    }

    // The only user-approved walk atlas remains the source of every walk row.
    for (final direction in directions) {
      final key = 'walk_${direction}';
      final clip = animations[key] as Map<String, dynamic>;
      final frames = (clip['frames'] as List<dynamic>).cast<String>();
      final atlas = atlases.singleWhere((entry) => entry['animation'] == key);
      expect(frames, hasLength(4), reason: key);
      expect(atlas['image'], 'atlases/shadow_walk_8dir_4frames_FINAL.png');
      expect(atlas['meta'], 'atlases/walk_${direction}_user.json');
      expect(frames.every((frame) => frame.contains('_user_')), isTrue);
    }
  });
}
