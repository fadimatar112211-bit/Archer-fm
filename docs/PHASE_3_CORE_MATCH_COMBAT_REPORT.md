# Phase 3 — Core Match and Combat Verification Report

**Date:** 2026-11-26  
**Repository:** `fadimatar112211-bit/Archer-fm`  
**Branch:** `feature/match-rules-foundation`  
**Code commit tested:** `7949380d98f551b0d83ab167c57aaab0f7f6b97b`  
**PR:** [#20](https://github.com/fadimatar112211-bit/Archer-fm/pull/20), Draft/open/unmerged.

## Verified implementation

### Manual hero combat
- One accepted attack command produces one hit; repeated attacks before weapon cooldown are rejected.
- Five-hit combo advances independently of Ultimates.
- Combo timing window is mandatory server configuration; the sequence resets when the configured window expires.
- Taking server-confirmed damage interrupts and resets the combo; switching weapons also resets it.
- Basic attacks do not consume energy.

### Ultimates and hero progression
- Four Ultimates remain separate from the five-hit combo and use the roster's level gates 1, 10, 20 and 30.
- Every Ultimate has its own cooldown and an individually configured energy cost.
- Energy regenerates at a configured rate up to a configured cap; insufficient energy rejects the cast without starting cooldown.
- The server publishes current/max energy and cooldowns in player-scoped match snapshots.
- Permanent hero XP/levels are stored per hero, migrate from older version-one saves, preserve independent hero progress and cap at level 40.
- A trusted server-only resolver can load a player's permanent hero level into the match. Client messages cannot set that level.

### Weapons and permanent progression
- All four heroes' three weapons are checked against their own canonical roster.
- The initial weapon is available; locked weapons are rejected unless a trusted ownership resolver approves them.
- Cross-hero weapon IDs are rejected.
- Permanent weapon upgrades are now loaded through a trusted server-side player/weapon resolver and scale both manual combo damage and Ultimate damage. The example config's 4% per level is a first-playtest baseline, not final balance approval.

### Monster army and match world
- Existing monster AI, target selection, formations, melee/ranged attacks, projectile lifecycle, death handling and permanent monster progression remain covered by the focused monster suite.
- Every player must submit exactly 20 starting units before a configured match starts.
- In-match purchases use the authoritative wallet, catalog cost, army capacity and atomic debit/refund path.
- Mine capture/production and physical pickup collection are tested; only the player touching a pickup receives its resources.
- Crystal damage/ownership, full castle fall, territory-validated rebuilding, wallet debit and rebuild restoration are tested.
- Match result logic is tested for last crystal holder, time expiry, score ranking, crystal tiebreak and forfeits.

### Server authority and multiplayer abuse checks
- Added a real four-WebSocket-client integration test using the combat-enabled room factory.
- All four clients enter the same running match, receive four-player public match state and their own 20 starting units, while enemy actors remain recipient-scoped by fog-of-war.
- Invalid movement, forged targets, unaffordable purchases, replayed purchase commands and client-side score injection are rejected.
- Crystal rebuild requests derive ownership from the server-side connection player ID; a forged `ownerId` in the request is ignored.
- The development gateway now refuses to start without an explicit reviewed combat configuration, rather than silently creating lobby-only matches.

## Code changes in this phase

- `lib/game/heroes/hero_combat_runtime.dart`: configurable combo timeout, interruption reset, Ultimate energy costs and regeneration.
- `lib/game/network/match_combat_authority.dart`: trusted hero-level loading, energy wiring and hit interruption.
- `lib/game/network/authoritative_match_session.dart`: hero level/energy snapshots and authoritative `rebuild_crystal` command.
- `lib/game/network/match_combat_configuration.dart`: strict decoder for reviewed combat/economy values; missing/extra monster or Ultimate entries are rejected.
- `lib/game/progression/hero_progress.dart` and `hero_progression_service.dart`: persistent independent hero XP/levels and serialized post-match XP awards.
- `tool/dev_game_server.dart`: requires an explicit combat JSON config; no invented tuning defaults.
- Added deterministic tests for configuration, hero progression, combo/energy, crystal rebuild, mine pickups and four-client WebSocket combat.

Configuration contract: [Match Combat Configuration](match/COMBAT_CONFIGURATION.md).

## Explicit first-playtest balance baseline

A committed, strict-schema development config now exists at [config/match-combat.example.json](../config/match-combat.example.json). It sets a 100-energy pool, 8 energy/second regeneration, Ultimate costs of 30/35/40/50 by unlock tier, a 1,200 ms combo window, and explicit stats/costs for all four monster types. The file is decoded in the Flutter test suite to prevent drift. The tuning rationale and full table are in [Phase 3 Balance Baseline](match/PHASE_3_BALANCE_BASELINE.md).

Run locally with:

```sh
ARCHER_FM_COMBAT_CONFIG="$PWD/config/match-combat.example.json" dart run tool/dev_game_server.dart
```

## Automated validation

All code results below are from commit `7949380d98f551b0d83ab167c57aaab0f7f6b97b` or a later documentation-only commit containing the same code:

| Check | Run | Result |
|---|---:|---|
| Full Flutter analysis + full test suite | [45851259471](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45851259471) | **Success — 265 tests passed** |
| Four-client combat WebSocket integration | Included in run 45851259471 | **Passed** |
| Monster-focused analysis + tests | [45850887419](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45850887419) | **Success — 121 tests passed** |
| Android build/emulator validation | [45851259514](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45851259514) | Retry in progress after Maven Central HTTP 429 on first attempt |

## Remaining scope — do not call the full game production-ready

The following are now implemented in the Phase 3 match runtime and covered by focused tests:
- Authoritative kill attribution and one-time score/resource rewards for player manual attacks, Ultimates, AI melee, ranged monster projectiles and lethal damage-over-time ticks. Crystal destruction remains governed by crystal standings, not monster/hero bounty.
- Trusted permanent weapon-upgrade levels scaling combo and Ultimate damage.
- Live burn, poison, slow, freeze and stun effects, advanced by the authoritative server tick. Crowd-control pauses actions; slow reduces movement; damage-over-time retains trusted source attribution.
- The live arena painter has received a stronger visual pass; it remains projected 2D terrain with 3D actors, not a fully volumetric terrain mesh.

Still outside a Phase 3 completion claim:
1. Production authentication and cloud account persistence are Phase 5.
2. The development match server still requires a reviewed external combat configuration; example tuning values are playtest placeholders, not approved competitive balance.
3. Final visual sign-off still requires a real 16:9 gameplay screenshot compared with the approved in-game reference.
4. APK build and emulator install/launch smoke test are still running on the latest validation attempt.
5. Physical-device QA and four-device network/security/performance validation remain Phase 6.

**Conclusion:** Phase 3 gameplay logic is implemented and the latest Match Rules and Monster Army CI suites pass. The phase is not signed off yet because Android emulator validation and human visual review remain outstanding. This does not claim production multiplayer or the full game is finished.

## Live battlefield visual pass — 2026-11-26

The requested Phase 3 scope explicitly includes a visual improvement pass for the live map. The live battlefield painter now has:

- A layered forest-ground gradient instead of a single flat green fill.
- Deterministic world-anchored grass tufts, small stones and ground flecks. Detail is generated only for the fixed 960x540 camera window and does not use random state or external textures.
- Layered river water with a darker bank, deeper base water and a lighter inner water surface.
- More readable tree silhouettes with visible trunks and overlapping canopy masses; rock obstacles now have layered highlights and ground shadows.

These are presentation-only changes. The authoritative world snapshot, movement, collision, visibility/fog rules, resource ownership, castle state and combat remain the source of truth. The map is still a 2D projected terrain painter with skinned 3D actors layered above it; this pass does not claim a fully volumetric 3D terrain mesh.

The visual code change is committed on `feature/match-rules-foundation`. CI must pass on the final branch head, and a real landscape gameplay screenshot still needs human visual review before map quality can be signed off.

## Trusted weapon-upgrade combat scaling — 2026-11-26

- Added a server-only `weaponUpgradeLevelForPlayer(playerId, weaponId)` lookup to the configured match-session factory. No client message can set or override this level.
- The trusted selected-weapon upgrade level is injected into `MatchHeroState` and `HeroCombatRuntime`; it now scales both manual five-hit-combo damage and Ultimate damage.
- The strict match config now requires `weaponUpgradeDamagePerLevel`. The example config uses 0.04 (4% per upgrade level) only as a first-playtest baseline; it is not a final balance approval.
- Runtime validation bounds the configured growth to 0–25% per level and the trusted weapon level to 0–40.
- Added tests for attack and Ultimate scaling and strict config decoding. Full CI on the final head is required before this integration can be marked validated.

## Kill attribution and live status effects — 2026-11-26

### Kill rewards
- The test match configuration now supplies explicit kill-reward values (monster: 5 score + 3 resources; hero: 15 score + 10 resources). These are first-playtest placeholders, not final balance.
- Player manual attacks and Ultimates award only on the live-to-defeated transition.
- AI melee damage and ranged projectile impacts now report the attacker owner to the same authoritative reward callback. Repeated impacts against an already defeated target do not create another kill event.
- Crystal destruction is intentionally excluded from hero/monster kill bounties; crystal scoring remains owned by the crystal/standings rules.

### Status effects
- Added a deterministic server-owned runtime for burn, poison, slow, freeze and stun, including duration refresh, strongest-slow handling, periodic damage, and expiry.
- Live basic attacks currently apply first-playtest effects by hero: Ranger slow, Flame burn, Shadow poison, Storm stun.
- Selected Ultimates apply stronger effects: the level-20 Ultimates apply each hero's signature control/damage-over-time effect; Storm's level-10 chain applies stun.
- Effects are advanced on authoritative match ticks. Damage-over-time kill credit goes to the latest trusted source player; stunned/frozen heroes cannot move, attack or cast, and stunned/frozen monsters pause their AI action loop. Slow reduces movement without changing attack cooldowns.
- Values are provisional playtest tuning and must be balanced from actual four-player match telemetry.

### Validation at commit `294b2b93454512836e12368bf376588be33925c2`
- Match Rules CI: analysis passed and **278 tests passed**, including exactly-once manual/AI melee/projectile kill attribution and live Flame burn / Storm stun integration tests.
- Monster Army CI: analysis and the monster/projectile/animation test suite passed.
- Android validation on this same head: analyze and Flutter tests passed; debug APK build is still running. Emulator install/launch has not yet been confirmed.
- Final map sign-off still requires a captured landscape gameplay screenshot and visual review. This remains open; the painter is still projected 2D terrain with 3D actors, not a fully volumetric 3D map.


## Final Phase 3 continuation — 2026-11-26

**Current branch head:** `bd804d91ed0c73a1360a0b329a3dd6bb8d04910c`

- Match Rules CI [45860464814](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45860464814): **success**; `flutter analyze --no-fatal-infos` passed and **282 tests passed**.
- Monster Army CI [45860464960](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45860464960): **success**; focused analysis and monster/projectile/animation tests passed.
- Android validation [45860452966](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45860452966): analysis and full Flutter tests passed; debug APK build is still running, followed by emulator install/launch.
- Latest arena visual changes include denser world-anchored ground details, layered water and ripples, timber bridge planks/rails, castle merlons, glowing crystals/mines and clearer chests/resource pickups.
- The pull request remains Draft/open/unmerged. No merge was performed.
