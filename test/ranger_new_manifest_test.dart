import 'dart:convert';
import 'dart:io';

import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:archer_fm/hero/sprite_player.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-game loading verification for the merged Ranger
/// (original reference model + the 8-animation rig).
///
/// These tests exercise the exact production path the game uses:
/// `BundleHeroAssetLoader` reads the committed manifest and decodes every
/// packed atlas through the Flutter asset bundle — no Blender involvement.
const String _renderRoot = 'assets/heroes/ranger_new/renders';
const String _manifestFile = '$_renderRoot/ranger_new_manifest.json';
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
  final manifestFile = File(_manifestFile);
  if (!manifestFile.existsSync()) {
    test(
      'the merged Ranger manifest is committed',
      () {},
      skip: 'Run the merged Ranger Blender Asset Pipeline to generate the sprites.',
    );
    return;
  }

  late HeroManifest manifest;
  setUpAll(() {
    manifest = HeroManifest.fromJson(
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
    );
  });

  test('the merged character ships under its own hero id', () {
    expect(manifest.heroId, 'ranger_new');
    expect(heroById('ranger_new').id, 'ranger_new',
        reason: 'the merged Ranger must be part of the playable roster');
    expect(manifest.frameWidth, 192);
    expect(manifest.frameHeight, 192);
    expect(manifest.pivotX, closeTo(0.5, 1e-9));
    expect(manifest.pivotY, closeTo(0.86, 1e-9));
  });

  test('every state and direction has an animation and an atlas', () {
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
    for (final state in ['idle', 'walk', 'run']) {
      expect(manifest.clipFor(state, 's')!.loop, isTrue, reason: state);
    }
    for (final state in ['attack', 'skill', 'dodge', 'hit', 'death']) {
      expect(manifest.clipFor(state, 's')!.loop, isFalse, reason: state);
    }
  });

  test('the attack and skill clips carry their gameplay events', () {
    for (final direction in _directions) {
      final attack = manifest.clipFor('attack', direction)!;
      final skill = manifest.clipFor('skill', direction)!;
      expect(
        attack.events.map((e) => e.name),
        containsAll(['bow_draw', 'projectile_release']),
        reason: 'attack_$direction',
      );
      expect(
        skill.events.map((e) => e.name),
        containsAll(['volley_charge', 'volley_release']),
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

  test('the merged Ranger bundle decodes every atlas and covers every frame',
      () async {
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
          expect(rect.right, lessThanOrEqualTo(sheet.width.toDouble()),
              reason: frameId);
          expect(rect.bottom, lessThanOrEqualTo(sheet.height.toDouble()),
              reason: frameId);
        }
      } finally {
        loader.dispose();
      }
    }
  });
}
