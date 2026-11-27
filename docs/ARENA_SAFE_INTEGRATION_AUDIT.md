# Arena integration audit and safe migration plan

Date: 2026-11-26

## Scope and safety

This audit concerns only `fadimatar112211-bit/Archer-fm`. The default branch `main` is the protected baseline for this work. No changes are made directly to `main`.

A clean working branch, `arena-safe-integration-audit`, was created from the current `main` head before recording this report.

## Verified repository facts

- The open draft PR #11, `Add unified four-hero combat roster foundation`, targets `main` from `heroes-complete`. Its declared scope includes the four-hero roster/combat foundation, arena map/castle/fog/mine systems, monster army runtime, tests, and asset pipeline. Its PR description explicitly says this is not yet the production arena combat loop and requires further verification.
- The open draft PR #15, `Add unified arena scene integration capture`, targets `ranger-reference-work` from `arena-scene-integration`, not `main`. It adds a unified visual capture test using `ArenaPainter`, Ranger GLB, generated map, armies, monster roles, castles and crystals. Its description explicitly says Flutter tests were not run in the authoring chat and the render is not device visual QA.
- PR #15 changes the live `GameScreen` and related rendering/test code, but its base is `ranger-reference-work`. It must not be merged directly into `main` without reconciling the base and all intervening commits.
- At audit time, `arena-scene-integration` was 949 commits ahead and 51 behind `main` in the GitHub compare result. `ranger-reference-work` was 891 ahead and 51 behind. These are diverged histories, not safe fast-forward updates.
- The latest `main` tree contains many hero render assets, but the PR descriptions and branch layout show that the arena implementation is spread across several development lines. A file existing on a feature branch is not proof that it is integrated into the default app entry point.

## User-approved gameplay requirements to preserve

- Four selectable heroes: Ranger, Flame, Shadow, Storm.
- 2.5D/isometric gameplay presentation, consistent with the approved gameplay screenshot and hero reference sheet.
- Manual attack input and a five-hit combo.
- Four separate Ultimate attacks unlocked at hero levels 1, 10, 20, and 30; these are not combo hits.
- Three weapons per hero, hero level cap 40, equal health for heroes at the same level, and distinct movement speeds.
- Arabic-first in-game UI and no advertisements.
- The arena plan includes four castles and seven crystals per player (28 total for four players), with the starting army and enemy roles subject to the current game design contract.

## Safe integration sequence

1. Rebase or recreate the arena integration work on a fresh branch from the current `main`; do not merge the 949-commit divergent branch wholesale.
2. Compare PR #11's exact file set against current `main`. Port the arena/world and monster subsystems in dependency groups, preserving current hero assets and app configuration. Run the existing tests after each group.
3. Integrate the hero combat runtime and hero selection with the actual arena scene. Keep the five-hit combo separate from all four Ultimate slots and verify the level unlock rules.
4. Port the `GameScreen`/input/render changes from PR #15 only after their dependencies are present. Resolve every conflict deliberately; do not accept broad branch replacement.
5. Add or retain one unified arena integration test that checks map, four castles, 28 crystals, starting army, four hostile roles, hero rendering, HUD, and controls.
6. Run `flutter pub get`, `flutter analyze`, the full `flutter test` suite, and an Android debug build in CI.
7. Review the generated 16:9 capture against the approved gameplay screenshot, then perform an actual Android device/emulator check for touch controls, camera scale, readability, frame rate, and GLB/atlas asset loading.
8. Open a pull request from the clean integration branch to `main`. Merge only after CI and visual QA pass.

## Explicit non-claims

This report does not claim the arena is already playable on a phone, that PR #11 or #15 has passed current CI, that the 3D models match the approved face references, or that any feature branch has been merged. No changes were made to `main`.


## CI follow-up (2026-11-26)

- The Monster Army Checks workflow on `heroes-complete` passed for commit `739627ac1b498d8c953ef248fcdfec82f550cae8`.
- The separate Flutter validation workflow also passed on that branch at the earlier pipeline commit.
- The Storm asset workflow failed before export because Ubuntu's apt package supplied Blender 3.0.1, while the checked-in `.blend` source files were saved by Blender 3.6.13. The log shows an explicit newer-file warning followed by a Blender segmentation fault (exit 139).
- The workflow was updated on `heroes-complete` to install and verify Blender 3.6.13. The rerun is currently in progress; this is a fix attempt, not a verified successful export.
- The latest successful visual-build run on `arena-scene-integration` ran only the Flame matrix job. Its workflow matrix currently lists Flame alone, so it is not evidence that all four hero sprite packs were rebuilt or validated.
