# Phase 3 — Proposed launch balance baseline

**Date:** 2026-11-26  
**Scope:** First playable balance pass for the development gateway. These are explicit starting values selected to unblock full-match playtesting, not claims of competitive balance. Tune only from match telemetry and playtests.

## Hero combat

- Every hero starts with 100 energy.
- Energy regenerates at 8 per second (12.5 seconds from empty to full).
- Ultimate energy costs by unlock tier: level 1 = 30, level 10 = 35, level 20 = 40, level 30 = 50.
- The existing per-Ultimate cooldowns and damage/radius values in the canonical hero roster remain authoritative.
- Combo reset window: 1,200 ms. The combo remains five manual taps, independent of Ultimate use.
- Equal hero health at equal level is retained; movement speed and attack profile remain class-defining differences.

## Monster economy and combat

| Type | Health | Damage | Move speed | Attack range | Cooldown | Cost |
|---|---:|---:|---:|---:|---:|---:|
| Runner | 550 | 20 | 26 | 28 | 900 ms | 10 |
| Tank | 1,600 | 38 | 12 | 30 | 1,400 ms | 25 |
| Stalker | 800 | 28 | 22 | 32 | 950 ms | 18 |
| Ranged | 650 | 24 | 16 | 180 | 1,200 ms | 20 |

The technical army ceiling remains 100. It is a server safety ceiling, not a claim that 100 units should be affordable or deployed in every match.

## Explicit integration command

Use this committed file for the local development server:

```sh
ARCHER_FM_COMBAT_CONFIG="$PWD/config/match-combat.example.json" dart run tool/dev_game_server.dart
```

The decoder remains strict and rejects missing, extra, or invalid monster and Ultimate entries.

## Still required before calling all of Phase 3 closed

This file intentionally does not pretend to implement systems that have no runtime integration yet:

1. Kill/reward attribution: award score and permanent currency only once per authoritative kill; crystal damage and castle outcomes must not double count. The match currently has trusted score APIs, but no complete authoritative kill-reward pipeline.
2. Weapon upgrade combat scaling: persistent upgrade levels exist, but no approved, applied per-level damage/cooldown curve is wired into match loadouts.
3. Status effects: burn, poison, slow, freeze and stun need authoritative durations, stacking/refresh rules, tick damage and snapshot visibility. Roster descriptions alone are not runtime effects.
4. Android APK build and device smoke test.

## Safe first-pass tuning decisions

- Rewards are not granted from client messages. Until the server-side kill pipeline exists, no client can mint score or currency.
- No status effect may be inferred from a descriptive Ultimate label. Only explicit server-applied effects can alter combat.
- Weapon levels must never be read from a client payload; they must be loaded from trusted account progression and supplied to match authority.
- After a first four-player playtest, revise these values based on match duration, unit survival, resource flow, Ultimate frequency and hero win rates.
