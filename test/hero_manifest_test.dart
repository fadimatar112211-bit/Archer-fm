import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

const String _renderRoot = 'assets/heroes/ranger/renders';
const List<String> _states = [
  'idle',
  'walk',
  'run',
  'attack',
  'skill',
  'dodge',
  'hit',
  'death',
];
const List<String> _directions = [
  's',
  'sw',
  'w',
  'nw',
  'n',
  'ne',
  'e',
  'se',
];

void main() {
  final manifestFile = File('$_renderRoot/ranger_manifest.json');
  if (!manifestFile.existsSync()) {
    test(
      'the rendered Ranger manifest is committed',
      () {},
      skip: 'Run the Ranger Blender Asset Pipeline to generate the sprites.',
    );
    return;
  }

  late HeroManifest manifest;
  setUpAll(() {
    manifest = HeroManifest.fromJson(
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
    );
  });

  test('every state and direction has an animation and an atlas', () {
    expect(manifest.heroId, 'ranger');
    expect(manifest.frameWidth, 192);
    expect(manifest.frameHeight, 192);
    expect(manifest.pivotX, closeTo(0.5, 1e-9));
    expect(manifest.pivotY, closeTo(0.86, 1e-9));
    expect(manifest.clips.length, _states.length * _directions.length);
    for (final state in _states) {
      for (final direction in _directions) {
        final name = '${state}_$direction';
        final clip = manifest.clipFor(state, direction);
        expect(clip, isNotNull, reason: 'missing clip $name');
        expect(clip!.frames.length, greaterThanOrEqualTo(2), reason: name);
        expect(clip.frameDurationMs, greaterThan(0), reason: name);
        expect(manifest.atlasFor(name), isNotNull, reason: 'missing atlas $name');
      }
    }
  });

  test('the attack and skill clips carry their gameplay events', () {
    for (final direction in _directions) {
      final attack = manifest.clipFor('attack', direction)!;
      final skill = manifest.clipFor('skill', direction)!;
      expect(
        attack.events.map((event) => event.name),
        contains('projectile_release'),
        reason: 'attack_$direction',
      );
      expect(
        skill.events.map((event) => event.name),
        contains('volley_release'),
        reason: 'skill_$direction',
      );
      for (final clip in [attack, skill]) {
        for (final event in clip.events) {
          expect(event.frame, lessThan(clip.frames.length), reason: clip.name);
        }
      }
    }
  });

  test('atlas metadata covers every frame and each tile is 192x192', () {
    for (final entry in manifest.atlases) {
      final metaFile = File('$_renderRoot/${entry.meta}');
      expect(metaFile.existsSync(), isTrue, reason: entry.meta);
      final meta =
          jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      final frames = meta['frames'] as Map<String, dynamic>;
      final clip = manifest.clips[entry.animation];
      expect(clip, isNotNull, reason: entry.animation);
      for (final frameId in clip!.frames) {
        expect(frames.containsKey(frameId), isTrue,
            reason: '${entry.animation} is missing $frameId');
        final rect = frames[frameId]['frame'] as Map<String, dynamic>;
        expect(rect['w'], 192, reason: frameId);
        expect(rect['h'], 192, reason: frameId);
      }
      expect(File('$_renderRoot/${entry.image}').existsSync(), isTrue,
          reason: entry.image);
    }
  });
}
