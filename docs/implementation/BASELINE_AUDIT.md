# Archer FM — Current Implementation Baseline

Audit date: 2026-11-19
Repository: `fadimatar112211-bit/Archer-fm`
Baseline branch: `ranger-reference-work`
Baseline commit: `481140e635730dfa82dcae4666b40fd01176677f`
Working branch: `implementation/phase-0-current-baseline`

## Executive summary

The newest project work is on `ranger-reference-work`, not `main`. This branch is substantially ahead of main and contains a playable Flutter game foundation: arena simulation, hero combat and combo, monster systems, map/world systems, progression, online/LAN networking modules, and custom GLB loading/rendering code. The app must be assessed from this branch; main is stale for current implementation work.

A GitHub Actions run for this branch completed successfully on 2026-11-18 (run `44398235818`, commit `c05605f62a7b387f390f98fc6e7a6a48b3afe65d`). This is evidence that the configured release workflow passed at that commit, not proof of full real-device, multiplayer, visual-fidelity, or production readiness.

## Verified current structure

### Runtime and gameplay
- Flutter app entry: `lib/main.dart`; launches Arabic RTL main menu in landscape mode and initializes settings/audio.
- Main gameplay screen: `lib/game/game_screen.dart`.
- Combat: `lib/game/combat/combo.dart`, `hero_kit.dart`, `hero_weapons.dart`.
- Monsters: `lib/game/monsters/monster_models.dart`.
- World: `lib/game/world/arena_map.dart`, `castle_system.dart`, `fog_of_war.dart`, `game_world.dart`, `mine_system.dart`.
- UI: `home_screen.dart`, `army_selection_screen.dart`, `minimap.dart`, settings and progression screens.
- Progression: hero progression, equipment, XP, match XP and progression modules under `lib/game/progress/`.
- Networking modules exist under `lib/game/net/`: authority, hotspot service, lobby, match models, online client/server, protocol and room coordinator.
- Account/social module exists at `lib/game/social/account_service.dart`.

### Heroes and 3D rendering
- `pubspec.yaml` declares runtime atlas assets and four animated GLB models: Ranger, Flame, Shadow and Storm.
- Custom GLB parser/CPU skeletal poser exists in `lib/game/render3/glb.dart`; controller and painter exist in `hero3d_controller.dart` and `hero3d_painter.dart`.
- Ranger, Flame, Shadow and Storm animated GLB paths are present in the branch tree.
- The main gameplay screen currently documents a Ranger atlas/sprite layer for combat. The existence of GLB loader/controller/painter and GLB assets does not by itself prove all four heroes are the active in-match renderer. This requires code-path and visual-capture verification.
- The branch contains a dedicated Ranger reference model folder. Visual fidelity, especially face details and all four heroes, still requires image-based comparison and acceptance.

### Tests present
The branch includes tests for hero manifests/catalogue, GLB loading, 3D capture/screens, combo/combat, monsters, world, castle, mine, game screen and online match behavior. Test files are evidence of intended coverage; actual current pass/fail state must be read from CI logs for the exact commit being assessed.

### CI evidence
- Workflow: `.github/workflows/flutter-android.yml`.
- It runs Flutter analyze, all Flutter tests, builds a Release APK, verifies APK signature, uploads visual captures and APK artifact, and publishes a GitHub Release.
- Latest observed run: `44398235818`, conclusion `success`, branch `ranger-reference-work`, commit `c05605f62a7b387f390f98fc6e7a6a48b3afe65d`, created 2026-11-18 21:07 UTC.
- The workflow expects Android signing secrets and visual-capture artifacts. Re-run/inspect on the current HEAD before treating current HEAD as release-verified.

## Important unresolved/acceptance gates

1. **Branch discipline:** continue from `ranger-reference-work` lineage; do not implement on stale `main` or mix with legacy `Archero_fm`.
2. **Current HEAD verification:** run the full workflow on the exact working commit and inspect all jobs/logs/artifacts.
3. **Hero rendering:** prove all four intended GLB models load and animate in the actual match scene; verify correct face, armor, palette, weapon, scale, rig and animation. Capture all four at consistent camera angles and compare with the user's reference sheet.
4. **Combat acceptance:** verify one tap equals one basic hit, five-hit combo has stronger fifth hit and reset timing, and four separate abilities unlock at levels 1/10/20/30. These four abilities are not the five combo hits.
5. **Monster acceptance:** verify the four approved types, 20-unit pre-match army, automatic target selection/combat, crystal attacks, defense behavior, purchase/death/replacement and practical performance limits.
6. **World/economy acceptance:** verify four-player map, seven crystals per player, mines, physical resource pickup, rebuild rules, fog/minimap, score and match timer against approved rules.
7. **Networking:** unit tests do not prove four physical devices work over hotspot or that online authoritative synchronization is production-ready. Test four real devices, reconnect/disconnect, host loss and state consistency.
8. **Persistence/accounts:** verify data survives app restart/reinstall and distinguish local preferences from real cloud-account synchronization. Google/Apple sign-in and cloud save remain explicit acceptance gates until demonstrated.
9. **Device quality:** test on a mid-range/low-end Android phone for frame rate, memory, thermal behavior, audio, controls and landscape layout.
10. **Release readiness:** verify signed APK installation and gameplay on a real device; do not equate a successful CI build with a finished game.

## Working policy

- All work proceeds on feature branches and is proposed through Pull Requests; do not push directly to `main`.
- Preserve all existing source models, GLBs, reference images and generated assets.
- Do not claim a feature is complete without source evidence plus relevant passing tests/builds; visual and multiplayer claims also need captures/device evidence.
- Record each verified milestone and its exact commit/test evidence in this file and `PROJECT_STATUS.md`.
- Do not add ads, paid items or real-money purchases.
