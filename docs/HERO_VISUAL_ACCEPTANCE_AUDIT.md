# Hero Visual Acceptance Audit

Date: 2026-11-23  
Branch: `ranger-reference-work`  
Canonical visual reference: `assets/references/approved_all/hero_roster_concept.jpg`

## Current approved production direction

The approved project plan is **four reference-faithful 2D/2.5D sprite heroes inside a lightweight 3D arena**. The heroes are camera-facing sprite actors; the environment is the real 3D world. This approved direction supersedes older notes in this audit that described live GLB characters as the final runtime target.

The original GLB/Blender sources may be retained as source material and animation inputs. They are not the final in-match character renderer. Never promote a generated atlas just because it has 64 clips or passes a packer; inspect its actual pixels and compare it with the approved roster sheet first.

## Canonical roster

Exactly four playable heroes exist:

- Ranger — `ranger_new` only. The retired `ranger` character ID and its assets have been deleted.
- Flame — `flame`.
- Shadow — `shadow`.
- Storm — `storm`.

Unknown hero IDs must fail explicitly; they must never silently fall back to another hero.

## Current evidence and route status

| Hero | Current evidence | Status |
|---|---|---|
| Ranger | Original playable source: `assets/heroes/ranger_new/ranger_animated.glb`; generated sprite pack: `assets/heroes/ranger_new/renders/ranger_new_manifest.json` | Canonical hero identity is `ranger_new`. Sprite atlas is not visually accepted; earlier captures showed face/hood/bow readability problems. Keep the safe transitional route until its approved 2.5D pack passes visual review. |
| Flame | Source scene and generated manifest under `assets/heroes/flame/` | Sprite appearance has not passed reference review; the earlier front render simplified the reference and the weapon obscured the face. |
| Shadow | User-approved walk sheet: `assets/heroes/shadow/renders/atlases/shadow_walk_8dir_4frames_FINAL.png` | Temporary sprite pilot only. Walk source is approved; attack/skill/dodge/hit/death remain held-frame placeholders and are not accepted final animations. |
| Storm | Source/model and generated manifest under `assets/heroes/storm/` | Sprite atlas remains rejected; prior inspected idle/walk sheets were blank blue tiles. |

The manifests currently present in the repository are structural data, not visual approval. A valid manifest does not prove that the face, costume, weapon, animation or in-game scale matches the approved reference.

## Acceptance gate for each hero

- [ ] Preserve the approved face, hair/hood silhouette, costume layers, palette and signature weapon.
- [ ] All eight directions are genuine views of the same character; no unrelated view reuse.
- [ ] Idle, walk, run, attack, skill, dodge, hit and death are coherent and visually distinct.
- [ ] Weapon-release / impact / skill events align with their authored frames.
- [ ] Feet, pivot, character scale and alpha edges remain stable across frames.
- [ ] Atlas image dimensions, metadata, frame rectangles and manifest agree.
- [ ] Character is recognizable at the actual 16:9 gameplay camera scale.
- [ ] In-game captures are compared directly with the approved hero sheet before enabling the pack in production.

## Immediate hero priorities

1. Complete Shadow's approved walk pilot and replace its held-frame action placeholders with real source-faithful animations.
2. Review Ranger New's face, hood, bow and cape against the approved sheet; correct readability without changing its identity.
3. Correct Flame's reference mismatch and oversized foreground weapon presentation.
4. Rebuild Storm's blank/rejected sprite views from its retained source and verify the front-facing pose.
5. Enable each hero's sprite runtime route only after its own visual acceptance gate passes.

## Legacy Ranger retirement

- Deleted all files under `assets/heroes/ranger/`; the folder is absent from the active branch.
- Removed the legacy Ranger catalog definition, pubspec asset declarations, generic Blender profile and Ranger-only workflow.
- The only playable Ranger is `ranger_new`; the shared Flame/Shadow/Storm render config now lives at `assets/heroes/render_pipeline_config.json`.
- CI-only sprite bundles are staged under `assets/heroes/_sprite_bundles/`, never under a hero's runtime asset directory.



## 2026-11-21 — Review actual in-game GLB captures and bind-pose fix

Reviewed the 3D hero capture artifact from Android run `44943067801`
(`archer-fm-3d-hero-visual-captures`). Flutter analysis and the full test
step completed before the APK job was cancelled during the release build; the
capture artifact was uploaded.

The isolated close-ups show that the existing "all eight directions" test is
not a visual acceptance test: it asserts that triangles were drawn and that
the projected bounds fit, but does not assert a readable face, intact mesh,
correct front-facing orientation or recognizable weapon.

Observed capture concerns:
- Ranger: several yaw views show severe fragmented/overlapping geometry and
  the face/weapon are not consistently readable.
- Flame: the large foreground weapon/round geometry dominates the front view
  and obscures the face; the reference identity is not yet clear at game scale.
- Storm: the close-ups show fragmented-looking armor/mesh and no consistently
  readable face.
- Shadow: the GLB test capture is not proof of the production route; Shadow
  remains on the approved 2.5D sprite pilot while its GLB is only a test/source.

A renderer defect was identified in `lib/game/render3/glb.dart`: glTF
animation channels are sparse, but the poser reset joints without a channel
(and missing individual TRS channels) to zero translation, identity rotation
and unit scale instead of preserving their bind-pose values. This can collapse
or displace rigidly bound mesh parts.

Fix and regression coverage added:
- Preserve each joint's rest-local matrix and decomposed translation, rotation
  and scale when loading a GLB.
- Initialize every animated joint from those rest values, then override only
  the channels actually authored by the current clip.
- Add `test/glb_rest_pose_test.dart` across all four hero GLBs to verify that
  joints without animation tracks retain their bind pose.

The new Flutter CI run must complete without cancellation before this fix is
considered verified. Then regenerate the four face/yaw capture sets and compare
them again. If fragmentation remains, investigate mesh-node transforms,
inverse-bind handling and the original GLB source rather than weakening the
visual acceptance checks.

## 2026-11-21 — Prevent rejected sprite atlases from appearing after GLB failure

A runtime fallback gap was found during the latest roster review: the painter previously used the loaded sprite atlas whenever the GLB controller was null. If Flame or Storm's GLB failed to load, their rejected placeholder atlases could therefore appear despite the GLB-primary policy.

Fix:
- Added `HeroRenderPolicy.allowsSpriteAtlas(heroId)` as the single explicit sprite-approval check.
- Production `GameScreen` now passes that approval into `ArenaPresentation`.
- `ArenaPainter` suppresses the hero atlas when approval is false. If a non-approved hero's GLB is unavailable, the existing neutral loading placeholder is shown instead of an unapproved character image.
- The painter's isolated preview default remains enabled so dedicated visual-capture tests can deliberately render supplied sheets; the production game path always supplies the policy result.
- Extended `hero_render_policy_test.dart` to assert that Shadow is currently the only production-approved sprite atlas.

This is a safety/consistency fix only. It does not alter hero art, combat, hitboxes, camera, animation timing or GLB source files. CI verification is pending for the new commits.


## 2026-11-23 — Four-hero render isolation guards

The Blender renderer now performs strict preflight checks before touching output:
- Only Ranger, Flame, Shadow and Storm are accepted as hero IDs.
- Each hero must render only into its own `assets/heroes/<hero>/renders` directory.
- The eight required states must all be present in the expected order.
- Every state must reference a distinct Blender Action, and every Action name must use that hero's own prefix. This prevents a valid-looking render job from silently animating one hero with another hero's rig/action set.

Added `tools/tests/test_hero_render_config.py` to check all four shared render profiles for independent action mappings, unique output directories, valid frame counts/ranges and gameplay events that fall inside their source action ranges.

These are pipeline integrity checks, not proof that the resulting faces, armor, weapons or animation quality match the approved reference. The current visual acceptance status above remains unchanged until the generated frames and in-game captures are inspected.


## 2026-11-23 — Inspect the first playable Ranger sprite artifact

- Downloaded and inspected the actual artifact from four-hero matrix run `45071818451`, Ranger job `137360235044` (source commit `4b3d7ee52d8f730337b694b12205f49ff054efae`). The job completed source validation, all eight-direction/eight-state rendering, frame/motion validation, atlas packing/manifest validation, and artifact upload successfully.
- Artifact: `archer-fm-ranger-new-2d5-sprite-pack` (about 40.7 MB; 14-day Actions artifact). It contains the Ranger-new source bundle and per-direction atlases.
- Inspected a contact sheet of all eight idle directions and sampled first/middle/last frames for idle, walk, run, attack, skill, dodge, hit and death. The frames are populated and the eight direction folders are present; the sampled walk/run/attack/skill/dodge/death frames show pose changes rather than empty blue placeholders.
- Visual review is **not accepted yet**: the face is angled downward/partly obscured in the sampled front-facing view, and several views are mostly profile/back. The contact sheet alone does not establish face likeness, fine detail match to the canonical roster sheet, or readable gameplay-scale presentation. Some sampled action poses also need a closer event/weapon review. Keep Ranger on its existing temporary GLB runtime route until a direct reference comparison and in-game 16:9 capture pass.
- This is a successful pipeline/artifact result on the stated source commit, not proof that the current branch-head matrix run has completed and not a final art approval.


## 2026-11-23 — Clarify 3D-only final acceptance

- Removed stale table wording that implied 2.5D sprite acceptance was still a final production goal.
- All four heroes are now consistently described as GLB-route or GLB-migration work with 3D visual acceptance still open. Shadow's sprite remains a temporary fallback, not an approved final visual.
- No hero route, model, geometry, or animation was changed in this documentation correction.


## 2026-11-23 — Face readability source audit (no speculative geometry edits)

Inspected the shared face builder and per-hero headgear source after the in-game captures showed face occlusion/poor readability. The current builder creates layered eye outline/white/iris/pupil/glint patches, upper lashes, lower lids, brows, ears, nose and mouth on the shaped head surface. This means a face disappearing in the arena is not simply a missing-face-generation step.

Source-level risks recorded for the next visual capture pass:
- The face patches are very shallow surface overlays. Their visibility depends on the shaped-head surface, mesh winding/backface handling, skinning and camera yaw; changing eye size or head yaw without a matched render could worsen z-fighting or detach the facial features.
- Shadow's hood opening is procedurally cut by an elevation profile and has a gold brim; its cowl sheets are parented to the head. The source comment explicitly states that the reference has no lower-face mask. Do not add a mask or narrow the opening as a guessed fix.
- Flame's source profile uses a large signature sword and a short cape; the known capture concern is weapon/foreground overlap. Any correction must preserve the reference greatsword silhouette and be verified from the actual gameplay camera, not by shrinking the weapon arbitrarily.
- Storm's circlet/crest and pale hair are distinct from Flame; the existing report of sideways/reclined appearance still requires rest-pose and animation-basis inspection before any per-hero yaw adjustment.
- Ranger's hood/collar, hair and bow need a front gameplay-facing capture after the bind-pose correction; do not change the shared face geometry for one hero until that comparison is available.

No GLB, rig, facial geometry, weapon, yaw, or hero render-policy changes were made in this source audit. The next safe action is to regenerate the four heroes' front/side/back and gameplay-yaw captures from the corrected rest-pose renderer, then make only evidence-backed per-hero corrections.

## 2026-11-23 — Confirm four-hero Ultimate design contract

Source review of `lib/game/combat/hero_kit.dart` and the committed contract tests confirms that the four special/Ultimate abilities are separate from the five-hit manual normal-attack combo. Every hero has four distinct abilities unlocked at levels **1, 10, 20 and 30**; the normal combo remains five taps/hits with multipliers 100%, 110%, 120%, 135% and 155%.

Current ability names in the game data:

| Hero | Level 1 | Level 10 | Level 20 | Level 30 |
|---|---|---|---|---|
| Ranger | وابل متعدد | سهم ثاقب | مطر السهام | اندفاع الرياح |
| Flame | ضربة اللهب | موجة النار | انفجار الجحيم | هياج اللهب |
| Shadow | أنياب التوأم | حجاب الظل | معطف السم | إعدام الظل |
| Storm | طعنة الصاعقة | برق متسلسل | حقل السكون | هيجان العاصفة |

Evidence:
- `test/ultimate_kit_contract_test.dart` checks all four kits, the exact unlock thresholds, four unique ability IDs/names, and the independent five-hit combo.
- `test/hero_kit_progression_test.dart` also checks the unlock boundaries, three weapons per hero, equal base HP and distinct movement speeds.
- `test/xp_progression_test.dart` checks that abilities are persisted when XP reaches the required level.
- `test/special_abilities_capture_test.dart` attempts in-game-state captures for all four heroes' ability effects.

This confirms the design/data contract exists in source and tests; it does not by itself certify balance, animation quality, visual readability, or successful Android runtime execution. Keep those checks separate.

## 2026-11-23 — Inspect uploaded in-game face captures at native resolution

Inspected the actual uploaded `70_game_3d_hero_face_3quarter_idle.png` and `71_game_3d_hero_idle.png` at 800×450, not just the artifact filename.

Observed:
- The 3D hero is present and the GLB renderer is drawing a posed character in the arena.
- At the captured 16:9 gameplay scale the hero occupies only a small central portion of the frame (roughly 55–75 px tall in these samples); facial features cannot be judged reliably at this scale.
- The three-quarter and idle captures do not yet establish a clear, readable face or reference-faithful armor/weapon silhouette. This is a visual acceptance failure, not proof that the face mesh is absent.
- The surrounding scene is partly dark/occluded in the supplied captures. Determine whether this is the intentional capture overlay/viewport mask or the actual production viewport before adjusting world lighting or camera framing.

Required next evidence:
1. Capture a clean full-frame 16:9 gameplay screenshot with all capture masks/overlays disabled, plus a separate close-up inspection render for each hero.
2. Include a ruler/bounds diagnostic for projected hero height and face pixel size; target a clearly legible gameplay silhouette without changing the established arena camera blindly.
3. Capture front, three-quarter and gameplay-facing yaw from the same rest-pose/idle state, then compare headgear, eyes, hair, armor and signature weapon directly against `hero_roster_concept.jpg`.
4. Correct one hero at a time. Do not globally enlarge heads/eyes or rotate all hero rigs to compensate for a possibly cropped capture.

No model, camera, face geometry, lighting, or combat code was changed based on these screenshots alone.


## 2026-11-23 — Four-hero GLB close-up review (run 45194460668)

Reviewed the actual 800×800 isolated yaw captures in artifact
`archer-fm-visual-review-captures` (artifact ID `14827820391`), alongside
the 800×450 in-game captures. This is a visual review of the current checked-in
GLBs, not a review of a new mesh revision.

Observed evidence:
- **Ranger:** the face is identifiable in some yaw samples (notably the
  front-facing half of the sweep), but the oversized cape/bow silhouette
  dominates or intersects the body in several other views. This is not yet a
  clean all-direction production presentation.
- **Flame:** the front-facing close-up shows a large circular foreground
  weapon/guard-like assembly covering much of the torso and reducing the face
  to a small upper detail. The canonical Flame reference is a red/orange-haired
  knight with a prominent flaming sword; the current capture does not establish
  that weapon silhouette.
- **Shadow:** the GLB close-ups show the purple hooded silhouette, but the
  face/eyes remain difficult to read under the hood/mask. Shadow is still not
  the production GLB route; these images are source-review evidence only.
- **Storm:** the sampled yaw sweep remains dominated by rear/side armor,
  pale hair and limbs; no sampled view gives a consistently clear face plus
  signature lightning weapon. The pose/orientation/weapon occlusion source is
  not proven by screenshots alone and must be traced in the source rig and
  animation before changing yaw or geometry.

The capture test currently proves that triangles are emitted and projected
bounds are large enough. It does **not** measure face-pixel coverage, detect
weapon occlusion, or compare the render against the approved image. Keep the
four heroes **NOT VISUALLY ACCEPTED** until a human-reviewed front,
three-quarter and gameplay-facing set passes those checks.

No GLB binary, rig, mesh, face, weapon, yaw, lighting, or combat values were
changed in this review. Next model pass must inspect the exact Blender source
and node/skin transforms for one hero at a time; do not rotate all four rigs
or enlarge faces globally to compensate for model-specific occlusion.
