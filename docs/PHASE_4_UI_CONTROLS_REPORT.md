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


## Seventh implementation batch — reconnect and room-response correctness

- Corrected a subtle timeout issue: the 12-second room-response deadline is no longer cancelled merely because the WebSocket transport connected. It remains active until the server sends the room welcome, preventing a silent stuck setup if the socket opens but the room handshake never completes.
- Added an explicit Arabic message while automatic room reconnection is underway.
- Session expiry now presents an actionable Arabic explanation to create or join another room.
- Commit: `dea6d165cc96a8ebcd32e24ab367d0b6ad976b09` (deadline/session handling) and `454d111b8244baf1515c933b743af0248d85a269` (reconnect status UI).


- Added live combat guidance beneath the HUD stats: explains one-tap/one-hit behavior and the five-hit combo, and gives Arabic reasons when controls are unavailable due to respawn, connection loss, non-running phase or attack cooldown. Commits: `ee765490f8c5f6ad52b543ef1952ae8d73149098`, `43061e83eadf9cd8449f828c2086643d123405a3`.

- The room retry action now remains visible even when the WebSocket reports connected but the server never completes the room welcome handshake. Commit: `dd51d5c6cda0cdce3b82fd0a5e486f3a45fe2318`.


## Validation correction — armory import

- The first Android validation run after adding the armory failed at `flutter analyze` because the new screen used an incorrect relative import for the existing canonical roster. The roster itself exists at `lib/game/heroes/hero_roster.dart`; the import is corrected to `../heroes/hero_roster.dart` in commit `2548bdd377913c4065816c7bcdf844edbee9dacf`.
- The failed run skipped Flutter tests and APK build because analysis stopped the job. Do not count that run as passing. A fresh validation against the corrected branch head is still required.


## Latest CI failure analysis and test correction

- The latest full Flutter test run reported 289 passing and 3 failing tests. All three failures were widget tests searching for list entries that were below the visible viewport; the failures were not analyzer errors or reported application exceptions.
- Updated the armory test to scroll to the level-30 Ultimate before asserting it, the home test to scroll to the armory tile before tapping, and the settings test to scroll to the haptics control before inspecting/toggling it.
- Commits: `ca91daec9fb150347dd449d5264fb27bc18e03e2`, `f49d8d82eb2381b95ff2bf01bf155393a5e11b04`.
- These are test corrections only; the corrected full suite still needs a fresh CI result. The earlier run's APK build was skipped because the test step failed.

## Remaining Phase 4 work

1. Account/profile and cloud identity are Phase 5 work; the home navigation, read-only armory, and authoritative match-result panel are now present. Add any further post-match return/requeue flow only when the server protocol supports it.
2. Audit every player-facing string for English leaks, RTL issues, truncation and numeric formatting.
3. Improve match setup connection lifecycle: reliable busy state, timeout/error feedback, retry affordances and explicit reconnect/session-expired messaging.
4. Verify joystick, attack, Ultimate, manual target cycling and unit-purchase controls, including disabled reasons, touch hit areas and a visible arena highlight for the selected target. Automated layout coverage now includes 640×360, 1280×540 and 1600×720 landscape viewports; physical touch-device verification remains outstanding.
5. Add clear empty, loading, success/confirmation and match-finished states.
6. The read-only armory now presents canonical weapons and Ultimates. Actual inventory ownership, unlock and upgrade transactions must remain server-authoritative and are not simulated in the UI.
7. Connect actual audio assets and settings only when the assets/runtime exist; until then keep the limitation explicit.
8. Responsive widget coverage now exercises compact and wide landscape setup screens and the battlefield/selected-target layer. The visual-capture fixture now includes an actively selected enemy monster so the target-ring render path is exercised in CI. A full live-HUD overlap check with an authoritative running-match stream and physical device remains outstanding.

**Do not mark Phase 4 complete** until the remaining flows and automated UI checks pass. Physical touch-device usability and audio verification remain device QA items; no emulator is run automatically during this phase.


## Arabic player identity presentation correction

- Match result summaries now map the local player to "أنت" and other participants to stable ordinal labels instead of exposing transport/player IDs.
- The live match standings use the same player-facing approach, so internal IDs such as `p1` and `p2` are not shown in the HUD. The room setup screen also confirms player membership without printing the internal room player ID.
- Added/updated result-panel widget expectations for winner and tie labels without raw IDs.
- Commits: `36dcb19d538b7958a29a15c7ae7ac9eb30523df5`, `f517fc8b15b76406b9f61c98d416811c746d9cd1`, `3510e38e12d366ae8b0de9e28cdd849f99d831a6`.
- Validation is running on the newest commit; do not count it as accepted until the corresponding Android validation and test workflows finish successfully.


## Eighth implementation batch — connection lifecycle disposal safety

- Added a mounted-state guard after the asynchronous previous-client disposal in room create/join setup. If the player leaves the screen while cleanup is awaiting completion, the screen no longer proceeds to create a new socket or call `setState` on a disposed widget.
- Commit: `0a2f745fb237c4cac96d3cffbfaa20a11ccc2517`.
- The change requires fresh CI validation; it is not counted as passed until the new workflow completes.


## Ninth implementation batch — combat touch targets and assistive semantics

- Increased the live attack button's minimum touch area to 120×56 logical pixels and each Ultimate button to at least 88×52.
- Added explicit button semantics for screen readers, including whether each Ultimate is currently enabled and its lock/cooldown/ready hint.
- Clarified in the attack/Ultimate accessibility hints that target selection currently chooses the nearest visible enemy automatically; this does not claim a manual target-picker exists.
- Commit: `ec1cf685c40a0965af5068412e60e32ecd990846`.
- Fresh CI validation is required for this change; physical-device touch verification remains outstanding.


## CI evidence — previous validation head

- Commit `dfccde948053f7d7bb4fa67eb88e08840b1efddc` completed all four relevant workflows successfully: Android validation run `45897633608`, Match Rules run `45897633519`, Monster Army run `45897633546`, and arena visual capture run `45897633593`.
- Android validation completed `flutter analyze`, the full `flutter test` suite and `flutter build apk --debug`; the Android artifact `archer-fm-android-validation` was uploaded (artifact ID `15155016256`). The emulator runner was skipped by its manual-dispatch guard, so no emulator execution is claimed.
- This CI evidence predates the subsequent lifecycle and touch/accessibility commits (`0a2f745...` and `ec1cf68...`). Their own validation runs are pending/in progress and must pass before these changes are certified.


## Tenth implementation batch — manual enemy target cycling

- Added a stable enemy-target candidate list sorted by distance from the local player's authoritative position. It includes living enemy heroes, enemy monsters and living enemy crystals, while excluding own entities, defeated heroes and destroyed crystals.
- Added a live HUD **تغيير الهدف** control. Repeated taps cycle through available targets; attacks and Ultimates now use the manually selected target while it remains in the latest authoritative snapshot. If it disappears, combat safely falls back to the nearest available enemy.
- The server remains authoritative for ownership, visibility, range, energy, cooldown and damage validation. The client-side selector only chooses the target ID sent with the action.
- Added a unit test for deterministic distance ordering, in addition to the existing nearest-target, own-entity, defeated-hero, destroyed-crystal and missing-position tests.
- Commits: `916770b640c15ceb7393ab7d8f201be4572f40c2` (ordered target candidates), `f404c7b1e244142e94e058a535a30ec8b3404d2a` (ordering test), `39daf5a200509bbc548825978ab6e198e104bbda` and `03bd74e60134b74943611871fef69b215614ba04` (live HUD control and stale-selection fallback), `55e8923af290ce5f23432e8f10a3a2a0aa4f5b90` (sortable candidate list).
- Fresh CI validation is required. The previous run against the earlier automatic-target-only code is not evidence for this implementation. Device-level visual confirmation that the selected target is highlighted in the arena is still outstanding; this batch adds a HUD selection control but does not yet draw a target highlight around the chosen entity.

## Current validation after manual-target implementation

- Latest code commit: `55e8923af290ce5f23432e8f10a3a2a0aa4f5b90`.
- Flutter Android validation, Match Rules, Monster Army and arena visual capture must complete on this exact commit before the new target-selection code is considered verified.
- No emulator/device result is claimed unless the corresponding workflow step actually runs and completes.


### Manual-target visual feedback follow-up

- Connected the currently selected target ID to the arena render layers.
- Added a gold selection ring around selected enemy heroes and monsters in the 3D actor layer, and around selected crystals in the battlefield painter.
- The ring follows the same snapshot positions and visibility-limited entities used by the arena renderers; it does not create client-side movement or alter server combat validation.
- Commits: `1d7a1d4ab1853285031d49173551712ccbbe7456` (crystal highlight), `5816344468da84254c0afde59b5363570c79640d` (hero/monster highlight), `4150aab672943259851082e315a3fd18993db695` (wire selected target into arena).
- Fresh Flutter analysis, widget/unit tests and arena visual capture are required for this renderer change. No screenshot or device result is claimed yet.


- Added the selected-target ID to the battlefield painter's repaint conditions, so changing targets redraws the crystal selection ring even when the authoritative snapshot itself has not changed. Commit: `7e9cf63016d71427925c0632131b26d56a5c65d8`.


## Eleventh implementation batch — landscape responsiveness and purchase controls

- Increased all four live unit-purchase buttons to a minimum 88×48 logical-pixel touch target, matching the accessibility baseline used by the combat controls.
- Added Arabic screen-reader labels and contextual hints to each purchase button. The hint clarifies that the server checks match currency and capacity before accepting a purchase; the client does not simulate a successful purchase.
- Added responsive match-setup widget coverage at 640×360, 1280×540 and 1600×720 landscape sizes, asserting that setup and army confirmation remain reachable without layout exceptions.
- Added battlefield rendering coverage at compact and wide landscape sizes with a selected enemy crystal, and updated the 960×540 visual-capture fixture to render a selected enemy monster highlight.
- Commits: `50121462eda27250bbaebecd1ae85bd74f08ed50` (purchase touch targets/semantics), `8acbd0356f30e0f4f7450abd07ba953e3df807b6` and `0a796e1671eb6c66edd987db79b2ba5178287740` (responsive setup tests), `d272514161460f56d1768b8546d4c30d5bba9ee0` (selected-target visual capture), `9fd0444063aad27d3c706264a9e41b82ebe631c3` and `42e98dbd027b83155065caf0c6933990e5cc891f` (battlefield responsive test and viewport cleanup).
- These tests were added to the branch and require a fresh complete CI result. The capture workflow can prove that the renderer generated the selected-target scene; it does not replace visual review on a physical phone.


## Validation evidence for the eleventh batch

- Latest branch head recorded with this report: `c8f4432d0b60e9a7e46f7371b974de94e85eddf7`.
- On this exact commit, Match Rules checks passed (run `45899552735`), Monster Army checks passed (run `45899552683`), and the arena visual-capture workflow passed (run `45899552810`).
- The Android workflow `45899552698` has completed `flutter analyze --no-fatal-infos` and the full `flutter test` suite successfully. Its debug APK build is still running; artifact upload and final workflow completion are not yet confirmed.
- No emulator or physical-device execution is claimed. The emulator step remains guarded for manual dispatch.


## Twelfth implementation batch — verified landscape widget coverage

- Added a real responsive widget test for match setup at 640×360, 1280×540 and 1600×720. It verifies that the setup screen remains scrollable and does not throw layout exceptions at each size.
- Added a real battlefield widget test at 640×360 and 1280×720 with an enemy crystal explicitly selected. This exercises the selected-target render path at compact and wide 16:9 landscape sizes.
- These tests are committed separately from the earlier renderer implementation so the coverage is present in the actual test files, not only described in this report.
- Commits: `269f58b1bd9866410840da739e6db60d42ef19de` (setup size coverage), `b086c35865d2d00d3e4e98eca0a4e4d798cbfa09` (viewport cleanup), `3a11a47e49d3947f9cdd59b456e1284313ec7428` (battlefield selected-target size coverage).
- The 960×540 production arena visual capture already passes on the preceding code head; these new tests require fresh CI on the current head.

## Audio asset audit and Android build status

- A recursive repository asset audit found no `.mp3`, `.wav`, `.ogg`, `.m4a`, `.aac` or `.flac` files and no `assets/audio`, `assets/sounds` or `assets/music` directories. The project also has no audio playback dependency configured. Therefore no genuine music or gameplay sound effects can be connected or verified without approved audio assets and a playback implementation; no placeholder audio is presented as finished.
- On code head `c8f4432d0b60e9a7e46f7371b974de94e85eddf7`, Android validation has now passed `flutter analyze --no-fatal-infos`, the full `flutter test` suite and `flutter build apk --debug`. Emulator setup and artifact upload are still pending at the time of this report update.
- Match Rules, Monster Army and arena visual-capture workflows all passed on `c8f4432d0b60e9a7e46f7371b974de94e85eddf7`. The new responsive widget tests are not covered by those earlier successful runs and need a fresh validation cycle.


## Thirteenth implementation batch — immersive live match presentation

- Replaced the running-match presentation embedded in the long setup ListView with a dedicated full-screen landscape battlefield.
- The authoritative arena now fills the live screen. Health, level, five-hit combo, resources, crystal count, monster count and connection status are overlaid at the top.
- The movement joystick is anchored bottom-left. Manual attack, target cycling, all four level-gated Ultimates and four unit-purchase controls are anchored bottom-right in a translucent control panel.
- Kept the existing server-authoritative command path, target selection, cooldown/level gates and accessibility semantics; this is a presentation/layout change, not a client-side combat simulation.
- Added a widget integration test using a local WebSocket host. It sends a real room welcome and running-state snapshot, then verifies that the live screen shows the arena and joystick/attack/target controls without the old setup AppBar or embedded HUD card.
- Commits: `c517e62a9cae011a0188b2aac08c0e5e0fd6188d` (immersive live screen), `59e2605262c18f02fac46bc61c5c9dcc9e0a4155` (live screen WebSocket widget test).
- The previous APK artifact belongs to pre-immersive code head `c8f4432d0b60e9a7e46f7371b974de94e85eddf7`; it is not the release candidate for this latest screen. A fresh Android build and full test result are required for the new head.

**Current Phase 4 status:** the running-match UI now uses the intended full-screen arena layout, but the latest integration/responsive tests must pass CI. Audio assets/playback and physical-device touch/audio verification remain outstanding. Do not mark Phase 4 complete yet.
