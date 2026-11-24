import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const heroes = ['ranger', 'flame', 'shadow'];
  const states = [
    'idle', 'walk', 'run', 'attack', 'skill', 'dodge', 'hit', 'death',
  ];
  const directions = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];

  for (final hero in heroes) {
    test('$hero manifest contains exactly 64 directional clips and atlases', () async {
      final path = 'assets/heroes/$hero/renders/${hero}_manifest.json';
      final source = await rootBundle.loadString(path);
      final json = jsonDecode(source) as Map<String, dynamic>;
      expect(json['hero_id'], hero);
      expect(json['frame_size'], {'width': 192, 'height': 192});

      final animations = json['animations'] as Map<String, dynamic>;
      final atlases = json['atlases'] as List<dynamic>;
      expect(animations.keys.toSet(), {
        for (final state in states)
          for (final direction in directions) '${state}_${direction}',
      });
      expect(animations, hasLength(64));
      expect(atlases, hasLength(64));

      final atlasNames = <String>[];
      for (final entry in atlases) {
        final atlas = entry as Map<String, dynamic>;
        expect(atlas['animation'], isA<String>());
        expect(atlas['image'], isA<String>());
        expect(atlas['meta'], isA<String>());
        atlasNames.add(atlas['animation'] as String);
      }
      expect(atlasNames.toSet(), hasLength(64));
      expect(atlasNames.toSet(), animations.keys.toSet());

      for (final state in states) {
        for (final direction in directions) {
          final name = '${state}_${direction}';
          final clip = animations[name] as Map<String, dynamic>;
          final frames = clip['frames'] as List<dynamic>;
          expect(frames.length, greaterThanOrEqualTo(2), reason: '$hero $name');
          expect(frames.toSet(), hasLength(frames.length), reason: '$hero $name duplicate frames');
          expect(
            frames.every((frame) => frame is String && frame.startsWith('${hero}_')),
            isTrue,
            reason: '$hero $name frame IDs must use the correct hero prefix',
          );
          expect(clip['loop'], isA<bool>(), reason: '$hero $name loop');
          expect(clip['frame_duration_ms'], isA<int>(), reason: '$hero $name duration');
          expect(clip['frame_duration_ms'] as int, greaterThan(0));

          final events = clip['events'] as List<dynamic>;
          for (final rawEvent in events) {
            final event = rawEvent as Map<String, dynamic>;
            final frame = event['frame'];
            expect(frame, isA<int>(), reason: '$hero $name event frame');
            expect(frame as int, inInclusiveRange(0, frames.length - 1),
                reason: '$hero $name event frame outside clip');
            expect(event['name'], isA<String>(), reason: '$hero $name event name');
            expect((event['name'] as String).isNotEmpty, isTrue);
          }
        }
      }
    });
  }

  test('combat clips contain valid frame events in every direction', () async {
    for (final hero in heroes) {
      final source = await rootBundle.loadString(
        'assets/heroes/$hero/renders/${hero}_manifest.json',
      );
      final json = jsonDecode(source) as Map<String, dynamic>;
      final animations = json['animations'] as Map<String, dynamic>;
      for (final direction in directions) {
        for (final state in ['attack', 'skill']) {
          final name = '${state}_${direction}';
          final clip = animations[name] as Map<String, dynamic>;
          final frames = clip['frames'] as List<dynamic>;
          final events = clip['events'] as List<dynamic>;
          expect(events, isNotEmpty, reason: '$hero $name must expose gameplay timing');
          for (final raw in events) {
            final event = raw as Map<String, dynamic>;
            expect(event['frame'], inInclusiveRange(0, frames.length - 1),
                reason: '$hero $name event index');
          }
        }
      }
    }
  });
}
