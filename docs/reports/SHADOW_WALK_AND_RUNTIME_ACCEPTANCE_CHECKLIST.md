# Archer FM — Shadow walk and hero-render acceptance checklist

Branch: `ranger-reference-work`

This checklist turns the approved conversion plan's direction/frame/pivot/event/capture requirements into checks that can be evidenced independently. A structural pass is not visual approval and is not runtime integration approval.

## A. Shadow's user-supplied walk sheet — structural checks

- [x] Manifest contains `walk_s`, `walk_sw`, `walk_w`, `walk_nw`, `walk_n`, `walk_ne`, `walk_e`, and `walk_se`.
- [x] Every directional walk clip contains exactly four ordered frame IDs.
- [x] All eight directional entries point to the same source image: `shadow_walk_8dir_4frames_FINAL.png`.
- [x] Each direction's metadata resolves exactly its four clip frame IDs.
- [x] Each cell is 192×192, untrimmed and unrotated; four cells occupy x=0,192,384,576 on one 192-pixel-aligned row.
- [x] The eight direction rows are distinct; source atlas metadata is 768×1536 (4 columns × 8 rows).
- [x] Manifest and atlas metadata use the approved 0.5 / 0.86 pivot.

Structural evidence: `assets/heroes/shadow/renders/shadow_manifest.json` and the eight `walk_<direction>_user.json` metadata files.

## B. Visual acceptance — not yet passed

- [ ] Inspect the original user-supplied sheet and all 32 extracted frames at full resolution.
- [ ] Confirm the original character identity, face, weapon, silhouette and colors remain unchanged.
- [ ] Confirm true RGBA alpha and no checkerboard pixels, halos, clipping or baked ground shadow.
- [ ] Compare all eight directions against the approved source; no guessed/reversed facing.
- [ ] Capture Shadow in the actual 16:9 arena at gameplay scale and inspect feet/pivot/scale.

## C. Shared sprite runtime — required tests

- [x] Regression test added for one-shot clip completion after a delayed frame tick; it asserts the frame-zero event and impact event are not repeated.
- [ ] Run the new Shadow walk structural test and SpritePlayer test in Flutter CI.
- [ ] Verify direction selection against all eight actual world movement directions.
- [ ] Verify elapsed-time animation remains stable under variable render frame times.
- [ ] Verify loop/one-shot transitions and last-facing preservation in the in-game capture suite.

## D. Gameplay event integration — not yet passed

- [ ] Verify the visual impact frame matches the existing combat damage event.
- [ ] Verify one manual attack press causes one attack and holding does not auto-repeat.
- [ ] Verify five-hit combo steps remain distinct from the four level-gated Ultimates.

## Evidence boundary

The structural checks above establish the mapping encoded by the committed JSON metadata only. They do not prove that the PNG pixels are visually correct, that the original image has valid transparency, or that Shadow is already rendered by the production arena. Those gates remain open until image inspection and runtime captures are attached.
