import 'dart:io';
import 'dart:ui' as ui;

import 'package:archer_fm/game/render3/sprite_actor_renderer.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:archer_fm/hero/sprite_player.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the real bundled Shadow sprite atlases through the shared
/// SpriteActorRenderer and captures representative loop/one-shot states.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('captures idle, walk, attack and death through the shared sprite renderer',
      () async {
    final hero = heroById('shadow');
    final loader = BundleHeroAssetLoader(hero);
    addTearDown(loader.dispose);
    final manifest = await loader.loadManifest();
    expect(manifest.heroId, 'shadow');

    final output = Directory('build/sprite-captures/shadow-phase2');
    if (output.existsSync()) output.deleteSync(recursive: true);
    output.createSync(recursive: true);

    Future<void> capture({
      required String name,
      required AnimationClip clip,
      required String frameId,
      required AtlasSheet sheet,
    }) async {
      final source = sheet.rectFor(frameId);
      expect(source, isNotNull, reason: '$name frame $frameId');

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      SpriteActorRenderer.paint(
        canvas,
        image: sheet.image,
        sourceRect: source!,
        groundAnchor: const ui.Offset(128, 204),
        frameSize: ui.Size(
          manifest.frameWidth.toDouble(),
          manifest.frameHeight.toDouble(),
        ),
        pivotX: manifest.pivotX,
        pivotY: manifest.pivotY,
        targetHeight: 176,
        filterQuality: ui.FilterQuality.none,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(256, 256);
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(png, isNotNull, reason: '$name must produce a PNG capture');
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        expect(rgba, isNotNull, reason: '$name must produce pixels');
        final pixels = rgba!.buffer.asUint8List(
          rgba.offsetInBytes,
          rgba.lengthInBytes,
        );
        var visible = 0;
        for (var i = 3; i < pixels.length; i += 4) {
          if (pixels[i] > 0) visible++;
        }
        expect(visible, greaterThan(500), reason: '$name must render visible sprite pixels');
        File('${output.path}/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      } finally {
        image.dispose();
        picture.dispose();
      }
    }

    // Idle and walk are looping clips: elapsed-time advancement must select
    // a later frame and remain active instead of completing.
    for (final state in ['idle', 'walk']) {
      final clipName = '${state}_s';
      final clip = manifest.clips[clipName];
      expect(clip, isNotNull, reason: clipName);
      final resolved = clip!;
      expect(resolved.loop, isTrue, reason: clipName);
      final sheet = await loader.loadSheet(manifest, clipName);
      final player = SpritePlayer(clip: resolved);
      await capture(
        name: '${state}_frame_0',
        clip: resolved,
        frameId: player.frameId,
        sheet: sheet,
      );
      player.advance(resolved.frameDurationMs);
      expect(player.frameIndex, 1, reason: '$clipName advances by elapsed time');
      expect(player.playing, isTrue, reason: '$clipName remains looping');
      await capture(
        name: '${state}_frame_1',
        clip: resolved,
        frameId: player.frameId,
        sheet: sheet,
      );
      player.dispose();
    }

    // Attack and death are one-shot clips. Capture the start, gameplay event
    // frame and final frame; then prove completion stops playback.
    for (final state in ['attack', 'death']) {
      final clipName = '${state}_s';
      final clip = manifest.clips[clipName];
      expect(clip, isNotNull, reason: clipName);
      final resolved = clip!;
      expect(resolved.loop, isFalse, reason: clipName);
      final sheet = await loader.loadSheet(manifest, clipName);
      final events = <String>[];
      final player = SpritePlayer(
        clip: resolved,
        onEvent: (event) => events.add(event.name),
      );
      await capture(
        name: '${state}_start',
        clip: resolved,
        frameId: player.frameId,
        sheet: sheet,
      );

      final eventFrame = resolved.events.first.frame;
      player.advance(resolved.frameDurationMs * eventFrame);
      expect(player.frameIndex, eventFrame, reason: '$clipName event frame');
      if (resolved.events.isNotEmpty) {
        expect(events, contains(resolved.events.first.name), reason: clipName);
      }
      await capture(
        name: '${state}_event',
        clip: resolved,
        frameId: player.frameId,
        sheet: sheet,
      );

      player.advance(resolved.frameDurationMs * resolved.frames.length);
      expect(player.completed, isTrue, reason: '$clipName completes once');
      expect(player.playing, isFalse, reason: '$clipName stops after final frame');
      await capture(
        name: '${state}_final',
        clip: resolved,
        frameId: player.frameId,
        sheet: sheet,
      );
      final eventCount = events.length;
      player.advance(resolved.frameDurationMs * 4);
      expect(events.length, eventCount, reason: '$clipName cannot re-emit after completion');
      player.dispose();
    }

    expect(output.listSync().whereType<File>().length, 10);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
