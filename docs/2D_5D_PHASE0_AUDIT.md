# Archer FM — Phase 0 Reference and Renderer Audit

**Date:** 2026-11-21  
**Branch:** `ranger-reference-work`  
**Audited HEAD:** `8170774995824e9335e124e716f866d2563ef5c1`

## User's non-negotiable art rule

Use only user-supplied/approved references for:
- the four heroes;
- the four monster types;
- the final in-game screenshot/composition.

Do not use assistant-generated art, generic web images, stock art, or invented placeholders. The original reference files are immutable. If a required source is missing or unclear, stop and ask the user.

## Exact approved references inspected

1. **Hero appearance:** `assets/references/approved_all/hero_roster_concept.jpg` — blob `b4283a86b3f1727aa6c59966a3ce8479d32d735f`.
2. **Monster appearance:** `assets/references/approved_all/archer_fm_monsters_reference.png` — blob `2d1b350617f71c00fb3986ae986cabbe53df00da`.
3. **Gameplay/camera/HUD:** `assets/references/approved_all/file_000000005c8c81f9ab4ccbb80ea59d5e.png`, as defined by `docs/references/USER_APPROVED_VISUAL_REFERENCES.md`.
4. **Shadow directional walk source:** user Library upload `1000241306.png`. This source has eight direction rows and four pose columns plus an Arabic label column; use it only as the supplied source to clean/crop, never replace its character with generated art.

The hero sheet defines hero identity. The monster sheet defines the four enemy designs. The gameplay screenshot defines presentation, camera, environment composition and HUD. They are not interchangeable.

## Verified code and asset findings

- Sprite runtime files exist: `lib/hero/hero_assets.dart`, `lib/hero/hero_manifest.dart`, `lib/hero/sprite_player.dart`.
- The production arena is currently drawn with Flutter Canvas in `lib/game/arena_painter.dart` and `ArenaWorldProjection`. It is not yet a real 3D world renderer.
- `GameScreen.initState` calls `_loadHero3D()`. A successfully loaded GLB is selected by `ArenaPresentation.hero3d` instead of the atlas sprite. This is why simply having sprite atlases in the repo does not guarantee the game is displaying them.
- `pubspec.yaml` currently includes both sprite assets and all four GLB assets.
- Existing sprite atlases are present for Ranger legacy, Ranger New, Flame, Shadow and Storm. Tree inspection counted 64 atlas PNGs for each current roster ID (Ranger New, Flame, Shadow, Storm). Presence does not establish visual fidelity.
- Shadow's existing manifest has 64 clips (8 states × 8 directions). Its `walk_s` clip has 9 frames at 83 ms. The user-provided source sheet has 4 frames per direction. We must treat these as distinct sources until the existing atlas is visually checked against the approved references.
- No production monster image directory (`assets/monsters/`) was found in the audited tree.
- Existing test files include hero manifest, sprite player, all-hero manifest, arena projection and visual capture tests. No tests were run during this read-only audit.

## Phase 0 conclusion

The project has a reusable sprite foundation, but it is not yet a completed 2.5D migration:
1. Sprite visuals need direct reference comparison.
2. The GLB path currently overrides the in-game sprite hero when loading succeeds.
3. Monster sprite assets still need to be located/produced from the approved monster source.
4. The world is still a 2D Canvas renderer; a lightweight actual 3D-world renderer remains to be designed and prototyped.
5. No source images should be generated to fill these gaps.

## Next implementation order

1. Inspect the actual Shadow sprite frames and compare them side-by-side with the user's supplied `1000241306.png` and the official hero sheet.
2. Clean/crop only the supplied Shadow sheet into uniform 8×4 frames; preserve the original image unchanged and verify alpha values.
3. Add a sprite-only Shadow preview/in-game test path with explicit direction mapping and a screenshot capture.
4. Only after visual approval, switch the production hero render path to 2D sprites while retaining GLB sources for rollback.
5. Prototype a lightweight 3D world renderer as a separate task; preserve the existing world simulation and input transform contracts.
6. Locate/prepare monster sprite assets strictly from the approved monster reference.

## Not claimed

- No code was changed in this audit.
- No tests/builds were run.
- No sprite or monster asset has been approved.
- The game has not yet been converted to 2.5D.

## Existing CI baseline (previous commit, not this documentation commit)

The latest workflow inspected during this audit is run `44751664933`, built from commit `ecf524c0c2bdada1a129ba6694710ad75c981eb7` (2026-11-20):
- Flutter Analyze: passed.
- Full Flutter test suite: passed.
- Release APK build and APK verification: passed.
- Android emulator smoke test: failed. The test expected landscape width greater than 683.43 logical pixels but measured 411.43, so the app did not satisfy the landscape orientation lock in that emulator run.
- The separate monster GLB generation job succeeded, but this is not evidence of approved monster sprite art.

This workflow predates the current documentation commits and is a baseline only; it is not a test of the current HEAD or the new 2.5D conversion. Re-run CI after the first code/asset integration change.

## Phase 1 — Shadow source inspection (2026-11-21)

Inspected the exact user-uploaded `1000241306.png` from Library (1536×1024 RGB; it is not an alpha PNG). It contains the intended 8 direction rows and 4 poses, but it is a presentation/reference sheet, not a clean engine-ready atlas:
- the Arabic direction labels occupy the left margin;
- the white background and cast shadows are baked into the pixels;
- several lower direction rows are vertically crowded/overlap at the boundaries, so naive equal-height row cropping cuts parts of adjacent poses;
- the source has no alpha channel. A checkerboard-looking preview must never be mistaken for true transparency.

A non-destructive extraction experiment was performed locally using background segmentation and fixed 256×256 output cells. The preview is **not accepted for production** because lower-row boundaries still risk clipping/cross-contamination. No extracted image was committed to the game and the original user image remains untouched. Do not ship this prototype or claim the 8×4 atlas is production-ready.

The existing runtime already supports manifest-driven sprite atlases:
- `HeroManifest` maps animation clips to atlas entries, with frame duration, loop and event data.
- `BundleHeroAssetLoader` loads PNG atlases and per-atlas frame rectangles.
- `SpritePlayer` advances clips from elapsed milliseconds and has unit tests for looping, pause/resume, restart and seek.
- `GameScreen` loads the hero's GLB asynchronously and uses the GLB painter when it succeeds; the sprite atlas is the fallback path.

### Phase 1 next action / acceptance requirement

Before any Shadow atlas replacement:
1. Acquire/derive clean isolated source frames from the exact user-approved Shadow art, without inventing or redrawing the character. The supplied reference sheet alone is insufficient for clean automated cropping of every lower row.
2. Preserve all original 32 poses; manually verify all eight directions and all four frames against the uploaded source.
3. Remove only the plain white background and baked cast shadows; do not erase purple glow, daggers, cape edges, armor highlights or facial details.
4. Confirm RGBA alpha programmatically, consistent scale/feet pivot, and no pixels from adjacent rows.
5. Build the atlas/metadata using the existing manifest loader contract and test it in an isolated Shadow-only scene before changing the production renderer.

**Status:** Phase 0 audit complete. Phase 1 started with source inspection; production atlas is blocked pending clean frame extraction/approval. No game runtime files changed and no tests/builds were run during this source inspection.

## Shadow 8×4 extraction package prepared (2026-11-21)

A local processing package was prepared from the user's exact uploaded `1000241306.png`; no assistant-generated or web-sourced character art was used.

- Combined sheet: 768×1536 PNG, RGBA, 8 rows × 4 columns, 192×192 cells.
- Alpha channel verified programmatically: range 0–255 (transparent and opaque pixels present).
- Each cell has a non-empty alpha bounding box and shares the 192×192 frame/pivot convention.
- Direction order follows the supplied sheet: front, front-right, right, back-right, back, back-left, left, front-left.
- Eight direction-specific 4-frame atlas PNG/JSON pairs were generated in the local delivery package, with proposed mapping `s,se,e,ne,n,nw,w,sw` and 120 ms/frame.
- The generated package is delivered separately as `ArcherFM_Shadow_2D5_walk_assets.zip`.

**Not integrated / not tested in game:** this chat's GitHub connector can create text blobs/files but does not provide a path to upload the generated local PNG binary bytes to the repository. Therefore the generated PNG atlases are not present in the branch, the manifest was not switched, the Shadow GLB path was not disabled, and no app build/emulator test was run. Do not claim this phase is complete. The extracted source is compressed and some cells may retain faint baked shadow/edge artifacts; user visual approval is still required before runtime use.

Next step: import the ZIP's eight PNG atlas files and JSON metadata into `assets/heroes/shadow/renders/atlases/`, merge only the eight walk clip entries from `shadow_walk_manifest_patch.json` into `shadow_manifest.json`, then disable the Shadow GLB override and run Flutter tests/build/capture on the same commit. Verify the direction mapping against `GameWorld.octantNames` before accepting it.

## Shadow pilot code integration — 2026-11-21

Committed `lib/game/game_screen.dart` change at commit `1b1c496f41c198ab99b615ecca8b08992ef20fee`:
- When the selected hero ID is `shadow` and no test-injected GLB controller/bytes are supplied, `_loadHero3D()` returns without loading the GLB.
- This leaves the existing manifest-driven sprite path active for Shadow in the production game screen.
- Test injection behavior and the other three heroes' GLB loading paths are unchanged.
- This is a reversible pilot switch, not deletion of GLB files.

**Important distinction:** this code currently selects the existing repository Shadow sprite atlas/manifest (including the existing 9-frame walk clips), not the newly cleaned 4-frame-per-direction pack in the local ZIP. The cleaned PNG atlas pack has not yet been uploaded to the repository, so it is not yet bundled into the app.

**Verification status:** code change committed; current branch HEAD checked. No CI run was triggered for this commit and no emulator/device run was performed. Therefore in-game appearance, actual runtime animation, and build success are still unverified. Do not treat the pilot as accepted until fresh captures and tests exist.

## Follow-up inspection — current Shadow runtime atlas and CI (2026-11-21)

A direct visual fetch of the committed production atlas `assets/heroes/shadow/renders/atlases/walk_s.png` shows that it does **not** match the user's approved Shadow reference: the character has a bare head/short hair rather than the purple hooded silhouette and does not preserve the reference identity. This atlas must not be shown as the final Shadow art and must not be used as the basis for the remaining heroes.

The current `lib/game/game_screen.dart` already contains a Shadow-only early return in `_loadHero3D()`, so a normal Shadow match bypasses GLB loading and falls back to the sprite renderer. Because the currently committed sprite atlas is visually incorrect, this means the branch's current Shadow pilot path is not ready for user approval. Do not mark it complete.

The newly extracted user-reference-based 8×4 source and eight direction atlases are available in the working session at `/mnt/data/shadow_2d5_assets/` and `/mnt/data/shadow_unpacked/shadow_2d5_assets/`, but the active GitHub connector in this session exposes text-file writes and Git blob/tree primitives without a supported local-file/binary upload bridge. I therefore did not replace the committed PNG atlases, alter the runtime manifest to point at uncommitted files, or claim an in-game result. This is an integration blocker, not an OpenCode requirement.

Latest workflow inspected: `44831375138`, commit `1b1c496f41c198ab99b615ecca8b08992ef20fee`:
- Flutter Analyze: passed.
- Full Flutter test suite: passed.
- Release APK build and APK verification: passed.
- Android emulator smoke test: failed at `integration_test/app_smoke_test.dart:61` because the expected `home_3d_loaded` widget key was not found after opening army selection. This is not a Shadow sprite rendering test and does not validate the new extracted atlas.

**Current truthful status:** extraction package exists and has genuine alpha; the new atlas is not committed to the repository; production manifest/runtime still uses the old incorrect Shadow atlas; no in-game validation of the new 8×4 frames has occurred.
