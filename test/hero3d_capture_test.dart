import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archer_fm/game/render3/glb.dart';
import 'package:archer_fm/game/render3/hero3d_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _save(String name, ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('build/arena-captures');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  image.dispose();
}

void main() {
  test(
    'ranger renders as a real skinned 3D model through the hero painter',
    () async {
      final bytes = await File(
        'assets/heroes/ranger_new/ranger_animated.glb',
      ).readAsBytes();
      final model = await GlbModel.load(Uint8List.fromList(bytes));
      final hero3d = Hero3DModel(model);
      hero3d.calibrate();
      final scale = hero3d.scaleForPixelHeight(150);

      ui.Image capture(String clip, double t, double yaw, bool loop) {
        hero3d.pose(clip, t, loop: loop);
        hero3d.skin();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 800, 450),
          Paint()..color = const Color(0xFF12351C),
        );
        hero3d.paint(
          canvas,
          anchor: const Offset(400, 330),
          yaw: yaw,
          scale: scale,
        );
        return recorder.endRecording().toImageSync(800, 450);
      }

      // All 8 production clips, hero facing the camera (yaw = π).
      await _save('60_hero3d_idle', capture('idle', 400, math.pi, true));
      await _save('61_hero3d_run', capture('run', 500, math.pi, true));
      await _save('62_hero3d_attack', capture('attack', 700, math.pi, false));
      await _save('63_hero3d_skill', capture('skill', 900, math.pi, false));
      await _save('64_hero3d_hit', capture('hit', 300, math.pi, false));
      await _save('65_hero3d_dodge', capture('dodge', 400, math.pi, false));
      await _save('66_hero3d_death', capture('death', 2000, math.pi, false));
      await _save('67_hero3d_walk', capture('walk', 500, math.pi, true));

      // Four directions in the idle clip: front, back, left, right.
      await _save('68_hero3d_yaw_0', capture('idle', 400, 0.0, true));
      await _save('69_hero3d_yaw_pi2', capture('idle', 400, math.pi / 2, true));
      await _save('70_hero3d_yaw_3pi2', capture('idle', 400, 3 * math.pi / 2, true));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
