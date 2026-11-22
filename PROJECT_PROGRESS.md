# Archer FM — Project Progress & Continuation Checkpoint

> This is the persistent hand-off document for every future work session. Read it before making changes. Update it after each meaningful batch, including commit SHA, CI result, files changed, evidence, blockers, and exact next steps.

## Project identity and working rules

- Active project: **Archer FM**.
- Repository: `fadimatar112211-bit/Archer-fm`.
- Current working branch: `ranger-reference-work`.
- Do not confuse this project with the legacy `Archero_fm` repository.
- Do not switch to or modify `main` unless explicitly requested.
- Current approved production direction (2026-11-21): **all four heroes and all four monster types must ship as reference-faithful 2D/2.5D sprite actors** in a lightweight 3D arena. This supersedes older full-3D hero-rendering notes below; GLB and Blender sources are retained as source/animation inputs for generating and validating the 2.5D sprite packs, not as the final in-match character renderer.
- Production character visuals may use only the user's approved reference/source images. Never invent, generate, or substitute character artwork.
- Migration status (not the target): Shadow is the only currently approved 2.5D production sprite route. Ranger, Flame and Storm still need reference-approved 2.5D packs; rejected placeholder atlases must remain disabled. Do not confuse this temporary migration state with the final all-four-hero 2.5D requirement.
- Never report an item as complete without file/build/test/visual evidence. Distinguish automated render coverage from actual visual quality review.
- Prefer large coherent implementation batches, then run the full relevant test/build workflow.
- Keep game UI Arabic-first.
- Do not delete legacy SVG/atlas assets unless a deliberate migration and fallback plan is tested.

## Last verified repository checkpoint

- Branch HEAD at checkpoint creation: `51d98aa83ac1feb6b0c1a2581fa44fd7b6b22b16`.
- Latest commit message: `Increase 3D hero on-screen prominence in arena`.
- Latest change: `lib/game/arena_painter.dart` increased the in-arena 3D hero target height from 92 to 112 logical pixels. This changes presentation size only; it does not change collision size or damage.
- GitHub Actions run for this commit: **44388255782**, workflow `Flutter Android Release APK`, completed with **success** after the checkpoint was drafted. The 112px presentation-size change passed that workflow.
- Previous CI run **44386356880**, commit `4c9cb2a9607416b69ac0a6e0aa12b4b1df45f15a`, completed successfully. Tests and capture-artifact upload succeeded. This is a prior commit, not the current HEAD.
- Visual capture artifact from run 44386356880: `archer-fm-3d-hero-visual-captures`, artifact ID `14466477157`. It contains arena renders for four heroes across eight directions plus Ranger arena states. Automated triangle-count checks prove geometry was drawn; they do **not** prove faces look good or match the reference. Inspect captures visually before making a quality claim.
- A previous verified APK belongs to commit `76d11b5d46fd03cc801a4bcf4e398a9095292457` (run `44385439264`), not the current HEAD. Do not present it as a build of current HEAD.

## Hero models and assets

The playable roster is four heroes:
- Ranger: `assets/heroes/ranger_new/ranger_animated.glb`
- Flame: `assets/heroes/flame/model/flame_animated.glb`
- Shadow: `assets/heroes/shadow/model/shadow_animated.glb`
- Storm: `assets/heroes/storm/model/storm_animated.glb`

Main appearance reference:
- `assets/heroes/reference/heroes_reference_sheet.jpg`

Related manifests:
- `assets/heroes/ranger_new/renders/ranger_new_manifest.json`
- `assets/heroes/flame/renders/flame_manifest.json`
- `assets/heroes/shadow/renders/shadow_manifest.json`
- `assets/heroes/storm/renders/storm_manifest.json`

The GLB runtime renderer/controller is in:
- `lib/game/render3/hero3d_painter.dart`
- `lib/game/render3/hero3d_controller.dart`
- arena integration: `lib/game/arena_painter.dart`
- game state / input: `lib/game/game_screen.dart`

The 3D render test is:
- `test/hero3d_game_capture_test.dart`

## Confirmed implementation already present

- Four playable heroes are registered in `lib/hero/hero_catalog.dart`; legacy Ranger access is retained for compatibility.
- GLB runtime path exists in the arena painter and the viewer can load 3D models without requiring a directional atlas manifest.
- The controller maps gameplay clip states to GLB animation clips and can fire manifest-timed animation events.
- The four models are tested for skeleton joints and clips including idle, walk, run, attack, skill, hit, and death.
- A capture test renders all four heroes in eight gameplay directions.
- The 3D capture artifact is uploaded by `.github/workflows/flutter-android.yml`.
- Hero kit data includes a five-hit manual combo with multipliers 100%, 110%, 120%, 135%, and 155%.
- Each hero has four separate ability/Ultimate definitions, unlocked at levels 1, 10, 20, and 30. These are separate from the five-hit combo.
- Four named ability sets are currently defined in `lib/game/combat/hero_kit.dart`:
  - Ranger: Multi Shot, Piercing Shot, Arrow Rain, Gale Surge.
  - Flame: Flame Slash, Fire Wave, Hell Burst, Inferno Rage.
  - Shadow: Twin Fangs, Shadow Veil, Venom Coat, Shadow Execute.
  - Storm: Thunder Thrust, Chain Lightning, Static Field, Tempest Rage.
- Three weapon definitions per hero are in `lib/game/combat/hero_weapons.dart`.

**Important:** Definitions and UI buttons do not by themselves prove that each ability has a unique, polished gameplay effect. Trace each ability through world/combat state, projectile/AoE logic, hit detection, animation events, and visual/audio effects; add functional tests for each hero's four abilities.

## Visual quality target and open work

The game should approach Archero's visual readability and feel, not merely contain 3D files. Continue with this priority order:

1. **Inspect actual captures:** examine front/three-quarter/back views for all four heroes. Compare face, eyes, head/body proportions, armor/clothing colors, silhouette, and weapon visibility against `heroes_reference_sheet.jpg`. Record concrete defects per hero. Do not claim exact likeness based on geometry tests.
2. **Fix face readability:** ensure eyes, face shape, hair/hood, and expression remain visible at the in-game camera distance and all relevant directions. Check material/texture quality, lighting, camera angle, and head orientation. If the source GLB itself is wrong, fix the source/model pipeline rather than hiding it with code.
3. **Animation quality:** inspect idle, walk/run, attack, skill, hit, death, and dodge where available. Verify feet contact the ground, no sliding/floating, weapon follows hands, no mesh clipping, and animation transitions are smooth.
4. **Attack readability:** every manual tap must produce one hit/attack action according to the combat rules. Confirm weapon swing/projectile launch, hit timing, impact reaction, damage feedback, and visible FX.
5. **Ultimates:** test all 16 abilities individually (4 heroes × 4 abilities), their unlock levels (1/10/20/30), energy/cooldown rules, target selection, damage/effects, and UI feedback. Preserve separation from the five-hit combo.
6. **Camera and scale:** confirm the new 112px target height is visually better without clipping HUD, obscuring enemies, or hurting performance. Check all eight directions and multiple screen aspect ratios.
7. **Performance:** profile/benchmark CPU skinning and draw cost on Android-class hardware; check frame pacing and memory with four hero models/assets loaded as needed.
8. **Full game validation:** run Flutter analyze, all tests, Android release build, APK verification, artifact upload, and inspect the generated APK from the same HEAD.

## Gameplay and design requirements to preserve

- Landscape mobile arena.
- Arabic-first game UI.
- Manual attacks (one tap = one attack); no automatic firing.
- Five-hit combo remains distinct from four Ultimate abilities.
- Hero level cap: 40.
- Three unique weapons per hero.
- Ultimate unlock levels: 1 / 10 / 20 / 30.
- At equal level, hero health should be equal; movement speed and abilities can differ.
- Multiplayer concept: up to four players, seven crystals per player, four monster types, pre-match unit selection and in-match purchases. Treat networking/match balance as separate work and do not claim online multiplayer is complete without end-to-end evidence.
- No ads.

## Next actions for the next session

1. Read this file and inspect current branch HEAD before touching code.
2. Check run 44388255782 to completion; inspect failed job logs if it failed.
3. Download and visually inspect artifact 14466477157; create a per-hero defect list, especially faces and weapon visibility.
4. Check whether the new 112px hero scale is better; add/update capture tests for the current commit.
5. Trace all 16 Ultimate implementations end-to-end and add tests for missing effects/edge cases.
6. Make the next focused fixes on `ranger-reference-work`, run CI, and update this checkpoint with the new HEAD and evidence.

## 2026-11-21 — All-four-hero 2.5D direction reaffirmed; arena environment pass started

- User explicitly reconfirmed that **all four heroes must be 2.5D**, alongside the four monster types; no hero is to be forgotten or left as a final live GLB character.
- Updated the project direction above: GLB/Blender sources are retained as source inputs and diagnostics; the final in-match actors are reference-faithful 2.5D sprite actors.
- Began a parallel map/environment visual pass in `lib/game/arena_painter.dart`:
  - Added stable, deterministic, camera-culled grass clusters with subtle biome tinting.
  - Grass details skip water, obstacle collision areas, mine clearings and castle clearings; no movement, collision, economy or map generation values were changed.
  - Added bridge timber variation, nail heads and cross-beams; added secondary stone facets/highlights without changing rock collision.
- Commits: `11fea5a` (terrain detail), `28d06f1` (bridge/rock detail), `0bf6e97` (integer grid index correction).
- These are code changes, not yet visually approved. Run Flutter analyze/tests and capture the 16:9 arena before claiming the map pass complete.
- Hero and monster sprite migration remains open. Do not enable rejected atlases; next asset batch must produce/review the 2.5D packs for Ranger, Flame, Shadow and Storm, then wire all four through the same sprite runtime.
- Keep map/environment work moving in parallel: terrain, river/bridges, castle/crystal structures, mines, walls, trees, rocks and minimap composition should be reviewed against the user's gameplay reference without changing game rules.

### 2026-11-21 — Continued four-hero 2.5D and arena environment batch

- Reaffirmed the final requirement in code comments and project documentation: Ranger, Flame, Shadow and Storm all end on reference-approved 2.5D sprite actors. Shadow is only the current approved migration pilot; GLB rendering for the others is transitional, not the final target.
- Expanded the arena painter with deterministic camera-culled ground grass, biome-tinted foliage detail, decorative stone approaches from castle clearings toward river bridges, richer bridge timber/nail/cross-beam details, and additional rock facets.
- All environment additions are presentation-only. No collision radii, map generation, river movement, mine production, castle/crystal HP, economy or touch transforms were changed.
- Commits: `11fea5a` grass detail; `28d06f1` bridge and rock detailing; `0bf6e97` integer index safety; `3ffb801` castle-to-bridge stone approaches; `394d9cd` progress/direction update; `99b8999` 2.5D plan clarification; `9c64c6a` render-policy comments; `cd5bc78` GameScreen migration comments.
- Validation is not yet green. The Android workflow runs are being cancelled when newer commits supersede them; the latest queued run must be allowed to finish. The legacy Ranger asset workflow continues to report failure with no job records exposed by the current Actions response, so its exact failure step is not yet verified.
- No hero atlas was promoted and no monster prototype was wired into production. Next: finish the four-hero source-to-2.5D atlas pipeline, visually inspect every hero's face/weapon/directions and monster role sheets, then switch all four heroes together only after acceptance. Continue the arena pass against the approved gameplay screenshot and capture a full 16:9 view.

## Session log

### 2026-11-18
- Confirmed branch HEAD before checkpoint: `51d98aa83ac1feb6b0c1a2581fa44fd7b6b22b16`.
- Increased in-arena 3D hero render target height from 92 to 112 in `lib/game/arena_painter.dart`.
- Triggered Actions run `44388255782`; pending at checkpoint time.
- Prior successful all-four-hero eight-direction capture run: `44386356880` at commit `4c9cb2a9607416b69ac0a6e0aa12b4b1df45f15a`.
- The 112px hero-size change passed Actions run 44388255782.
- Face-quality visual review and full ability-effects validation remain open.
- Checkpoint file created in commit `37683674ee0b241569578d98cfe8f598abc94459`.


### 2026-11-18 — Ultimate ability capture coverage expansion
- Current branch before this batch: `a554ec9ee5353791d6c6c13bb1fe044f5d722c1e`.
- Extended `test/special_abilities_capture_test.dart` to capture the previously missing seven abilities: Ranger Multi Shot and Arrow Rain; Flame Flame Slash, Fire Wave, and Hell Burst; Shadow Shadow Veil and Shadow Execute.
- Existing cases remain for the other nine abilities. The test now has explicit real-GameWorld arena capture scenarios for all 16 hero abilities (4 heroes × 4 abilities), with damage-state assertions.
- New code commit: `50793bc0330b23089b5f4f91441a231ae7c1931a`.
- GitHub Actions run `44389706091` was observed **in progress** immediately after push; do not treat the new coverage as passed until this run completes successfully.
- This expands test/capture coverage; it does not by itself prove final visual polish or real-device performance.
- Next: inspect run `44389706091`, fix any failures, inspect the new 16-ability capture artifact, then continue with face/animation visual review and targeted gameplay fixes.


### 2026-11-18 — Ultimate capture review and progression contract tests
- Inspected Actions run `44389706091`: Flutter Analyze **passed**, all tests **passed**, and 3D/Ultimate capture artifact upload **passed**. Android Release APK build was still running at last check; Verify APK and publish steps had not run yet.
- Downloaded capture artifact `14466379982` (6,026,454 bytes), containing the newly added Ultimate captures plus existing hero, map, monster, and arena captures.
- Visually inspected the Ultimate contact sheet and Ranger Multi Shot capture. The captures prove a real in-game scene was rendered, but the 800×450 arena view shows the hero and ability details quite small; the images do not yet prove polished, clearly readable signature effects. Do not mark visual polish complete.
- Added `test/ultimate_kit_contract_test.dart` to verify all four kits expose exactly four distinct named Arabic Ultimates at unlock levels 1/10/20/30, and that the five-hit combo remains an independent five-step chain.
- New test commit: `a45d222e4b8e534d85092fbf656c2c40c4823e8e`.
- The new contract test has been pushed after run `44389706091`; it still needs its own Actions run to pass.
- Next: verify the prior APK workflow result, then verify the new contract-test run; improve visual readability/signature FX and inspect hero face captures against the reference sheet.


### 2026-11-18 — First arena visual polish pass
- Confirmed run `44390536499` on code commit `a45d222e4b8e534d85092fbf656c2c40c4823e8e` completed successfully: Analyze, all tests, 3D/Ultimate capture upload, Android Release APK build, APK signature verification, APK artifact upload, and GitHub Release publish all passed.
- Verified APK artifact: `archer-fm-release-apk`, ID `14468161803`, approx. 100.3 MB. This APK belongs to commit `a45d222...`; it does **not** include the visual changes in this section.
- Verified capture artifact for the same tested commit: `archer-fm-3d-hero-visual-captures`, ID `14467661313`.
- Visual code change pushed to `ranger-reference-work`: commit `ef21d205d36b2ca187b3a73886fece2d49bfcaa8`, file `lib/game/arena_painter.dart`.
- Changes: layered glow/edge/core rendering for slash arcs, burst rings and lightning; brighter multi-layer projectile trails/cores; subtle team-accent ground halo beneath the 3D hero; increased 3D in-arena hero target height from 112px to 120px.
- These are code-level visual improvements only. They still require the new commit's CI, fresh captures, and visual review on different screen sizes before being accepted as final.
- Next: verify Actions for `ef21d205...`; inspect fresh captures and tune the hero framing/face readability. Then address terrain depth, monster silhouettes/animation, HUD readability, and each Ultimate's signature VFX separately.


### 2026-11-18 — Camera, controls and latest visual build verification
- Re-checked branch `ranger-reference-work`: current HEAD is `b471aabf8db21fa7c9ba1a1418783fa80041c17f` (`Record arena visual polish checkpoint`). This is a progress-document commit whose parent is the tested code commit `ef21d205d36b2ca187b3a73886fece2d49bfcaa8`.
- Verified Actions run `44391677916` for code commit `ef21d205...` completed successfully: Flutter setup/dependencies, Analyze, all tests, 3D/Ultimate capture upload, Android Release APK build, APK verification, artifact upload, and GitHub Release publish all passed.
- Fresh capture artifact: `archer-fm-3d-hero-visual-captures`, ID `14469790781`. Fresh APK artifact: `archer-fm-release-apk`, ID `14468782622` (about 100.27 MB). Both are from the tested `ef21d205...` code commit, not the later documentation-only HEAD.
- Inspected fresh arena captures. The 3D hero is clearly visible in the battle scene and the 120px render-target change is present; the captures still need detailed per-hero face/reference comparison and mobile-device review. Do not infer final visual quality from CI alone.
- Re-verified the intended Archero-style controls in `lib/game/game_screen.dart`: left/right-configurable joystick forwards pointer movement to `world.setMoveInput` and resets on pointer-up/cancel; attack is triggered on `onPointerDown` only; the fixed-step loop explicitly documents no held-button auto-repeat. This matches the requested one-tap/one-attack behavior in code. It still needs real-device touch testing for feel and accidental multi-touch edge cases.
- Camera follows the player through the smoothed `world.cameraOrigin` and the painter uses that same origin for rendering; arena taps are converted through the camera origin so touch coordinates remain aligned.
- No gameplay/control redesign was made. Preserve the Archero-like camera, joystick and manual attack model.
- Next implementation batch: inspect the full fresh captures hero-by-hero against `heroes_reference_sheet.jpg`; check 3D face/weapon readability and animation direction; add/verify explicit touch interaction tests (one pointer-down = one attack, held pointer does not repeat, joystick cancel resets movement); then make targeted visual/control refinements and run the full workflow again.


### 2026-11-18 — Manual combat and joystick interaction regression coverage
- Added a stable widget key to the joystick touch zone without changing its layout or control behavior.
- Added widget regression test: holding the attack control for 1.4 seconds must register exactly one combo hit; this guards against held-button auto-repeat.
- Added widget regression test: dragging the joystick moves the hero, and pointer cancellation clears the movement vector and stops continued movement.
- Changes pushed to `ranger-reference-work`: game-screen hook commit `281212be42716dfb9f0cadc57be885fe853c4788`; tests commit `a29e507a554688a892add5cb5ef756e3d43826b0`.
- Tests are committed but not yet verified by Actions at the time of this note. Do not call them passing until the workflow run for the latest HEAD completes.
- This batch intentionally preserves the Archero-style camera, left joystick, tap-to-attack control, four separate Ultimate buttons, and five-hit combo.
- Next: inspect the new Actions run and fix any test/build failure. Then improve hero face/readability only after inspecting close-up reference captures for all four heroes; current wide arena captures are too small to judge face fidelity.


### 2026-11-18 — New whole-game visual direction approved and documented

- User-approved direction: bring the **entire game presentation** (heroes, monsters, attacks, abilities, terrain and camera) toward a polished League of Legends-inspired elevated/isometric 3D look, while retaining Archer FM's simple Archero-like mobile action controls.
- Added `VISUAL_DIRECTION_PLAN.md` in commit `ee2cca0215f8aa7c77a3b2c6c00d3eea5dddcc6a`.
- The plan explicitly preserves landscape play, left joystick, manual one-press/one-attack behavior, dodge, five-hit combo, four separate Ultimates at levels 1/10/20/30, current hero/monster roles, match rules, Arabic-first HUD and the existing asset fallback strategy.
- The plan calls for an evidence-first staged upgrade: baseline capture audit; camera/composition; hero readability; monster presentation migration; combat/VFX; arena/environment; HUD; Android performance and same-commit release validation.
- Architecture fact checked from current source: the arena is a Flutter custom-painted 960×540 logical view with smoothed camera origin; heroes have a GLB render path, while monster presentation is still driven by the arena painter/procedural animation path. Monster roles are defined in `lib/game/monsters/monster_models.dart`. Therefore, a whole-scene 3D look requires staged monster/environment work; it is not already present.
- Latest branch HEAD before this plan: `489a01dd9eff25302e3b44412491d457127fea37`.
- Verified Actions run `44393936891` for code commit `a29e507a554688a892add5cb5ef756e3d43826b0`: **success**. Analyze, all tests, 3D capture upload, Android release APK build, APK verification, artifact upload and GitHub Release all completed successfully.
- Artifacts from that tested code commit: capture artifact `14469518505`; release APK artifact `14468594555` (~100.27 MB). These artifacts predate the new plan commit and are not builds of the current documentation HEAD.
- Next implementation task: inspect the latest hero/monster/arena capture artifacts and relevant painter code; write a concrete visual defect audit, then implement the first camera/composition pass with capture and coordinate-regression tests. Do not start mass 3D asset replacement before auditing the current monster renderer and assets.


### 2026-11-18 — Approved crystal visual specification
- User clarified that castle crystals must be large, tall, elongated crystal pillars/spires, not small gemstones.
- Added this as an explicit visual requirement to `VISUAL_DIRECTION_PLAN.md`: prominent faceted vertical forms, visible base, controlled internal glow, player-color accents, readable HP bar, progressive crack/damage feedback, and a distinctive destruction effect.
- Preserve the existing seven crystals per player and their HP values (500/700/900/1200/1500/1800/2200), targeting and rebuild rules; this is a visual change only.
- Next: implement the large crystal presentation in the arena renderer, then capture and inspect at normal mobile gameplay zoom. Do not mark complete until visual evidence and tests pass.


### 2026-11-18 — Crystal visual specification
- Updated `VISUAL_DIRECTION_PLAN.md`: all seven crystals per player must be large, tall, prominent faceted crystal pillars/columns, not small stones. Added silhouette, base, glow/team color, health-bar readability, damage/cracking, destruction, and scale/readability requirements.
- Existing seven-crystal count, HP values, placement, targeting, rebuild and gameplay rules are explicitly preserved; this is a visual-only decision.
- Plan update commit: bbe054b71be16b983cc5e71cc562a896c0e891d2.


### 2026-11-18 — First in-game crystal visual implementation
- Replaced the former small diamond crystal drawing in `lib/game/arena_painter.dart` with a tall, faceted crystal monolith and a substantial pedestal.
- Added a pulsing owner-color energy bloom, brighter facet highlights, always-visible HP bars, and progressive crack details as HP falls.
- Kept the existing seven crystal slots, positions, HP values, damage rules, rebuild logic, and gameplay hit/collision radius unchanged.
- Commit: `c05605f62a7b387f390f98fc6e7a6a48b3afe65d`.
- Validation status: source change is pushed; Flutter analyze/tests and Android release build are pending the GitHub Actions run. Visual scale/readability still needs an in-game capture review at normal mobile zoom.


### 2026-11-19 — Shared camera transform and tap-coordinate regression fix
- Added `lib/game/arena_camera.dart` as the shared viewport transform for scale, letterbox offset, smoothed camera origin, screen-to-world and world-to-screen conversion.
- Updated `ArenaPainter.paint` and `arenaToWorld` to consume the same transform data. This removes the previous mismatch where painting used the smoothed `world.cameraOrigin` while taps used an instantaneous player-centered camera origin.
- Added `test/arena_camera_test.dart` for smoothed-camera alignment, round-trip conversion at four landscape phone aspect ratios, visible-world bounds, and integration through the arena tap helper.
- Commits: `46da550294f18cff170dad0739b77405ebcd7504`, `3faa207ad3af58cb5c4282d95eba98e870bf5a65`, `b7f599f64d7681168b2bc860b2c9ae58ecb07448`, `69b0a00a0a955b95fbf2f358f25eda99635fc474`, `a1ac049386a893cf602e7f6fcf58e53ad30bf2a8`, `61996ccb9dbbf31912b90967d31bd2fb15ad2fcb`.
- CI caught and led to a fix for missing `dart:ui` geometry imports in the new test. The latest Actions run for `61996ccb` has not yet reported a final result; do not mark analyze/tests/build as passing until it completes.
- No camera zoom, isometric projection, map layout, combat rules, or gameplay behavior was changed in this batch. Next: wait for the latest validation result; only after green validation proceed to the unified 2.5D/isometric projection prototype.

## Camera transform regression follow-up — 2026-11-19

- Verified branch head is still `163347fc166819ce131119eb30d64068e414242d`; no commits exist after this checkpoint.
- GitHub Actions run `44423019949` completed with failure: 313 tests passed and 2 camera mapping tests failed. Analyze passed; APK build and verification were skipped.
- Failure 1: `ArenaCameraTransform.visibleWorldRect` width comparison used exact floating-point equality (actual 960.0000000000001). Change the assertion to a tight tolerance.
- Failure 2: castle screen-mapping test assumed the camera was instantly centered on a manually repositioned hero. Change it to round-trip known world points through `ArenaCameraTransform.worldToLocal` and `arenaToWorld`, preserving the smoothed camera behavior.
- Next: run the full Flutter test suite and Android release workflow; only then proceed to the shared isometric projection prototype.


### 2026-11-19 — Camera regression gate passed; unified projection scoped
- Branch checkpoint before this entry: `45d31a21994c237689e0288fc31c106aed5bd9fd`; camera test fixes were already present.
- Workflow run `44423577850` on commit `8ce14b2c89768fffb16f70b7ddbc929bf44ae21f`: Analyze **success**, all Flutter tests **success**, 3D hero capture upload **success**. Release APK build was still `in_progress` at last check; APK verification/artifact publication were pending. This is not an APK success claim.
- Earlier run `44423574351` failed on the preceding commit and is superseded by the later run's passing test result.
- Inspected current renderer: `ArenaCameraTransform` is top-down scale/letterbox/translation; `ArenaPainter` draws world content in 2D; `Hero3DModel` independently applies a 0.9-radian tilt and perspective. This confirms the main visual mismatch is a split camera/projection, not simply hero scale.
- Added `docs/implementation/UNIFIED_WORLD_CAMERA_PROTOTYPE.md` in commit `481f3468e0e0fff47e1e9f6a1275042919d00d83`. It defines a staged, testable shared ground-projection migration, preserves world simulation coordinates and gameplay rules, and sets visual/performance rollback gates.
- Next implementation gate: implement and test projection math + inverse input mapping first; then migrate ground, one monster, hero, and combat/objective passes in order. Do not generate all monster GLBs until one actor prototype proves projection, depth sorting, touch mapping and Android performance.

- Downloaded and visually inspected capture artifact `14482777856`. Gameplay captures show the 3D hero over a still-flat 2D arena; monsters are small relative to crystal objectives, and map/fog renders remain flat. These findings are recorded in `docs/implementation/UNIFIED_WORLD_CAMERA_PROTOTYPE.md`. This is automated-capture review, not device playtesting or a face-reference sign-off.
- Latest documentation-only commit: `2e0179140891f6cac16a78af083245dea13fd88b`.

### 2026-11-19 — First shared oblique camera integration
- Added `ArenaWorldProjection` and integrated its reversible ground transform into `ArenaCameraTransform`; pointer-to-world and world-to-screen now use the same centered projection.
- Enabled a conservative initial ground-depth compression of 0.82. The painter applies that projection to the world canvas, while hero, monsters, corpses and floating labels receive inverse local scaling so their bodies/text remain upright.
- Monster depth ordering now uses the projection's depth key (currently equivalent to map Y because yaw is 0). World simulation, collision, movement, combat ranges and stored map coordinates remain unchanged.
- Added camera tests for centered projection, depth compression, inverse pointer mapping and expanded visible-world bounds, plus standalone projection math tests.
- This is the first rendering prototype, not final MOBA camera approval. Need CI on the newest head, visual captures at narrow/16:9/wide landscape ratios, actor overlap/occlusion review, and Android performance measurement before increasing the angle or migrating more world systems.


### 2026-11-19 — Ten-step projection and GLB occlusion regression expansion

- Starting branch HEAD: `91721b4f1165fd4202613d95e5e7d95f4f437eb9`.
- Step 1: projection test verifies that a configured camera focus maps to projected origin for multiple focus points.
- Step 2: projection test verifies depth differences are invariant under translating both world points.
- Step 3: projection test verifies negative world height moves an elevated point downward by the expected scaled amount.
- Step 4: projection test verifies linear projected displacement under yaw, depth compression and uniform scale.
- Step 5: camera test verifies letterbox offsets and logical viewport dimensions across narrow and wide landscape sizes.
- Step 6: camera test verifies the logical arena center remains centered under a non-zero yaw projection.
- Step 7: camera test verifies yawed visible-world bounds contain all inverse-projected viewport corners.
- Step 8: production-path GLB capture adds a far-background tree case at 16:9.
- Step 9: production-path GLB capture adds a background rock case at narrow landscape size.
- Step 10: corrected stale prototype documentation that still claimed trees were single depth-sorted items; recorded the expanded test/capture coverage and remaining visual gates.
- Commits: `c18ae6d5` (projection tests), `6cd88102` (camera tests), `37e92e0f` (GLB captures), `03030d04` (prototype documentation).
- Validation: GitHub Actions runs were triggered for the code commits. They were not yet complete when this checkpoint was written; do not mark the new tests as passing until the newest run completes.
- Visual acceptance: not complete. New GLB captures must be reviewed from the workflow artifact. The terrain, rivers, bridges, projectiles, crystals, fog and all world objects still do not share a full yawed 3D projection.
- APK: no current-HEAD verified APK is claimed.
- Next: inspect latest Actions results and logs; fix any analyzer/test errors; download and review the newest GLB capture artifact; only then continue staged ground/monster projection work.


### 2026-11-19 — Fifteen-step camera/projection regression and CI failure correction batch

- Starting HEAD: `b4434b1c869892e31abee5eef0c388bddd078538`.
- Step 1: corrected the projection linearity test tolerance. CI had reported a 2.10e-8 floating-point difference against a 1e-8 tolerance; this was test precision, not a renderer runtime failure.
- Step 2: tested inverse mapping of projected origin to a non-zero focus, scale-independent depth keys, negative-yaw depth direction, height offset independence, and focus-translated visible bounds.
- Step 3: added dense-grid round-trip and deterministic projection checks.
- Step 4: added camera tests for ultrawide aspect ratios, yawed pointer conversion beyond map center, and immutable camera snapshots.
- Step 5: added viewport-edge round trips and relative world displacement checks.
- Step 6: added camera-right and camera-depth basis tests.
- Step 7: corrected the test's camera-depth basis vector to match the projection's documented yaw convention.
- Step 8: audited and documented actual painter pass order and remaining depth-order gaps: projectiles remain a later pass above actors; terrain/objectives are flat; yaw is not applied to the live whole scene.
- Step 9: locked the current live default camera contract: horizontal scale is unchanged and vertical ground depth is compressed by 0.82.
- Step 10: locked zero-yaw X-axis behavior.
- Step 11: locked zero-yaw Y-axis compression behavior.
- Step 12: tested projection-scale forward/inverse camera mapping and camera-follow response.
- Step 13: verified visible-world bounds shrink consistently with projection zoom.
- Step 14: tested camera input round trips at all map corners and far-edge coordinates.
- Step 15: recorded the batch, evidence, CI status and remaining renderer gates in this checkpoint.
- Main commits: `2f2cefdf` (tolerance fix), `f09b04bb`, `8053e965`, `734e68cc`, `81d49d5b`, `3005b38b`, `bcd3db10`, `a37440ca`, `2cc283b6`, `bf923a3f`, `deefb351`, `b49c9a26`, `c5d65230`, `1f00f566`.
- CI evidence: runs `44426601917`, `44426624520` and `44426641401` failed on the earlier too-tight floating-point assertion (329/330, 332/333 tests passed in those runs). The tolerance fix is on a later commit. Runs for subsequent commits were still in progress at checkpoint time; do not call the full suite green yet.
- Latest code HEAD before this checkpoint: `1f00f5663c2b544e988318342580a7f093256ff6`.
- APK: no current-HEAD verified APK is claimed.
- Visual acceptance: not complete. These are regression tests and source audit updates; no claim that live yaw or complete 3D world projection is implemented.
- Next: wait for the latest workflow run, inspect any new failures, and review the new Ranger GLB obstacle captures. Once the test gate is green, continue with a staged projectile/actor depth integration rather than enabling yaw across only part of the scene.


### 2026-11-19 — Twenty-step projection/camera hardening batch

- Steps 1–8: added projection edge regressions for constructor assertions, extreme-but-valid depth compression, projected radius, height/depth independence, and finite conservative viewport bounds.
- Steps 9–14: added camera viewport regressions for immutable snapshots, supported landscape scales, logical center, yawed viewport framing, repeated forward/inverse mapping, and letterboxed world-vs-HUD separation.
- Steps 15–20: documented projection coverage, camera viewport coverage, whole-scene migration blockers, projectile depth acceptance criteria, visual evidence checklist, and this progress checkpoint.
- Latest code HEAD before this checkpoint: `138710b7a2e46df44bfe167cb0fa099ad412f65e`; progress commit follows.
- No live renderer yaw was enabled. Projectiles remain a later pass and are not yet depth-interleaved with obstacles and actors.
- CI status must be checked on the newest runs; the earlier failures were from the previous batch and must not be described as fixed until the new full test job passes.
- No current-HEAD APK or visual acceptance is claimed.


### 2026-11-19 — Projectile shared-depth integration

- Added projectiles to the same depth-sorted entry queue as player, monsters, corpses, and split tree/rock obstacle layers, using the common camera projection depth key.
- Removed the old unconditional post-actor projectile draw pass to prevent duplicate drawing and the previous always-on-top behavior.
- Added a zero-velocity guard before normalizing projectile velocity.
- Added `test/arena_projectile_depth_test.dart` with moving and stationary projectile painter regressions.
- Implementation commit: `8dc8f4379061e80de0ef7d2565f1cc0007fe74e5`; duplicate-pass fix: `2a55ebca1f6fcd85924a14e5394a001a056364f7`; painter test commit: `8c339d1a4c9ecd0ef07a639fb9b0f4848f43e417`.
- Verification status: pending CI for the newest source/test commits. Do not treat the prior camera batch as fully verified until the workflow completes. No visual ordering acceptance or APK build is claimed.


### 2026-11-19 — Projectile regression expansion and verification audit

Twenty-five tracked work items in this continuation:
1. Inspected branch HEAD and prior Actions state before changing files.
2. Confirmed the previous camera batch has not reached final CI completion.
3. Added projectile entries to the shared actor/obstacle depth queue.
4. Used the common projection depth key for projectile anchors.
5. Kept each projectile's glow, edge, core, arrowhead and trail in one draw entry.
6. Removed the unconditional after-actors projectile pass.
7. Prevented duplicate projectile rendering.
8. Added a near-zero velocity guard before vector normalization.
9. Added a dedicated projectile depth painter test file.
10. Added moving-projectile rendering coverage.
11. Added zero-velocity rendering coverage.
12. Added multiple simultaneous projectile coverage.
13. Added left/up direction coverage.
14. Added high-velocity coverage.
15. Added simulation-position immutability coverage.
16. Added velocity immutability coverage.
17. Added no-enemy/no-army coverage.
18. Added projectile-with-obstacles/corpses coverage.
19. Added large-projectile styling coverage.
20. Added repeated-paint determinism/state-retention coverage.
21. Documented shared-depth integration and its known limitations.
22. Documented the ten painter regression scenarios and what they do not prove.
23. Checked latest branch HEAD after code/test changes.
24. Inspected Actions job steps for the new test-file run and the prior camera run.
25. Recorded the remaining CI, pixel-capture and APK acceptance gates.

Latest source/test HEAD at this checkpoint: `d9a3ec230b329335aab4e5a6ff54364451ce366e`. The dedicated test-file workflow (`44427793874`) was still in progress at Flutter setup when checked; the source change run (`44427737324`) had passed setup/dependencies and was running Analyze. The earlier camera run (`44427516363`) had Analyze success and was running all tests. These are intermediate statuses, not final pass results.

Known unresolved work: confirm all new tests and analysis pass; inspect actual projectile-vs-tree/actor capture pixels; add separate projectile visual-height/trail segmentation if needed; migrate ground/objective passes before enabling live yaw; visually validate all heroes against the reference; and verify a current-HEAD APK. No full-game completion is claimed.


### 2026-11-19 — Shared yaw projection and projectile elevation

- Fixed the analyzer blocker found in run `44427894937`: removed the now-unreferenced legacy `_paintProjectiles` helper. The earlier run failed Analyze on that warning; it did not reach tests or APK.
- Added a separate non-negative `ProjectileState.visualHeight` and `visualPosition`. Ground depth/collision still use `position`; rendering uses the lifted position.
- Added projectile tests for zero/default lift, positive lift, negative-height assertion, and stable ground anchor.
- Injected one `ArenaWorldProjection` into `ArenaPainter` and its `ArenaCameraTransform`.
- Applied world yaw rotation and depth compression to the entire world canvas in the same order as `projectGround`.
- Added inverse yaw/depth compensation around upright actors, tree layers and floating labels.
- Added a non-zero-yaw painter capture regression. Production default remains yaw zero until visual review.
- Latest source branch tip at this checkpoint is tracked by the later progress commit; Actions remain pending for the newest changes.


### 2026-11-19 — 30-step shared projection and projectile-height pass

1. Rechecked the current `ranger-reference-work` branch head before editing.
2. Rechecked the previous Actions runs instead of assuming the prior batch passed.
3. Retrieved the failed analyzer log and identified the exact unused-element warning.
4. Removed the obsolete `_paintProjectiles` compatibility method that had become unreferenced after shared-depth integration.
5. Added `ProjectileState.visualHeight` as an optional render-only height.
6. Added a non-negative assertion for projectile visual height.
7. Added `ProjectileState.visualPosition` to derive the elevated render coordinate.
8. Kept `ProjectileState.position` as the unchanged gameplay and depth-sort ground anchor.
9. Updated projectile painting to use `visualPosition`.
10. Kept projectile ordering keyed by the original ground `position`.
11. Added a regression for zero/default visual lift.
12. Added a regression for the exact upward visual offset.
13. Added a regression that negative lift is rejected.
14. Added a painter regression confirming a lifted projectile does not mutate its ground anchor.
15. Added an optional projection parameter to `ArenaPainter`.
16. Passed that exact projection instance into `ArenaCameraTransform`.
17. Changed the world canvas transform to apply yaw rotation before depth compression.
18. Kept the canvas transform order consistent with `ArenaWorldProjection.projectGround`.
19. Added inverse yaw compensation around upright actor anchors.
20. Kept inverse depth compression for upright actors.
21. Applied upright compensation to tree trunks.
22. Applied upright compensation to main tree canopies.
23. Applied upright compensation to upper canopy lobes.
24. Kept floating labels upright through the same actor compensation helper.
25. Kept terrain, mines, castles, pickups, zones, fog and effects inside the shared ground-plane transform.
26. Added a non-zero-yaw painter regression with a lifted projectile.
27. Centralized the default `ArenaWorldProjection` instance.
28. Updated `ArenaCameraTransform` to use the centralized default.
29. Updated `ArenaPainter` and painter tests to use the same centralized default.
30. Added a camera regression asserting the default projection instance and yaw/scale values.

Verification:
- Run `44427894937` failed Analyze because of the obsolete unused helper; tests and APK were skipped.
- After removing that helper, run `44428139297` reported Analyze **success**, all tests **success**, and hero visual-capture upload **success**; the APK build was still in progress when checked.
- The later visual-height and shared-yaw commits have their own Actions runs queued/in progress. They are not yet verified by a completed workflow.
- The latest camera/projection regression run `44428528101` was still at checkout when checked.
- The production default remains yaw zero. Non-zero yaw is now available through projection injection, but visual review of the resulting screenshots is still required before enabling it in the shipped game.
- Current-head APK verification is not yet established.

### 2026-11-19 — Castle and crystal depth-order integration

- Removed castle drawing from the terrain-only pass.
- Added each standing castle to the shared actor/obstacle depth queue using its world anchor.
- Kept the castle keep, walls, banners and all living crystal objectives together as one draw unit so their internal composition remains stable.
- Applied the upright-ground compensation at the castle anchor so tall crystal silhouettes do not inherit ground-plane depth compression.
- Preserved castle ownership colors, standing-state visibility, crystal HP bars, and all gameplay coordinates/state.
- This is a coarse castle-level depth unit: individual walls and crystals are not yet independently sorted against actors. Capture and review is still required.
- Code commit: `e4ba35b6ff83a1dac0d4e1d00d6feb41a70c2834`.
- The new commit's Analyze/tests/APK status must be read from its Actions run before claiming verification.

- Follow-up code commit: `7e9b26f375a82f1d0511e5c320bcf1d10f461758`.
- Split living crystals out of the castle draw closure and inserted each crystal into the shared depth queue using its own base position. This permits per-crystal foreground/background ordering while keeping the castle keep and wall composition stable.
- Crystal rendering still uses the existing owner tint, glow and HP bar painter; no gameplay or objective state was changed.

- Added a focused painter regression that keeps all 28 living crystal objectives in the world, damages them to exercise their HP-bar rendering path, and paints them through the shared actor queue.
- Test commit: `a4cd95350b65f40883702e3038a15bd1e07b3318`.
- The test is an automated render-path regression, not pixel-level proof that the GLB hero is visually occluded by each crystal.

### 2026-11-19 — Segmented castle occlusion follow-up

- Refactored castle rendering into courtyard, keep/banner, and independent wall-arc painters.
- Added each wall arc to the shared actor depth queue using the arc midpoint on its ground circle; its stone strokes and crenellations remain grouped.
- Kept each living crystal independently depth-sorted by its base.
- Added `test/arena_castle_depth_test.dart` for all four castles, 16 arcs, missing/single arcs, sweep extremes, fallen castles, destroyed crystals, repeated paints, state immutability, ownership and isolated castle rendering.
- Extended projection tests for curved wall midpoint anchors, opposite depth bands, and yaw/scale finite values.
- Extended real Ranger GLB capture test with south-wall, north-wall, and local-crystal overlap captures.
- Updated `UNIFIED_WORLD_CAMERA_PROTOTYPE.md` with the new painter order and explicit remaining limits.
- Code commits: `d61a5e04`, `3cac8ccd`, `4e447730`, `5e4feab2`, `56c6c385`.
- Visual captures and tests still require completed Actions and review; no claim of final visual acceptance is made.

### 2026-11-19 — Mine and pickup depth integration

- Continued from the user-confirmed base commit `19440a6c`, with all new work on `ranger-reference-work`.
- Removed mines from the terrain-only paint pass and added them to the shared ground-depth queue with the hero, monsters, trees, castles, crystals and projectiles.
- Extracted a dedicated mine painter while preserving neutral/local/rival tints, ore chunks, size pips and capture-progress arc.
- Moved mine-output resource piles and map chests into the same depth queue; map resource entries remain represented by the mine-controller pickup list to avoid duplicate rendering.
- Added `test/arena_mine_depth_test.dart` with coverage for mine ownership, size classes, capture fractions, empty collections, yaw, state immutability, chests and resource pickups.
- Extended real Ranger GLB captures with mine foreground/background, chest and resource-pile overlap cases.
- Updated `UNIFIED_WORLD_CAMERA_PROTOTYPE.md` with integration details and remaining limitations.
- Code commits: `33e98ff3`, `a1878564`, `151e263f`, `4cd749a2`, `95fba146`, `edbc159e`, `af2852cd`, `3ff0d27a`, `4cb43556`, `550b0497`.
- Previous workflow `44429243077` proved Analyze and 401 tests passed and uploaded 93 visual captures, but Release APK failed at Gradle dependency resolution for Kotlin 2.0.21 (repository resolution failure). This is distinct from a Dart compile/test failure.
- Current mine/pickup changes still require fresh Analyze/test/capture CI on the latest branch head; no APK claim is made.

- CI review exposed test-only analyzer errors in the new mine test file: missing direct imports for `MineSize`/`PickupKind` and an integer literal assigned to a double capture-progress field. Corrected both in `48d8817e`. The new HEAD's Analyze/test run is queued; the correction is not yet declared green.

- Follow-up Analyze on `48d8817e` isolated one remaining integer literal in the zero-progress mine test (the earlier type fix addressed a different line). Corrected zero and full-progress assignments to explicit doubles in `547e1aef`. Fresh Analyze/test confirmation is pending.

### 2026-11-19 — Stage one, first five terrain/projection tasks

- Verified the existing shared ground projection and added a painter/camera input projection identity regression.
- Added a yaw invariant linking projected ground Y to the same depth coordinate used by actor sorting.
- Corrected hero/monster ground contact shadow offsets.
- Added layered river-bank shading and flow-normal water shimmer for curved river segments.
- Added `test/arena_terrain_projection_test.dart` covering biome/river/bridge painting under oblique projections, geometry immutability, multiple yaw values and input mapping.
- Code commits: `03e59766`, `d6409b58`, `96e3f9c2`, `ef04401d`, `e1bd88a8`, `6d9fa931`.
- Production camera yaw remains zero pending visual review; no unsupported claim of final camera angle or bridge depth occlusion is made.
- CI for this batch is pending; the previous successful Analyze/tests run was `44430061513` on `547e1aef`, before this batch.

- Follow-up refinement for the first five tasks: tree and rock contact shadows are now drawn on the projected ground plane (not inside upright actor wrappers); biome patches use a softer three-stop radial fade; terrain regression tests include repeated projected obstacle/biome paints and verify map obstacle geometry is immutable. Latest code/test commit: `89277c60`. New CI is queued/running; not yet declared green.

### Stage one — second five tasks (6–10), 2026-11-19

- Bridge decks moved from the flat terrain pass into the shared actor depth queue; bridge deck now has contact shading, rails and plank details.
- Confirmed tree trunk/main canopy/upper lobe remain independent depth-sorted layers (tasks 7–8).
- Improved tree bark, root accent and canopy lighting (task 9).
- Improved rock ground edge, light facet and dark facet seam (task 10).
- Added regression coverage for bridge/tree/rock rendering at multiple projection yaws and verified map geometry remains unchanged.
- Code/test batch: `dd2cdfcb`, `a002cddf`, `910b2448`, `a6f4089f`.
- CI run for latest batch is queued/running. First batch's final Analyze, all tests and 3D capture stages passed on `89277c60`; APK build remained in progress at last check.
- Stage-one plan progress: first 10 of 30 tasks addressed; task 11 (hero overlap from multiple directions) remains in the next batch.

### Stage one — third five tasks (11–15), 2026-11-19

- Task 11: added hero/tree/rock overlap render regression, covering four trees and four rocks, hero center/left/right offsets, positive/negative camera yaw, and obstacle immutability.
- Task 12: improved castle keep building silhouette with contact shadow, raised roof and roof highlight.
- Task 13: verified courtyard/keep/wall/crystal actors remain in shared depth queue; regression paints all four castles with hero overlaps.
- Task 14: tested each independently sorted wall-arc midpoint with hero overlap.
- Task 15: improved crystal plinth with separate ground shadow, top face and rim highlight; regression covers all seven crystals per castle.
- Latest code/test commit: `385efb23`; Actions run `44431595448` is still running, so CI is pending.
- Phase 1 implementation batches: 15/30 tasks addressed; two more five-task batches remain after this one.

### Stage one — fourth five tasks (16–20), 2026-11-19

- Task 16: added hero front/rear approach rendering around castle wall and crystal ground anchors under non-zero yaw.
- Task 17: added projected contact shadows for castle footprints, individual wall segments and living crystal bases.
- Task 18: unified hero and monster contact shadows using a shared soft radial helper.
- Task 19: routed tree and rock footprints through the same helper while preserving type-specific footprint sizes/opacity.
- Task 20: applied diagonal upper-left lighting to castle wall stonework and refined its bright edge highlight to match keep/crystal/tree lighting.
- Regression coverage: front/rear wall/crystal approaches and castle/actor shadows at yaw -0.42, 0 and +0.42; crystal counts remain unchanged.
- Implementation commits: `71d0b4fc`, `3964ef94`, `3bd0442c`. Latest CI is still running release APK builds.
- Phase 1 implementation batches: 20/30 tasks addressed; two five-task batches remain.

### Stage one — final ten tasks (21–30), 2026-11-19

- 21: unified tree canopy and rock facet highlights with upper-left scene lighting.
- 22: audited shared projected-depth sorting for hero, monsters, tree layers, rocks, corpses and projectiles.
- 23: verified mines, resource piles and chests join the shared actor depth queue.
- 24: verified bridge decks join the queue at their ground anchors while river banks remain projected terrain.
- 25: verified castle courtyard, keep, individual wall arcs and living crystals are separate depth-sorted objects.
- 26: added hero overlap rendering for bridges, mines, resources and chests; prior tests cover obstacles and castle layers.
- 27: added deterministic PNG arena captures at 1280×720, 1920×1080 and 2340×1080.
- 28: added landscape viewport transform/render checks for those three sizes.
- 29: added matching ground-contact shadows for bridges, mines, resource piles and chests; corrected remaining lighting gradients.
- 30: updated Android CI to upload the generated arena captures, then run analyze, all tests, release APK build and APK signature verification.
- Capture output: `build/arena-captures/`; artifact name: `archer-fm-3d-hero-visual-captures`. These are painter-generated captures, not physical-device screenshots.
- All 30 stage-one tasks are implemented/verified in source and tests. Final acceptance awaits the latest CI run and inspection of its capture artifact. No device visual sign-off is claimed.


### Stage two — batch 1 (steps 1–5), 2026-11-19

- Audited monster catalog, renderer, world/test coverage and repository asset tree.
- Confirmed the four existing roles and locked their current level-1 stat baselines, palettes, silhouettes, face direction and weapon reads in `docs/monsters/MONSTER_PRODUCTION_SPEC.md`.
- Confirmed monsters still use the procedural Canvas painter in `lib/game/arena_painter.dart`; no dedicated monster GLB/BLEND models, rigs or animation manifests were found on `ranger-reference-work`.
- Reviewed the existing monster mechanics and capture tests. They cover roster, stats/progression, army, purchases, losses, movement, targeting, ranged projectiles and basic visual capture execution. They do not prove final 3D art quality.
- Added the production specification in commit `e6a5554a7b27583fd9677f9958226d121d527a84`.
- Batch 1 steps 1–5 are complete as an audit/design/source-readiness batch. The asset audit has a clear blocker: no approved monster 3D source assets exist in the active branch. No fake asset paths were added and the procedural fallback remains untouched.
- Next: steps 6–10, establish a free/reproducible model pipeline and produce/validate four distinct monster assets before runtime integration.
- Stage-one Actions run `44465905653` on code commit `e82257a`: Analyze, all Flutter tests and hero/arena capture upload passed; Android emulator step is still in progress. Release APK build, signature verification and upload have not started. Stage one is not yet accepted.


### Stage two — batch 2 (steps 6–10), 2026-11-19 — blocked at asset creation

- Step 6: defined the reproducible free Blender/glTF production contract, canonical folder layout, GLB manifest schema, required clips/events, coordinate/scale conventions and per-model acceptance gate in `docs/monsters/MONSTER_3D_ASSET_PIPELINE.md`. Documentation complete.
- Steps 7–10: Runner, Tank, Stalker and Ranged model creation/validation are not complete. The active branch has no source monster GLB/BLEND models, and no actual model-generation/export runtime is available through the connected GitHub operations. Existing legacy SVG sheets and procedural Canvas shapes are not 3D source models and will not be mislabeled as such.
- Audited `monster-army-work`: it contains a substantial older monster runtime and legacy SVG assets, but its history has diverged heavily from `ranger-reference-work` (347 commits ahead, 278 behind; merge base `645bbeeb`). It also contains no dedicated monster GLB/BLEND production assets. Do not merge this branch wholesale into the active hero branch; preserve it as reference pending a deliberate, file-by-file port plan.
- Current branch remains on the hero-safe `ranger-reference-work`; no monster runtime or hero files were overwritten.
- Stage 2 visual production cannot honestly advance to runtime integration until four real model sources are created/provided and pass the GLB gates.
- Stage 1 Android checks: runs `44465905653` and `44465899058` still show emulator step running, with Release APK build and signature verification pending. Analyze, all Flutter tests and visual-capture upload passed in run `44465905653`; emulator/APK success is not confirmed.


### Stage two — batch 2 tooling follow-up, 2026-11-19

- Added `tools/validate_monster_glb.py` (commit `e4e1096`), a dependency-free Python validator for GLB v2 container integrity, mesh/node presence, skin/skeleton presence, embedded/self-contained image references, and all required named animation clips for Runner/Tank/Stalker/Ranged.
- The validator is ready to run when actual GLB files and `assets/monsters/3d/manifest.json` are supplied. It intentionally does not claim to assess visual quality, deformation, foot contact or Android performance.
- No model files were fabricated. The four model-production steps remain blocked until actual source meshes/rigs are created or supplied.
- Stage-one run `44465905653` was checked again at 2026-11-19 05:43 UTC: Android emulator step had been running since 05:34 UTC, with no completed result; Release APK and APK verification were still pending. Run `44465899058` was in the same state. This is a stalled/long-running CI condition, not a successful emulator or APK result.


### 2026-11-19 — Stage-one CI isolation and monster model generator

- Split Android Release APK build/signature verification and Android emulator smoke test into independent GitHub Actions jobs. A stalled emulator can no longer block APK compilation, signing verification, artifact upload, or release publication.
- Added an 8-minute widget-test timeout to `integration_test/app_smoke_test.dart` so a hanging smoke test fails with a bounded diagnostic instead of occupying the emulator job indefinitely.
- Added `tools/monsters/generate_monsters_blender.py`: a free, reproducible Blender-based generator for four distinct stylized, rigged monster GLBs (Runner, Tank, Stalker, Ranged), including face/weapon details, skinning, and named gameplay clips.
- Added a CI job that installs Blender, generates the four GLBs, runs `tools/validate_monster_glb.py`, and uploads the generated files as the `archer-fm-rigged-monster-glbs` artifact.
- Important acceptance limit: these are generated first-pass production prototypes. They are not yet approved final art, are not yet integrated into the arena runtime, and must pass the CI export/validation plus gameplay-distance visual review before the Canvas fallback is replaced.
- Workflow runs `44467506887` and `44467502786` (created before the final generator-job commit) show Analyze, all Flutter tests, and visual-capture upload passing; Release APK build and Android emulator smoke test are running independently. Their outcomes are not yet known.
- Latest implementation commits: `2cbb029` (generator), `7abb6f8` (clip-name manifest fix), `73fbeff` (CI model-generation job).


## Monster GLB generator follow-up — 2026-11-19

- The free Blender job successfully generated all four prototype GLBs (Runner, Tank, Stalker, Ranged), each with one skin and the expected animation count (6/5/5/7 respectively).
- The first validator run rejected the manifest because clip-map keys were title-cased while the runtime contract requires lowercase gameplay state keys. The exported animation names themselves were present.
- Fixed the generator manifest to emit lowercase keys mapped to the exact exported clip names in commit `fbf80b5`.
- Removed the unnecessary Weighted Normal modifier that emitted repeated Blender 3.x warnings on bevelled low-poly meshes.
- Pending: rerun CI, confirm all four GLBs pass the validator, inspect model renders/gameplay-distance captures, and only then decide on runtime integration. These remain prototypes, not visually approved production assets.


## 2026-11-19 parallel verification update
- Workflow run 217 (commit 7d668bd) completed Release APK build, signing verification, release upload, normal tests, and monster GLB generation/validation successfully. Android emulator smoke remained in progress at the last poll.
- Workflow run 218 (commit 78c539a) completed Release APK build and APK signature verification successfully and published release `v1.0.218`. Normal Flutter tests and Analyze passed. Emulator smoke and monster generation were still running at the last poll.
- The monster generator now renders four 768x768 front three-quarter PNG previews after exporting GLBs, under `build/monster-glb/previews/`; these previews are included in the same Actions artifact for visual review. This latest preview generation has not yet completed.
- Manual review of existing Stage One captures: the hero baseline render is visible and the hero model is large enough to inspect, but the separate 1920x1080 arena overview has no hero in frame and crops the upper/lower castle areas. This is recorded as a visual acceptance issue to investigate; passing image-capture tests alone do not prove camera framing is accepted.
- CI hardening: cap apt package installation, Blender generation/rendering, and emulator test runtime so a stalled environment does not occupy a runner indefinitely.
- No claim that Stage One is complete until Android emulator smoke passes and the arena framing/captures are reviewed.


## Follow-up fixes after CI failures (2026-11-19)
- Run 218 Android emulator smoke failed because Android system services died after boot (ADB Broken pipe / DeadSystemException); this is an emulator environment crash, not a Flutter assertion report. Retrying with clean no-snapshot boot and explicit 2 GB / 2 CPU emulator limits.
- Run 219 monster generation failed inside Blender 3.0.1 while starting EEVEE render in headless mode (process aborted with exit 134). GLB generation had passed in earlier run 217; changed preview rendering to Blender Workbench studio/material shading to avoid headless EEVEE initialization. Needs CI revalidation.
- Stage One remains incomplete: emulator smoke still not passed; camera overview crop/no-hero issue remains open.
- Stage Two: four GLB prototypes previously generated and validator passed in run 217. New preview-render change is pending validation; no final visual sign-off or runtime integration yet.


## Parallel continuation — stage-by-stage status (2026-11-19)

### Stage One — arena and Android acceptance (30 steps)
- Verified current camera transform is shared by painter and input, and camera follows the player with smoothing and map-bound clamping (lib/game/arena_camera.dart, lib/game/world/game_world.dart).
- Visual review remains blocked: the 1920×1080 arena capture shows the castle/crystal field cropped at viewport edges and no visible player; the separate hero baseline capture does show the Ranger but its body reads side/back-facing. This needs a corrected in-match capture and facing/camera review.
- Android smoke failure from run 44483818874 is an emulator OS crash after boot (DeadSystemException, ADB broken pipe), not a reported Flutter test assertion. New run retries clean boot with no snapshot, wipe-data, 2 GB RAM and 2 cores.
- APK build/signing succeeded in run 44483818874 (release v1.0.218), but Stage One is NOT accepted until a fresh emulator smoke passes and camera/hero visuals are reviewed.
- Current progress: foundational implementation and build verification are in place; visual framing + reliable emulator smoke remain open. Do not mark 30/30.

### Stage Two — four monster models and army integration (30 steps)
- Batch 1 / steps 1–5: complete as audit/specification, not art completion.
- Batch 2 / steps 6–10: canonical pipeline and four rigged GLB prototypes exist; run 44483399654 structurally validated all four assets (Runner 6 clips, Tank 5, Stalker 5, Ranged 7; 1 skin each). These are procedural low-poly prototypes, not visually approved production art and not integrated in runtime.
- Current headless Blender CI aborts while invoking render backend. Changed previews to opt-in only via ARCHER_MONSTER_PREVIEWS=1, so required GLB export and structural validation do not depend on headless rendering. Revalidate in latest workflow before proceeding.
- Keep Canvas monsters as runtime fallback until visual and animation review plus Android runtime integration passes.
- No new monster types or gameplay systems added.


## Evidence update — 2026-11-19 (run 44485644182)

### Stage One — 30-step acceptance
- New Android emulator smoke and release APK jobs are still running; no pass is claimed yet.
- Reviewed the two latest arena captures directly. The 1920×1080 overview cuts off the upper and lower castle areas and has no playable hero visible. The hero baseline capture includes the Ranger but the current angle does not clearly show the face; facing/orientation needs a focused in-match review. This remains an acceptance defect, not a pass.
- Keep the requested closer gameplay camera; do not zoom out the live camera just to make a static overview fit. The capture needs a distinct, deliberately framed overview if the purpose is to show the whole map.

### Stage Two — 30-step monster/army pipeline
- Run 44485644182 successfully generated all four GLBs after preview rendering was made opt-in, and the structural validator passed all four.
- Downloaded the actual workflow artifact and independently checked GLB v2 headers and manifest mappings: Runner 609,852 B / 22 meshes / 1 skin / 6 clips; Tank 654,524 B / 23 meshes / 1 skin / 5 clips; Stalker 611,492 B / 21 meshes / 1 skin / 5 clips; Ranged 631,068 B / 21 meshes / 1 skin / 7 clips. The manifest includes Idle/Walk/Attack/Hit/Death for all; Runner also Run; Ranged also Cast/Release.
- This closes structural generation for steps 7–10, but does NOT approve visual quality, facial detail, deformation, animation playback, Android performance or runtime integration. The generated archive contains GLBs and manifest only; no preview images were produced because previews are now opt-in.
- Runtime remains on procedural Canvas monsters until visual/animation review and in-game integration are completed.


## Parallel work update — 2026-11-19 (visual review)

### Stage One — arena / Android (30 steps)
- Current smoke and release jobs are still running; no emulator pass is claimed.
- Outstanding visual acceptance remains the clipped arena overview and insufficiently clear Ranger face/facing in the supplied captures. The in-match camera should stay close as specified; a full-map diagnostic capture must use its own framing rather than changing gameplay zoom.

### Stage Two — monster art / army (30 steps)
- Inspected the actual Runner and Tank preview PNGs, not just the GLB validator output. The current previews are NOT art-approved: surfaces show unwanted wire/triangulation overlays and material/face readability is poor. The underlying prototypes are blocky and the visible face details are not yet convincing.
- Fixed preview configuration to explicitly disable wireframe and object outlines, disable cavity noise, retain material colours, and use a tighter lens. Enabled opt-in previews in CI (`ARCHER_MONSTER_PREVIEWS=1`) so the next artifact includes review images while preserving the successful GLB validator path.
- This is a preview-quality correction only; it does not yet improve the mesh geometry or prove the faces/animations are production-ready. Reinspect all four new previews before approving or integrating.


### 2026-11-19 — Blender 3.0 preview compatibility correction
- The first preview-enabled CI attempt (run `44486504634`, commit `8656e7c`) exposed a version-specific API failure: Blender 3.0.1 does not expose `View3DShading.show_wireframe`; the exception stopped the generator before writing the manifest, so this run is a failure and no preview artifact is approved.
- Updated `tools/monsters/generate_monsters_blender.py` in commit `87eaca0f3cb4363baca12f67803bb7a50521c9f5` to guard optional shading properties with `hasattr`, supporting Blender 3.0 and newer without aborting export.
- New Actions run `44486855762` is testing this correction. Await the GLB generation, preview images, Flutter tests, APK build, and emulator smoke results before marking any of them passed.
- Stage One remains open: Android smoke and visual framing/facing acceptance have not yet passed on the current HEAD.
- Stage Two remains open: four GLBs passed structural validation on earlier runs, but the procedural art prototypes are not visually approved and the current runtime still uses the Canvas renderer.

- Follow-up visual geometry adjustment in commit `0f8ea90f13c9a80719a10bb0ddc1a4d689cc85fc`: organic forms (spheres/icospheres/cylinders) now use smooth polygon shading while armor/cube forms remain crisp. This is intended to reduce faceted/triangulated noise in small monster faces and silhouettes; it is pending the new CI preview artifact and visual review.


### 2026-11-19 — Larger parallel batch: preview runner, GLB integrity, monster lifecycle tests

#### Stage One — arena / Android
- Kept the landscape emulator smoke path enabled; it verifies app launch, landscape orientation, army selection at 20/20, match entry, joystick/attack controls, and teardown.
- Camera/projection coverage already includes reversible world/screen mapping, multiple aspect ratios, yaw/scale behavior, and visible bounds. No gameplay zoom change was made: the user's close gameplay framing remains the target, while full-map overview framing must be handled by the capture itself.
- Current emulator job is still running; no pass is claimed yet. A prior release attempt failed during Gradle dependency resolution (`kotlin-stdlib`/Kotlin Gradle plugin 2.0.21 could not be retrieved from the plugin portal), after visual capture upload had succeeded. Treat that as an unresolved build-environment/repository failure, not a code pass.

#### Stage Two — four monsters / army
- CI preview job now installs `xvfb` and launches Blender through `xvfb-run -a`, giving Workbench preview rendering a virtual display instead of crashing with `Unable to open a display` / exit 134.
- Extended `tools/validate_monster_glb.py` beyond container headers and clip names: checks mesh POSITION/accessor references, skin joint and inverse-bind accessor references, animation target-node and sampler/accessor references.
- Extended `test/monster_system_test.dart` with compatibility aliases, lower/upper level clamping, formation-offset finiteness/separation, and corpse-animation timing bounds.
- These changes are pending the Actions run on the new HEAD. Earlier generated GLBs were structurally valid, but the current prototypes are not yet visually approved or integrated into the runtime renderer.

#### Batch commits
- `066f32a48a981cf0a662d4a82ad6c6208c78089d` — CI virtual display for previews.
- `d35e996366c096b3a5ebfece022bcbbd87536ad2` — stronger GLB reference validation.
- `34c3ac5415de7e23c33b4a6d49a44adbecedcad7` — monster lifecycle/compatibility tests.
- Latest observed HEAD at this checkpoint: `34c3ac5415de7e23c33b4a6d49a44adbecedcad7`.


### 2026-11-19 — Virtual-display render succeeded; first four-monster visual review

- CI run `44487374412` (commit `066f32a48a981cf0a662d4a82ad6c6208c78089d`) successfully generated all four GLBs and all four PNG previews under `xvfb-run`; artifact `14511286354` contains four models, manifest, and previews. GLB structural validation passed: Runner 244,556 B / 22 meshes / 1 skin / 6 clips; Tank 295,928 B / 23 meshes / 1 skin / 5 clips; Stalker 248,428 B / 21 meshes / 1 skin / 5 clips; Ranged 259,872 B / 21 meshes / 1 skin / 7 clips.
- Downloaded and visually inspected the four actual preview PNGs. The display/preview pipeline now works, but the first set remains visually prototype-grade: toy-like spherical bodies, detached-looking limbs, weak archetype detail, and small/unclear expressions at review scale. They are not approved as final game art and have not been integrated into the live Canvas monster renderer.
- Follow-up art commit `e82dad4023671070b24fe937dfedda38a09b736f` enlarges the chibi head, strengthens eye/pupil/brow/mouth readability, improves torso proportions, and moves the preview camera closer to frontal so both eyes can be judged. Await its own artifact before deciding whether this fixes the issues.
- Stronger GLB skin/animation reference checks and monster lifecycle edge tests were pushed in `d35e996...` and `34c3ac5...`; their workflow runs are in progress at this checkpoint.
- Stage One: the emulator smoke jobs are still running; no end-to-end Android pass or current-HEAD APK success is claimed. A prior release job failed while Gradle attempted to retrieve Kotlin 2.0.21 artifacts from the plugin portal; investigate if repeated on a fresh run.

## 2026-11-19 continuation after visual-review checkpoint

### Stage One — arena and Android acceptance

- The map-wide captures from the latest hero-capture artifact (run `44487884841`, commit `e82dad4`) are diagnostic map renders, not a playable match screenshot: `arena-1280x720.png` and the 1920/2340 variants have no hero controller attached and show only a cropped viewport around map objects. Do not use them as evidence that the in-game camera hides the hero.
- The dedicated 3D hero capture `73_glb_hero_no_obstacle_baseline.png` is a north-facing run pose; the model is correctly showing its back/side for that direction. It is not a front-face approval image. Added an explicit south-facing idle capture (`70_game_3d_hero_front_idle`) in `test/hero3d_game_capture_test.dart` so future artifacts include a valid face-readability frame alongside the eight-direction suite.
- The live camera remains close and player-following; do not zoom it out to make a static map overview fit. Stage One is still open until the current-head workflow completes Android smoke, full tests, release APK build and APK signature verification, and the new front-idle capture is visually inspected.
- The current-head Actions run triggered by the art/test changes must be treated as the acceptance run; older successful jobs are not proof for the new HEAD.

### Stage Two — four monster models and runtime

- The `e82dad4` artifact `14512140347` successfully generated and validated four GLBs and preview PNGs. Visual inspection of all four new previews shows larger/clearer eyes and mouths, but the bodies remain primitive toy-like forms with visibly segmented limbs; Stalker/Ranged hood and weapon reads are weak, and the four designs do not yet meet the intended polished chibi-fantasy standard. They are explicitly **not approved for runtime integration**.
- Follow-up generator change `324c574` adds neck/limb bridges and shins, more distinctive Runner scarf tails/chest badge, a fuller Stalker hood/cloak, a tapered Ranged robe and a more readable staff/orb assembly. This is an art iteration only; it is not accepted until its newly generated previews are inspected and the validator passes.
- Procedural Canvas rendering remains the live fallback. The GLB outputs are CI artifacts, not committed runtime assets. Do not claim the 3D monster migration is finished or remove the fallback.
- The four roles, stats, starting 20-unit roster, level-40 cap, purchases, combat/death lifecycle and regression tests remain the locked gameplay scope. No fifth monster or new economy/win mechanics are permitted.

### Current verified state and blockers

- Commit `324c574`: monster geometry iteration.
- Commit `19c581c`: dedicated front-facing idle hero capture added.
- The current branch CI run must still be polled for: Flutter tests, capture artifact, release APK + signature, Android emulator smoke, four GLB generation and GLB validation.
- Stage One: **not complete** pending current-head Android/release evidence and front-facing hero visual inspection.
- Stage Two: **not complete** pending review of the new model previews, animation/pose quality review, approved asset integration and Android performance checks.

## 2026-11-20 — Stage One resumed: fresh source audit

### Scope and evidence
- Re-read `VISUAL_DIRECTION_PLAN.md` and the current `ranger-reference-work` source snapshot before continuing. No Stage Two work is authorized until Stage One is accepted.
- Re-inspected `lib/game/arena_camera.dart`, `lib/game/arena_painter.dart`, `lib/game/world/arena_projection.dart`, `test/arena_camera_test.dart`, and `test/arena_projection_test.dart`.
- Confirmed a source-level camera API mismatch: `arena_painter.dart` declares and uses `ArenaCameraConfig`, `defaultArenaCameraConfig`, and calls `ArenaCameraTransform.forViewport(..., config: config, projection: projection)`; the fetched `arena_camera.dart` defines only the projection-based API and has no `ArenaCameraConfig` or matching `config` parameter. This is an unresolved compile/analyzer blocker until reconciled.
- `arena_painter.dart` also expects `config.projection`; its `cameraProjection` getter delegates to the selected projection. No `ArenaCameraFollower` or zoom implementation was present in the fetched camera file.
- Existing camera tests cover projection sharing, painter/input round-trips, letterboxing, camera smoothing snapshots, yawed projection, and visible-world bounds. They do not yet validate the requested zoom/config/world-bound clamping behavior.
- The existing progress history still records Stage One open: Android emulator smoke, actual in-match framing capture, and front-facing hero visual review have not all been accepted on one current HEAD. Older APK/CI successes are not evidence for a newer commit.

### Stage One status
- Source audit: in progress; camera API mismatch recorded as the first blocking defect.
- Camera fix: not applied yet; do not claim it is fixed until the API, all call sites, tests, and current-HEAD CI agree.
- Visual evidence: pending fresh playable-match capture and inspection of the dedicated south-facing idle hero capture.
- Android/release gate: pending successful emulator smoke, full tests/analyze, release APK build, and signature verification on the same commit.
- Stage One remains **OPEN**. Do not start Stage Two.

### Next actions
1. Reconcile the camera config/transform API with every painter and pointer-input call site; preserve a single shared projection snapshot.
2. Add/adjust tests for the approved zoom behavior, world-edge clamping, and pointer-to-world round trips under zoom.
3. Run analyze and all tests; then produce fresh gameplay/hero captures and inspect them.
4. Run Android emulator smoke and release APK/signature verification on the exact same HEAD; record run IDs, artifacts, and outcomes here.


## 2026-11-20 — Review of Claude ZIP submission

### Files reviewed
- Received `archer_fm_fixes.zip` containing four files: `lib/game/arena_painter.dart`, `lib/game/combat/hero_kit.dart`, `docs/game/special_abilities.md`, and `test/hero_consistency_test.dart`.
- The ZIP's `arena_painter.dart` is an older/simpler camera implementation (46,684 bytes) than the current `ranger-reference-work` file (70,868 bytes). It uses its own scale/origin conversion and omits the current shared `arena_projection.dart` integration. Replacing the current painter with this file would regress the camera work, so it was deliberately **not applied**.
- `hero_kit.dart` and `docs/game/special_abilities.md` already exist on this branch; the ZIP copies were not blindly overwritten.
- Added the new `test/hero_consistency_test.dart` regression test to check equal base HP/energy/energy regeneration, distinct hero movement speeds, five-hit combo multipliers, four special abilities at levels 1/10/20/30, and Arabic ability-name consistency with the documentation.

### Verification status
- GitHub commit adding the test: `77ffc29dd4cd8d80b79b4710fe1ba676f98c775e`.
- The test has been committed but has **not yet been executed** in a Flutter environment. No test pass or build success is claimed.
- This ZIP review does not resolve the previously recorded camera API mismatch. Stage One remains **OPEN**; the camera fix and current-HEAD Android/release evidence are still required.


### Follow-up comparison of the ZIP contents
- Re-opened the uploaded ZIP and computed Git blob hashes for all four files.
- `test/hero_consistency_test.dart` has blob SHA `28493cf261aa1c7d48c911a576ed94e0759c0a42`, identical to the file currently on this branch. No second copy or duplicate update was needed.
- The ZIP copies of `lib/game/combat/hero_kit.dart` and `docs/game/special_abilities.md` have blob SHAs `0a4f56a755f7f7f5f6dd99b054ba840d3cbe7c25` and `48284f271288e76a685353eb19d912a0279f3e51`, respectively; the current branch versions have different blob SHAs. They were **not overwritten** because the branch already contains these files and a blind replacement could discard newer work.
- The ZIP documentation states `116/116` tests passed and `flutter analyze` reported no issues. These claims were not independently reproducible from the four-file ZIP, so they are recorded as Claude-reported results only, not accepted as verified project evidence.
- No additional source changes were justified by this comparison. Stage One remains **OPEN**; the outdated ZIP painter is not suitable for integration, and camera reconciliation plus current-HEAD test/build evidence remain outstanding.


## 2026-11-20 — Camera API reconciliation and 1.15 zoom

### Changes committed to `ranger-reference-work`
- Restored the shared `ArenaCameraConfig` and `defaultArenaCameraConfig` API in `lib/game/arena_camera.dart`. `ArenaCameraTransform.forViewport` now accepts the same config/projection inputs already used by the painter and pointer helper; an explicit projection overrides the config projection.
- Set the shared default projection scale to **1.15** while preserving the existing oblique depth compression (`groundScaleY: 0.82`).
- Updated `ArenaPainter.paint` to apply projection scale and focus offset to the actual canvas transform. Previously, the pointer transform accounted for projection scale/focus but the painter's canvas transform did not, so custom projection settings could disagree visually with touch mapping.
- Added a camera test asserting the default config uses the shared 1.15 projection.
- Preserved the shared projection architecture; the older Claude ZIP painter was not used.

### Commits
- `46b4b5867deed4140c3cff3662b280a5c7a0cd9b` — restore camera config API.
- `4da845381cf799348d0bcc17d316343ff338d771` — apply projection scale in painter.
- `37aead65333d3c7e82a95fc0b560af60e359d3a6` — add default zoom regression test.
- `674e60775087c3d1e87cc05c3e8bf0e960ff743a` — set default projection scale to 1.15.
- `be28138fec9d5d26d98dded877ca033a02e76e6e` — align painter focus offset with projection.

### Verification and remaining gate
- Source re-fetch confirms the camera config symbols, matching `forViewport` parameters, default 1.15 projection, and painter scale/focus transforms are now present on the branch.
- The new test is committed but **has not been executed** in Flutter. No analyzer, test-suite, emulator, release APK, or signature result is claimed for this new HEAD.
- The latest commit currently has no reported combined status checks from the GitHub status endpoint; the workflow lookup available here returned no PR-triggered run for this commit. This is **not** evidence of a passing CI run.
- Stage One remains **OPEN** until current-HEAD analyze/tests, real gameplay camera capture and visual review, Android emulator smoke, release APK build, and signature verification are all evidenced on the same commit.

### Next actions
1. Run `flutter analyze` and the full `flutter test` suite on this branch HEAD.
2. Inspect the 1.15 zoom in a real landscape gameplay capture; verify player framing, enemy/objective visibility, map edges, and HUD safe areas.
3. Verify pointer-to-world mapping at the zoomed projection, including edge and letterbox cases.
4. Run Android emulator smoke, build the release APK, verify its signature, and record all results against the exact tested commit.


## 2026-11-20 — First CI results after camera zoom change

### Run evidence
- GitHub Actions run `44732950237` tested commit `39f80a6345b052d94369b48e6c584f0328e52a87`.
- `flutter analyze --no-fatal-infos`: **passed**.
- `flutter test --reporter expanded`: **failed with 5 assertions**; the run reached 468 reported test cases before exiting.
- The failures were:
  1. `hero_consistency_test.dart`: Storm `tempest_rage` Arabic name in the documentation did not match the code's `هيجان العاصفة`.
  2. `arena_camera_test.dart`: four assertions still expected pre-zoom geometry (scale 1.0), while the approved default projection is now 1.15.
- The failing test cases were the oblique depth delta, default horizontal/vertical scale, visible-bounds comparison against an explicit 1.5 projection, and default visible-world rectangle dimensions.

### Corrections committed after that run
- Updated the four camera assertions to include the default projection zoom of 1.15 and its effect on visible world bounds.
- Corrected the Storm ability row in `docs/game/special_abilities.md` to use the exact Arabic name already defined by `hero_kit.dart`: **هيجان العاصفة**.
- These changes are committed after the failing CI run; they have **not yet been validated by a new run**. A fresh push-triggered workflow is expected from this progress update.

### Current gate
- Analyze passed on the earlier camera-fix commit, but full tests failed on that commit.
- The new camera-test/documentation corrections are awaiting CI on the resulting HEAD.
- Android emulator smoke and four-monster GLB generation were still running in run `44732950237` at the time its jobs were inspected; their results must not be transferred to a later commit.
- Release APK build and signature verification were skipped because the test step failed.
- Stage One remains **OPEN**. Do not begin Stage Two until the latest HEAD passes the complete gate and the 1.15 gameplay framing is visually accepted.


## 2026-11-20 — Hero completion batch opened

### Active scope
- The user approved starting with all four heroes and finishing their visual presentation before moving to monsters.
- Work order is now: baseline audit → heroes → monsters → arena/environment → shared visual polish → final camera tuning → HUD → performance/release. Existing camera work is preserved; final framing is intentionally postponed until actor and environment scale are stable.
- Production runtime assets listed in `pubspec.yaml`:
  - Ranger: `assets/heroes/ranger_new/ranger_animated.glb`
  - Flame: `assets/heroes/flame/model/flame_animated.glb`
  - Shadow: `assets/heroes/shadow/model/shadow_animated.glb`
  - Storm: `assets/heroes/storm/model/storm_animated.glb`
- `GameScreen._glbCandidatePaths` resolves these paths and falls back to atlas sprites if loading fails. This fallback must remain until each 3D hero is visually and functionally accepted.
- Existing `test/hero3d_game_capture_test.dart` checked all eight facings for every hero but only asserted triangle count; its dedicated face-readability capture covered Ranger only.
- Added a dedicated front/three-quarter idle PNG capture for each of the four heroes, retaining the eight-direction captures. This gives reviewers an actual face-facing frame for Ranger, Flame, Shadow and Storm rather than treating a successful draw call as visual approval.
- Test/capture change commit: `d34b9fae6ce40dc093c84f50e752f5f7ac5debe4`.
- Reordered `VISUAL_DIRECTION_PLAN.md` to make hero completion the active visual phase and final camera tuning follow the stable hero/monster/arena scale.

### Current hero acceptance status
- Runtime GLB loading path exists for all four heroes; this proves integration wiring only, not visual quality.
- The capture suite requires each GLB to contain a skeleton and the core `idle/walk/run/attack/skill/hit/death` clips.
- Face, eyes, hair, armor, weapon silhouette, hand/weapon alignment, material response, animation deformation and gameplay-scale readability remain **not visually approved** until fresh captures are generated and inspected against `assets/heroes/reference/heroes_reference_sheet.jpg`.
- No GLB mesh has been modified in this batch yet. Do not claim any hero complete until actual visual defects are fixed and recaptured.

### Verification
- The new capture-test commit has been pushed to `ranger-reference-work`; its fresh CI run and artifact are pending.
- No new analyzer/test/build pass is claimed at this checkpoint.
- Next: inspect the fresh four-hero capture artifact; compare face/front and three-quarter views; record per-hero defects; then fix the source models/rig/materials and regenerate only the affected hero assets, followed by recapture and regression tests.


## 2026-11-20 — Isolated hero close-up capture gate

- Review of the first four gameplay face captures showed that the heroes occupy too little screen space to approve eye/face, hair, armour and weapon details. The gameplay captures remain useful for in-arena scale and facing only; they are not sufficient evidence for close-up visual acceptance.
- Added four isolated close-up yaw captures per hero using the same runtime `Hero3DController` / `Hero3DModel.paint` renderer used by the game. Each view is framed to approximately 520 px tall in an 800×800 review image, and the test asserts the rendered bounds remain between 400 and 700 px.
- Added capture/test change: `23bbf06bf9b9d8b9b1de62690f678265cb7fe23d`.
- Fresh workflow run `44745932498` is in progress. Do not treat the new close-up suite as passing until its test job completes and the four-hero captures are downloaded and visually inspected.
- No hero source mesh, rig, material or animation has been changed yet. All four heroes remain **not visually approved**. Next step after capture generation: inspect the close-up angles, identify the true front-facing view and record concrete per-hero mesh/face/material/weapon/rig defects before changing source assets.

## 2026-11-20 — Four-hero reference and capture audit

### Reference source confirmed
- The current branch contains the approved four-hero roster image at `assets/references/approved_all/hero_roster_concept.jpg`. It clearly defines the four distinct identities: green Ranger with bow/quiver; red Flame Knight with greatsword and gold armour; violet Shadow with hood and twin daggers; blue/white Storm mage with lightning orb.
- The older path `assets/heroes/reference/heroes_reference_sheet.jpg` is **not present** on this branch (GitHub returned 404). Use the approved roster image above as the checked-in reference unless the user later supplies a different canonical sheet. Do not invent or substitute a new design.

### Existing source/profile audit
- All four production runtime GLBs are present and referenced by the game.
- The procedural source profiles in `tools/blender/hero_profiles.py` define distinct palettes, armour/clothing, signature weapons and FX for Flame, Shadow and Storm. Ranger's green/brown base palette and bow/quiver are authored in `tools/blender/build_ranger_source.py`.
- Source comments and profile code are not visual approval. The face, eye placement, expression, hair silhouette, armour proportions, weapon grip/alignment, materials and animation deformation still require close-up review against the roster image.
- No model mesh/material/rig was changed as part of this audit; avoid regenerating production GLBs before the close-up defects are identified.

### Capture evidence inspected
- Downloaded and inspected artifact `archer-fm-3d-hero-visual-captures` (artifact ID `14632133991`). It contains gameplay captures for all four heroes and all eight facings.
- Those gameplay captures show the models are drawn in the arena, but their on-screen size is too small to judge facial detail or approve armour/weapon craftsmanship. They are not a visual sign-off.
- The test now includes isolated four-angle close-ups for each hero and checks the rendered height bounds. However, workflow run `44745932498` was cancelled before checkout; it did **not** execute the updated capture test or produce a fresh artifact. The older artifact must not be treated as evidence that the new close-up test passed.

### Per-hero status
| Hero | Checked-in identity | Runtime GLB | Visual sign-off |
|---|---|---|---|
| Ranger | Green/brown archer, bow and quiver | Present | Pending isolated close-ups |
| Flame | Red/gold knight, greatsword | Present | Pending isolated close-ups |
| Shadow | Violet hooded rogue, twin daggers | Present | Pending isolated close-ups |
| Storm | Blue/white mage, lightning orb | Present | Pending isolated close-ups |

### Next implementation gate
1. Obtain a successful current-HEAD run of `hero3d_game_capture_test.dart` and inspect all 16 isolated hero close-ups (four yaw views × four heroes).
2. Identify the actual forward-facing view and record concrete face/eye/hair/weapon/rig defects separately for each hero.
3. Fix only evidenced defects in the relevant Blender source/profile; preserve each hero's approved identity and signature weapon.
4. Regenerate only the affected GLB, then re-run capture tests and compare before/after images.
5. Approve a hero only after face readability, full silhouette, weapon alignment, animation deformation and arena-scale readability all pass.

### Current status
- Hero batch: **IN PROGRESS — source assets exist; visual acceptance is not yet met.**
- No claim of analyzer, full test-suite, Android smoke, release APK or signature success is made for the current HEAD.


## 2026-11-21 — Official 2.5D migration resumed (supersedes legacy full-3D hero work)

**Binding direction:** playable heroes and monsters are 2D sprites with a polished 2.5D appearance; the arena/world is planned as a lightweight real 3D environment. The previous full-3D hero production path is historical only. Do not use GLB hero rendering as the production visual path once each approved sprite is integrated. Keep source GLBs archived until the migration is accepted; do not delete them.

### User reference constraints
- Production hero/monster/final gameplay visuals must use only the user's approved references. No assistant-generated, web-sourced, stock, generic or invented character art.
- Canonical roster: `assets/references/approved_all/hero_roster_concept.jpg`.
- Canonical monsters: `assets/references/approved_all/archer_fm_monsters_reference.png`.
- Canonical gameplay composition: `assets/references/approved_all/file_000000005c8c81f9ab4ccbb80ea59d5e.png`.
- Shadow walk source: the user's uploaded `1000241306.png`, preserved in the repo as `assets/heroes/shadow/renders/atlases/shadow_walk_8dir_4frames_FINAL.png`. Original reference files remain immutable.

### Shadow Phase 1 — implementation evidence
- The checked-in Shadow walk atlas is a 768×1536 PNG with RGBA color type (PNG IHDR type 6), arranged as 8 rows × 4 columns, each cell 192×192.
- All eight direction clips (`walk_s`, `walk_se`, `walk_e`, `walk_ne`, `walk_n`, `walk_nw`, `walk_w`, `walk_sw`) reference exactly four user-source frames each, at 100 ms/frame.
- The shared pivot is x=0.50, y=0.86; per-direction frame metadata maps the four columns and eight rows explicitly.
- `lib/game/game_screen.dart` has a Shadow pilot guard that prevents the legacy GLB from overriding the atlas sprite path for the normal production screen. Test injection remains available.
- `test/shadow_2d5_in_game_capture_test.dart` loads the real manifest/atlas and renders Shadow through `ArenaPainter` for all eight world facings.
- `test/shadow_user_walk_atlas_test.dart` now also decodes the PNG and checks the actual alpha channel/corner transparency, not just the file extension/header. Added in commit `a5993b9cf2ebf3686c703ee3f5c0680a6ee1695e`.
- **Acceptance is not yet granted:** the new alpha-validation test is queued in run `44888593832`; inspect its result and the resulting eight-direction captures before marking Shadow Phase 1 complete. Visual foot grounding, direction convention and motion quality still require review at gameplay scale.

### Other hero/monster work — do not mislabel as 2.5D completion
- Flame's current generated sprite workflow failed on the old CI Blender 3.0.1 runtime: the checked-in .blend was authored by Blender 3.6.13 and crashed on load; the procedural material builder also used the newer Principled BSDF socket name `Emission Color`. More importantly, the workflow's code-generated appearance is not an approved substitute for the user's Flame reference. Do not accept or integrate its output. Flame needs a reference-faithful, user-approved sprite source.
- The monster GLB generation job succeeded in run `44888328566`, but those GLBs are not approved production assets under the current 2D/2.5D monster direction. Keep them isolated; do not integrate them as production monsters.
- The earlier full-3D hero APK/capture pipeline is not evidence of 2.5D sprite acceptance.

### Current CI evidence (as of this update)
- Commit under test: `a5993b9cf2ebf3686c703ee3f5c0680a6ee1695e`.
- Fresh workflow run `44888593832` was queued at the time this note was written; no pass is claimed for that commit yet.
- Previous run `44888328566` at commit `ce873de026f681add86416fabd0608152a77eea2`: Flutter analyze and full Flutter test suite completed successfully; Android emulator smoke and release APK build were still running at the last inspection. Monster GLB generation succeeded but is not accepted for production.
- Flame render run `44888328674` failed due Blender version incompatibility and the material socket mismatch described above. It is not an approved art output.

### Next steps (strict order)
1. Wait for `44888593832`; fix any alpha/test failures and inspect the eight Shadow capture images.
2. If the Shadow captures pass visual review, mark Phase 1 complete and extract the reusable sprite direction/frame renderer without changing gameplay.
3. Convert Flame only from an approved reference-faithful source; stop rather than inventing missing views/frames.
4. Convert Ranger and Storm the same way, then the four monster roles from their approved reference.
5. Only after sprite actors are stable, prototype the lightweight 3D world/billboard integration and compare the final scene to the approved gameplay image.


### Follow-up alignment — production pipeline
- Disabled the obsolete `generate-monster-glbs` job in `.github/workflows/flutter-android.yml` (commit `cd19aee969cfa6feb3dcc5e9eb13d6f033ff6273`). The generated GLBs from the already-running earlier workflow remain isolated artifacts and are not production monster assets.
- Future production monster work must use reference-approved 2D/2.5D sprite sheets. No GLB monster generation should be re-enabled as a substitute.


### 2026-11-21 — enforce 2.5D across the full playable roster
- Updated `lib/game/game_screen.dart`: production gameplay no longer loads or displays a GLB for *any* selectable hero. All four production heroes now stay on their manifest-driven 2D sprite path. Explicit GLB injection remains available only for isolated renderer tests.
- Updated `integration_test/app_smoke_test.dart`: after tapping Start Match, wait 400 ms for the MaterialPageRoute transition before checking the arena controls. The previous smoke failure was a timing race: the test queried `joystick_zone` after only one frame while the route was still transitioning; logs showed app startup, home, army selection and start tap all completed.
- Latest verified prior run `44889367500` at `319fe4a55f297365bf0e6090a3b51aad24511604`: Flutter Analyze passed, full Flutter test suite passed, release APK built and verified; Android smoke failed only at the too-early `joystick_zone` lookup. This is not yet proof that the patched smoke test passes.
- New run `44891945537` is testing commit `0a1123926718a838abb8b58510f0c946dd9a91fd`; wait for its result before calling the new smoke fix verified.
- The legacy 3D hero assets remain archived in the repository for source/provenance and test injection, but are not loaded by production gameplay.


### Reference audit — block unapproved/placeholder sprite atlases
- Inspected the actual committed idle atlases against the canonical roster reference `assets/references/approved_all/hero_roster_concept.jpg`.
- Shadow's old generated `idle_*.png` showed a visibly different bald/moustached character and did not match the approved hooded purple Shadow. Updated all eight Shadow idle clips to hold frame 0 from the user's approved `shadow_walk_8dir_4frames_FINAL.png` directional row instead. The user-supplied walk cycle remains the only accepted Shadow character artwork in this pilot; dedicated idle/attack/skill/hit/death art still needs reference-approved source frames.
- Flame's current idle atlas is a simplified render that does not yet demonstrate faithful match to the canonical red-haired armored Flame reference. Storm's inspected idle atlas is a flat blue placeholder with no visible character. Do not treat either as production-approved sprite art.
- Therefore the all-roster GLB shutdown was rolled back for the transition: Shadow remains on its 2.5D sprite pilot; Flame, Storm and Ranger keep their current verified visuals until their reference-matched sprite atlases are validated. This is a temporary migration stage, not a change to the final 2D/2.5D decision.
- Added assertions in `test/shadow_user_walk_atlas_test.dart` ensuring all eight idle directions use the approved user atlas rather than the mismatched legacy idle art.
- Final acceptance still requires review of Shadow attack/skill/hit/death source frames and visual gameplay capture, followed by Flame/Ranger/Storm sprite conversion from their own approved references.


## 2026-11-21 — Shadow static-idle manifest compatibility fix

- Branch: `ranger-reference-work`
- Fixed `lib/hero/hero_manifest.dart`: a one-frame looping clip is now accepted as a valid static pose; non-looping clips still require at least two frames.
- Updated `test/all_hero_render_manifest_test.dart`: idle clips may contain one or more frames, while all animated/action states still require at least two.
- This matches the approved Shadow pilot: each of its eight directional idle clips deliberately holds frame 0 from the user-supplied walk sheet until dedicated idle artwork is approved.
- Commits: `e72d603` (parser), `8268e5e` (manifest test).
- Verification status: source changes committed; a fresh CI run for these commits has not yet appeared. Do not mark Phase 1 complete until the full test suite, capture checks, and Android build pass.
- Known outstanding failure from the previous CI run `44892099544`: the five-hit normal attack-chain widget test failed in addition to the two Shadow single-frame-idle assumptions. Its detailed assertion was not present in the available job log excerpt and must be isolated in a focused rerun.


## 2026-11-21 — Current-HEAD Android verification and visual acceptance checkpoint

- Tested branch: `ranger-reference-work`.
- Tested commit: `c8bad8df47f8d44a10195946d2ea531d66856e97` (`Add close-up Shadow ground-contact captures`).
- GitHub Actions run: `44935787919`.
- Flutter Analyze: **passed**.
- Full Flutter test suite: **passed**.
- Visual capture artifact upload: **passed**; artifact `archer-fm-3d-hero-visual-captures` (ID `14719378531`).
- Android emulator boot and `integration_test/app_smoke_test.dart`: **passed**.
- Release APK build: **passed**.
- APK verification/signature check: **passed**.
- Actions APK artifact upload: **passed**; artifact `archer-fm-release-apk` (ID `14719733122`, ZIP size 102,246,340 bytes).
- GitHub Release publish step: **passed**; release page `v1.0.342` includes `app-release.apk` (130,126,135 bytes).
- Important release metadata mismatch: the existing tag `v1.0.342` still resolves to commit `029147b71e0dd7fe7e2a0c01c75bdd778d6ebb62` from 2026-11-18, not tested commit `c8bad8d`. The current run uploaded its APK asset to that pre-existing release/tag. Do not claim the release tag points at the tested commit; use the Actions artifact for an unambiguous run-specific build, and fix release-tag uniqueness before treating future release pages as canonical.
- Shadow contact review: the eight-direction capture set and zoomed south-facing capture were inspected. The current manifest pivot remains `(0.50, 0.86)`; visible feet align closely with the pivot line, so no production pivot change was justified by the evidence.
- Hero face review: close-up/gameplay captures are available, but they do not yet establish reference-faithful facial detail and clean geometry for all four heroes. Face/material/mesh visual sign-off remains **OPEN**; do not claim all heroes complete.
- Production visual direction is the approved 2D/2.5D sprite actor pipeline in the lightweight 3D arena. The older full-3D GLB hero path is historical/test/reference-only and must not be used as proof of current 2.5D art acceptance.
- Next steps: (1) correct the release workflow's tag collision/uniqueness policy before the next release; (2) inspect and accept reference-matched sprite art for each hero, especially Flame/Ranger/Storm and Shadow's missing action states; (3) continue arena/actor visual acceptance only after fresh captures; (4) retain the successful current-HEAD Analyze/tests/emulator/APK evidence above.


## 2026-11-21 — Hero sprite readiness audit and render-route guard

### Visual evidence reviewed
- Compared the checked-in hero assets against `assets/references/approved_all/hero_roster_concept.jpg`.
- Shadow: the user-supplied `shadow_walk_8dir_4frames_FINAL.png` is the only currently approved sprite animation source. It contains eight direction rows × four frames and is integrated as the 2.5D pilot. Idle holds the first approved frame per direction. Dedicated approved run/attack/skill/hit/death source frames are still missing.
- Flame: the current `renders/atlases/idle_s.png` is a simplified small character and does not demonstrate the reference's detailed red-haired knight, gold armor and greatsword. It is not approved for production sprite use.
- Storm: the current `renders/atlases/idle_s.png` is a flat blue tile with no visible character. It is a placeholder, not a production sprite.
- Ranger: no source/model/art changes were made in this batch. Preserve the existing Ranger work; do not alter it as part of this audit.

### Code safeguard
- Added `lib/hero/hero_render_policy.dart` and a regression test so the production route is explicit: Shadow uses the approved sprite pilot; Ranger, Flame and Storm remain GLB-primary until their sprite replacements pass reference and animation review.
- `GameScreen._loadHero3D()` now consults this policy instead of a hard-coded Shadow ID check. No gameplay, camera, collision, or art asset was changed.

### Current blockers and next actions
1. Complete the Shadow Phase 1 acceptance review; its walk source is approved, but missing action-state art prevents full Shadow completion.
2. Flame needs approved source frames that preserve the canonical red-haired knight, armor and greatsword. Do not use the current simplified atlas.
3. Storm needs actual reference-faithful character frames; do not use the flat blue placeholder atlas.
4. Keep Ranger unchanged until the user explicitly reopens its sprite work.
5. Once approved Flame/Storm source material is available, convert one hero at a time, validate all eight directions/states and inspect gameplay captures before switching its production route.

### Verification
- The prior current-head workflow run `44935787919` passed Analyze, all Flutter tests, Android smoke, APK build and signature verification for commit `c8bad8df47f8d44a10195946d2ea531d66856e97`.
- Workflow run `44936501289` is testing the release-tag uniqueness fix at commit `660daeee90e1da38e15a307d81e64365c4ee8f32`; Analyze, all tests and visual-capture upload passed, while Android smoke and APK build were still running at the time of this note.
- This new policy/test change must receive its own CI run before it is considered verified.


## 2026-11-21 — Remove unapproved Shadow action art from the pilot

- A fresh visual inspection of the committed Shadow atlases found that `run`, `attack`, `skill`, `hit` and `death` still showed a bald/moustached character, visibly different from the approved hooded purple Shadow. The same legacy atlas family was also used for `dodge`.
- Updated all eight directions in `shadow_manifest.json`:
  - `idle` continues to hold the first approved user frame.
  - `walk` uses the four approved user frames.
  - `run` reuses the same four approved frames at 66 ms/frame.
  - `attack`, `skill`, `dodge`, `hit` and `death` temporarily hold the first approved frame for their original clip duration. Their gameplay animation events and timings are preserved exactly. This intentionally favors consistent approved character identity over showing the mismatched legacy art; dedicated action artwork is still required for final polish.
- Expanded `shadow_user_walk_atlas_test.dart` to enforce that every Shadow state/direction loads the approved user atlas and that all original combat event schedules remain intact.
- Expanded `shadow_2d5_in_game_capture_test.dart` to emit one four-frame walk-cycle strip for each of the eight directions, enabling direct foot-contact and motion review.
- No source reference image was altered. No other hero's artwork was modified.
- CI verification for this batch is pending; do not mark Shadow action art complete.

## 2026-11-21 — Full roster sprite audit

- Inspected the canonical reference and representative front/back/side atlas frames for Ranger, Flame and Storm, plus the Shadow approved source.
- Ranger atlas: 64 declared clips across 8 states/directions and 496 declared frames. Preserve current work; keep GLB primary pending full acceptance.
- Flame atlas: 64 clips and 496 declared frames, but the inspected front sprite is a simplified brown-haired fighter with a small flame, unlike the canonical red-spiky-haired gold-armored knight with a greatsword. Keep GLB primary; do not promote current atlas.
- Storm atlas: inspected idle/walk sheets for S/N/W; they are flat blue tiles with no visible character. Keep GLB primary and reject these atlases as placeholders.
- Shadow remains the only approved 2.5D pilot. Dedicated action art is still missing; temporary held poses preserve approved identity and combat event timing.
- Added `docs/HERO_VISUAL_ACCEPTANCE_AUDIT.md` with evidence, production route decisions, per-hero acceptance checklist and next tasks.
- No canonical reference, source GLB or user-provided sprite artwork was changed.


## 2026-11-21 — Hero sprite fallback safety gate

- Compared the checked-in front-facing idle atlases directly against `assets/references/approved_all/hero_roster_concept.jpg`.
- Confirmed the current evidence: Shadow is the only approved sprite pilot; Ranger remains pending full visual acceptance; Flame's atlas is visibly inconsistent with the red-haired gold-armored greatsword reference; Storm's atlas is a flat blue placeholder.
- Fixed a production fallback leak: when a GLB failed to load, the arena painter could previously fall through to an unapproved atlas. `HeroRenderPolicy.allowsSpriteAtlas()` now provides the explicit approval decision, `GameScreen` passes it into `ArenaPresentation`, and `ArenaPainter` suppresses unapproved hero atlases. A neutral placeholder is shown instead of wrong character art when an unapproved GLB is unavailable.
- Added regression assertions that Shadow is the only hero whose atlas is approved for production.
- Updated `docs/HERO_VISUAL_ACCEPTANCE_AUDIT.md` with the failure mode and fix.
- No hero artwork, canonical references, GLB source files, gameplay, camera, hitboxes or combat timing were changed.
- Verification: CI has not yet produced a usable job result for these latest commits; final verification is pending. Do not mark the change verified until a clean run completes.



## 2026-11-21 — Monster visual acceptance audit and Storm render status

- Added `docs/MONSTER_VISUAL_ACCEPTANCE_AUDIT.md` using the exact approved four-enemy reference sheet as the source of truth.
- Recorded the four canonical enemy identities: green goblin sword wielder, dual-blade skeleton, horned armored mace brute, and purple hooded masked fighter with violet energy blades.
- The prior Phase 0 audit found no `assets/monsters/` production asset directory. No verified monster model/rig/animation pack or in-game acceptance evidence is currently available in the reviewed records; all four monster visuals remain NOT READY.
- No substitute art or placeholder monster was created. The canonical reference image remains unchanged.
- Storm render workflow run `44940626160` has completed Blender installation and selected-hero source-scene validation; its eight-direction/state render step was still running at the latest check. No artifact has been published yet, so no Storm output is accepted.
- The selected-hero workflow still needs a completed render, validation, atlas packing, and artifact review before its result can be called successful.
- Hero readiness remains unchanged: Shadow is a limited 2.5D pilot with incomplete action artwork; Ranger remains pending visual acceptance; Flame's existing atlas is rejected for identity mismatch; Storm's checked-in atlas is rejected as a flat placeholder.



## 2026-11-21 — Reference-directed monster prototypes and hero render continuation

- Updated `tools/monsters/generate_monsters_blender.py` so the prototype geometry/palettes follow the approved monster sheet:
  - Runner: green goblin with pointed ears and one short sword.
  - Tank: horned heavy armored brute with a spiked mace.
  - Stalker: ivory skeleton with dark eye sockets and paired blades.
  - Ranged: purple masked infiltrator with violet energy blades.
- Added `.github/workflows/monster-reference-prototypes.yml` to build four review-only GLBs, validate skeleton/clip/material structure, and upload previews/artifacts. Generated prototypes are not runtime assets and are not visually accepted.
- First prototype build run `44942396591` exposed an environment failure: Blender's glTF exporter could not import NumPy. Fixed the workflow to install `python3-numpy` with Blender.
- Corrected build run `44942594455` is currently in progress. No GLB validation result or review artifact is available yet.
- Updated `docs/monsters/MONSTER_PRODUCTION_SPEC.md` to remove contradictory legacy color/design briefs and lock the four approved visual-to-gameplay mappings. Existing game stats, roles, projectile behavior, economy and progression must remain unchanged. The Ranged character's violet blades are visual identity only; its projectile behavior remains ranged.
- Hero render workflow `44940626160` (selected hero: Storm) remains in progress. Source-scene validation passed; the eight-direction/state render step was still running at the latest check. No Storm atlas is accepted until render validation, packing and visual review complete.
- Android release workflow `44942377013`: Flutter analyze, all tests, and visual-capture upload completed successfully; APK build and Android emulator smoke test were still running. This is not yet a successful APK verification.
- Commits from this batch:
  - `2ea2682546fb1f2a17896fb552bc0cbea75951fb` — reference-directed monster geometry/palettes.
  - `bc2cdf790df652a8e159c443f8e4b9f78beea14c` — monster prototype build workflow.
  - `96e786bf38ad62957f121e5ffad8d72ec6208fc8` — install NumPy for Blender GLB export.
  - `4c3f29e5e271a76cd5ba7b0868bbc3d0e7dbd57d` — align monster production spec with approved designs.
- Current acceptance status: all four monster models remain PROTOTYPE / NOT VISUALLY ACCEPTED; Storm sprite render remains pending; hero visual readiness is unchanged (Shadow limited pilot, Ranger pending review, Flame atlas rejected, Storm atlas rejected).
- Next: finish and inspect the monster build artifact, fix any exporter/validator errors, then visually review the four previews against the approved sheet. In parallel, wait for Storm render/validation and the Android build/smoke-test result. Do not integrate any unapproved monster atlas or hero atlas.


### 2026-11-21 — Blender headless preview environment fix

- The NumPy-enabled prototype run `44942594455` successfully started GLB export, but Blender aborted when it entered preview rendering because `libEGL.so.1` was unavailable.
- Updated `.github/workflows/monster-reference-prototypes.yml` to install Xvfb and Mesa/EGL runtime libraries, and run Blender under `xvfb-run` with software rendering enabled.
- Fix commit: `0e9223961a8688998c4decfd8787661d353fd5a6`.
- Corrected workflow run `44942727221` is queued/in progress; no preview or final GLB validation result is available yet.
- Storm render run `44940626160` is still running its eight-direction/state render stage; do not treat the render as accepted until the remaining validation, packing and artifact review steps finish.


### 2026-11-21 — Monster GLB export and manifest clip-name correction

- The corrected headless rendering environment succeeded: Blender exported the prototype models and rendered the preview PNGs without the earlier EGL abort.
- Structural validation then exposed a real manifest bug: GLB animation names are namespaced (for example, `runner_Walk`, `tank_Idle`), but the manifest incorrectly mapped generic names (for example, `Walk`, `Idle`). The validator correctly rejected all 23 mismatched clip mappings.
- Fixed `tools/monsters/generate_monsters_blender.py` so each manifest clip maps to its actual namespaced animation name (`<monster>_<Clip>`).
- Fix commit: `9280dabea67f1a10e85e1a77b1a1d7ab25bf9f37`. A fresh prototype build/validation run is triggered by this change; visual/runtime acceptance remains pending.


### 2026-11-21 — Skeleton silhouette refinement

- Refined the procedural Stalker skeleton so it no longer inherits the shared solid humanoid torso, neck, generic head, muzzle or generic eyes beneath its skull/ribs.
- Added visible vertebrae and collarbones to strengthen the exposed-bone silhouette; retained the ivory skull, dark sockets, rib cage, pelvis and paired blades.
- Commit: `404761618cbf5cfc6d02142a1781007c48f29867`.
- This is still a technical prototype refinement; visual acceptance depends on reviewing the newly generated previews against the approved monster reference.


### 2026-11-21 — Fix selected-hero render validation paths

- Storm's Blender source-scene validation and eight-direction/eight-state render stages both completed successfully in run `44940626160`.
- The next gate failed because the workflow did not persist `HERO` between steps and passed `assets/heroes/storm/renders` to the validator, while `render_hero.py` deliberately writes into the fixed `assets/heroes/ranger/renders` working directory. The pack step also constructed a hero-specific manifest path even though the renderer always writes `ranger_manifest.json` there.
- Fixed `.github/workflows/flame-2d5-sprites.yml`: persist `HERO` through `GITHUB_ENV`, validate the actual fixed render root (the validator itself checks `active_hero.txt` and manifest hero_id), and pass the actual working manifest to the packer. The packer then publishes the non-Ranger hero bundle to the selected hero path.
- Fix commit: `2a1bc6f7020c60a3f77bb7f009ba384f25e9de8e`. A fresh selected-hero run is triggered; Storm is not accepted until frame validation, atlas packing, and artifact review succeed.

### 2026-11-21 — Continue 2.5D roster and arena environment pass

- Reconfirmed the active branch head before editing: `ranger-reference-work`.
- Added restrained animated riverbank foam highlights in `lib/game/arena_painter.dart`. The accents are deterministic and presentation-only; they skip bridge decks and do not modify river geometry, movement, collision, or map rules.
- Locked the monster production spec to the same final runtime direction as the heroes: all four monsters must be reference-faithful 2D/2.5D animated sprite actors in the lightweight 3D arena. GLB/BLEND prototypes remain source/render inputs only; the procedural Canvas fallback stays active until each sprite pack passes visual and technical acceptance.
- Verified that `ArenaMap.isBridge(Offset)` exists and that the stone approach pass uses the real map bridge query.
- Current verification limitation: the Android workflow for commit `770678e` was queued/pending at the latest check, not yet green. The legacy `ranger-assets.yml` run reports failure but the Actions API returned zero jobs for that run, so its failing step cannot yet be identified from the available run metadata. Do not treat the current hero or monster atlases as accepted.
- Next batch: isolate the legacy Ranger workflow failure, make the selected-hero render/pack/validation path reproducible for each of Ranger, Flame, Shadow and Storm, then review the generated 2.5D previews against the approved sheets. Continue map dressing in parallel without changing gameplay rules.

### 2026-11-21 — Four-region biome map pass

- Changed biome placement from four arbitrary random circles to four broad player-quadrant regions. Every match still shuffles which biome occupies each quadrant, but all four required environments are now guaranteed to be present and each castle starts inside a distinct biome.
- Added a regression assertion that the four castle anchors resolve to all four distinct biome kinds.
- Replaced the one-size-fits-all ground flecks with biome-specific details: wind-carved sand ripples in desert, ice-crystal glints in snow, dark fissures with ember cores in volcanic terrain, and denser grass/wildflower details in forest.
- Kept the existing river and bridge network, map size, castle placement, mine economy, obstacles, movement slowdown, collision and combat rules unchanged. Riverbank foam and stone approaches remain presentation-only.
- Verification status: source edits and regression test are committed, but no green Android/test workflow result has been observed for this batch yet. Visual captures still need review at the target 16:9 gameplay camera before calling the biome art accepted.

### 2026-11-21 — Expand the river network across all four biomes

- Extended generated water from one main meandering river to a two-channel system: a broad main river plus a narrower side stream that joins it. Both have dry bridges; the side stream is kept in the open lane between the left-side castle clearings.
- Added a deterministic safety route for the tributary if randomized paths are rejected, so the second channel is not silently omitted.
- Updated map regression coverage to require at least two rivers, a multi-segment course, and at least one bridge per river across ten deterministic seeds.
- The existing painter already iterates all river objects for bank shading, water fill, moving glints, foam and bridge decks, and the existing water-speed/collision queries already operate across all rivers. Mines, pickups and obstacles are also generated against the full river list, so the new branch participates in the existing world rules.
- Hero pipeline investigation: the current renderer intentionally writes all active heroes to the fixed Ranger render folder because the CI workflow is pinned there; the packer then bundles non-Ranger outputs. The workflow is still failing, and GitHub returned no job records for the failed run, so the exact failing step is not proven. The repository tree currently contains Flame and Shadow source BLEND files; Storm has an animated GLB but no `assets/heroes/storm/source/storm_source.blend` at the active branch head. Do not claim all four sprite atlases exist.
- Verification status: code and regression test committed; no green Android build or test run observed yet. Need a full run without pushing superseding commits, then inspect the actual 16:9 game capture.

### 2026-11-21 — Strengthen river-network regression coverage

- Expanded the river test to inspect every bridge on every generated channel, not only the first/main river.
- Each bridge must lie on its own river, be recognized by the map as a bridge, remain dry, and preserve full movement speed.
- Added a direct check that the tributary's water slows movement using the same water-speed rule as the main channel.
- Latest verification remains pending: the Android workflow was cancelled by a later push before it produced a completed result. The Ranger asset workflow returned a failed run with zero jobs exposed by GitHub's jobs endpoint; no failing step or log is available, so its cause remains undiagnosed.


### 2026-11-21 — Hero render output isolation fix

- Fixed `tools/blender/render_hero.py` so each selected hero writes frames to that hero's configured `output_directory`, instead of routing every render into Ranger's folder. The manifest is now named `<hero_id>_manifest.json`.
- Added a repository-root guard to reject configured output paths that escape the checkout.
- Updated `tools/blender/validate_rendered_frames.py` to load the active hero's manifest name rather than always expecting `ranger_manifest.json`.
- Updated the Ranger-only workflow to explicitly select Ranger before rendering its Ranger source scene. This prevents the checked-in Storm selection marker from asking a Ranger .blend file to supply a Storm rig.
- Commits: `e993a31` (per-hero render output), `66f8c54` (hero-specific validator manifest), `da35ebb` (Ranger workflow selection).
- Verification: repository file updates were accepted by GitHub. Blender render, Python syntax, atlas packing, Flutter tests, and visual review have **not** yet been run for these commits. Do not mark any non-Ranger atlas as generated or visually accepted. The current workflow remains Ranger-only; Flame, Shadow and Storm still need dedicated source-scene/workflow wiring and a four-hero batch validation.
- Next: run the Ranger workflow once without superseding pushes; inspect its logs and artifact. Then generalize workflow inputs/source scenes per hero and add tests for manifest path isolation.


### 2026-11-21 — Four-hero 2.5D matrix pipeline

- Reworked `.github/workflows/flame-2d5-sprites.yml` into a four-job matrix for Ranger, Flame, Shadow and Storm. Each job selects its hero independently, builds that hero's source scene, validates its rig/actions, renders eight directions across all eight states, validates frames, packs atlases, validates the final manifest, and uploads a hero-specific artifact.
- Updated each matrix job to use `assets/heroes/<hero>/source/<hero>_source.blend`, `assets/heroes/<hero>/renders/<hero>_manifest.json`, and the matching hero render directory. This now matches the per-hero renderer and manifest paths introduced in commits `e993a31` and `66f8c54`.
- The shared profile/config remains at `assets/heroes/ranger/source/render_config.json`; its `heroes` map contains the four profiles and per-hero output directories.
- Each matrix runner has an isolated checkout, so writing its own `active_hero.txt` cannot race with another hero's build.
- Commit: `a3a1d4f` — four-hero isolated matrix workflow.
- Verification status: workflow YAML and actual Blender execution have not yet been confirmed by a completed Actions run. The workflow is now configured to trigger on relevant pushes; wait for the run and inspect each hero job before accepting any atlas. A successful technical validation still does not replace visual review against the approved roster reference.


## 2026-11-21 — Isolate the four-hero sprite pipeline

- The four-job matrix run `44945324378` started from commit `a3a1d4f`.
- All four jobs (Ranger, Flame, Shadow, Storm) completed their dedicated source-scene build and passed the source rig/authored-animation validation step.
- Rendering all eight directions and eight states is still running; no atlas pack is considered complete or visually accepted until the remaining frame validation, packing, manifest validation and artifact upload steps pass.
- The old Ranger-only workflow was firing automatically on the same Blender tool changes, creating redundant failing runs against the new shared multi-hero setup. It is now manual-only; the four-hero matrix is the only automatic sprite pipeline.
- Commit: `870cc16` — Retire duplicate automatic Ranger-only sprite workflow.


## 2026-11-21 — Monster reference palette and silhouette pass

- Updated the four procedural fallback monster palettes to match the approved roster: green sword goblin (Runner), steel/brass horned mace brute (Tank), ivory skeleton (Stalker), purple masked infiltrator with violet energy (Ranged).
- Reworked the Stalker fallback body from a generic hooded robe into visible rib-cage/skull anatomy with dark eye sockets and paired blade silhouettes.
- Reworked Ranged fallback into a purple hood/mask and violet energy blades. The existing long-range projectile attack and its combat stats remain unchanged; the blades are visual identity only.
- Reworked Runner's sword and Tank's spiked mace silhouette.
- Added a regression test for the four distinct palette identities and the Ranged 210-unit attack range.
- These are improvements to the procedural fallback only. They are not the final approved sprite actors; the reference-faithful 2.5D monster sprite pipeline remains required.
- Fixed the Flutter analyzer warning from an unused bridge paint local and removed an unnecessary test import.
- Commits: `276c6e8` palette, `bd1f74c` body silhouettes, `d200486` weapons, `5f063cc` regression test.


## 2026-11-21 — Correct the hero matrix to the actual playable roster

- Audited `lib/hero/hero_catalog.dart`: the selectable Ranger is `ranger_new`; `ranger` is explicitly legacy-only and must not be treated as the fourth playable hero.
- Corrected `assets/heroes/ranger_new/source/render_config.json` so its sprite renderer writes into `assets/heroes/ranger_new/renders`, not the legacy Ranger folder.
- Added `tools/blender/validate_ranger_new_source.py` to validate the original playable Ranger's armature, skinned mesh, camera, eight named actions and configured frame ranges.
- Updated `.github/workflows/flame-2d5-sprites.yml`: Flame, Shadow and Storm use the shared per-profile build matrix; the actual playable Ranger gets its own job using the checked-in original `ranger_new_source.blend` and its own render config. The matrix no longer mistakes legacy Ranger assets for the playable hero.
- Commits: `333d053` render-root correction, `05b6dbb` dedicated Ranger validator, `f1d9979` playable Ranger job.
- These workflow changes are queued for CI; do not claim the new four-playable-hero packs passed until each job completes validation and uploads its artifact.


## 2026-11-23 — Reconcile hero visual target and audit

- Re-read the active `ranger-reference-work` branch rather than relying on earlier session claims. The repository still has a temporary mixed runtime state: Ranger/Flame/Storm use the GLB route; Shadow is the only currently approved 2.5D sprite pilot. This does **not** change the final production requirement: all four heroes must become reference-faithful 2D/2.5D sprite actors in the lightweight 3D arena.
- Corrected `docs/HERO_VISUAL_ACCEPTANCE_AUDIT.md` so it explicitly distinguishes the final target from the temporary runtime migration state. It also keeps rejected Flame and Storm atlases rejected and records that Ranger is not visually accepted merely because its atlas manifest is populated.
- Current map implementation remains in `lib/game/world/arena_map.dart` and `lib/game/arena_painter.dart`: four distinct biome regions, two river channels with dry bridges, biome-specific ground detailing, and depth-sorted actors/bridges/castles.
- Current monster rendering remains custom-painted in `lib/game/arena_painter.dart`, with four distinct silhouettes and weapons. The Blender GLB generator is still a review-only prototype workflow; it is not the final in-match monster renderer and its models have not passed visual acceptance.
- This documentation correction is committed as `ad2100f60567c7cb507d39e791ac54b8b1ef14de`.
- **Verification status:** this documentation-only commit has no Flutter/Android test result attached. No claim is made that the four-hero sprite workflow or monster visual acceptance has completed.
- Next: validate the current hero matrix and Ranger-new jobs end-to-end; inspect their generated artifacts rather than trusting manifest counts; then replace the placeholder monster paint shapes with approved reference-faithful 2.5D sprite assets only after a visual review gate exists.


## 2026-11-23 — Fix non-Ranger sprite bundle manifest corruption

- Found a concrete serialization defect in `tools/pack_hero_atlases.py::publish_bundle`: after copying a non-Ranger hero source asset, the bundle manifest was written with the two literal characters `\\n` rather than a newline. That makes the JSON invalid when a source asset is found (Flame/Shadow/Storm paths), even though the original render-directory manifest remains valid.
- Fixed the write to append a real newline.
- Added `test_publish_bundle_writes_valid_json_when_source_asset_exists` in `tools/tests/test_pack_hero_atlases.py`. It creates a temporary Flame bundle, copies a source asset, parses the final bundled manifest with `json.loads`, and verifies the source-asset metadata.
- Commits: `05b6f15b0744ec470ccb9d865ada91cdd0f03d45` (fix), `e815c1e40a0eab3eabda576cdf10099cbd7435a3` (regression test).
- **Verification pending:** the test has been added but has not yet been run in CI. Do not claim the fix is verified until the atlas packer unit-test job completes.


## 2026-11-23 — Make sprite regression tests part of the four-hero CI

- Updated `.github/workflows/flame-2d5-sprites.yml` to run `python3 -m unittest discover -s tools/tests -p 'test_*.py' -v` before Blender scene generation.
- Added `tools/tests/**` to the workflow path filters, so changes to the atlas packer or frame validators trigger the production sprite pipeline.
- This makes the new bundle-manifest regression test an actual CI gate instead of an unexecuted local test file.
- Workflow update commit: `ce81af9cbc7e63a3f0cee1ff35c8f2499a4590fa`.
- **Verification pending:** the updated workflow has been pushed, but no completed Actions run is visible yet. Do not claim Python tests, renders, atlas packing or Android build have passed until run results are available.


## 2026-11-23 — Map pickup clearance and sprite pipeline cleanup

- Fixed map generation order so trees/rocks are placed before resources and chests. Pickup placement now rejects positions within the obstacle collision clearance, in addition to the existing river, mine, castle and pickup-spacing checks. This prevents collectible markers from appearing underneath solid scenery.
- Expanded the pickup map test from one fixed seed to 20 deterministic seeds. It now asserts all expected resources/chests spawn and every pickup remains dry and outside tree/rock collision radii.
- Updated the atlas packer's `publish_bundle` docstring to describe the current isolated matrix-job artifact staging; removed obsolete wording about a workflow token limitation and manual artifact relocation.
- Commits: `df970d155a2aee650ecfca4932fe10d85772afb0` (map generation), `cdb57fcc52435b235c9693b60c687c08cb5d1d93` (20-seed regression test), `a19d4ed02cdd977b194bbbd3c0151d714aad2cbe` (pipeline documentation).
- **Verification pending:** these commits are pushed to `ranger-reference-work`; no completed Flutter or sprite Actions run has been confirmed in this session. The 20-seed map test and the sprite packer regression suite still need a green CI result.


## 2026-11-23 — Final obstacle pass respects pickup reservations

- Follow-up review found a subtle ordering issue in the previous pickup-clearance fix: preliminary obstacles were used to choose pickup locations, but the final obstacle list was the same preliminary list and did not explicitly reserve the selected pickups against later scenery generation.
- Map generation now uses two passes: preliminary scenery reserves clear pickup candidates; after pickups are selected, final scenery is regenerated with the pickup list as a hard exclusion. This ensures the final tree/rock set also avoids every resource and chest.
- The existing 20-seed map regression test checks final obstacles against every pickup, so it now covers the final scenery pass.
- Commit: `dd82d50100fc8b9544ea30939fbaa18eee8ce72b`.
- CI verification remains pending; no passing Flutter/Android test result is claimed.


## 2026-11-23 — Expand randomized biome coverage

- Strengthened the map regression test: the four distinct castle/biome assignments are now checked across 20 deterministic seeds instead of only seed 7.
- The test also verifies that all four biome types remain present and that the assignment changes across generated matches, while each castle remains inside its own biome.
- Test change commit: `0229f6d3ababf8b85791ac8a96c4232964205ef8`.
- Verification is still pending a completed CI run; this records test coverage, not a passing result.


## 2026-11-23 — Diagnose historical sprite-pipeline CI failure

- Retrieved the failed GitHub Actions job logs rather than treating the failure as an unexplained render issue.
- Root cause in the historical run: the validator traversed sibling hero manifests even when CI passed one specific hero manifest. An older checked-in manifest then failed the schema-version check, although the current Ranger/Flame/Shadow manifests shown in the same log passed.
- The current validator has already been corrected: sibling manifests are excluded by default, and repository-wide checks require the explicit `--all-manifests` option. Confirmed this corrected implementation is present in the commit used by the latest sprite workflow run.
- In the latest observed matrix run, Python packer regression tests and each hero's source rig/animation validation completed successfully; all four jobs had entered rendering. Atlas packing, frame-motion validation, visual approval and final artifact upload are not yet confirmed.
- Historical failure log: run `45059816186`. Latest observed matrix run: `45071046416`.


## 2026-11-23 — Fix verified CI rendering failure

- Inspected the failed `build-release-apk` test logs rather than treating the failure as an unexplained pipeline issue.
- The suite reported `Invalid argument(s): "colors" must have length 2 if "colorStops" is omitted` in `ArenaPainter._paintStoneApproaches` at `lib/game/arena_painter.dart:434`.
- The stone-paver gradient supplied three colors but omitted the three matching stop positions. Added explicit stops `[0.0, 0.52, 1.0]`, consistent with the other three-color gradients in this painter.
- Fix commit: `b22ad2c25094e23103b5836021b164a976985cfc`.
- The failing test run was `45071237812`; this fix is committed, but a fresh run must complete before claiming the full suite is green.


## 2026-11-23 — Hero pipeline isolation and configuration regression tests

- Continued work on all four heroes without promoting any rejected sprite atlas or inventing replacement character art.
- Hardened `tools/blender/render_hero.py`: only the four roster IDs are accepted; each render must target its own hero-specific output folder; all eight gameplay states are required; states cannot share Blender Actions; and Action names must belong to the selected hero. This prevents cross-hero rig/action mixups and accidental overwriting of another hero's frames.
- Added `tools/tests/test_hero_render_config.py`, checking all four profiles for complete independent actions, unique output paths, valid frame counts/action ranges, and event frames within the configured source action ranges.
- Updated `docs/HERO_VISUAL_ACCEPTANCE_AUDIT.md` to record these safeguards and explicitly distinguish pipeline integrity from visual approval.
- Commits: `88cb8678585af69709a5f95668b337f1d4fc7b13` (renderer guards), `4b3d7ee52d8f730337b694b12205f49ff054efae` (config regression tests), `a791791c4cfa5a43508aaa8a6349cb1bbae6aa00` (visual audit).
- **Verification pending:** no completed green workflow has yet confirmed this new test or a fresh four-hero render. The hero atlases remain unapproved until visual comparison against the canonical roster reference and 16:9 in-game captures.
- Next: inspect the Android CI run, then run/inspect the four-hero sprite matrix; address specific face, silhouette, weapon and animation defects from actual captures before changing any runtime route.


### Follow-up — Preserve the distinct playable Ranger source profile

- The four-hero render preflight initially exposed a fifth pipeline profile: the actual playable Ranger is `ranger_new`, with lowercase Blender Action names and its own `assets/heroes/ranger_new/renders` output directory. It is separate from the legacy `ranger` profile.
- Updated the renderer guard to explicitly support `ranger_new` without weakening the cross-hero checks for Flame, Shadow, Storm and legacy Ranger.
- Extended the config regression test to validate Ranger-new's eight state mappings and event frame ranges too.
- Commits: `945d3296e772310e46dcbea3e4e7bb72fa403cbe` and `49337955eead15176249f750bf6a3278a209d82f`.
- The earlier matrix run started before this correction; use the new run on the latest commit for verification.


## 2026-11-23 — First successful playable Ranger sprite artifact and visual review

- Retrieved actual GitHub Actions artifact `archer-fm-ranger-new-2d5-sprite-pack` from matrix run `45071818451` (Ranger job `137360235044`, source commit `4b3d7ee52d8f730337b694b12205f49ff054efae`). Artifact size: 40,671,262 bytes.
- Ranger job completed: source rig/action validation, rendering all eight directions and eight states, frame/motion validation, atlas packing/manifest validation, and upload.
- Inspected actual extracted PNG frames in a direction contact sheet and a multi-state motion contact sheet. The artifact is populated and not a blank/placeholder atlas. However, the sampled front-facing face is angled down/partly obscured and several directions are mainly profile/back; reference likeness and in-game readability are not yet approved. Keep the current GLB route until direct reference comparison and 16:9 in-game review pass.
- On that same matrix run, Flame, Shadow and Storm passed their source rig/action validation and entered frame rendering; their final frame validation, atlas packing and uploads were still pending at last check. The latest matrix run on branch head `072c3d23cf113dc6c25c2850f6a30469a214bfeb` is `45071916513` and was still queued at last check. Do not treat the earlier Ranger result as completion of all four heroes or as a green current-head workflow.


## 2026-11-23 — Monster renderer and sprite-matrix follow-up

- Re-audited `lib/game/arena_painter.dart` monster rendering and `lib/game/monsters/monster_models.dart`. The runtime currently has four distinct procedural silhouettes (runner/scarf, armored horned tank, skeletal stalker, purple hooded ranged unit), shared readable team rings and HP bars, walk bob/limb swing, attack lunge/weapon motion, hit flash and burn indicators. This is code-level review only; it is not visual acceptance against the approved monster reference sheet.
- Confirmed `test/monster_system_test.dart` covers the four-type catalog, stat-role separation, level-40 scaling, 20-unit starting roster, purchases/cap, death lifecycle and formation spacing. `test/monster_capture_test.dart` contains a 800x450 direct painter capture for all four types, both teams, gait and attack states; the capture output is written to the runner's temporary directory and is not itself a published artifact.
- Four-hero sprite matrix run `45071818451`: Ranger job `137360235044` remains successful. Flame/Shadow/Storm passed regression tests, scene setup and rig/action validation, but their rendering steps remain in progress. The last available log timestamps were around 2026-11-22 21:32 UTC; no later completion or final atlas validation/upload was visible at this check. Do not call those three complete.
- Current branch head at this check: `37013bb3240dc4601624c396fc80c8528dcae902`. A later matrix run `45071916513` was queued at its older source SHA and does not replace the in-progress earlier run.
- Visual acceptance still requires opening the actual four hero packs and monster capture, comparing faces/silhouettes to the approved reference assets, and checking a representative 16:9 gameplay capture. Keep unapproved hero atlases out of the production route.


## 2026-11-23 — Make monster painter captures available for visual review

- Found that `test/monster_capture_test.dart` wrote its PNGs to the OpenCode-specific temporary path `/tmp/opencode/merge/captures`, while the Android workflow uploads `build/arena-captures/`. As a result, the monster capture test output was not included in the existing visual-capture artifact.
- Changed the test output directory to `build/arena-captures/`, matching the workflow's existing artifact upload step. This makes the four-type monster lineup and gait captures retrievable from CI without adding another workflow or duplicating uploads.
- Verification is pending on the newly triggered Flutter test run; no visual acceptance is claimed until the uploaded PNGs are inspected.


## 2026-11-23 — Stop Android CI from cancelling its own verification

- The Android workflow used `cancel-in-progress: true` for the branch concurrency group. The recent sequence of small, necessary commits repeatedly cancelled the full analysis/test/APK run before it could finish.
- Changed the group to `cancel-in-progress: false` so a running verification can complete; a newer push can wait rather than terminating the active test/emulator job.
- This is a CI reliability change, not a passing test result. Confirm the next complete Android workflow run before claiming verification.


## 2026-11-23 — Close Ranger-new workflow coverage gap

- Audited the four-hero sprite workflow against the separate playable Ranger-new profile.
- Added `assets/heroes/ranger_new/source/render_config.json` to the workflow push-path filter, so edits to the actual playable Ranger profile now trigger sprite generation instead of being silently ignored.
- Added a dedicated `tools.tests.test_hero_render_config` regression-test step to the Ranger-new job before rig validation/rendering. The Flame/Shadow/Storm matrix already runs the full Python test discovery; Ranger-new now receives explicit config coverage too.
- Commit: `63cc898295822306998fabe457ea32b79aa3c642`.
- Verification is pending on the newly triggered workflow. Existing in-progress matrix jobs were launched from older commits and do not verify this workflow correction.


## 2026-11-23 — Expand monster visual capture coverage

- Extended `test/monster_capture_test.dart` with a dedicated combat-feedback capture after the existing lineup and gait captures.
- The new capture puts all four hostile monster archetypes into attack animation and includes hit flash, burn feedback, and a second corpse from the player team (the first corpse is enemy team). This gives CI a more useful image for reviewing combat readability and both-team death silhouettes, not only idle/walk presentation.
- Commit: `54be9fd7c8fb8fd2c6617622090ebabced8514a2`.
- Visual review remains pending until the Flutter workflow uploads the PNG and the actual image is inspected; this is test coverage, not art approval.


## 2026-11-23 — Make map visual captures available to CI review

- Fixed `test/map_capture_test.dart` to write its generated PNGs into `build/arena-captures/`, the same directory uploaded by the Android workflow's visual-capture artifact step.
- Previously map screenshots were written to the OpenCode-specific `/tmp/opencode/merge/captures` path, so CI could run the map capture tests but would not include their images in the downloadable review artifact. The shared build path now includes the map world, fog, minimap, mine, castle and occlusion captures alongside monster captures.
- Commit: `21938f5cf4168e24a62f3841801b2638dba9d957`.
- Pending: wait for Android workflow to complete, then inspect the uploaded PNGs. This path fix does not itself establish that the map visuals pass review.


## 2026-11-23 — Unify visual review capture artifacts

- Routed the remaining visual-capture tests (gameplay, hero closeups, lobby, progression, special abilities and UI) from the OpenCode-only temporary folder into `build/arena-captures/`. Map and monster captures already use that path; all capture suites now converge on the Android workflow's artifact directory.
- Updated the Android workflow to upload whatever captures exist with `if: always()`, even when analysis/tests fail, and changed missing captures from a hard artifact-step failure to a warning. This preserves diagnostic PNGs when a test fails before the complete capture set is produced.
- Updated the hero gameplay capture comment to document the shared path.
- Changes include workflow commit `d2321d444294faa15fa96eb6ac360dd8b114ba88` and the capture-test path commits immediately preceding it.
- Pending verification: the Android workflow has not yet completed on this branch; artifact availability and test success remain unconfirmed.


## 2026-11-23 — Improve monster attack-pose visual evidence

- Adjusted the monster capture test's attack timestamps to the midpoint of the 320 ms attack animation. Previously the capture was taken at the very start of the timer, when the procedural lunge factor is zero; the image showed the attack arm pose but missed the strongest forward lunge.
- The lineup and combat-feedback captures now sample the attack at its peak-lunge phase, making the PNG review more useful for judging attack readability.
- Commit: `7e17fcbe16da62a0f82e97184e0812fa5af24260`.
- This is a capture-timing improvement only; it does not claim the monster art has passed visual review.


## 2026-11-23 — Parallel visual polish: monsters, heroes and biome ground

- **Monsters —** Improved procedural monster face readability in `lib/game/arena_painter.dart`: living archetypes now have distinct pupils and catchlights, a readable mouth line, and the skeletal stalker gets dim ember eyes inside its dark sockets. Existing silhouettes, team rings, HP bars, attack timing, hit flash and burn behavior are unchanged.
- **Map —** Reordered terrain composition so biome colour fields are laid down before the deterministic ground-detail pass. Grass blades, desert ripples and biome-specific marks therefore retain their contrast instead of being muted by the translucent biome tint. No map generation, collision, river, bridge, mine or movement values changed.
- **Heroes —** Raised the ambient component of the GLB per-vertex lighting from 0.68 to 0.73 (with directional contribution reduced correspondingly from 0.32 to 0.27). This is a small fill-light adjustment intended to keep reference faces, eyes and armor readable under the elevated arena camera while preserving directional shading. All-four-hero 3D close-up and eight-direction capture coverage already exists in `test/hero3d_game_capture_test.dart` and will provide the visual review set.
- Commits: `7ddcb78` (monster faces + biome ground layering), `bcfdcd4` (hero ambient fill).
- Validation status: **not yet run on this batch**. Do not treat the lighting or monster-face adjustments as visually approved until the current-HEAD capture artifact is downloaded and inspected. Next: let the new Android and four-hero sprite jobs run; inspect logs and captures, then correct any actual defects found.


## 2026-11-23 — Second expanded visual/gameplay polish batch

- **Monster faces:** added readable brow shapes and a restrained nose highlight to the existing four distinct monster faces; retained the established eye/pupil/catchlight palette and skeletal ember sockets.
- **Map ownership:** overlapping biome circles now resolve ground-detail ownership to the nearest biome centre instead of whichever patch happened to appear first in the list. The soft painter gradients remain intact, while sand/grass/snow/volcanic decals now follow the geographically nearest region.
- **Map readability:** ground-detail decals are suppressed on bridge decks and around resource/chest pickups so decoration cannot visually muddy crossings or interactable markers.
- **Hero readability:** increased the GLB hero ambient fill slightly from 0.73 to 0.75 while correspondingly reducing directional contribution; this is a conservative follow-up to the prior face/armor visibility adjustment.
- Added a 20-seed overlap-ownership regression test in `test/arena_map_test.dart`.
- **Verification pending:** these changes are committed but not yet confirmed by Android/Flutter CI or reviewed from fresh 16:9 captures. Existing in-progress CI runs were launched before this batch.


## 2026-11-23 — Third expanded visual/readability batch

- **Monster combat readability:** added a short attack-trail pass for all four monster archetypes. Tank uses a heavier sweep, runner a quick narrow cut, stalker dual trails, and ranged a restrained energy sweep. The effect is driven only by the existing attack animation clock; damage, hit timing, AI, and projectile simulation are unchanged.
- **Bridge/map validation:** added 20-seed checks at the centre and all four inner edges of every generated bridge deck to confirm the full deck remains dry and keeps normal movement speed.
- **Biome/map validation:** added boundary checks confirming points well outside the generated biome patches return no biome rather than inheriting a fallback region.
- **Monster balance regression:** added explicit role-separation assertions for runner speed, tank durability, stalker reach and ranged attack range.
- **Verification pending:** this batch is committed as one coherent commit. It has not yet passed Flutter/Android CI and has not been visually reviewed from fresh capture artifacts.


## 2026-11-23 — Hero, monster and river readability pass

- Monster rendering: added distinct ground-level movement accents for the four existing roles (tank footfall dust, runner speed streaks, stalker spectral wisps, ranged arcane glint). Effects are presentation-only and are driven by the existing walk phase; movement speed, collision, attack timing and damage are unchanged.
- River presentation: added restrained central-channel shading and inner-water edge glints beneath the existing animated shimmer. Bridge geometry and walkability are unchanged.
- Hero rendering: slightly increased ambient fill from 0.75 to 0.78 while retaining directional shading, to improve face/eye/armor readability at the elevated arena camera. This is a rendering adjustment only and still requires visual capture review.
- Added a 20-seed regression test sampling every river segment to verify unbridged water slows movement and bridge-covered samples remain excluded.
- This batch is committed as a single change to avoid repeatedly superseding the queued Android verification.
- CI and visual captures are pending; no visual acceptance is claimed for hero likeness, monster art, or map polish.
