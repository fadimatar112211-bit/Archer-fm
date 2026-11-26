# Phase 1 — Repository protection and full audit report

**Date:** 2026-11-26  
**Repository:** `fadimatar112211-bit/Archer-fm`  
**Branch:** `feature/match-rules-foundation`  
**PR:** [#20](https://github.com/fadimatar112211-bit/Archer-fm/pull/20) — Draft, open, not merged  
**Scope:** Phase 1 only. No Phase 2 asset integration changes were made.

## Work performed

1. Rechecked active branch, PR metadata and latest commit. PR #20 remains Draft/open/unmerged and targets `heroes-complete`.
2. Re-read the complete recursive Git tree (2,049 blobs; not truncated) and inventoried hero model files, render manifests, monster assets, docs, tests and Flutter asset declarations.
3. Updated the stale current-status banner in `PROJECT_STATUS.md` while preserving historical project notes.
4. Broadened Match Rules Checks path filters so source, tests, assets, tooling, pubspec and workflow changes on the active branch/PR cannot silently bypass validation.
5. Expanded Monster Army Checks to cover pushes on the active match branch and PRs targeting `heroes-complete`.
6. Added workflow concurrency cancellation to avoid redundant runs stacking for each commit.
7. Removed the CI formatter step that modified the checked-out files before tests; CI now analyzes/tests committed source rather than silently testing a reformatted workspace.
8. Investigated the previous failing test run. Run `45840088636` had 228 passing tests and one 10-minute timeout in the arena fog pixel test.
9. Updated the image-readback test to use `tester.runAsync` for engine image operations.
10. Fixed a real fail-open fog-of-war bug: enemy monsters are now hidden when the local authoritative reveal position is missing. Extended the pixel test to cover this case.

## Asset inventory findings (technical only)

- Roster references these expected model outputs:
  - `assets/heroes/ranger/model/ranger_animated.glb`
  - `assets/heroes/flame/model/flame_animated.glb`
  - `assets/heroes/shadow/model/shadow_animated.glb`
  - `assets/heroes/storm/model/storm_animated.glb`
- None of those four exact paths were present in the inspected branch tree.
- Files actually present included:
  - Ranger: `assets/heroes/ranger/source/ranger_source.blend`, `assets/heroes/ranger_new/ranger.glb`
  - Flame: `assets/heroes/flame/source/flame_source.blend`
  - Shadow: `assets/heroes/shadow/source/shadow_source.blend`
  - Storm: `assets/heroes/storm/storm.glb`
- Flame, Ranger and Shadow render manifests were present. No Storm render manifest was found.
- `pubspec.yaml` registers the three hero render manifests/atlas directories and `assets/monsters/legacy/`; it does not register the expected animated GLB paths or Storm render manifest.
- These are recorded as Phase 2 integration work, not silently changed during Phase 1.

## CI evidence

- Previous run `45840088636`: **failed** — 228 passed, one timed out in `test/arena_battlefield_test.dart`.
- Latest runs after the fixes must be checked before marking Phase 1 complete. Running/queued jobs are not passes.
- Flutter analyzer in the prior run completed successfully with informational deprecation/unnecessary-import notices and no reported analyzer failure.
- Android build/device validation was not part of this phase and is not claimed.

## Acceptance status

| Requirement | Status |
|---|---|
| Current branch and PR state verified | Verified |
| Complete recursive tree inventoried | Verified |
| Hero/monster asset paths compared with roster/pubspec/manifests | Verified; mismatches documented for Phase 2 |
| Stale project status banner updated | Done |
| CI path filters cover active branch and asset/test changes | Updated; latest CI confirmation pending |
| Monster checks cover PR base `heroes-complete` | Updated; latest CI confirmation pending |
| Previous arena test timeout investigated and corrected | Fix committed; latest CI confirmation pending |
| Fog fail-open visibility issue corrected | Fix committed; latest CI confirmation pending |
| Latest Match Rules Checks green | Pending |
| Latest Monster Army Checks green | Pending |

**Phase 1 is not declared complete until the latest Match Rules Checks and Monster Army Checks runs finish successfully.** If either fails, inspect the logs, fix the underlying issue, and rerun.

## Phase 2 handoff

Phase 2 should reconcile the four expected model paths with the actual post-OpenCode deliverables, validate the GLBs/skeletons/animations/materials, register correct runtime assets, and prove hero/monster visual layers are wired into a live match. Do not regenerate or replace existing hero/monster art, and do not judge likeness to reference sheets.
