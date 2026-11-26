# Multiplayer sample reuse and integration boundary

Source files reviewed:
- User attachment `archer_fm_multiplayer.zip` (29 archive entries; ZIP integrity check passed).
- User attachment `README.md`.

The source README explicitly marks the sample as unrun and untested. It also identifies these placeholders:
- `PlaceholderRules` instead of the actual combat engine adapter.
- `GridMap.demo` instead of the real arena/castle/crystal coordinates.
- `HeroModelAdapter` as an interface only.
- A file-based profile key as temporary identity, not account authentication.
- Temporary unit and weapon balance numbers.

## Reuse decisions

| ZIP component | Decision | Reason |
|---|---|---|
| WebSocket client | Adapted into `lib/game/network/game_client.dart` | Mobile client handles create/join/resume, reconnect, sequence reconciliation and replay of durable commands only. |
| Reliable command replay | Improved | Only durable selection/progression/purchase commands replay; movement and combat inputs are dropped while offline. |
| Progress/weapon ownership model | Adapted into `lib/game/progression/hero_progress.dart` | Uses the existing canonical hero roster and weapon IDs. Costs and level caps are injected, not copied from provisional ZIP balance. |
| Joystick widget | Adapted into `lib/game/controls/virtual_joystick.dart` | Normalized input, dead zone, release-to-zero and retry while transport rejects movement are covered by widget tests. Final camera projection and HUD placement remain integration work. |
| Selection screen and catalog | Not copied | They duplicate hero/weapon/unit catalogs and use a three-unit sample roster that conflicts with the canonical four monster types and OpenCode's integration. |
| Game HUD | Not copied | It expects the ZIP Match snapshot schema, demo minimap coordinates, and ZIP unit IDs. |
| server/lib/match.dart and world.dart | Not copied | They duplicate existing hero combat, castle/crystal, mine, world and monster systems; they also contain provisional combat rules and different economy/respawn assumptions. |
| server/lib/grid_map.dart | Not copied | GridMap.demo is explicitly a sample map and duplicates the current arena map work. |
| server/lib/weapons.dart and weapons.json | Not copied verbatim | They extend PlaceholderRules and contain unapproved provisional values. The ownership/progression concept is retained in the new domain model. |
| server/lib/store.dart | Not promoted to production | File JSON storage is single-server development storage and the profile key is not account authentication/cloud save. |
| server/bin/server.dart | Not copied yet | It depends on the ZIP Match model and in-memory room registry; a production transport host must be wired to the canonical authoritative game session and account service. |

## Current implementation in this branch

- `MatchRulesEngine` is an isolated four-player match-result/clock rules foundation.
- `GameClient` is a mobile WebSocket transport.
- `WebSocketGameHost` is the transport/room gateway, and `AuthoritativeMatchSession` now supplies a concrete four-player lobby, canonical hero/weapon selection validation, match clock/results, reconnect identity, and forfeit handling. The session factory receives the room creation message so the selected approved match duration is applied.

- `VirtualJoystick` is a reusable control widget; final HUD placement and camera/world-axis projection remain pending.
- `HeroProgress` stores permanent currency, weapon ownership, and per-weapon upgrade levels in a serializable domain model. `HeroProgressionService` applies unlock/upgrade transactions using server-supplied costs and caps; `PersistentHeroProgressionService` loads and saves transactions and serializes concurrent changes per trusted account ID. No ZIP sample prices are hardcoded.
- Monsters and map integration remain owned by OpenCode and are not modified here.

## Not yet implemented

- Authenticated account service and cloud persistence.
- `AuthoritativeMatchSession` now creates a per-match `MatchWorldAuthority` at match start. It maps the four session player IDs to the four canonical castle anchors, creates seven crystals per player, advances the canonical mine controller, exposes server-side movement through map collision/terrain rules, applies crystal damage and rebuild checks, and synchronizes living-crystal counts into match standings. Client movement, attacks, damage, purchases, and rewards are still rejected at the transport boundary until authenticated server-side input handlers and the monster/hero combat adapters are connected.
- Matchmaking, private room invite flow, friend invitations, and player removal.
- Local Wi-Fi hotspot/LAN hosting and reconnect/host migration policy.
- Final landscape selection screen and HUD connected to current 3D/2.5D renderer.
- Wire `PersistentHeroProgressionService` into the production authenticated account/session handler, supply approved economy configuration, and pass a preloaded trusted ownership validator into match session creation. The persistent service is implemented and tested, but the auth/socket endpoint is not yet connected.
- Connect `MatchWorldAuthority` to the existing monster combat adapters so monster attacks and hero attacks resolve against live crystals/units in the same authoritative tick.
- Client input protocol and server-side movement-intent processing with the approved hero speed/world-unit conversion.


## Concrete match-session contract added

- Create a room with `durationMinutes` (defaults to 30; accepted values are validated against the approved duration list).
- A room accepts at most four players. The match cannot start until all four have selected a hero and one of that hero's canonical weapons. By default only the hero's starting weapon is selectable; other weapons require an injected trusted progression ownership validator.
- Client messages may select a valid roster loadout, start the full lobby, or forfeit. Client-submitted score/crystal/reward mutations are not accepted.
- The server-side `awardScore` and `updateLivingCrystals` methods are the only exposed paths for trusted combat/castle integrations to update match scoring and crystal counts.
- The session snapshot includes lobby selections, match phase/clock, participant score/crystal state, and final standings.
- A local development entry point is available at `tool/dev_game_server.dart`. Run it with `dart run tool/dev_game_server.dart`; it binds to loopback by default. Set `ARCHER_FM_BIND_ADDRESS` and `ARCHER_FM_PORT` only for controlled LAN testing. It has no TLS or account authentication and must not be exposed to the public internet.
- This is a tested match-session foundation, not a complete live game server: movement, attacks, unit purchases, economy, damage simulation, authenticated accounts, and cloud persistence still require integration with the existing game systems.


## Canonical world bridge added

- `MatchWorldAuthority` wraps the existing `ArenaMap`, `CastleController`, and `MineController`; it does not introduce duplicate map, crystal, or mine rules.
- The castle controller now accepts an optional ordered player-ID list while preserving the original offline/default ownership behavior.
- A four-player session creates exactly four player-owned castles and seven crystals per castle, with player IDs matching the room's actual server IDs. Network snapshots now include map dimensions, player positions, castle anchors/fallen state, all crystal IDs/positions/HP/exposure, mine ownership/capture progress, resource pickups and per-player wallets.
- Server-side movement uses `ArenaMap.slideMove` for bounds/obstacle collision. The client transport still does not accept raw position writes.
- Mine capture and production are advanced from the authoritative player-position map; only pickups touched by a player are added to that player's match wallet.
- Crystal damage rejects friendly/unknown targets and updates the match's living-crystal tiebreak count. Rebuild attempts use the canonical territory, collision, seven-crystal cap and wallet checks.
- Added unit coverage for player-to-castle mapping, crystal damage/friendly-fire rejection, mine capture/production, rebuild affordability, and session-to-match tiebreak synchronization. These tests are included in CI; the latest run must pass before treating the changes as validated.


## Live combat integration — 2026-11-26

- Added `MatchCombatAuthority` as the match-owned bridge over the existing `HeroCombatRuntime`, `MonsterArmy`, `MonsterMatchRuntime`, `MonsterMatchCombatLoop`, `MonsterCombatResolver`, and `MonsterExternalEntityAdapter`. It does not duplicate those combat rules.
- A configured match creates four armies, each from that player's supplied `InitialArmySelection` of exactly 20 units. The catalog, unit stats/prices, projectile speed/capacity, and world-units-per-second conversion are injected by the trusted host; the integration deliberately does not invent the still-unapproved balance numbers.
- Monster AI now receives live positioned adapters for all heroes and living crystals. Melee attacks and homing ranged projectiles apply damage to the actual hero health or canonical `CastleController` crystal HP. The match session synchronizes crystal counts back into standings after every combat tick.
- Player commands now support normalized directional movement, one manual attack per command, Ultimate activation, and monster purchases. Movement distance is calculated from server tick duration, selected hero speed, host-provided world-unit conversion, and the map's water factor; the map's obstacle geometry is passed into monster steering.
- Hero attacks resolve against live enemy heroes, monsters, and crystals, use the selected weapon's canonical damage multiplier/cooldown, and preserve the five-hit combo. Ultimate unlock/cooldown state remains in `HeroCombatRuntime`; the current adapter uses each Ultimate's configured radius around the selected target and does not reset combo progress.
- Monster purchases debit the match wallet atomically using the catalog's price. The existing mine production/collection system remains the source of match resources.
- Session snapshots now include hero health/weapon/combo/cooldowns, live and dying monsters, and active monster projectiles for a future HUD renderer.
- Added integration tests for four 20-unit armies, monster-to-hero damage, hero-to-monster combo damage, Ultimate damage without combo reset, monster-to-crystal damage, speed-capped movement, and wallet-backed unit purchase.

### Explicit integration boundaries still open

- The development WebSocket server currently uses the lobby-only default factory. A trusted deployment must pass `combatConfiguration` through a configured `sessionFactory`; no unapproved monster balance values or arbitrary army composition have been silently selected.
- The exact hit shapes/animations of line, chain, dash, persistent-damage and other hero Ultimates are not represented by the current `HeroUltimate` schema. The first integration uses the existing radius metadata as a generic target-centered area; each ability still needs its authored shape/effect implementation and 3D animation binding.
- Hero ranged projectile visuals, hero death/respawn rules, kill scoring/rewards, monster permanent-level save loading, and the final mobile HUD/rendering hookup remain separate tasks.
- The world-unit conversion and monster balance catalog must be supplied by the approved server configuration. The test fixture uses isolated synthetic values solely to verify integration behavior; they are not proposed production balance values.
