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
