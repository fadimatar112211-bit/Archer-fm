# Hero Visual Acceptance Audit

Date: 2026-11-21  
Branch: `ranger-reference-work`  
Canonical visual reference: `assets/references/approved_all/hero_roster_concept.jpg`

## Production rule

**Final production target:** all four heroes are reference-faithful 2D/2.5D sprite actors inside the lightweight 3D arena. GLB/Blender files are retained as source and animation inputs, not as the final in-match character renderer.

**Temporary migration state:** the checked-in runtime still uses the GLB route for Ranger, Flame and Storm; Shadow is the only currently approved 2.5D sprite pilot. This temporary state is not a change to the final target. Keep rejected atlases disabled and do not switch a hero to an unapproved atlas merely because a manifest exists. A GLB file or a non-empty sprite manifest is not, by itself, proof of visual acceptance.

Do not generate substitute character art or silently promote an atlas because it has a manifest. A hero may switch to the sprite route only after its front/side/back views, all eight directions, action states, foot contact, transparency, and in-game captures are reviewed against the canonical reference.

## Current roster evidence

| Hero | Current checked-in sprite evidence | Reference comparison | Production route |
|---|---|---|---|
| Ranger | `assets/heroes/ranger_new/renders/ranger_new_manifest.json`: 64 clips, 8 states, 8 directions; atlases contain 496 declared frames | Rendered atlas depicts a detailed green ranger, but this audit does not approve all views/actions against the reference | Temporary GLB route; final 2.5D sprite acceptance open |
| Flame | `assets/heroes/flame/renders/flame_manifest.json`: 64 clips, 8 states, 8 directions; atlases contain 496 declared frames | Front atlas is a simplified brown-haired fighter with a small flame/torch; canonical reference is a red-spiky-haired knight with gold armor and a large sword. Back/side views exist but do not resolve the identity/detail mismatch | Temporary GLB route; sprite atlas rejected |
| Shadow | `assets/heroes/shadow/renders/shadow_manifest.json`: 64 clips, 8 states, 8 directions; uses the user-supplied `shadow_walk_8dir_4frames_FINAL.png` | Approved hooded purple character source. Walk has four genuine frames per direction. Idle holds the first approved frame. Run currently reuses the walk cycle at a faster cadence. Attack/skill/dodge/hit/death temporarily hold the approved pose while preserving event timing; these are safe placeholders, not final action animation | Only currently approved 2.5D pilot; action-art completion still open |
| Storm | `assets/heroes/storm/renders/storm_manifest.json`: 64 declared clips, 8 states, 8 directions | Inspected idle/walk atlases in S/N/W directions: they are solid blue tiles with no character pixels. A populated manifest is not valid art evidence | GLB primary; sprite atlas rejected as placeholder |

## Source assets retained

- Ranger: `assets/heroes/ranger_new/ranger_animated.glb` and related source/merged GLBs.
- Flame: `assets/heroes/flame/model/flame_animated.glb`, `assets/heroes/flame/source/flame_source.blend`.
- Shadow: approved user sprite atlas under `assets/heroes/shadow/renders/atlases/`.
- Storm: `assets/heroes/storm/model/storm_animated.glb` and original `assets/heroes/storm/storm.glb`.

Keep these source assets intact while producing and reviewing replacement sprite sheets.

## Acceptance checklist per hero

- [ ] Front face and facial expression are legible and match the canonical reference.
- [ ] Hair silhouette, hood/helmet, armor palette, signature weapon and proportions match.
- [ ] Eight directional views are genuinely rendered; no direction reuses an unrelated view.
- [ ] Idle, walk, run, attack, skill, dodge, hit and death are visually coherent.
- [ ] Action events (weapon release/impact/skill burst) still align with the authored frames.
- [ ] Feet remain grounded across every frame; pivot and shadow remain stable.
- [ ] Atlas dimensions, alpha channel, frame rectangles and metadata agree.
- [ ] In-game 16:9 captures at production scale are readable.
- [ ] A reviewer compares captures directly against the canonical reference before route promotion.

## Next work

1. Keep Shadow as the only approved sprite pilot. Finish dedicated Shadow action artwork from approved source material; do not use the temporary held poses as final.
2. Flame: use the preserved source model as the rendering source for a new reference-faithful sprite set; ensure red spiky hair, gold armor and greatsword are visible. Do not use the current simplified atlas.
3. Storm: regenerate the sprite set from the preserved animated source model; replace all flat blue placeholders with real transparent character frames.
4. Ranger: leave the existing benchmark unchanged until its full sprite set has passed the same visual acceptance checklist.
5. After each hero passes visual review, update `HeroRenderPolicy` and add a regression test for the approved route. Do not switch multiple heroes at once.


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
