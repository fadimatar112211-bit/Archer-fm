# Archer FM — Three core sprite-runtime regression additions

Date: 2026-11-24
Branch: `ranger-reference-work`
Latest test commit: `ff4b8d017de867bbafd0e7ba930d363c7c30f324`

## Completed implementation work

### 1. Phase 2 — eight-direction octant boundary regression coverage
Added `test/sprite_actor_clip_resolver_boundary_test.dart`.
- Checks both sides of all eight 22.5-degree direction boundaries.
- Covers positive and negative angles, including the wrap around east.
- Confirms direction choice is invariant to facing-vector magnitude.
- This protects the boundary behavior of the existing world-space octant mapping; it does not change gameplay facing.

### 2. Phase 2 — elapsed-time animation regression coverage
Added `test/sprite_player_timing_regression_test.dart`.
- Checks elapsed-time remainder across multiple render ticks.
- Checks a large delta crossing multiple frames and loops while preserving remainder.
- Checks loop event delivery as frames are entered.
- Checks clip switching resets the frame clock and enters the new clip once.
- Checks one-shot completion does not re-emit events.

### 3. Phase 0 / Phase 2 — production loader coverage for all four heroes
Added `test/all_hero_runtime_loader_test.dart`.
- Uses the production `BundleHeroAssetLoader` for Ranger New, Flame, Shadow and Storm.
- Requires each manifest to expose its 64 clips and 64 atlas entries.
- Decodes every unique atlas image through the runtime loader.
- Verifies every clip frame ID resolves to a correctly sized, in-bounds rectangle.
- Verifies clips sharing an image path reuse the same decoded image, including Shadow's eight-direction walk sheet.
- Groups decoding by image path and disposes the loader after each group to avoid retaining all decoded images simultaneously.

## Verification status and honest boundary

The three test files are committed to the working branch. A combined-status query and the available PR-filtered workflow-run query for the latest test commit returned no status entries or workflow runs. Flutter test/analyze/format/build were not executed by this audit. Therefore these are **implemented regression tests, not passing test results**. Keep the runtime acceptance gates open until CI or a local Flutter run reports actual results.

No hero art, approved reference image, manifest, gameplay rule, render route or GLB fallback was changed.
