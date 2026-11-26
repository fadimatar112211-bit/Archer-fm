# Archer FM — Full Project Audit & Execution Plan

**Repository:** `fadimatar112211-bit/Archer-fm`  
**Working branch:** `feature/match-rules-foundation`  
**Related PR:** [#20](https://github.com/fadimatar112211-bit/Archer-fm/pull/20) — keep open as Draft; do not merge before integration and full validation.  
**Audit baseline:** 2026-11-26  
**Purpose:** one tracked plan for completing the game from the current repository state, with evidence-based status and acceptance criteria.

## 1. Audit scope and rules

This plan covers the whole Archer FM project: assets and technical integration, map, gameplay, combat, progression, UI, networking, persistence, build, tests, and release readiness.

- **Excluded from acceptance:** judging or reworking whether hero and monster appearances visually resemble their reference sheets. Their technical validity and integration are still in scope.
- **Included:** aesthetic and technical quality of the arena map. The map must be judged in an actual rendered game view, not only from source code.
- Do not replace, regenerate, rename, or overwrite assets being merged by OpenCode. Inspect first; coordinate any missing paths with the active asset integration work.
- Do not claim a feature is complete from the existence of a source file alone. Require runtime wiring and tests or a reproducible manual check.
- Do not invent economy, rewards, prices, scoring, castle rebuilding, mine production, or balance values. Mark unresolved values as decisions.
- Preserve the current branch and Draft PR until integration and validation are complete.

## 2. Verified baseline

The following are findings from the repository tree and source files inspected for this audit. They are not a claim that every test or every device build has passed.

| Area | Current evidence / status |
|---|---|
| Repository inventory | Recursive tree inspected: 2,048 blobs, approximately 168 MB; tree response was not truncated. |
| Heroes | Roster defines Ranger, Flame, Shadow, Storm; three weapons per hero; level cap 40; equal base HP (600) with differing movement speeds; four Ultimate slots at levels 1/10/20/30; five-hit combo is separate. |
| Hero model paths | Roster expects `assets/heroes/{hero}/model/{hero}_animated.glb`. The inspected tree instead showed Ranger source files and `assets/heroes/ranger_new/ranger.glb`, Flame/Shadow source .blend files, and `assets/heroes/storm/storm.glb`. The expected animated GLB paths were not present in that inspected tree. Recheck after OpenCode's merge before changing paths. |
| Hero manifests | Flame, Ranger, Shadow manifests were found; no Storm manifest was found in the inspected tree. |
| Monsters | Monster battle, movement, formation, projectile, combat, animation and progression code/tests exist. Live match renderer wiring still needs a definitive runtime check; do not equate a standalone layer with an integrated match. |
| Arena/map | World/map logic and a Flutter CustomPainter battlefield renderer exist. The renderer is a projected 2D presentation, not a full 3D terrain scene. No dedicated terrain/map model asset was found in the inspected tree. Aesthetic rating remains provisional until a real gameplay screenshot is reviewed. |
| Match foundation | Four-player authoritative session, lobby/WebSocket development host, snapshots, visibility filtering, reconnect flow, movement, purchases and combat authority are present in source. |
| Combat | Manual attacks, combo, Ultimate runtime and hero/monster combat authority are present in source. End-to-end play verification remains required. |
| Castles/mines | Systems exist, but comments/configuration identify provisional values and rules (including crystal rebuild/territory and mine production). Final design values are not approved. |
| Progression | Hero weapon ownership/upgrades and local file stores exist. This is not yet equivalent to production account-linked/cloud progression. |
| UI | Arabic RTL loadout and live match HUD/control elements exist. Full product UI and device usability still need an inventory and verification. |
| Networking | Development WebSocket server is loopback-oriented and explicitly not production-ready: no production TLS/account authentication/database. Matchmaking, private invites, LAN and host migration are not established as production features. |
| Tests | 37 Dart test files were counted in the inspected tree. This is a file count, not a passed-test count. |
| CI at audit time | Workflow run 45840088636: dependency setup, formatting and Flutter analysis succeeded; `flutter test` was still running when polled. Final result must be checked before declaring CI green. |
| PR | PR #20 was confirmed open, Draft, unmerged; head branch `feature/match-rules-foundation`, base `heroes-complete`. |

## 3. Execution roadmap

### Phase 0 — Protect the integration baseline
1. Recheck branch head, PR #20 state, and the latest OpenCode asset-merge commits.
2. Poll outstanding CI run 45840088636 and record its final result and failing test names, if any.
3. Re-inventory hero, monster and map assets after the latest merge; compare actual files against manifests, pubspec declarations and runtime paths.
4. Keep a list of externally owned/in-progress asset paths. Do not overwrite them.

**Acceptance:** branch and PR state recorded; no asset merge overwritten; CI result recorded; asset inventory reflects the latest commit.

### Phase 1 — Complete technical asset integration
1. Resolve hero GLB path/manifest mismatches against the actual merged files.
2. Validate each model file can be parsed/loaded; inspect skeleton, animation clips, materials and texture dependencies. Visual resemblance is explicitly out of scope.
3. Register required assets correctly in Flutter asset configuration and verify loading on device/runtime.
4. Audit monster asset catalogues, missing animation states, projectile assets, manifests and pubspec registration.
5. Prove the live match mounts and updates the intended monster visual layer; fix only the confirmed missing integration.
6. Check map assets/configuration and ensure all referenced resources resolve.

**Acceptance:** no broken asset references; four hero model entries resolve; monster runtime layer demonstrably appears and animates in a live match; no missing runtime asset warnings.

### Phase 2 — Map quality (technical + aesthetic)
1. Capture the current arena from a real running build at target mobile landscape resolution.
2. Review terrain readability, biome distinction, river/bridge composition, obstacles, castle/crystal visibility, mines, spawn spacing, pathing clarity, contrast, depth, lighting/shadows and HUD overlap.
3. Record an evidence-backed aesthetic review with screenshots and a prioritized visual defect list.
4. Improve map composition and rendering without changing gameplay coordinates or authority rules unintentionally.
5. Verify map symmetry/fairness, navigation/pathing, collision boundaries, spawn and objective placement.
6. Re-capture screenshots and compare before/after at phone resolution and different camera/device aspect ratios.

**Acceptance:** map review includes actual screenshots; all critical gameplay objects remain legible; paths/collisions/objectives are correct; visual improvements are demonstrated in a new runtime capture. Do not call the map production-ready based on source inspection alone.

### Phase 3 — Core match and combat verification
1. Verify manual tap = one attack input, five-hit combo sequencing/reset, attack cooldowns and interruption.
2. Verify four independent Ultimate abilities per hero, unlocked at levels 1/10/20/30 and separate from the five-hit combo.
3. Verify all four heroes, their three weapons each, ownership/unlock/upgrade restrictions and server-side validation.
4. Verify equal HP at equal level, distinct intended movement speeds, level cap 40 and XP/level transitions.
5. Test monster AI, targeting, formations, attacks, projectiles, death, rewards and progression.
6. Test crystal/castle damage, ownership, destruction, rebuild, territory and win/score logic.
7. Test mines, resource generation, pickups, spending, starting army (20 units), in-match recruitment and resource synchronization.
8. Run four-player scenarios and adversarial cases (invalid loadout, duplicate purchase, stale snapshot, impossible movement, rapid inputs).

**Acceptance:** deterministic automated tests for core rules; no client-only authority for competitive outcomes; four clients see consistent match state; no unapproved economy values silently treated as final.

### Phase 4 — UI, controls, accessibility and audio
1. Inventory every route/screen and identify missing home, profile/account, hero, weapon, inventory/equipment, settings and match-end flows.
2. Verify Arabic-only strings, RTL layout, number formatting, text overflow and landscape phone safe areas.
3. Verify joystick, attack, Ultimate, target selector and purchase controls on touch devices.
4. Add user-facing loading, connection-lost, reconnecting, error, empty and confirmation states.
5. Verify audio settings and feedback; no advertisements.
6. Test on small and large phone aspect ratios and prevent HUD/map overlap.

**Acceptance:** complete navigation for a match lifecycle; Arabic RTL verified on device; all controls usable by touch; no dead buttons or missing states; ads absent.

### Phase 5 — Persistence and production networking
1. Define authenticated player identity; never trust a client-supplied account identifier as proof of identity.
2. Design production storage for accounts, hero XP/level, weapon ownership/upgrades, inventory/equipment, match results and progression.
3. Add secure authentication, TLS, session expiry/rotation, authorization, rate limiting and input validation.
4. Replace dev-only loopback server assumptions with deployable server configuration and health/metrics/logging.
5. Define matchmaking, private rooms/invites, reconnect policy, server crash recovery and host migration only if required by the final architecture.
6. Add schema/version migration and backup/restore strategy.

**Acceptance:** production identity and persistence survive reinstall/device change; reconnect and recovery tested; transport is encrypted; abuse/rate-limit tests pass; dev server is clearly separated from production.

### Phase 6 — Build, QA and release gate
1. Run formatter, analyzer, complete Flutter tests and all specialized monster/match checks.
2. Build Android release APK/AAB and install/run on a physical Android device.
3. Verify cold start, permissions, landscape mode, assets, memory/performance, network transitions and long-session stability.
4. Execute a full four-player match with disconnect/reconnect and match-end validation.
5. Review CI path filters so relevant tests run for this PR/branch, not only on unrelated branches.
6. Update project status and release notes with actual evidence.

**Acceptance:** all required CI jobs green; release build succeeds and installs; physical-device QA checklist signed off; four-player end-to-end test passes; no critical/high severity blockers.

## 4. Decisions required before final balance lock

Keep these values configurable and visibly marked provisional until approved:
- Crystal/castle rebuild cost, duration, ownership and territory rules.
- Mine production rates and resource caps.
- Score, kill attribution, rewards and match-end tie-breakers.
- Monster spawn timing/scaling and unit prices.
- Match duration and overtime/end conditions.
- Ultimate cooldowns, damage, range, effects and weapon upgrade costs.

Do not block technical integration on these decisions; implement configuration and tests around explicit defaults only where already approved.

## 5. Suggested work order and deliverables

| Order | Deliverable | Dependency |
|---|---|---|
| P0 | CI result + fresh branch/asset inventory | None |
| P0 | Hero/monster asset reference and runtime wiring audit | OpenCode merge status |
| P1 | Live monster integration proof and fixes | P0 inventory |
| P1 | Actual map screenshots + aesthetic review | Runnable build |
| P1 | Map technical/fairness test report | Map review |
| P1 | Core combat/Ultimate/weapon tests | Existing match foundation |
| P1 | Crystal, mine and economy rules decision sheet | Owner approval |
| P2 | Arabic UI and touch-device audit | Runnable build |
| P2 | Persistent account/data architecture | Identity/backend choice |
| P2 | Production network/security implementation | Backend deployment |
| P0 release gate | Android build + four-player device QA | All critical phases |

## 6. Status vocabulary

- **Verified:** supported by inspected code/output and the relevant test or runtime evidence.
- **Implemented, unverified:** source exists, but runtime/end-to-end proof is outstanding.
- **Partial:** some components exist, with known integration or product gaps.
- **Blocked:** requires an external merge, owner decision, backend, or device access.
- **Not started:** no implementation evidence found in this audit.

Update this document after each meaningful batch with commit references, test commands/results, screenshots, and any changed decisions. Never mark a phase complete without its acceptance evidence.


## 7. Phase 1 execution update — 2026-11-26

- Rechecked the active branch after the latest asset-merge work: branch head at audit start was `6f6f2d471597929220ffc72b572e258f172ec4f8`; PR #20 remained open, Draft, unmerged, targeting `heroes-complete`.
- Re-inventoried the complete recursive Git tree: 2,049 blobs, response not truncated.
- Rechecked hero source/model files and Flutter registration. The roster still references four expected animated GLB paths under `assets/heroes/{id}/model/`; those four paths were not present in this branch tree at audit time. The tree showed Ranger source BLEND + `assets/heroes/ranger_new/ranger.glb`, Flame source BLEND, Shadow source BLEND, and `assets/heroes/storm/storm.glb`. Flame/Shadow/Storm expected animated output paths and Ranger expected output path need reconciliation with the actual merged deliverables before Phase 2 can be accepted.
- `pubspec.yaml` currently registers the three hero render manifests/atlases (Ranger, Flame, Shadow) and `assets/monsters/legacy/`; no Storm render manifest or model paths are registered there.
- Found stale `PROJECT_STATUS.md` header dated 2026-11-14 and updated its current-status banner. Historical dated entries remain intact.
- CI trigger audit found Match Rules Checks did not trigger for many asset-only or test-only changes because its path filters were narrow. It now watches all `lib/**`, `test/**`, `assets/**`, `tool/**`, pubspec files and workflow changes on the active branch and PRs targeting `heroes-complete`.
- Monster Army Checks previously targeted pushes to `monster-army-work` and PRs to `main`, so it did not cover this PR's base branch. It now also targets `feature/match-rules-foundation` pushes and PRs to `heroes-complete`, with monster source/tests/assets and pubspec changes as triggers.
- Added workflow concurrency cancellation to prevent a queue of redundant validation runs for every successive commit.
- CI validation no longer runs a formatter that mutates the checkout before tests. Formatting is not silently changed in the CI workspace; analyzer and tests run against the committed source.
- The prior run `45840088636` failed: 228 tests passed, while `test/arena_battlefield_test.dart` timed out after 10 minutes during engine image readback. Updated the test to perform `RenderRepaintBoundary.toImage` and `toByteData` via `tester.runAsync` so engine readback does not wait inside the widget test fake-async zone.
- The same audit found a fail-open visibility condition: when the local authoritative reveal position was absent, enemy monsters were still considered visible and could be painted over the fog. Changed the visibility predicate to fail closed and extended the pixel test to include an enemy monster with no local reveal position.
- New CI runs were triggered by these commits. Phase 1 remains **in progress** until the latest required jobs finish green; do not treat queued/running workflows as passes.

Current commit trail includes workflow trigger/concurrency corrections, the fog visibility correction, and the test readback correction. See GitHub history for exact commit SHAs; the completion report records the acceptance gate.
