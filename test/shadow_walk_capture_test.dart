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

/// Produces a real ArenaPainter review grid for every supplied Shadow walk
/// frame. One decoded atlas image is shared by all eight directional sheets.
void main() {
  test(
    'capture Shadow walk pilot in all eight directions and four frames',
    () async {
      final hero = heroById('shadow');
      final manifestFile = File(
        '${hero.assetRoot}/${hero.manifestPath.split('/').last}',
      );
      final manifest = HeroManifest.fromJson(
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
      );
      final atlasPath =
          '${hero.assetRoot}/atlases/shadow_walk_8dir_4frames_FINAL.png';
      final codec = await ui.instantiateImageCodec(
        await File(atlasPath).readAsBytes(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();

      final world = GameWorld(
        kit: shadowKit,
        random: math.Random(71),
        spawnWaves: false,
      );
      world.enemies.clear();
      world.projectiles.clear();
      world.army.clear();

      const rows = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw'];
      const facings = <String, Offset>{
        'e': Offset(1, 0),
        'se': Offset(0.7071, 0.7071),
        's': Offset(0, 1),
        'sw': Offset(-0.7071, 0.7071),
        'w': Offset(-1, 0),
        'nw': Offset(-0.7071, -0.7071),
        'n': Offset(0, -1),
        'ne': Offset(0.7071, -0.7071),
      };
      final output = Directory('build/arena-captures/shadow-walk');
      if (output.existsSync()) output.deleteSync(recursive: true);
      output.createSync(recursive: true);

      try {
        for (final direction in rows) {
          final clip = manifest.clipFor('walk', direction)!;
          final metaFile = File(
            '${hero.assetRoot}/atlases/walk_${direction}_user.json',
          );
          final meta =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          final frames = <String, ui.Rect>{};
          for (final entry in (meta['frames'] as Map).entries) {
            final rect = (entry.value as Map)['frame'] as Map;
            frames[entry.key as String] = ui.Rect.fromLTWH(
              (rect['x'] as int).toDouble(),
              (rect['y'] as int).toDouble(),
              (rect['w'] as int).toDouble(),
              (rect['h'] as int).toDouble(),
            );
          }
          final sheet = AtlasSheet(
            image: image,
            frames: frames,
            width: image.width,
            height: image.height,
            ownsImage: false,
          );

          world.player.facing = facings[direction]!;
          for (var frame = 0; frame < clip.frames.length; frame++) {
            final frameId = clip.frames[frame];
            expect(sheet.rectFor(frameId), isNotNull,
                reason: '$direction frame $frame');
            final painter = ArenaPainter(
              world: world,
              presentation: ArenaPresentation(
                kit: shadowKit,
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
                heroSpriteApproved: true,
              ),
            );
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            painter.paint(canvas, const Size(800, 450));
            final capture = await recorder.endRecording().toImage(800, 450);
            final bytes = await capture.toByteData(format: ui.ImageByteFormat.png);
            expect(bytes, isNotNull);
            expect(bytes!.lengthInBytes, greaterThan(1000));
            File('${output.path}/shadow_walk_${direction}_frame_$frame.png')
                .writeAsBytesSync(bytes.buffer.asUint8List());
            capture.dispose();
          }
        }
        expect(output.listSync().whereType<File>().length, 32);
      } finally {
        image.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
