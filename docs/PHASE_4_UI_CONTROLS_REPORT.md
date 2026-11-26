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

## Remaining Phase 4 work

1. Complete the home/profile/account and post-match navigation without inventing account functionality before Phase 5.
2. Audit every player-facing string for English leaks, RTL issues, truncation and numeric formatting.
3. Improve match setup connection lifecycle: reliable busy state, timeout/error feedback, retry affordances and explicit reconnect/session-expired messaging.
4. Verify joystick, attack, Ultimate, target selection and unit-purchase controls, including disabled reasons and touch hit areas.
5. Add clear empty, loading, success/confirmation and match-finished states.
6. Complete inventory/equipment/weapon presentation using the existing canonical weapon data; do not create duplicate progression rules.
7. Connect actual audio assets and settings only when the assets/runtime exist; until then keep the limitation explicit.
8. Add responsive widget tests for short landscape and wide landscape dimensions, including HUD/map overlap checks.

**Do not mark Phase 4 complete** until the remaining flows and automated UI checks pass. Physical touch-device usability and audio verification remain device QA items; no emulator is run automatically during this phase.
