# Phase 4 — UI, Controls, Accessibility and Audio

**Date:** 2026-11-26  
**Branch:** `feature/match-rules-foundation`  
**Status:** In progress; first navigation/settings batch committed.  
**Android emulator:** Disabled for automatic Phase 4 validation. Emulator QA is now manual-dispatch only.

## Phase 4 scope

- Complete navigation for the match lifecycle.
- Inventory home, profile/account, hero, weapon, inventory/equipment, settings and match-end screens.
- Arabic-only player-facing text, RTL layout, readable number formatting and landscape safe areas.
- Touch controls for movement, attack, four Ultimates, target selection and purchases.
- Loading, disconnected, reconnecting, error, empty and confirmation states.
- Audio settings/feedback, no advertisements.
- Responsive layouts for small and large landscape phones.

## Implemented in the first batch

- Added an Arabic game hub with direct routes to match setup, the four-hero viewer and settings.
- Made the hub the application entry screen while preserving the existing hero viewer and its injected asset-loader test seam.
- Added a functional haptics preference control. The setting currently lives in screen state; durable preferences belong to the persistence phase.
- Added explicit settings disclosure that music/sound assets are not yet wired. No non-functional audio toggle is presented.
- Added an explicit no-advertising statement; no ad SDK or ad placement was introduced.
- Updated the existing hero-viewer widget tests to enter through the new hub.
- Added widget coverage for Arabic hub navigation, match setup routing, haptics toggle behavior and honest audio status.
- Changed the Android workflow so the emulator-runner step only executes on an explicit `workflow_dispatch`. Push/PR Phase 4 checks still run analysis, tests and APK build, but do not boot an emulator.

## Commits

- `b0c98fc12c8227307cb63eb37141182064ef9deb` — gate Android emulator behind manual QA dispatch.
- `41d24177209ef29a04a32e57f5029f1a5f9b77c4` — add Arabic game hub and settings entry point.
- `ef327628498e790d9d371ffb8d307943941fb909` — launch the hub from the app entry point.
- `e6e97dca02ef061de259aec8bf224fed22fac8d9` — route existing hero-viewer tests through the hub.
- `234c0648e4bc65b63aa8f17ef58299813a13dff8` — avoid settling the continuously animated hero viewer in tests.
- `a63426438cef2f70e7ebfe261fe752e454e34679` — add hub/settings widget tests.

## Validation state

- Phase 3 gameplay implementation and automated match/monster test suites were already passing before this UI batch. The map capture was reviewed as a renderer fixture; it is not a live-device gameplay capture.
- The new Match Rules, Monster Army and Flutter Android validation workflows have been triggered for the UI changes. Their results are pending.
- The Android workflow's emulator step is guarded by `github.event_name == 'workflow_dispatch'`; normal push/PR validation will not start it.
- An older Android run that began before this guard was committed may still be running. This repository integration does not expose a cancel-running-workflow action, so the guard prevents new automatic emulator starts but cannot terminate that already-running job from this session.


## Second implementation batch — room connection lifecycle

- Added a 12-second room-response deadline so the setup screen cannot remain in a silent indefinite busy state when a socket opens but no room welcome arrives.
- Added a visible progress indicator and waiting message while the server response is pending.
- Added a retry action for failed room creation/join attempts, retaining whether the last attempt was create or join.
- Added explicit Arabic messaging for expired room sessions and clearer connection failures.
- Added a widget test proving malformed/missing WebSocket addresses are rejected before any socket attempt.
- The UI listens for connection state changes and clears its busy state on connected, closed, and expired-session states. A room welcome cancels the response deadline.
- Commit: `87e7e66ad5b6d4fc9da30f48f2f931f8f73382a9` — bounded room connection feedback and retry.
- Commit: `89c7152fadd8b9925a30f10d502a96d9bff66661` — connection address validation test.


## Third implementation batch — armory catalogue and safer touch controls

- Added an Arabic armory screen backed directly by the canonical `archerFmHeroes` combat definitions. It lists all three weapons and four Ultimates for the selected hero, their descriptions/ranges/cooldowns and unlock levels.
- Added an armory entry to the home hub and widget tests for home navigation, weapon data and changing between heroes.
- The armory is explicitly read-only: no fake unlock/upgrade buttons or invented prices. Weapon purchases remain authoritative server transactions and account persistence is a later phase.
- Improved the virtual joystick accessibility semantics with an Arabic label and movement hint.
- The joystick now sends a neutral movement command when disposed while a direction is active, preventing stale movement if the gameplay overlay/control is removed mid-gesture.
- Added widget coverage for the joystick semantics and disposal release.
- Commits: `b786cf0083680a0660d02ac1acaba22fe16ceafa` (armory), `efee21efe9c45248b7b81dce7b6689a42cba98e4` (home route), `c6253fff32da3058818fa092a410002fe5d4bc6c` (armory tests), `194562379e912bc5c8564d477c1d5b3f97032115` (home route test), `26b72bdd550eed08475c651ce41473f9904b32be` (joystick semantics and release), `8b5116b8ab033811da68756ac634015bf34814f8` (joystick tests).


## Fourth implementation batch — match results and compact landscape layout

- Added a dedicated result panel consuming the match host's actual `result` payload: winner or tie, finish reason, ordered standings, rank, score, living crystals, forfeits and local-player marker.
- Integrated the panel into the existing live match HUD only after the authoritative phase becomes `finished`. It does not infer a winner from local UI state.
- Added widget tests for timed winner results, tied results and crystal-finish reason.
- Added a short-landscape widget test for match setup scrollability and overflow safety.
- Commits: `876ecfe9e5b654d996cc7b4c9d269079df17e4d1` (result panel), `fed8d80958d19e762fae784f81bb8867642f5f02` (HUD integration), `66ca033ccda26b7863611f90e8dcb4af06fe84e1` (result tests), `3e755b96363c60600172c555ba43287855c53c05` (compact landscape test).


## Fifth implementation batch — live Ultimate controls

- Replaced generic Ultimate labels in the live HUD with each selected hero's actual canonical Ultimate name.
- Each button now exposes a tooltip with the ability name, its unlock level when locked, remaining cooldown when cooling down, or ready state.
- Buttons remain disabled unless the player is alive, connected, in a running match, at the required level and past cooldown; the authoritative server still validates energy, range and all combat rules.
- Commit: `2fee0a14bdebe62fb02b1282f07bebc3cb9db82d`.


## Sixth implementation batch — Arabic UI fallbacks

- Removed raw internal English monster type IDs from the Arabic starting-army list.
- Unknown connection/action errors now show a clear Arabic fallback instead of leaking server reason identifiers into player-facing UI.
- Unknown match phases now fall back to a generic Arabic label.
- Added widget assertions that the internal `runner/tank/stalker/ranged` identifiers are not displayed.
- Commits: `10da6c4acde3418575d228b8a1a9e316040e832b` and `0085fbe0d456eb80262075f5755a69d08b172ca8`.


- Additional Arabic HUD cleanup: attack cooldown is now formatted in seconds with the Arabic unit rather than exposing the English `ms` suffix. Commit: `8213f7d71d6ebe70301ca20be14aef4623d1f2bf`.


- Added a return-to-home action to the authoritative match result panel, so players can leave the finished match and return to the main hub. Callback behavior is covered by a widget test. Commits: `188a5876b92b4dd6e3e01daed30d694ccaee3f3b`, `86eaf43435275361c6aefa6b8b737b62559c0297`, `8e966589680ab04e46e51b77ebb0ff4336a2bc7a`, `aae29afc04b073d2a81dd4cfd03a06b9558e8dba`, `8805c06f5f41c7c5eba453148eef272971dab291`.

## Remaining Phase 4 work

1. Account/profile and cloud identity are Phase 5 work; the home navigation, read-only armory, and authoritative match-result panel are now present. Add any further post-match return/requeue flow only when the server protocol supports it.
2. Audit every player-facing string for English leaks, RTL issues, truncation and numeric formatting.
3. Improve match setup connection lifecycle: reliable busy state, timeout/error feedback, retry affordances and explicit reconnect/session-expired messaging.
4. Verify joystick, attack, Ultimate, target selection and unit-purchase controls, including disabled reasons and touch hit areas.
5. Add clear empty, loading, success/confirmation and match-finished states.
6. The read-only armory now presents canonical weapons and Ultimates. Actual inventory ownership, unlock and upgrade transactions must remain server-authoritative and are not simulated in the UI.
7. Connect actual audio assets and settings only when the assets/runtime exist; until then keep the limitation explicit.
8. Add responsive widget tests for short landscape and wide landscape dimensions, including HUD/map overlap checks.

**Do not mark Phase 4 complete** until the remaining flows and automated UI checks pass. Physical touch-device usability and audio verification remain device QA items; no emulator is run automatically during this phase.
