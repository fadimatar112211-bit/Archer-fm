import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/sprite_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Shadow 2.5D user-reference walk renders through the real arena painter in all eight directions',
    () async {
      final loader = BundleHeroAssetLoader(heroById('shadow'));
      addTearDown(loader.dispose);
      final manifest = await loader.loadManifest();
      expect(manifest.heroId, 'shadow');
      expect(manifest.frameWidth, 192);
      expect(manifest.frameHeight, 192);

      const directions = <String>['e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne'];
      const facings = <Offset>[
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
        Offset(-1, 1),
        Offset(-1, 0),
        Offset(-1, -1),
        Offset(0, -1),
        Offset(1, -1),
      ];

      final world = GameWorld(
        kit: kitForHero('shadow'),
        random: math.Random(7),
        spawnWaves: false,
      );
      world.enemies.clear();

      for (var i = 0; i < directions.length; i++) {
        final direction = directions[i];
        expect(
          GameWorld.octantNames[GameWorld.octantIndexOf(facings[i])],
          direction,
          reason: 'world facing must select the matching 2.5D row',
        );
        final clipName = 'walk_$direction';
        final clip = manifest.clipFor('walk', direction);
        expect(clip, isNotNull, reason: clipName);
        expect(clip!.frames, hasLength(4), reason: clipName);

        final sheet = await loader.loadSheet(manifest, clipName);
        final atlasRgba = await sheet.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(atlasRgba, isNotNull, reason: clipName);
        final atlasPixels = atlasRgba!.buffer.asUint8List();
        int visiblePixelsIn(ui.Rect rect) {
          var visible = 0;
          final left = rect.left.toInt();
          final top = rect.top.toInt();
          final right = rect.right.toInt();
          final bottom = rect.bottom.toInt();
          for (var y = top; y < bottom; y++) {
            for (var x = left; x < right; x++) {
              final alpha = atlasPixels[(y * sheet.width + x) * 4 + 3];
              if (alpha > 0) visible++;
            }
          }
          return visible;
        }

        // Every direction/frame cell must contain actual non-transparent
        // character pixels; a valid JSON rectangle alone is not enough.
        for (final frame in clip.frames) {
          final rect = sheet.rectFor(frame);
          expect(rect, isNotNull, reason: '$clipName/$frame');
          expect(rect!.width, 192, reason: '$clipName/$frame width');
          expect(rect.height, 192, reason: '$clipName/$frame height');
          expect(
            visiblePixelsIn(rect),
            greaterThan(4000),
            reason: '$clipName/$frame must contain the visible Shadow sprite',
          );
        }

        final player = SpritePlayer(clip: clip);
        player.advance(clip.frameDurationMs * 2);
        final frameId = player.frameId;
        for (final frame in clip.frames) {
          expect(sheet.rectFor(frame), isNotNull, reason: '$clipName/$frame');
        }
        expect(sheet.rectFor(frameId), isNotNull, reason: '$clipName/$frameId');

        world.player.facing = facings[i];
        final painter = ArenaPainter(
          world: world,
          presentation: ArenaPresentation(
            kit: kitForHero('shadow'),
            theme: ThemeData(brightness: Brightness.dark),
            sheet: sheet,
            frameId: frameId,
            pivotX: manifest.pivotX,
            pivotY: manifest.pivotY,
            frameWidth: manifest.frameWidth,
            frameHeight: manifest.frameHeight,
            labels: const [],
            timeMs: world.nowMs,
            comboText: null,
            hero3d: null,
          ),
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(800, 450));
        final image = recorder.endRecording().toImageSync(800, 450);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(data, isNotNull, reason: clipName);
        final bytes = data!.buffer.asUint8List();
        expect(bytes.length, greaterThan(5000), reason: clipName);

        final dir = Directory('build/arena-captures');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File('${dir.path}/shadow_2d5_$direction.png').writeAsBytesSync(bytes);
        image.dispose();
        player.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
