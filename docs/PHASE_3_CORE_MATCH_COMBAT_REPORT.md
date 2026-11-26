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
- Existing persistent unlock/upgrade transactions are covered by tests; weapon stat-scaling remains unapproved and is not fabricated.

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

## Automated validation

All code results below are from commit `7949380d98f551b0d83ab167c57aaab0f7f6b97b` or a later documentation-only commit containing the same code:

| Check | Run | Result |
|---|---:|---|
| Full Flutter analysis + full test suite | [45851259471](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45851259471) | **Success — 265 tests passed** |
| Four-client combat WebSocket integration | Included in run 45851259471 | **Passed** |
| Monster-focused analysis + tests | [45850887419](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45850887419) | **Success — 121 tests passed** |
| Android build/emulator validation | [45851259514](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45851259514) | Retry in progress after Maven Central HTTP 429 on first attempt |

## Explicitly unresolved — do not call the entire Phase 3 release-ready

These items depend on owner-approved balance/design decisions or later infrastructure phases:

1. Permanent reward amounts, kill/crystal reward attribution and final scoring values are not approved. No reward/score values were invented.
2. Weapon upgrade levels persist, but their combat stat-scaling curve is not approved and therefore is not applied as a guessed multiplier.
3. Burn/poison stacking and freeze/stun durations/effects are not implemented as final runtime effects; Ultimate runtime currently validates unlock, energy, cooldown, damage and configured area.
4. The local development gateway is not production authenticated. Account-linked weapon ownership/hero levels require the authenticated account context and cloud persistence planned for Phase 5.
5. The server requires a reviewed external combat configuration. No production balance JSON has been supplied or committed.
6. Phase 2 map quality is still pending an actual gameplay screenshot review. The earlier asset report filename was corrected: technical asset integration is Phase 1, map quality is Phase 2.
7. Physical-device QA and release build/install checks remain in Phase 6.

**Conclusion:** the implemented core match/combat rules are now covered by passing automated tests, including four real WebSocket clients. Phase 3 remains partially open for the explicitly listed design-dependent systems; this report does not claim the entire game or production multiplayer is finished.
