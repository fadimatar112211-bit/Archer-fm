import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual capture of the REAL production renderer with the REAL
/// `ranger_new` face-welded atlases.
///
/// This is a plain (non-widget) test on purpose: `flutter_tester` under the
/// qemu software rasterizer takes many minutes per rasterized widget frame,
/// while plain tests decode the production atlases quickly (the same pattern
/// as `hero_manifest_test.dart`). The test drives `ArenaPainter.paint` — the
/// exact painter the game screen composites — over scripted `GameWorld`
/// states and saves PNGs to `/tmp/opencode/merge/captures` for inspection.
///
/// Widget-level integration (input, HUD, event → arrow sync, persistence) is
/// covered separately and fast in `game_screen_test.dart` with fake atlases.
void main() {
  test(
    'ranger_new battle scenes render through ArenaPainter with real atlases',
    () async {
      final hero = heroById('ranger_new');
      // Plain tests have no ServicesBinding, so read the bundled files
      // directly from disk (same approach as hero_manifest_test.dart).
      final loader = _FileAtlasLoader(hero, hero.assetRoot);
      final manifest = await loader.loadManifest();
      final sheets = <String, AtlasSheet>{};
      for (final animation in const ['idle_e', 'attack_e', 'skill_e']) {
        sheets[animation] = await loader.loadSheet(manifest, animation);
      }

      // Scripted arena: three stationary enemies around the hero.
      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(5),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.enemies.addAll([
        EnemyState(
          id: 'd1',
          kind: 'slime',
          position: world.player.position + const Offset(170, 10),
          maxHp: 120,
          speed: 0,
          contactDamage: 8,
          xpValue: 10,
        ),
        EnemyState(
          id: 'd2',
          kind: 'archer',
          position: world.player.position + const Offset(-190, -40),
          maxHp: 40,
          speed: 0,
          contactDamage: 6,
          xpValue: 14,
          ranged: true,
        ),
        EnemyState(
          id: 'd3',
          kind: 'brute',
          position: world.player.position + const Offset(120, -120),
          maxHp: 200,
          speed: 0,
          contactDamage: 14,
          xpValue: 25,
        ),
      ]);
      world.player.facing = const Offset(1, 0);

      AtlasSheet? activeSheet;
      String? activeFrameId;
      String? comboText;

      ui.Image capture(String frameId, {String? combo}) {
        activeFrameId = frameId;
        comboText = combo;
        final painter = ArenaPainter(
          world: world,
          presentation: ArenaPresentation(
            kit: rangerNewKit,
            theme: ThemeData(brightness: Brightness.dark),
            sheet: activeSheet,
            frameId: activeFrameId,
            pivotX: manifest.pivotX,
            pivotY: manifest.pivotY,
            frameWidth: manifest.frameWidth,
            frameHeight: manifest.frameHeight,
            labels: const [],
            timeMs: world.nowMs,
            comboText: comboText,
          ),
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(800, 450));
        return recorder.endRecording().toImageSync(800, 450);
      }

      Future<void> save(String name, ui.Image image) async {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('/tmp/opencode/merge/captures');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File('${dir.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      }

      // 1 — idle, first combo state, no shots yet.
      activeSheet = sheets['idle_e']!;
      save('01_idle', capture('ranger_new_idle_e_000'));

      // 2 — attack chain: two escalating hits, second arrow in flight.
      activeSheet = sheets['attack_e']!;
      world.requestAttack();
      world.releaseArrow();
      _runFor(world, 1100); // arrow lands on the slime, cycle elapses
      world.requestAttack();
      world.releaseArrow();
      _runFor(world, 240); // second arrow mid-flight
      save(
        '02_attack_chain',
        capture('ranger_new_attack_e_002', combo: 'الضربة 2/5 · 110%'),
      );

      // 3 — multi_shot volley: five arrows in the air.
      _runFor(world, 900); // let the combo arrow finish its flight
      world.player.energy = rangerNewKit.baseMaxEnergy;
      expect(world.useAbility('multi_shot'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.projectiles.length, 5);
      _runFor(world, 180);
      activeSheet = sheets['skill_e']!;
      save('03_multi_shot_volley', capture('ranger_new_skill_e_006'));

      // 4 — arrow rain zone ticking on the slime.
      world.level = 20;
      world.player.energy = rangerNewKit.baseMaxEnergy;
      expect(world.useAbility('arrow_rain'), isNotNull);
      world.releaseWeaponPayload(volley: true);
      expect(world.zones.length, 1);
      _runFor(world, 600); // two rain ticks landed
      save('04_arrow_rain_zone', capture('ranger_new_skill_e_004'));

      // Real combat accounting happened across the scripted scene.
      expect(world.totalDamageDealt, greaterThan(rangerNewKit.baseDamage * 2));
      expect(world.enemies.any((enemy) => enemy.hp < enemy.maxHp), isTrue);

      for (final sheet in sheets.values) {
        sheet.dispose();
      }
      loader.dispose();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Loads the real bundled atlases straight from disk (no rootBundle).
class _FileAtlasLoader extends HeroAssetLoader {
  _FileAtlasLoader(this.hero, this.assetRoot);

  final HeroDefinition hero;
  final String assetRoot;

  @override
  String get heroId => hero.id;

  @override
  Future<HeroManifest> loadManifest() async {
    final text = await File('$assetRoot/${hero.manifestPath.split('/').last}')
        .readAsString();
    return HeroManifest.fromJson(
      jsonDecode(text) as Map<String, dynamic>,
    );
  }

  @override
  Future<AtlasSheet> loadSheet(
    HeroManifest manifest,
    String animation,
  ) async {
    final entry = manifest.atlasFor(animation);
    if (entry == null) {
      throw StateError('Manifest has no atlas for $animation');
    }
    final meta = jsonDecode(
      await File('$assetRoot/${entry.meta}').readAsString(),
    ) as Map<String, dynamic>;
    final bytes =
        await File('$assetRoot/${entry.image}').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;
    final frames = <String, ui.Rect>{};
    for (final MapEntry(key: frameId, value: value)
        in (meta['frames'] as Map).entries) {
      final rect = (value as Map)['frame'] as Map;
      frames[frameId] = ui.Rect.fromLTWH(
        (rect['x'] as int).toDouble(),
        (rect['y'] as int).toDouble(),
        (rect['w'] as int).toDouble(),
        (rect['h'] as int).toDouble(),
      );
    }
    return AtlasSheet(
      image: image,
      frames: frames,
      width: image.width,
      height: image.height,
    );
  }
}

void _runFor(GameWorld world, int ms) {
  for (var t = 0; t < ms; t += 16) {
    world.update(16);
  }
}
