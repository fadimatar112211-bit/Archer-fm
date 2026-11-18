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
