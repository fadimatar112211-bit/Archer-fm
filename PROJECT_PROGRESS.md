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
