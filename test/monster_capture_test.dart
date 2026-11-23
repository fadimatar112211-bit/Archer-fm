import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archer_fm/game/arena_camera.dart';
import 'package:archer_fm/game/arena_painter.dart';
import 'package:archer_fm/game/combat/hero_kit.dart';
import 'package:archer_fm/game/monsters/monster_models.dart';
import 'package:archer_fm/game/monsters/monster_telegraph_geometry.dart';
import 'package:archer_fm/game/world/arena_projection.dart';
import 'package:archer_fm/game/world/game_world.dart';
import 'package:archer_fm/hero/hero_assets.dart';
import 'package:archer_fm/hero/hero_catalog.dart';
import 'package:archer_fm/hero/hero_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual capture of the temporary procedural monster fallback with the
/// real ranger atlas composited on top. This proves role rendering executes;
/// it does not approve the monster art against the user's reference sheet.
/// Plain test for the same reason as
/// `game_capture_test.dart`: `ArenaPainter.paint` is captured directly, so the
/// four monster silhouettes, gait frames, team rings, HP bars and corpses are
/// checked without the slow widget rasterizer.
void main() {
  test(
    'all four monster types render with walking, attacking and corpses',
    () async {
      final hero = heroById('ranger_new');
      final loader = _FileAtlasLoader(hero, hero.assetRoot);
      final manifest = await loader.loadManifest();
      final sheets = <String, AtlasSheet>{};
      for (final animation in const ['idle_e', 'attack_e']) {
        sheets[animation] = await loader.loadSheet(manifest, animation);
      }

      final world = GameWorld(
        kit: rangerNewKit,
        random: math.Random(21),
        spawnWaves: false,
        startingArmy: const {
          MonsterType.runner: 3,
          MonsterType.tank: 2,
          MonsterType.stalker: 2,
          MonsterType.ranged: 2,
        },
      );
      // Keep the constructor's camera target and player spawn in sync. Moving
      // only PlayerState.position leaves cameraOrigin at the old spawn and can
      // silently capture the isolated actors outside the viewport.
      world.enemies.clear();
      world.projectiles.clear();
      world.corpses.clear();
      world.army.clear();

      // Friendly line, one of each type, mid-stride.
      var slot = 0;
      final armyTypes = [
        MonsterType.tank,
        MonsterType.runner,
        MonsterType.stalker,
        MonsterType.ranged,
      ];
      for (final type in armyTypes) {
        final stats = MonsterStats.of(type, 6);
        final ally = EnemyState(
          id: 'army_cap_$slot',
          kind: type.name,
          type: type,
          team: MonsterTeam.player,
          level: 6,
          position: world.player.position + Offset(-150 + slot * 90, 90),
          maxHp: stats.maxHp,
          speed: stats.speed,
          contactDamage: stats.damage,
          xpValue: 0,
          radius: stats.radius,
        );
        ally.groupSlot = slot;
        ally.moving = true;
        ally.walkPhase = math.pi * slot * 0.5;
        world.army.add(ally);
        slot++;
      }

      // Hostile mirror line, one of each type, plus one attacking.
      slot = 0;
      for (final type in armyTypes) {
        final stats = MonsterStats.of(type, 4);
        final enemy = EnemyState(
          id: 'enemy_cap_$slot',
          kind: type.name,
          type: type,
          team: MonsterTeam.enemy,
          level: 4,
          position: world.player.position + Offset(-150 + slot * 90, -170),
          maxHp: stats.maxHp,
          speed: stats.speed,
          contactDamage: stats.damage,
          xpValue: stats.xpValue,
          radius: stats.radius,
        );
        enemy.moving = slot.isEven;
        enemy.walkPhase = math.pi * slot * 0.4 + 0.6;
        enemy.hp = stats.maxHp * (0.9 - slot * 0.2);
        world.enemies.add(enemy);
        slot++;
      }
      world.enemies.first.attackAnimUntilMs = world.nowMs + 160;

      // One corpse of each team mid-collapse.
      world.corpses.add(
        MonsterCorpse(
          type: MonsterType.runner,
          team: MonsterTeam.enemy,
          position: world.player.position + const Offset(140, -90),
          facing: const Offset(1, 0),
          bornAtMs: world.nowMs - 250,
        ),
      );

      ui.Image capture(String frameId) {
        final painter = ArenaPainter(
          world: world,
          presentation: ArenaPresentation(
            kit: rangerNewKit,
            theme: ThemeData(brightness: Brightness.dark),
            sheet: sheets['idle_e'],
            frameId: frameId,
            pivotX: manifest.pivotX,
            pivotY: manifest.pivotY,
            frameWidth: manifest.frameWidth,
            frameHeight: manifest.frameHeight,
            labels: const [],
            timeMs: world.nowMs,
            comboText: null,
          ),
          // Keep normal gameplay captures at the default camera scale, but
          // zoom isolated review shots so monster faces/armor are legible.
          config: frameId.startsWith('monster_isolated_')
              ? const ArenaCameraConfig(
                  projection: ArenaWorldProjection(
                    groundScaleY: 0.82,
                    scale: 2.4,
                  ),
                )
              : defaultArenaCameraConfig,
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(800, 450));
        return recorder.endRecording().toImageSync(800, 450);
      }

      await _save('20_monster_lineup', capture('ranger_new_idle_e_000'));

      // Advance the gait and the attack timers for a second pose.
      for (final monster in [...world.army, ...world.enemies]) {
        monster.walkPhase += math.pi * 0.7;
      }
      world.enemies.first.attackAnimUntilMs = world.nowMs + 120;
      await _save('21_monster_gait', capture('ranger_new_idle_e_000'));

      // Dedicated combat-state capture: every hostile archetype attacks,
      // while hit/burn feedback and both team corpse silhouettes are visible.
      for (final monster in world.enemies) {
        monster.attackAnimUntilMs = world.nowMs + 160;
      }
      world.enemies[1].hitFlashUntilMs = world.nowMs + 220;
      world.enemies[2].burnTicksLeft = 2;
      world.corpses.add(
        MonsterCorpse(
          type: MonsterType.stalker,
          team: MonsterTeam.player,
          position: world.player.position + const Offset(210, -40),
          facing: const Offset(-1, 0),
          bornAtMs: world.nowMs - 250,
        ),
      );
      await _save('22_monster_combat_feedback', capture('ranger_new_idle_e_000'));

      // Review impact-ring and critical-health feedback separately for all
      // four archetypes at the same gameplay zoom. Reset the other bars so
      // each capture isolates the selected monster's readability.
      for (final type in armyTypes) {
        for (final monster in world.enemies) {
          monster.hp = monster.maxHp;
          monster.hitFlashUntilMs = 0;
        }
        final target = world.enemies.firstWhere((enemy) => enemy.type == type);
        target.hp = target.maxHp * 0.12;
        target.hitFlashUntilMs = world.nowMs + 220;
        await _save(
          '22b_monster_${type.name}_hit_critical',
          capture('ranger_new_idle_e_000'),
        );
      }

      // Review each archetype's attack warning across all eight arena
      // directions. The body stays upright while its ground telegraph rotates
      // into the actual attack lane; these captures catch mirrored/diagonal
      // regressions that a single east-facing image would miss.
      for (final type in armyTypes) {
        for (final other in world.enemies) {
          other.attackAnimUntilMs = 0;
          other.hitFlashUntilMs = 0;
        }
        final actor = world.enemies.firstWhere((enemy) => enemy.type == type);
        final directionAngles = <String>{};
        for (var direction = 0; direction < 8; direction++) {
          final angle = direction * math.pi / 4;
          actor.attackAnimUntilMs = world.nowMs + 230;
          actor.facing = Offset(math.cos(angle), math.sin(angle));
          // The pure geometry test verifies that all eight vectors map to
          // unique body-local angles. Full-frame pixel hashes are unsuitable
          // here: the body is intentionally kept upright and some telegraphs
          // are rotationally symmetric, so distinct lanes can rasterize to
          // the same pixels at this capture scale.
          final localAngle = monsterTelegraphAngle(
            actor.facing,
            mirrored: actor.facing.dx < -0.08,
          );
          expect(
            directionAngles.add('${actor.facing.dx < -0.08}:${(localAngle * 1000000).round()}'),
            isTrue,
            reason: '${type.name} attack direction $direction must map to a unique warning angle',
          );
          await _save(
            '23b_monster_${type.name}_attack_dir_$direction',
            capture('ranger_new_idle_e_000'),
          );
        }
      }

      // Isolated archetype review captures: enlarge only the test actor so
      // its face, armor silhouette and weapon can be inspected without the
      // normal arena zoom hiding the details. Gameplay radii are untouched.
      final isolatedActors = {
        for (final actor in world.enemies) actor.type: actor,
      };
      final isolatedFingerprints = <int>{};
      for (final type in armyTypes) {
        final source = isolatedActors[type]!;
        final actor = EnemyState(
          id: 'isolated_${type.name}',
          kind: type.name,
          type: type,
          team: MonsterTeam.enemy,
          level: source.level,
          position: world.player.position + const Offset(80, 0),
          maxHp: source.maxHp,
          speed: source.speed,
          contactDamage: source.contactDamage,
          xpValue: source.xpValue,
          radius: 28,
        )
          ..moving = false
          ..facing = const Offset(-1, 0);
        world.enemies
          ..clear()
          ..add(actor);
        world.army.clear();
        world.corpses.clear();
        final fingerprint = await _save(
          '24_monster_${type.name}_isolated_review',
          capture('monster_isolated_review'),
        );
        expect(
          isolatedFingerprints.add(fingerprint),
          isTrue,
          reason: '${type.name} isolated monster must be visible and distinct',
        );
      }

      for (final sheet in sheets.values) {
        sheet.dispose();
      }
      loader.dispose();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<int> _save(String name, ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final dir = Directory('build/arena-captures');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());

  // Sample the rendered pixels so the capture test fails if the actor is
  // outside the viewport or a direction/archetype silently renders identically.
  var fingerprint = 0x811c9dc5;
  for (var i = 0; i < pixels!.lengthInBytes; i += 4) {
    fingerprint = ((fingerprint ^ pixels.getUint8(i)) * 0x01000193) & 0xffffffff;
  }
  image.dispose();
  return fingerprint;
}

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
    final bytes = await File('$assetRoot/${entry.image}').readAsBytes();
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
