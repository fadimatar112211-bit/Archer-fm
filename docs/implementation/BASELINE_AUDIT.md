# Archer FM — Baseline Audit and Implementation Gate

Audit date: 2026-11-19
Audited repository: `fadimatar112211-bit/Archer-fm`
Audited branch: `main`
Audited HEAD: `029147b71e0dd7fe7e2a0c01c75bdd778d6ebb62`
Working branch: `implementation/phase-0-baseline-audit`

## 1. Executive result

The repository is a real Flutter project with a working hero-animation viewer foundation and automated Android validation workflow. It is **not yet a playable game**. The current application entry point opens `HeroViewerScreen`; no match loop, combat simulation, map, monsters, castles, crystals, mines, account system, or multiplayer implementation is present in the inspected runtime source.

This audit deliberately does not mark any feature complete based only on planning documents or asset filenames.

## 2. Verified repository facts

- Default branch is `main`; HEAD is `029147b71e0dd7fe7e2a0c01c75bdd778d6ebb62`.
- Flutter/Dart project: `pubspec.yaml`, package name `archer_fm`, Dart SDK constraint `>=3.4.0 <4.0.0`.
- Runtime dependencies currently contain only Flutter SDK; no game engine, networking, persistence, authentication, or 3D runtime package is declared.
- `lib/main.dart` sets landscape orientation and launches `HeroViewerScreen` in Arabic RTL.
- Hero viewer modules exist under `lib/hero/`: asset loading, catalogue, manifest parsing, stage rendering, viewer screen, and sprite playback.
- Existing automated tests are `test/hero_manifest_test.dart`, `test/sprite_player_test.dart`, and `test/widget_test.dart`.
- Android CI workflow `.github/workflows/flutter-android.yml` runs Flutter analyze, Flutter tests, debug APK build, Android emulator install/launch checks, and uploads the APK artifact.
- CI currently triggers on pushes to `main` for selected paths, plus manual dispatch. Work on feature branches therefore needs manual workflow dispatch or a later workflow trigger adjustment.

## 3. Asset inventory verified from the main-branch Git tree

### Hero source files found
- Blender sources: `assets/heroes/ranger/source/ranger_source.blend`, `assets/heroes/flame/source/flame_source.blend`, `assets/heroes/shadow/source/shadow_source.blend`.
- Storm source: `assets/heroes/storm/storm.glb` and `assets/heroes/storm/source/storm_source.blend`.
- Ranger GLB: `assets/heroes/ranger_new/ranger.glb`.
- The tree contains hero render/atlas assets for the current sprite-viewer pipeline.

### Important integration gaps
- `pubspec.yaml` bundles manifests and atlases for Ranger, Flame, and Shadow, but does not declare a Storm runtime manifest/atlas path.
- The inspected `pubspec.yaml` does not declare any GLB asset paths or a 3D runtime dependency. The existence of GLB files does not prove that the app loads or renders them.
- The current app runtime is an atlas/sprite viewer, not a verified real-time 3D character renderer.
- No monster asset paths were found in the main-branch recursive tree during this audit.
- No reference sheet path matching `assets/heroes/reference/heroes_reference_sheet.jpg` was found in the inspected main-branch tree. The exact reference must be re-located/confirmed before visual matching can be signed off.

## 4. Feature status based on inspected runtime code and tree

| Area | Verified status |
|---|---|
| Flutter app shell / landscape / Arabic RTL | Present |
| Hero catalogue and sprite/atlas viewer | Present |
| Four hero catalogue entries | Present |
| Four fully integrated runtime hero asset sets | Not verified; Storm is absent from pubspec runtime declarations |
| True 3D GLB runtime rendering | Not implemented/verified |
| Hero progression to level 40 | Not found in runtime source |
| Three weapons per hero | Not found in runtime source |
| Four abilities unlocked at levels 1/10/20/30 | Design requirement only; not found in runtime source |
| Separate five-hit manual combo | Not found in runtime source |
| Monster roster/AI | Not found in main tree |
| Arena/map/biomes/mines/castles/crystals | Not found in runtime source |
| PvP match simulation | Not found in runtime source |
| Online multiplayer / LAN multiplayer | Not found in runtime source |
| Accounts/cloud save/friends | Not found in runtime source |
| Android CI and emulator launch validation | Workflow present; latest successful run not checked in this audit |

## 5. Product requirements retained as design constraints

The implementation must preserve the documented Archer FM direction:
- Four-player free-for-all arena, online play and four-device local Wi-Fi mode.
- Arabic-only initial UI and landscape mobile layout.
- Four heroes; equal HP at the same level, differing movement speeds/roles.
- Manual attack input for every hit; five-hit combo with a stronger fifth hit.
- Four separate hero abilities unlocked at levels 1, 10, 20, and 30. These are separate from the five-hit combo. The Ultimate is one of the four abilities, not a fifth ability.
- Hero level cap 40; three weapons per hero.
- Four existing monster types, 20-unit starting army, autonomous monster combat.
- Four castles/players, seven crystals per player as the current design, resource mines, rebuilding, scoring and match durations as documented in `PROJECT_STATUS.md`.
- No ads or real-money purchases.
- Do not copy gameplay architecture from the legacy `Archero_fm` repository.

Unapproved balance values remain proposals; do not silently hard-code them as final.

## 6. Implementation sequence

1. **Foundation decision:** inspect the full project and choose/confirm the runtime rendering and simulation architecture that can meet Android performance requirements. Do not claim true 3D until GLB loading, skeleton animation, camera, materials, and on-device rendering are demonstrated.
2. **Hero runtime:** integrate and validate all four hero assets, including faces and reference-sheet fidelity; add a reproducible asset validation gate.
3. **Combat vertical slice:** manual attack input, five-hit combo, target damage, HP/death/respawn, four ability slots and level unlock gates.
4. **Arena simulation:** map bounds, movement/collision, castles/crystals, mines/resources, monster AI and army purchase.
5. **Progression/equipment:** hero levels, weapons, abilities, equipment, persistent progression.
6. **Multiplayer:** authoritative online match and local Wi-Fi host/client mode; validate synchronization and disconnect handling.
7. **Production UI/audio/accessibility:** Arabic screens, lobby, matchmaking/private rooms, HUD/minimap, controls and settings.
8. **Release hardening:** automated tests, Android emulator tests, performance/memory checks, APK artifact and real-device acceptance.

## 7. Safety and change policy

- Work on feature branches; do not directly replace `main` during the initial implementation.
- Preserve source models, reference images, and existing assets. Never delete/overwrite large binary assets as part of text-only edits.
- Every claimed completion must cite concrete files and passing test/build evidence.
- A green CI run proves only the checks actually executed; it does not prove gameplay quality or visual fidelity.
- Keep the old `Archero_fm` repository separate.
- Update this audit and `PROJECT_STATUS.md` after each substantial verified milestone.
