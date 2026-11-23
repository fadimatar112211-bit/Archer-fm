# Archer FM — Unified character-render acceptance checklist

Branch audited: `ranger-reference-work`
Audited HEAD: `75b7920c696a19b3123f096492496c9dd25f0ce2`
Date: 2026-11-24

This checklist applies the approved conversion plan to the four playable heroes. It separates repository structure, image-level visual review, runtime behavior, and device acceptance. A checked structural item never implies visual or gameplay acceptance.

## 1. Shared requirements — every hero

| Gate | Ranger New | Flame | Shadow | Storm |
|---|---|---|---|---|
| Manifest and all required asset paths resolve | [ ] | [ ] | [ ] | [ ] |
| Eight direction names and world-axis mapping verified | [ ] | [ ] | [ ] | [ ] |
| Idle / walk / run / attack / hit / death clips inspected | [ ] | [ ] | [ ] | [ ] |
| Five combo hits are distinct | [ ] | [ ] | [ ] | [ ] |
| Four unique Ultimates exist at levels 1 / 10 / 20 / 30 | [ ] | [ ] | [ ] | [ ] |
| True alpha, no checkerboard, halos, clipping or baked shadow | [ ] | [ ] | [ ] | [ ] |
| Face, costume, colors and signature weapon match approved roster reference | [ ] | [ ] | [ ] | [ ] |
| Feet pivot, scale and ground contact verified | [ ] | [ ] | [ ] | [ ] |
| Close-up and 16:9 gameplay captures reviewed | [ ] | [ ] | [ ] | [ ] |
| Production runtime route verified without changing gameplay | [ ] | [ ] | [ ] | [ ] |

## 2. Shared runtime checks

- [ ] Direction mapping tested for all eight actual world movement vectors.
- [ ] Animation frame selection and elapsed-time timing tested.
- [ ] Loop and one-shot completion tested, including delayed frame ticks.
- [ ] Last-facing preservation tested while stationary.
- [ ] Feet pivot, scale, depth sorting and occlusion checked in the arena.
- [ ] Attack impact animation event aligns with existing combat damage timing.
- [ ] One manual press produces one attack; holding does not auto-repeat.
- [ ] Five-hit combo remains separate from four level-gated Ultimates.

## 3. Per-hero visual review

For each hero, compare the approved roster image with front, three-quarter and gameplay-facing frames. Record the exact source image/atlas and capture paths. Do not redraw or replace user-approved reference art. If a required source is missing or ambiguous, stop rather than inventing a replacement.

## 4. Current evidence snapshot

- The branch's latest commit found during this audit is `75b7920c696a19b3123f096492496c9dd25f0ce2` (commit message: `Test Shadow walk atlas through production runtime loader`).
- That commit adds `test/shadow_walk_runtime_test.dart`, which exercises the production `BundleHeroAssetLoader`, the shared 768×1536 atlas, eight directional walk clips, four frames per direction, 192×192 rectangles, the 0.5/0.86 pivot, and loop wrap behavior.
- A combined commit-status query for that SHA returned no status entries. The PR-filtered workflow-run query also returned no runs for that SHA. This is **not** proof that all workflows are absent; it means this audit has no CI result to report for that commit.
- Flutter test, analyze, format and build commands were not executed by this audit. Do not treat the added test as passed until CI or a local run reports its result.
- This document does not approve any hero visually and does not certify Android runtime integration.

## 5. Evidence required to close a hero

Attach the manifest and atlas paths, actual test command/result and commit SHA, original-reference comparison captures, gameplay-scale capture, and any device/performance observations. Keep the hero's production fallback until all applicable gates pass.
