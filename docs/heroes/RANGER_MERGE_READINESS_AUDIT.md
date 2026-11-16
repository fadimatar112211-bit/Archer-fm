# Ranger merge readiness audit

Audit date: 2026-11-16
Branch: `ranger-reference-work`
Audited head before this report: `9b0c915a71dd46379bcd5ab5992d0761222e5f71`

## Verified repository inventory

- Original high-detail source mesh: `assets/heroes/ranger_reference/original_model.glb` (22,390,620 bytes; blob `038ac3ac89fc5bcc502296594742863f85807892`).
- Developed rigged model: `assets/heroes/ranger_new/ranger.glb` (3,489,528 bytes; blob `b0498d49acad1a8a96c4bf2f73ecd83bbef1d3b0`).
- Procedural Blender source scene: `assets/heroes/ranger/source/ranger_source.blend` (8,052,352 bytes; blob `698e2fa259fdcdeedfbe7199301dd6d008d0fd4b`).
- Blender source builder: `tools/blender/build_ranger_source.py`.

The developed GLB was copied from `main` onto this branch in commit `9b0c915a71dd46379bcd5ab5992d0761222e5f71`. The original source GLB remains untouched.

## Existing sprite/manifest checks

The checked-in `assets/heroes/ranger/renders/ranger_manifest.json` declares:

- 8 actions: idle, walk, run, attack, skill, dodge, hit, death.
- 8 directions: s, sw, w, nw, n, ne, e, se.
- 64 action/direction animation entries and 64 atlas image + metadata pairs.
- All 64 atlas image paths and all 64 metadata paths exist in the branch tree.
- Every frame ID referenced by the manifest resolves to an existing PNG.
- Frame counts per action/direction: idle 5; walk 9; run 9; attack 7; skill 9; dodge 9; hit 5; death 9.
- Every one of the 8 directional attack entries has exactly one `projectile_release` event.

These are repository/manifest integrity checks. They do not prove visual quality, Blender scene provenance, or that the atlas PNGs were rendered from `ranger_new/ranger.glb`.

## Merge status — NOT YET VERIFIED

No `ranger_animated.glb` or `build_ranger_new_animations.py` exists on this branch at the audited tree. The original high-detail GLB and the developed GLB are both present, but no checked-in merge output or reproducible merge script proves that the original mesh has been skinned to the developed rig.

The existing `build_ranger_source.py` is explicitly a procedural geometry builder based on `ranger_reference_crop.png`; it is not the original-mesh merge step. Its source description says that it generates meshes and rigid-skinning bindings. Do not treat its generated `.blend` scene or the existing sprite atlas set as proof of a successful high-detail-mesh merge.

## Required next validation gates

1. Obtain/restore the complete merge script (the previously shared chat copy was truncated; it is not present in this branch).
2. Inspect the developed GLB armature, deform bones, mesh objects, and all 8 animation clips.
3. Transfer weights from the developed skinned mesh to a copy of the original high-detail mesh in a consistent coordinate space; reject unweighted vertices and degenerate/empty groups.
4. Export a separate candidate GLB; never overwrite either source GLB.
5. Re-import the candidate in Blender and validate that the original mesh is deformed by the target armature across all 8 clips, with finite transforms and no unweighted vertices.
6. Only after visual review and runtime checks should the candidate be promoted to production assets.

## Scope limitation

GitHub repository content was inspected. The GLB binary payloads were not available through the connected file reader for local Blender inspection, and no Blender execution was performed during this audit. Therefore this report deliberately does not claim a successful merge or a Blender render/test pass.

## Additional direct inspection of the original GLB

A local copy of the original upload (`archer boy 3d model.glb`, 22,390,620 bytes) was available for binary inspection. Its glTF 2.0 JSON and mesh geometry were parsed directly:

- 1 scene node, 1 mesh, 270,033 vertices and 501,170 faces.
- 0 skins, 0 animations, and no joint/skin binding on the mesh.
- Mesh bounds are approximately 0.485 × 1.000 × 0.563 in the file's local units.
- The mesh is not watertight (not automatically a defect for an animated character, but relevant if downstream processing assumes a closed solid).

This independently confirms the original GLB is a static, unskinned mesh. It cannot animate by itself. It must receive valid vertex weights and an Armature modifier from the developed rig before it can be exported as an animated character.

The developed GLB's binary could not be fetched into the local runtime through the connected GitHub reader, so its armature, action names, transforms, and vertex-group layout have not yet been independently inspected here. No mesh transfer or Blender export was performed.
