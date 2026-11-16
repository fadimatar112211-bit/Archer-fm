# Ranger merge: original reference model + the verified 8-animation rig

This document records how the approved original reference model
(`assets/heroes/ranger_reference/original_model.glb`, uploaded to GitHub) was
combined with the animation system built on the developed rig
(`assets/heroes/ranger_new/ranger.glb` → `ranger_animated.glb`), and which
results are real measurements rather than assumptions.

## What the two inputs actually are (measured from the raw glTF JSON)

| Property | `original_model.glb` | `ranger.glb` (developed) |
|---|---|---|
| Vertices / triangles | 270,033 / 501,170 | 45,288 / 77,619 |
| World bounds | x ±0.243, y ±0.282, z 0→1 | x ±0.242, y −0.351→0.212, z 0→1 |
| Skeleton | **none (0 skins)** | 1 skin, 21 joints |
| Animations | **0** | 0 (rigged rest pose only) |
| Material | 1 PBR material, 3 baked textures (basecolor 2.84 MB, rm 2.46 MB, normal 2.43 MB) | 1 PBR material, same 3 textures at reduced size |
| Generator | Tripo | glTF export of the rigged build |

Key facts that decided the merge strategy:

1. The original model is a **static, unrigged mesh** — there is no skeleton to
   "retarget between". The animations live only on the developed rig, so the
   correct transfer is **rigging the original mesh to that rig**, not copying
   keyframes between two skeletons.
2. Both meshes occupy the **same rest-pose space** (identical z range 0→1 and
   x range ±0.24, verified in Blender against world-space bounding boxes, and
   visually via an overlay render — `docs/heroes/ranger_merged_pose_align.png`).
3. The texture names are identical (`archer_boy_3d_model_*`): the developed
   model is a decimation of the same source sculpt.

## Merge method (implemented in `tools/blender/build_ranger_new_animations.py`)

The proven animation-builder gained a `--mesh-glb` merge mode:

1. Import the developed GLB (21-bone rig + its skinned mesh).
2. Import the original unrigged mesh alongside it.
3. Recreate the rig's 21 vertex groups on the original mesh and transfer the
   developed mesh's authored skin weights onto the original surface with a
   `DATA_TRANSFER` modifier (`POLYINTERP_NEAREST`), then normalize every
   vertex. Measured result: **0 of 270,033 vertices left unweighted**.
4. Attach the original mesh to the armature (ARMATURE modifier).
5. Remove the developed mesh — the original mesh with its full-detail
   textures becomes the only visual. The original's materials/textures are
   kept byte-identical (verified: texture byte sizes in the exported GLB match
   the uploaded original exactly).
6. Author the 8 gameplay animations (`idle, walk, run, attack, skill, dodge,
   hit, death`) on the shared rig with the same world-space pose system used
   for the developed build (no retargeting guesses, no name mapping).

The original model is never modified as a reference:
`assets/heroes/ranger_reference/original_model.glb` stays untouched in the
repository; the merge happens on imported copies inside Blender.

## Outputs and backups

- `assets/heroes/ranger_new/ranger_merged_animated.glb` — the merged character
  (original mesh + 21-bone rig + 8 animations), 27.98 MB, 63 channels per
  animation, exported and re-import verified.
- `assets/heroes/ranger_new/ranger_animated.glb` — the earlier developed-mesh
  build, kept as a backup.
- `assets/heroes/ranger_new/source/ranger_merged_source.blend` — production
  render source (orthographic camera + lights + 8 exactly-named actions).
- `docs/heroes/ranger_merged_animations_sheet.png` — 8-pose visual check of
  the merged character.
- `docs/heroes/ranger_merged_vs_developed_compare.png` — merged vs developed
  full-body comparison (idle + attack).

## Verification performed so far (all executed in Blender)

- `ANIM_CHECK` on the merged mesh (final build5): 8/8 PASS
  (idle 0.063 m, walk 0.215 m, run 0.482 m, attack 0.518 m, skill 0.660 m,
  dodge 0.527 m, hit 0.249 m, death 0.716 m max displacement; no NaN; loop
  seams 0.0000; min z ≥ −0.030 on every state except death −0.014; death lies
  on the ground via measured ground-lift keys — auto-lift keeps it at −0.014
  instead of the earlier −0.618 ground sink).
- Weight transfer completeness: 0 unweighted vertices.
- Texture preservation: exported texture byte sizes match the uploaded
  original model exactly (2,843,303 / 2,463,591 / 2,426,635 bytes).
- Visual sheets rendered from the merged GLB show natural motion with no part
  separation; the lying death pose rests on the ground plane.

Sprite atlas production and in-game verification results are recorded in
`docs/ranger_merge_report.md` (final report).

## Renderer compatibility fix

Rendering the merged rig exposed a renderer bug: `render_hero.py`'s
`reset_pose()` forced every bone's rotation mode to Euler XYZ, but the
re-imported GLB actions drive quaternion F-curves — so every posed frame
silently rendered the rest pose. `reset_pose(armature, action)` now clears
each bone with an identity `matrix_basis` and aligns the rotation mode to the
channels the active action actually drives (`rotation_quaternion` →
QUATERNION, `rotation_euler` → XYZ). With the fix, measured framing is a
global orthographic scale of **1.334** (standing figure ≈ 145 px of 192 ≈ 75%
fill, vs 73.4% for the old committed `ranger` set).

## Face weld fix (final pass)

The merged model shipped with its face split into two unwelded mirrored
halves: 2,247 pairs of coincident (≤0.8 mm apart, same y/z, |x| ≤ 0.02)
duplicate vertices shared no edge — 1,504 of them in the face region,
visible as a dark shading crack along the midline (forehead → nose).

Fix (`/tmp/opencode/merge/face_weld.py`):
1. Locate exactly those 2,247 coincident unconnected pairs.
2. Average the vertex-group (bone) weights across each pair before merging
   (only 2 of 2,247 pairs differed by >0.01 total weight; max diff 0.026).
3. Weld only the affected vertices with
   `bmesh.ops.remove_doubles(dist=0.0008)`.
4. Drop the stray `Icosphere` (42 verts) artifact and strip the `_Armature`
   import suffix from the action names before export.
5. Export with the builder's exact settings
   (`export_skins=True, export_animations=True, export_animation_mode="ACTIONS",
   export_morph=False, export_apply=False`).

Results:
- Vertices: 270,042 → 267,969; coincident unconnected pairs after: **0**.
- Largest face-region component now spans both sides (25,401 verts:
  14,741 at x<0 + 10,348 at x>0 connected).
- Skeleton untouched (21 joints); all 8 actions re-validated on the welded
  GLB with evaluated-mesh displacement sampling — idle 0.088, walk 0.214,
  run 0.469, attack 0.503, skill 0.652, dodge 0.566, hit 0.278, death 0.692
  max displacement; no NaNs; min_z ≥ −0.030. Non-loop clips keep their
  expected first/last-frame seams (attack 0.045, death 0.710 = standing vs
  lying, not a defect).
- Textures byte-identical to the original (2,843,303 / 2,463,591 / 2,426,635).
- Before/after renders of the head from front, 45°, both sides and back show
  the midline crack gone and all features unchanged; full-body pixel compare
  (s/n/e: 0 pixels differing >16, w: 9 pixels of slightly different shading
  at the welded body midline — same defect class).
- Backup of the pre-fix model:
  `assets/heroes/ranger_new/ranger_merged_animated_BACKUP_pre_face.glb`.

The face-welded model is the one rendered into the final 496-frame sprite set
and packed into the 64 atlases.
