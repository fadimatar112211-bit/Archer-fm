import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/render3/glb.dart';
import 'package:archer_fm/game/render3/hero3d_controller.dart';
import 'package:archer_fm/game/render3/hero3d_painter.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-game proof of the special abilities that had no ArenaPainter capture
/// yet: the real hero GLB is posed on its skill/attack clip while the real
/// GameWorld applies the ability payload, so every PNG shows the actual
/// combat state (damage labels, fx, projectiles, zones), not a UI button.
void main() {
  test(
    'missing special abilities captured from real in-game state',
    () async {
      final heroes = <String, ({HeroKit kit, String glb})>{
        'ranger_new': (
          kit: rangerNewKit,
          glb: 'assets/heroes/ranger_new/ranger_animated.glb',
        ),
        'flame': (
          kit: flameKit,
          glb: 'assets/heroes/flame/model/flame_animated.glb',
        ),
        'shadow': (
          kit: shadowKit,
          glb: 'assets/heroes/shadow/model/shadow_animated.glb',
        ),
        'storm': (
          kit: stormKit,
          glb: 'assets/heroes/storm/model/storm_animated.glb',
        ),
      };

      final dir = Directory('/tmp/opencode/merge/captures');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      for (final hero in heroes.entries) {
        final bytes = File(hero.value.glb).readAsBytesSync();
        final model = await GlbModel.load(Uint8List.fromList(bytes));
        final hero3d = Hero3DController(Hero3DModel(model));
        hero3d.model.calibrate();
        final kit = hero.value.kit;

        Future<void> captureAbility({
          required String abilityId,
          required String fileName,
          required List<Offset> dummies,
          bool followUpSwing = false,
          bool followUpShot = false,
          int afterReleaseMs = 220,
        }) async {
          final def = kit.abilityById(abilityId)!;
          final world = GameWorld(
            kit: kit,
            random: math.Random(7),
            spawnWaves: false,
          );
          world.enemies.clear();
          for (var i = 0; i < dummies.length; i++) {
            world.enemies.add(
              EnemyState(
                id: '${abilityId}_$i',
                kind: i == 0 ? 'slime' : 'archer',
                position: world.player.position + dummies[i],
                maxHp: 500,
                speed: 0,
                contactDamage: 8,
                xpValue: 10,
              ),
            );
          }
          final before = world.enemies.map((e) => e.hp).toList();
          world.player.facing = const Offset(1, 0);
          world.level = 30; // every special unlocked

          expect(world.useAbility(abilityId), isNotNull,
              reason: '$abilityId should be castable at level 30');

          // Pose the 3D hero exactly like the game screen does.
          hero3d.playClip(
            def.usesAttackClip ? 'attack' : 'skill',
            loop: false,
            pace: 1.0,
            nowMs: world.nowMs,
            events: const [],
          );

          // Advance to the weapon-event frame, release the payload, then let
          // the effect live ~220 ms so the fx/projectile is mid-flight.
          for (var t = 0; t < 180; t += 16) {
            world.update(16);
          }
          world.releaseWeaponPayload(volley: !def.usesAttackClip);
          if (followUpSwing) {
            // Buffs (static field, venom coat, tempest rage) prove their
            // combat effect through the next swing.
            world.requestAttack();
            world.releaseMeleeSwing();
          } else if (followUpShot) {
            // Ranger buffs prove their effect through the next arrow.
            world.requestAttack();
            world.releaseArrow();
          }
          for (var t = 0; t < afterReleaseMs; t += 16) {
            world.update(16);
          }
          hero3d.advance(world.nowMs, onEvent: (_) {});

          // Real damage labels from the actual hp deltas of this cast.
          final labels = <FloatLabel>[];
          for (var i = 0; i < world.enemies.length; i++) {
            final lost = before[i] - world.enemies[i].hp;
            if (lost > 0.5) {
              labels.add(
                FloatLabel(
                  text: '-${lost.round()}',
                  worldPosition: world.enemies[i].position -
                      const Offset(0, 26),
                  bornAtMs: world.nowMs - 150,
                  color: const Color(0xFFFFE082),
                ),
              );
            }
          }

          final painter = ArenaPainter(
            world: world,
            presentation: ArenaPresentation(
              kit: kit,
              theme: ThemeData(brightness: Brightness.dark),
              sheet: null,
              frameId: null,
              pivotX: 0.5,
              pivotY: 0.85,
              frameWidth: 192,
              frameHeight: 192,
              labels: labels,
              timeMs: world.nowMs,
              comboText: null,
              hero3d: hero3d,
            ),
          );
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          painter.paint(canvas, const Size(800, 450));
          final image = recorder.endRecording().toImageSync(800, 450);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${dir.path}/$fileName.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
          expect(hero3d.model.drawnTriangles, greaterThan(0));
          // The screenshot shows a real combat state change, not a button.
          expect(labels, isNotEmpty,
              reason: '$abilityId should damage at least one dummy');
          expect(
            world.enemies.any((e) => e.hp < e.maxHp),
            isTrue,
            reason: '$abilityId left every dummy untouched',
          );
        }

        switch (hero.key) {
          case 'ranger_new':
            await captureAbility(
              abilityId: 'piercing_shot',
              fileName: '13_ranger_piercing_shot',
              dummies: const [Offset(160, 10), Offset(300, 10)],
              afterReleaseMs: 330,
            );
            await captureAbility(
              abilityId: 'gale_surge',
              fileName: '14_ranger_gale_surge',
              dummies: const [Offset(160, 10)],
              followUpShot: true,
              afterReleaseMs: 480,
            );
          case 'flame':
            await captureAbility(
              abilityId: 'inferno_rage',
              fileName: '15_flame_inferno_rage',
              dummies: const [Offset(70, 0)],
              followUpSwing: true,
            );
          case 'shadow':
            await captureAbility(
              abilityId: 'twin_fangs',
              fileName: '16_shadow_twin_fangs',
              dummies: const [Offset(60, 0)],
            );
            await captureAbility(
              abilityId: 'venom_coat',
              fileName: '17_shadow_venom_coat',
              dummies: const [Offset(60, 0)],
              followUpSwing: true,
            );
          case 'storm':
            await captureAbility(
              abilityId: 'thunder_thrust',
              fileName: '18_storm_thunder_thrust',
              dummies: const [Offset(70, 0), Offset(200, 0)],
            );
            await captureAbility(
              abilityId: 'chain_lightning',
              fileName: '19_storm_chain_lightning',
              dummies: const [
                Offset(80, -10),
                Offset(120, 10),
                Offset(160, -10),
              ],
            );
            await captureAbility(
              abilityId: 'static_field',
              fileName: '32_storm_static_field',
              dummies: const [Offset(70, 0)],
              followUpSwing: true,
            );
            await captureAbility(
              abilityId: 'tempest_rage',
              fileName: '33_storm_tempest_rage',
              dummies: const [Offset(70, 0)],
              followUpSwing: true,
            );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
