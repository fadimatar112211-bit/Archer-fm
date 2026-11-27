# Phase 1 — Repository protection and full audit report

**Date:** 2026-11-26  
**Repository:** `fadimatar112211-bit/Archer-fm`  
**Branch:** `feature/match-rules-foundation`  
**Final audited head:** `e9d61832639331a5be7bcbd78b89d2bcf2ddc2f5`  
**PR:** [#20](https://github.com/fadimatar112211-bit/Archer-fm/pull/20) — Draft, open, not merged  
**Scope:** Phase 1 only. No Phase 2 asset integration or visual redesign was attempted.

## Result

<badge>Phase 1 complete</badge>

The repository audit, asset inventory, CI trigger corrections, fog visibility fix, test timeout correction, documentation updates, and final automated checks are complete.

## Work performed

1. Rechecked active branch, PR metadata and latest commit. PR #20 remains Draft/open/unmerged and targets `heroes-complete`.
2. Re-read the complete recursive Git tree: 2,050 blobs; response not truncated.
3. Inventoried hero model files, render manifests, monster assets, docs, tests and Flutter asset declarations.
4. Updated the stale current-status banner in `PROJECT_STATUS.md`, preserving historical project notes.
5. Broadened Match Rules Checks path filters so source, tests, assets, tooling, pubspec and workflow changes on the active branch/PR trigger validation.
6. Expanded Monster Army Checks to cover pushes on the active match branch and PRs targeting `heroes-complete`.
7. Added workflow concurrency cancellation to prevent redundant validation runs stacking for each commit.
8. Removed CI formatting that silently modified the checkout before tests.
9. Investigated prior run `45840088636`: 228 tests passed, one arena fog pixel test timed out after 10 minutes during engine image readback.
10. Moved engine image readback in the widget test to `tester.runAsync`.
11. Fixed a fail-open fog-of-war bug: enemy monsters are now hidden when the local authoritative reveal position is missing. Extended the pixel test to include an enemy monster with no local reveal position.

## Asset inventory findings (technical only)

- Roster references:
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
- `pubspec.yaml` registers the three hero render manifests/atlas directories and `assets/monsters/legacy/`; it does not register the expected animated GLB paths or a Storm render manifest.
- These discrepancies are not evidence of visual mismatch. They are technical integration items for Phase 2 and must be reconciled against the actual merged deliverables before modifying assets.

## Final CI evidence

| Workflow | Run | Result |
|---|---:|---|
| Match Rules Checks | [45843157534](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45843157534) | **Success** |
| Monster Army Checks | [45843157554](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45843157554) | **Success** |

- Full Flutter test suite: **229 tests passed**.
- `flutter analyze --no-fatal-infos`: success.
- Monster-specific analysis: success.
- Monster-specific test suite: success.
- Dependency resolution: success.
- Android build/device validation was not part of Phase 1 and is not claimed.
- Earlier failed/cancelled workflow runs belong to intermediate commits; the two final runs above passed on the final audited branch head.

## Acceptance checklist

| Requirement | Result |
|---|---|
| Current branch and PR state verified | Complete |
| Complete recursive tree inventoried | Complete |
| Hero/monster asset paths compared with roster/pubspec/manifests | Complete; mismatches documented for Phase 2 |
| Stale project status banner updated | Complete |
| CI triggers cover active branch, assets and tests | Complete |
| Monster checks cover PR base `heroes-complete` | Complete |
| Prior arena image-readback timeout addressed | Complete; full suite passed |
| Fog fail-open visibility issue fixed and regression test added | Complete; full suite passed |
| Full Flutter tests | 229 passed |
| Match Rules Checks | Passed |
| Monster Army Checks | Passed |
| PR #20 remains Draft/open/unmerged | Verified |

## Phase 2 handoff

Phase 2 can now begin. It must reconcile the four expected model paths with the actual post-OpenCode deliverables, validate GLBs/skeletons/animations/materials, register correct runtime assets, and prove hero/monster visual layers are wired into a live match. Do not regenerate or replace existing hero/monster art, and do not judge likeness to reference sheets.
