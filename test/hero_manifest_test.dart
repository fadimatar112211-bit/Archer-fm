import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

const String _renderRoot = 'assets/heroes/ranger_new/renders';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifestFile = File('$_renderRoot/ranger_new_manifest.json');
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
    expect(manifest.heroId, 'ranger_new');
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
      final releases = attack.events
          .where((event) => event.name == 'projectile_release')
          .toList();
      expect(releases, hasLength(1), reason: 'attack_$direction');
      expect(releases.single.frame, attack.frames.length ~/ 2,
          reason: 'projectile_release must map to the configured release frame');

      final volleys = skill.events
          .where((event) => event.name == 'volley_release')
          .toList();
      expect(volleys, hasLength(1), reason: 'skill_$direction');
      expect(volleys.single.frame, skill.frames.length ~/ 2,
          reason: 'volley_release must map to the configured release frame');
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
  test('the real Ranger bundle decodes every atlas and covers every frame', () async {
    final hero = heroById('ranger_new');
    final manifestLoader = BundleHeroAssetLoader(hero);
    late final HeroManifest loaded;
    try {
      loaded = await manifestLoader.loadManifest();
    } finally {
      manifestLoader.dispose();
    }

    expect(loaded.heroId, 'ranger_new');
    expect(loaded.atlases.length, 64);
    expect(loaded.clips.length, 64);

    // Decode one atlas at a time so all production images are verified without
    // retaining every decoded bitmap in memory simultaneously.
    for (final entry in loaded.atlases) {
      final loader = BundleHeroAssetLoader(hero);
      try {
        final sheet = await loader.loadSheet(loaded, entry.animation);
        final clip = loaded.clips[entry.animation]!;
        expect(sheet.width, greaterThan(0), reason: entry.animation);
        expect(sheet.height, greaterThan(0), reason: entry.animation);
        for (final frameId in clip.frames) {
          final rect = sheet.rectFor(frameId);
          expect(rect, isNotNull, reason: '${entry.animation}: $frameId');
          expect(rect!.width, loaded.frameWidth.toDouble(), reason: frameId);
          expect(rect.height, loaded.frameHeight.toDouble(), reason: frameId);
          expect(rect.left, greaterThanOrEqualTo(0), reason: frameId);
          expect(rect.top, greaterThanOrEqualTo(0), reason: frameId);
          expect(rect.right, lessThanOrEqualTo(sheet.width.toDouble()), reason: frameId);
          expect(rect.bottom, lessThanOrEqualTo(sheet.height.toDouble()), reason: frameId);
        }
      } finally {
        loader.dispose();
      }
    }
  });


  test('manifest rejects duplicate atlas mappings for one animation', () {
    final json = _minimalManifest();
    json['atlases'] = [
      {'animation': 'idle_s', 'image': 'idle.png', 'meta': 'idle.json'},
      {'animation': 'idle_s', 'image': 'idle-copy.png', 'meta': 'idle-copy.json'},
    ];

    expect(
      () => HeroManifest.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('manifest rejects clips without atlas mappings', () {
    final json = _minimalManifest();
    json['animations'] = {
      'idle_s': {
        'loop': true,
        'frame_duration_ms': 100,
        'frames': ['idle_0'],
      },
      'walk_s': {
        'loop': true,
        'frame_duration_ms': 100,
        'frames': ['walk_0'],
      },
    };

    expect(
      () => HeroManifest.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('manifest rejects atlas mappings to unknown clips', () {
    final json = _minimalManifest();
    json['atlases'] = [
      {'animation': 'attack_s', 'image': 'attack.png', 'meta': 'attack.json'},
    ];

    expect(
      () => HeroManifest.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

}

Map<String, dynamic> _minimalManifest() => {
  'hero_id': 'test_hero',
  'frame_size': {'width': 64, 'height': 64},
  'pivot': {'x': 0.5, 'y': 1.0},
  'animations': {
    'idle_s': {
      'loop': true,
      'frame_duration_ms': 100,
      'frames': ['idle_0'],
    },
  },
  'atlases': [
    {'animation': 'idle_s', 'image': 'idle.png', 'meta': 'idle.json'},
  ],
};
