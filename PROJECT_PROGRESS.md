# Archer FM — Project Progress & Continuation Checkpoint

> This is the persistent hand-off document for every future work session. Read it before making changes. Update it after each meaningful batch, including commit SHA, CI result, files changed, evidence, blockers, and exact next steps.

## Project identity and working rules

- Active project: **Archer FM**.
- Repository: `fadimatar112211-bit/Archer-fm`.
- Current working branch: `ranger-reference-work`.
- Do not confuse this project with the legacy `Archero_fm` repository.
- Do not switch to or modify `main` unless explicitly requested.
- Target visual direction: polished Archero-like top-down action game, with true 3D chibi heroes, readable faces, visible weapons, clear attack poses, strong skill effects, and responsive combat.
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
