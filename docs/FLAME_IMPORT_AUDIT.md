# Flame Flutter Package — Import Audit (Archer FM)

Date: 2026-11-26
Source: user-uploaded `flame_hero_flutter.zip`
Target: `fadimatar112211-bit/Archer-fm`, branch `main` at `39e0e46e4658f36ad87e4254f61d27b52ff3e48f`

## 1. Package inventory

- 14 WebP sprite sheets: idle, run, attack1–attack5, dash, hurt, death, ult1–ult4.
- 7 WAV sound effects: boom, swish, step, hit, charge, hurt, death.
- `lib/flame_hero.dart`.
- Archive payload: 1,836,989 bytes across 28 entries (including directories).

All 14 WebP images decode successfully as RGBA. Frames are 192×192, arranged in 8 direction rows.

| Sheet | Pixel size | Frames per direction |
|---|---:|---:|
| idle | 1152×1536 | 6 |
| run | 1536×1536 | 8 |
| attack1–attack5 | 1152×1536 each | 6 each |
| dash | 576×1536 | 3 |
| hurt | 768×1536 | 4 |
| death | 1536×1536 | 8 |
| ult1 | 1536×1536 | 8 |
| ult2 | 1920×1536 | 10 |
| ult3 | 1536×1536 | 8 |
| ult4 | 2688×1536 | 14 |

## 2. Controller review

`FlameHero` is a standalone Flutter `dart:ui` Canvas controller. It supports eight-direction facing and movement input, idle/run, dash, hurt and death states, five queued melee attacks with damage values [10, 12, 15, 20, 40], four distinct Ultimate routines, target-position callback, hit callback, sound callback, revive and disposal.

It does not integrate itself with a game. The host must own the update loop, coordinate space, collision/target resolution, sound playback, player input, lifecycle and UI.

## 3. Gameplay gaps

- `ultimate(1..4)` is callable at any level; level 1/10/20/30 unlock checks are absent.
- No Ultimate cooldown, energy cost or authoritative game-state validation.
- No three-weapon/equipment system.
- Hit detection is callback/radius based and is not connected to Archer FM enemy entities.
- No arena/world bounds or navigation/collision handling.
- Audio is callback-only; the host must load and play the seven WAV files.
- No multiplayer/network authority model.

## 4. Target repository findings

The current `main` branch already contains a shared hero asset pipeline:

- `lib/hero/hero_assets.dart` loads manifest-described atlas images.
- `lib/hero/hero_manifest.dart` expects `hero_id`, `frame_size`, `pivot`, non-empty `animations`, and `atlases`.
- `lib/hero/sprite_player.dart` advances clips and emits frame events.
- `lib/hero/hero_catalog.dart` already defines Flame in the four-hero catalogue.
- `pubspec.yaml` already includes `assets/heroes/flame/renders/flame_manifest.json` and `assets/heroes/flame/renders/atlases/`.
- The existing Flame manifest describes the repository's directional atlas pipeline (8 directions; idle/walk/run/attack/skill/dodge/hit/death).
- `lib/main.dart` currently launches `HeroViewerScreen`; this branch is a hero animation viewer/prototype, not yet the full playable arena/combat runtime.

## 5. Compatibility decision

The uploaded pack is a separate 2D sprite-sheet implementation. The repository's existing Flame assets are already in the shared manifest/atlas format used by the current hero viewer. Replacing those assets or changing the manifest blindly risks breaking the existing Flame preview and mixing two rendering pipelines.

This audit therefore does not overwrite the current Flame assets, shared manifest, or hero catalogue. The uploaded package can be used as a separate Flame sprite-controller integration, but it is not safe to declare it merged into the current 2.5D/atlas hero pipeline without an explicit rendering decision.

## 6. Required integration sequence

1. Decide whether Flame's in-game appearance should switch from the existing repository atlas render to this supplied 2D sprite pack. Do not silently replace one with the other.
2. If selected, put the supplied assets behind a separate asset-root/renderer adapter so the existing atlas renderer remains available as fallback.
3. Connect the controller to the actual arena update/render loop (currently absent from `main.dart`), movement input, world coordinates, enemy target queries and authoritative damage handling.
4. Add level gates for Ultimate unlocks at levels 1, 10, 20 and 30; keep the five-hit combo independent.
5. Add three Flame weapon/equipment definitions and route weapon stats into damage/range/cooldowns.
6. Add an audio service mapping the seven WAV files and respecting sound settings.
7. Add tests for combo queueing, hit timing, Ultimate unlocks, target selection, death/revive and disposal; add visual smoke test and Android build.

## Status

- Package archive and image geometry: validated.
- Dart source: reviewed statically.
- Existing repository architecture: inspected.
- Production gameplay integration: **not complete**; the repository currently exposes a hero viewer rather than the playable arena runtime required to wire this controller safely.
- Flutter analyze, automated tests and Android build: **not run** because a complete repository checkout/build environment was not available in this task session.
