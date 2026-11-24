import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const heroes = ['ranger', 'flame', 'shadow', 'storm'];
  const states = [
    'idle', 'walk', 'run', 'attack', 'skill', 'dodge', 'hit', 'death',
  ];
  const directions = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];

  for (final hero in heroes) {
    test('$hero manifest contains all 64 directional state clips', () async {
      final path = 'assets/heroes/$hero/renders/${hero}_manifest.json';
      final source = await rootBundle.loadString(path);
      final json = jsonDecode(source) as Map<String, dynamic>;
      expect(json['hero_id'], hero);
      final animations = json['animations'] as Map<String, dynamic>;
      final atlases = json['atlases'] as List<dynamic>;

      expect(animations, hasLength(64));
      expect(atlases, hasLength(64));

      for (final state in states) {
        for (final direction in directions) {
          final name = '${state}_${direction}';
          expect(animations.containsKey(name), isTrue, reason: '$hero $name');
          final clip = animations[name] as Map<String, dynamic>;
          expect(clip['frames'], isA<List<dynamic>>());
          expect((clip['frames'] as List).length, greaterThanOrEqualTo(2));
          expect(
            atlases.where((entry) => (entry as Map)['animation'] == name),
            hasLength(1),
            reason: '$hero atlas for $name',
          );
        }
      }
    });
  }

  test('Storm atlases contain unique, correctly packed frame rectangles', () async {
    final source = await rootBundle.loadString(
      'assets/heroes/storm/renders/storm_manifest.json',
    );
    final manifest = jsonDecode(source) as Map<String, dynamic>;
    final atlases = manifest['atlases'] as List<dynamic>;
    final animations = manifest['animations'] as Map<String, dynamic>;
    expect(atlases, hasLength(64));
    expect(animations, hasLength(64));

    for (final entry in atlases) {
      final atlas = entry as Map<String, dynamic>;
      final animation = atlas['animation'] as String;
      final imagePath = 'assets/heroes/storm/renders/${atlas['image']}';
      final metaPath = 'assets/heroes/storm/renders/${atlas['meta']}';
      final imageBytes = await rootBundle.load(imagePath);
      expect(imageBytes.lengthInBytes, greaterThan(100), reason: imagePath);

      final meta = jsonDecode(await rootBundle.loadString(metaPath))
          as Map<String, dynamic>;
      final frames = meta['frames'] as Map<String, dynamic>;
      final clip = animations[animation] as Map<String, dynamic>;
      final frameIds = clip['frames'] as List<dynamic>;
      expect(frames.keys.toSet(), frameIds.toSet(), reason: animation);
      final rects = frames.values.map((value) {
        final rect = (value as Map<String, dynamic>)['frame']
            as Map<String, dynamic>;
        return '${rect['x']}:${rect['y']}';
      }).toSet();
      expect(rects, hasLength(frameIds.length), reason: animation);
      expect(frameIds.every((id) => (id as String).startsWith('storm_')), isTrue);
    }
  });

  test('combat clips contain frame events for attack timing', () async {
    for (final hero in heroes) {
      final source = await rootBundle.loadString(
        'assets/heroes/$hero/renders/${hero}_manifest.json',
      );
      final json = jsonDecode(source) as Map<String, dynamic>;
      final animations = json['animations'] as Map<String, dynamic>;
      for (final direction in directions) {
        final attack = animations['attack_$direction'] as Map<String, dynamic>;
        final skill = animations['skill_$direction'] as Map<String, dynamic>;
        expect(attack['events'], isA<List<dynamic>>(), reason: '$hero attack $direction');
        expect(skill['events'], isA<List<dynamic>>(), reason: '$hero skill $direction');
      }
    }
  });
}
