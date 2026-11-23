# Archer FM — 2.5D Sprite Character + Lightweight 3D World Conversion Plan

**Status:** Approved direction  
**Decision date:** 2026-11-21  
**Repository:** `fadimatar112211-bit/Archer-fm`  
**Working branch:** `ranger-reference-work`

## 0.1 User's mandatory reference-only rule (added 2026-11-21)

The user explicitly requires that production visuals must come only from their uploaded/approved reference images. This is a hard constraint, not a preference:
- Never insert assistant-generated, AI-generated, web-sourced, stock, generic, or invented pictures for any hero, monster, or the final gameplay reference.
- Hero appearance must be checked against `assets/references/approved_all/hero_roster_concept.jpg` (current Git blob SHA: `b4283a86b3f1727aa6c59966a3ce8479d32d735f`).
- Monster appearance must be checked against `assets/references/approved_all/archer_fm_monsters_reference.png` (current Git blob SHA: `2d1b350617f71c00fb3986ae986cabbe53df00da`).
- Final in-match composition/camera/HUD must be checked against `assets/references/approved_all/file_000000005c8c81f9ab4ccbb80ea59d5e.png` (see `docs/references/USER_APPROVED_VISUAL_REFERENCES.md`).
- Shadow's user-supplied eight-direction/four-frame walk sheet `1000241306.png` is an animation-layout/source reference. Preserve the source; derive clean frame assets only by editing/cropping that supplied image. Do not replace its character art with newly generated art.
- If an exact reference is unavailable, ambiguous, or conflicts with another approved reference, stop and ask the user. Do not improvise.
- Reference image files are immutable. Never overwrite, crop, recolor, compress, or otherwise alter the original reference files in the repository.

## 0.2 Phase 0 repository audit — 2026-11-21

Audited branch `ranger-reference-work`, HEAD `8170774995824e9335e124e716f866d2563ef5c1`.

Verified:
- The project already has a sprite-atlas runtime: `lib/hero/hero_assets.dart`, `lib/hero/hero_manifest.dart`, `lib/hero/sprite_player.dart`.
- The arena's current production renderer is `lib/game/arena_painter.dart` using Flutter Canvas and `ArenaWorldProjection`; it is not currently a real 3D scene/renderer.
- `lib/game/game_screen.dart` calls `_loadHero3D()` during initialization. When a GLB loads, `ArenaPresentation.hero3d` selects the 3D hero painter instead of the atlas sprite. Therefore the 2D sprite path exists but is currently overridden for heroes when GLB loading succeeds.
- `pubspec.yaml` declares sprite manifests/atlases and all four GLB models.
- The sprite directories contain existing atlases for Ranger (legacy), Ranger New, Flame, Shadow and Storm. Tree audit counted 64 atlas PNGs for each of the four current roster IDs (ranger_new, flame, shadow, storm); this is asset presence only, not proof of visual approval.
- Shadow's current manifest has 64 directional clips across eight directions and eight states. Its `walk_s` clip has 9 frames at 83 ms; the user-supplied `1000241306.png` sheet depicts 4 frames per direction. These are different asset sources/animation specifications and must not be silently conflated.
- No `assets/monsters/` production image assets were found in the current tree query. The approved monster reference exists under `assets/references/approved_all/`.
- Existing tests include `hero_manifest_test.dart`, `sprite_player_test.dart`, `all_hero_render_manifest_test.dart`, `arena_projection_test.dart`, and capture tests. No tests were run as part of this read-only audit.

Important implications:
1. Do not assume existing atlases visually match the approved roster sheet; inspect actual frames and compare before enabling them in production.
2. First make the approved user-supplied Shadow walk sheet the explicit Phase 1 input and verify its true alpha/cell extraction without changing the original.
3. Add a controlled sprite-only in-game path (or equivalent test mode) after inspecting all GLB override call sites; preserve GLB source files and diagnostic viewer until the four sprite replacements are approved.
4. The 3D-world requirement is a separate renderer migration. The existing Canvas projection is 2D; do not label it "3D". Prototype the lightest real 3D-world integration while preserving world coordinates, camera/touch mapping, depth order, and game rules.
5. The final gameplay reference and hero/monster appearance references are separate authorities; never use one to invent or override another.

## 0.3 User clarification — no hero may remain a final live GLB character

The final deliverable is **all four heroes (Ranger, Flame, Shadow and Storm) as 2D/2.5D sprite actors**, not a mixed roster of sprite and live-GLB characters. The same reference-only rule applies to all four monster roles. Existing GLB and Blender files may be used as retained source/rig/animation inputs for sprite rendering and diagnostics; they are not the final in-match hero presentation.

During migration, keep the last safe runtime route for each hero until its replacement 2.5D pack passes acceptance. This temporary fallback must never be mistaken for the final art direction. In particular, do not enable the rejected Flame simplification or Storm blue placeholder atlas.

Map/environment production may proceed in parallel, but the character-art sequence is strict: **finish and visually accept all four heroes first; only then begin production replacement work for the four monsters.** The arena pass covers terrain/biomes, river and bridges, paths, trees/rocks, mines, castles/walls/crystals, resource pickups, depth/occlusion, and the 16:9 camera composition. Preserve map generation, collision, economy, combat and touch transforms unless a separate test-backed change is approved.

## 1. Final approved direction

- **Heroes:** 2D sprite characters with a polished 2.5D appearance: dimensional painted forms, readable faces, layered clothing, controlled highlights, contact shadows and signature VFX.
- **Monsters:** 2D sprite characters using the same 2.5D visual language.
- **World:** a lightweight 3D arena/environment. Characters are rendered as camera-facing sprite/billboard actors positioned in the 3D world.
- **Do not rebuild gameplay.** This is a rendering/assets migration. Preserve match rules, player controls, hitboxes unless visual alignment requires a verified offset, combat balance, XP, progression, weapons, abilities, crystals, mines, economy, multiplayer and Arabic-first UI.
- Approved character reference images remain the source of truth. Do not redraw, replace or silently reinterpret the approved designs.

## 2. Current repository starting point

The current project is a Flutter game with a custom-painted 960×540 logical arena/camera path, existing hero render/atlas directories and production GLB assets. The `pubspec.yaml` currently declares both atlas/render assets and all four GLB hero files. The current visual-direction document also contains older full-3D hero requirements; this decision explicitly supersedes those conflicting hero-rendering requirements.

Before implementation, inspect the exact renderer, coordinate transforms, actor state, animation state machine, asset manifests and tests at the current branch HEAD. Do not assume a 3D engine is already integrated. Select the lightest renderer architecture that genuinely supports the approved lightweight 3D world and reliable sprite billboards. Avoid adding a large engine/dependency solely to play sprite sheets.

## 3. Asset and animation standard

### 3.1 Character identity
Each hero must retain the approved reference's:
- face, eyes, hair/hood silhouette and expression;
- costume layers, armor shapes, signature colors and trim;
- exact signature weapon identity and readable hand/weapon placement;
- compact chibi proportions and recognizable silhouette.

The same identity must hold across all eight facings and every animation. No frame may randomly change costume, face, weapon, proportions, scale or palette.

### 3.2 Directions
Use eight consistent directions, in one documented coordinate convention:
- front, front-right, right, back-right,
- back, back-left, left, front-left.

The angle labels (0°, 45°, … 315°) must be mapped to the game's actual world axes after inspecting the existing camera/world transform. Do not assume that image-row order and game-angle order are identical. Document the mapping in each manifest and test it with movement in all eight directions.

### 3.3 Sprite sheets and atlases
- Source sheets use a regular grid with transparent PNG alpha, not a checkerboard painted into the image.
- The first walking prototype is **8 rows × 4 columns = 32 frames** for Shadow.
- All cells have identical dimensions, consistent character scale, consistent ground pivot/feet baseline and safe padding.
- Remove labels, captions, direction badges, guide text, borders and background shadows baked into the source art. Runtime shadows are rendered separately.
- Export lossless source PNGs, then pack runtime atlases using the project's chosen packing format.
- Use manifests containing frame rectangles, frame duration, direction mapping, pivot/origin, animation name and loop behavior.
- Keep source renders outside the runtime asset bundle where practical; bundle only optimized runtime atlases/manifests.
- Split atlases by character and animation (or use measured page sizes) to avoid oversized GPU textures and excessive memory. Confirm maximum texture dimensions on target Android devices.
- Use true RGBA transparency and verify alpha-channel values programmatically. Never claim transparency based only on a checkerboard preview.

### 3.4 Required animation set
For each hero, produce and validate:
- idle (8 directions);
- walk (8 directions);
- run (8 directions);
- basic attack / weapon attack (8 directions where visually necessary);
- five-hit combo (five distinct attack steps; combo remains separate from Ultimates);
- hit reaction;
- death;
- four hero-specific Ultimate abilities, unlocked at levels 1 / 10 / 20 / 30.
- Each of the four Ultimate abilities must have its own identifiable animation/event sequence per hero; a single generic `skill` clip or VFX recolor is not sufficient to claim all four are complete. Keep the Ultimate names, unlock levels and gameplay effects bound to the hero kit contract.

Dodge is not a gameplay action in the current documented combat rules; do not reintroduce a dodge control or gameplay ability during this art conversion. Only create a dodge animation if a separately approved gameplay change requires it.

For monsters, implement the direction and animation set appropriate to each of the four existing roles (runner, tank, stalker, ranged): idle, locomotion, attack, hit and death. Do not add new monster roles.

## 4. Runtime architecture

1. Keep gameplay simulation and rendering separate. The actor's world position, velocity, facing, health, team, level and combat state remain owned by the existing game model.
2. Add a sprite actor renderer that receives the actor state and chooses the correct animation, direction and frame.
3. Determine facing from world-space movement/aim direction, then map it through the documented camera orientation. When stationary, preserve the last valid facing.
4. Advance animation using elapsed time, not frame count per render call, so animation speed is stable across frame rates.
5. Use a consistent feet/base pivot so sprites stand on the ground plane. Scale sprites against existing world units and actor collision radii; do not change gameplay hitboxes to compensate for artwork mistakes.
6. Render world/environment first, then depth-sort actors and relevant props by their ground position. Add contact shadows and team/selection rings as separate lightweight elements.
7. Use explicit occlusion rules for trees, walls and foreground props. A sprite must not appear to float above the ground or be incorrectly hidden behind distant objects.
8. Connect animation events to combat timing: attack wind-up, active/hit frame and recovery must match the existing simulation timing. Visual animation must not independently apply damage.
9. Keep effects separate from sprite frames where practical: dagger glow, arrows, lightning, fire, poison, impact flashes and ground telegraphs should be reusable runtime effects.
10. Preserve fallback rendering until each new sprite actor passes visual, functional and performance gates.

## 5. Lightweight 3D world

- Retain the existing world dimensions, camera/world transforms, touch-to-world mapping and minimap contract unless a measured defect requires a separately tested change.
- Use a low-cost stylized 3D environment for terrain, paths, water, bridges, walls, trees, rocks, castles, mines and crystal structures.
- Use restrained materials, lighting and shadows. Prioritize readable paths, objective silhouettes and unit contrast over decorative complexity.
- Sprite actors must face the camera consistently while their eight-direction artwork communicates world-facing orientation.
- Match the approved gameplay reference's landscape composition, elevated three-quarter camera, readable arena scale, crystal prominence and HUD hierarchy.
- Avoid expensive real-time shadows for every object; prefer baked/static or simplified contact shadows where appropriate.
- Profile the chosen 3D world renderer before committing to a dependency or migrating the entire scene. Record the decision and measured trade-offs.

## 6. Migration sequence and gates

### Phase 0 — Baseline and architecture audit
- Record branch HEAD, current test/analyze/build state and current visual captures.
- Trace the player/monster renderers, actor state machine, camera transforms, painter/layer order and asset manifests.
- Identify which existing atlas assets are usable and which are stale/incorrect.
- Prototype the lightest viable 3D-world + sprite-billboard integration without changing gameplay.
- **Gate:** a written renderer decision, baseline captures and reproducible tests.

### Phase 1 — Shadow walking proof
- Use the supplied Shadow directional walk sheet as the art target.
- Remove the Arabic label column and all non-character guides.
- Rebuild/clean the sheet into exactly 8 direction rows × 4 frame columns.
- Verify true alpha, uniform cell dimensions, consistent pivot, scale and character identity.
- Pack the atlas and manifest.
- Integrate Shadow into a test scene and move it through all eight world directions.
- **Gate:** no missing/duplicated direction, no wrong facing, no foot sliding beyond the accepted animation, no floating, no checkerboard pixels, no frame clipping, and no visible identity drift. Capture all eight directions.

### Phase 2 — Reusable sprite animation system
- Implement direction selection, frame timing, loop/one-shot behavior, animation transitions, last-facing preservation, pivoting, depth sorting and render scaling.
- Add deterministic tests for direction mapping and frame selection.
- Add capture tests for idle/walk and one-shot attack/death transitions.
- **Gate:** tests pass and the same renderer can load a second character without character-specific hardcoded logic.

### Phase 3 — Four hero conversion
- Produce final atlases/manifests for Ranger, Flame, Shadow and Storm.
- Preserve each hero's reference identity and signature weapon.
- Add idle, walk, run, attacks, hit, death and four Ultimates per hero.
- Integrate one hero at a time; compare close-up and normal gameplay zoom against the approved roster sheet.
- **Gate:** all four heroes pass visual review and animation/state tests before GLB runtime removal.

### Phase 4 — Four monster conversion
- Convert only the existing Runner, Tank, Stalker and Ranged roles.
- Ensure distinct silhouettes, sizes, facing, locomotion and attack readability.
- Validate group movement and large on-screen unit counts.
- **Gate:** monsters remain readable at gameplay scale and do not obscure heroes or objectives.

### Phase 5 — 3D world integration and visual polish
- Integrate the low-cost 3D terrain and props with sprite actors.
- Verify ground pivots, shadows, depth sorting, occlusion, water/bridge boundaries, crystal scale and minimap alignment.
- Unify lighting/color treatment, team rings, health bars and combat effects.
- **Gate:** a full-match capture resembles the approved gameplay reference in composition and clarity, with no visual floating or layer-order defects.

### Phase 6 — Performance, regression and release
- Profile representative low/mid-range Android hardware or a clearly documented equivalent.
- Measure frame time, memory, texture/atlas sizes, loading time and actor-count scaling.
- Run formatter, static analysis, unit/widget/integration tests, capture suite and release build on the exact same commit.
- Verify controls, touch mapping, hitboxes, combat timing, XP, mines, crystals, multiplayer and Arabic UI are unchanged.
- Review the final APK and fresh screenshots before marking conversion complete.
- **Gate:** no critical visual/gameplay regression and all agreed test/build checks pass.

### Phase 7 — Retire GLB runtime path (only after approval)
- Remove GLB files from runtime asset declarations and production loading paths only after all four sprite heroes pass.
- Keep GLB source files in a clearly marked archive/reference location or repository history; do not delete source art without explicit approval.
- Remove obsolete code only after tests prove no remaining runtime dependency.
- **Gate:** clean build, no missing asset references and verified fallback/rollback instructions.

## 7. Performance and quality requirements

- Prefer atlas batching and shared materials where supported.
- Avoid per-frame file decoding, allocation and image resizing.
- Cache decoded atlas pages and dispose them correctly when no longer used.
- Use texture sizes supported by target devices; split pages if required.
- Keep animation updates deterministic and independent of render FPS.
- Test a full battlefield with four heroes and a high but realistic number of monsters.
- Measure actual memory and frame-time impact; do not claim the sprite route is automatically faster without profiling.
- Ensure transparency edges do not show white/black halos.
- Ensure sprites are not blurred, stretched, cropped or scaled inconsistently.
- Ensure VFX do not obscure faces, weapons, health bars or objective feedback.

## 8. Gameplay invariants — must not change during conversion

- Four-player free-for-all match concept.
- Four existing playable heroes and four existing monster roles.
- Seven crystals per player and the approved crystal rules/HP.
- Eight neutral mines and existing resource collection/ownership rules.
- Starting army of twenty units and current purchasing/economy rules.
- Manual attack: one press equals one attack; holding must not auto-repeat.
- Five-hit combo remains separate from four Ultimates.
- Four Ultimates unlock at hero levels 1 / 10 / 20 / 30.
- Three weapons per hero, hero level cap 40 and existing XP/progression formulas.
- Existing equipment, save/progression and multiplayer rules.
- Arabic-first UI and no ads.

Any gameplay change must be separately proposed and approved; do not bundle it into a rendering migration.

## 9. Completion report format

For each phase, report:
- exact branch and commit SHA;
- files added/changed and asset dimensions/formats;
- which animations/directions were verified;
- visual capture references;
- tests/analyze/build commands and actual results;
- known limitations and unverified device-specific behavior.

A phase is not complete because an atlas exists or code compiles. It is complete only after its acceptance gate is demonstrated.

## 10. First implementation task

Start with **Phase 0 audit**, then **Phase 1 Shadow walk proof**. Do not start mass-generating all characters before the Shadow sheet, runtime mapping, transparency, pivot and eight-direction behavior have passed. Do not edit the approved reference images. Do not delete or disable the GLB renderer yet.
