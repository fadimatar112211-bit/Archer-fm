# Storm render artifact QA — 2026-11-24

## Source evidence
- GitHub Actions run: [Build All Four Hero 2.5D Sprite Packs](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45071818451)
- Run conclusion: `success`
- Source commit: `4b3d7ee52d8f730337b694b12205f49ff054efae`
- Inspected artifact: `storm-sprite-pack.zip` (downloaded from the run's artifact collection)

## Task 1 — atlas image integrity: PASS
- 64 atlas PNGs found (8 animation states × 8 directions).
- Total atlas PNG payload: 18,769,286 bytes.
- All 64 PNGs decoded successfully as RGBA.
- All 64 had a non-empty alpha bounding box, dimensions above 32×32, and more than 8 distinct decoded colors.
- No missing atlas image and no corrupt/empty/flat-color atlas detected.
- Atlas dimensions: 40 at 784×588 and 24 at 784×392.

## Task 2 — manifest and frame mapping integrity: PASS
- Manifest identifies `hero_id: storm`, frame size 192×192, pivot (0.5, 0.86).
- 64 animation clips and 64 atlas entries.
- Coverage: idle, walk, run, attack, skill, dodge, hit, death; each has all 8 directions.
- 496 frame records across atlas metadata.
- Every manifest frame ID exists in its corresponding atlas metadata.
- No repeated frame IDs within a clip.
- No missing atlas or metadata files.
- Clip frame counts: 16 clips × 5 frames, 8 clips × 7 frames, 40 clips × 9 frames.

## Scope and limitations
This report verifies the generated CI artifact only. It does **not** claim that the artifact has been copied into `assets/heroes/storm/renders`, wired into the live runtime, visually accepted against the user's reference, or tested in an Android gameplay capture. Storm remains unaccepted until those separate gates pass. The 2.5D sprite output follows the repository's current approved sprite conversion plan; this QA does not change hero/gameplay design.
