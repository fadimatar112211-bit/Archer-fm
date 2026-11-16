# Ranger (`ranger_new`) — Final Merge Report

Branch: `ranger-reference-work` · Date: 2026-11-16

## Deliverable

- **Final animated model:** `assets/heroes/ranger_new/ranger_merged_animated.glb`
  (27.97 MB, face-welded — one connected face)
- **Pre-fix backup:** `assets/heroes/ranger_new/ranger_merged_animated_BACKUP_pre_face.glb`
  (md5 `50cf36a53de7f316e7f2fb8287819d81`)
- **Production render source:** `assets/heroes/ranger_new/source/ranger_merged_source.blend`
- **Sprites:** `assets/heroes/ranger_new/renders/` — 496 frames (8 states ×
  8 directions) + 64 atlases + `ranger_new_manifest.json`

## Model

- Original high-detail merged mesh: 267,969 vertices (after face weld),
  501,170 polygons, original textures byte-identical
  (2,843,303 / 2,463,591 / 2,426,635 bytes).
- Rig: 21 joints, untouched by the weld; 8 actions: idle, walk, run,
  attack, skill, dodge, hit, death (exact names in the GLB).
- Gameplay events: attack — `bow_draw` @16, `projectile_release` @31;
  skill — `volley_charge` @8, `volley_release` @38. Loop: idle/walk/run.

## Face weld (split-face fix)

- Root cause: mirrored halves unwelded — 2,247 coincident (≤0.8 mm)
  duplicate-vertex pairs sharing no edge; 1,504 in the face region,
  visible as a dark midline shading crack.
- Fix: weight-averaged each pair, welded only those vertices
  (`remove_doubles`, dist 0.0008). Vertices 270,042 → 267,969.
- Verified: 0 coincident unconnected pairs remain; largest face component
  spans both sides (25,401 verts). Before/after head renders (front, 45°,
  both sides, back): crack gone, features unchanged. Full-body pixel
  compare: s/n/e 0 differing pixels >16, w 9 pixels (body-midline shading
  of the same defect class). See `docs/heroes/ranger_merge_method.md`.

## Animation validation (welded GLB, evaluated-mesh sampling)

| action | frames | max_disp | seam (first vs last) | min_z |
|--------|--------|----------|----------------------|-------|
| idle   | 1–48   | 0.088    | 0.000 (loop)         | −0.007 |
| walk   | 1–33   | 0.214    | 0.000 (loop)         | −0.030 |
| run    | 1–25   | 0.469    | 0.000 (loop)         | −0.024 |
| attack | 1–40   | 0.503    | 0.045 (expected)     | −0.015 |
| skill  | 1–56   | 0.652    | 0.015 (expected)     | −0.030 |
| dodge  | 1–28   | 0.566    | 0.000 (loop)         | −0.020 |
| hit    | 1–20   | 0.278    | 0.000 (loop)         | −0.010 |
| death  | 1–64   | 0.692    | 0.710 (standing vs lying — expected) | −0.020 |

No NaNs in any clip.

## Render + atlas production

- `flutter test` renderer fix documented in
  `docs/heroes/ranger_merge_method.md` (quaternion `reset_pose`).
- Full 496-frame render of the face-welded model: EXIT=0,
  `FRAMING measured orthographic_scale=1.334` (standing figure ≈145 px of
  192 ≈ 75% fill; old `ranger` set was 73.4%).
- Manifest `hero_id: ranger_new`, frames 192×192, pivot (0.5, 0.86).
- Atlas packing: "Verified 64 atlases: every tile and padding strip
  reproduces its rendered frame".
- Frame audit: 0 bad frames of 496 (size, alpha bbox, height bounds).
- Visual audit of all 8 states × 8 directions: natural motion, distinct
  directions, death lies on the ground in every direction; face crops show
  a connected face with no midline crack in the new sprites.
- The old `ranger` asset set (`assets/heroes/ranger/`) is untouched
  (git-clean) and `ranger_reference/original_model.glb` is pristine.

## In-game tests (Flutter 3.35.7, real `flutter test`)

- Full suite: **+19 All tests passed**, exit 0
  (`hero_manifest_test.dart`, `widget_test.dart`,
  `ranger_new_manifest_test.dart`).
- `ranger_new_manifest_test.dart` solo re-run: **5/5 passed**, exit 0
  (bundle decodes, every state/direction covered, events intact, 192×192
  tiles, all 64 atlases decode).

## In-game id

- Final hero id: `ranger_new` (`lib/hero/hero_catalog.dart`, `pubspec.yaml`
  updated). The old `ranger` id remains untouched.
