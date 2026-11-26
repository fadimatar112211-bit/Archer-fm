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
- `HeroProgress` stores permanent currency, weapon ownership, and per-weapon upgrade levels in a serializable domain model. `HeroProgressionService` applies unlock/upgrade transactions using server-supplied costs and caps; no ZIP sample prices are hardcoded.
- Monsters and map integration remain owned by OpenCode and are not modified here.

## Not yet implemented

- Authenticated account service and cloud persistence.
- `AuthoritativeMatchSession` now creates a per-match `MatchWorldAuthority` at match start. It maps the four session player IDs to the four canonical castle anchors, creates seven crystals per player, advances the canonical mine controller, exposes server-side movement through map collision/terrain rules, applies crystal damage and rebuild checks, and synchronizes living-crystal counts into match standings. Client movement, attacks, damage, purchases, and rewards are still rejected at the transport boundary until authenticated server-side input handlers and the monster/hero combat adapters are connected.
- Matchmaking, private room invite flow, friend invitations, and player removal.
- Local Wi-Fi hotspot/LAN hosting and reconnect/host migration policy.
- Final landscape selection screen and HUD connected to current 3D/2.5D renderer.
- Server-side progression transaction endpoint that authenticates the account, loads/saves `HeroProgress`, and supplies the unlocked-weapon validator to session creation.
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
- A four-player session creates exactly four player-owned castles and seven crystals per castle, with player IDs matching the room's actual server IDs.
- Server-side movement uses `ArenaMap.slideMove` for bounds/obstacle collision. The client transport still does not accept raw position writes.
- Mine capture and production are advanced from the authoritative player-position map; only pickups touched by a player are added to that player's match wallet.
- Crystal damage rejects friendly/unknown targets and updates the match's living-crystal tiebreak count. Rebuild attempts use the canonical territory, collision, seven-crystal cap and wallet checks.
- Added unit coverage for player-to-castle mapping, crystal damage/friendly-fire rejection, mine capture/production, rebuild affordability, and session-to-match tiebreak synchronization. These tests are included in CI; the latest run must pass before treating the changes as validated.
