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
| WebSocket client | Adapted into `lib/game/network/game_client.dart` | Useful transport only; it does not own game rules. |
| Reliable command replay | Improved | Only durable selection/progression/purchase commands replay; movement and combat inputs are dropped while offline. |
| Progress/weapon ownership model | Adapted into `lib/game/progression/hero_progress.dart` | Uses the existing canonical hero roster and weapon IDs. Costs and level caps are injected, not copied from provisional ZIP balance. |
| Joystick widget | Reuse candidate only | Must be adapted to the final landscape HUD and existing game camera projection before UI integration. |
| Selection screen and catalog | Not copied | They duplicate hero/weapon/unit catalogs and use a three-unit sample roster that conflicts with the canonical four monster types and OpenCode's integration. |
| Game HUD | Not copied | It expects the ZIP Match snapshot schema, demo minimap coordinates, and ZIP unit IDs. |
| server/lib/match.dart and world.dart | Not copied | They duplicate existing hero combat, castle/crystal, mine, world and monster systems; they also contain provisional combat rules and different economy/respawn assumptions. |
| server/lib/grid_map.dart | Not copied | GridMap.demo is explicitly a sample map and duplicates the current arena map work. |
| server/lib/weapons.dart and weapons.json | Not copied verbatim | They extend PlaceholderRules and contain unapproved provisional values. The ownership/progression concept is retained in the new domain model. |
| server/lib/store.dart | Not promoted to production | File JSON storage is single-server development storage and the profile key is not account authentication/cloud save. |
| server/bin/server.dart | Not copied yet | It depends on the ZIP Match model and in-memory room registry; a production transport host must be wired to the canonical authoritative game session and account service. |

## Current implementation in this branch

- `MatchRulesEngine` is an isolated four-player match-result/clock rules foundation.
- `GameClient` is a mobile WebSocket transport, not yet connected to a server or game HUD.
- `HeroProgress` stores permanent currency, weapon ownership, and per-weapon upgrade levels in a serializable domain model. The authoritative server must supply costs and maximum levels.
- Monsters and map integration remain owned by OpenCode and are not modified here.

## Not yet implemented

- Authenticated account service and cloud persistence.
- Authoritative server session wired to the current canonical combat/world/castle/mine systems.
- Matchmaking, private room invite flow, friend invitations, and player removal.
- Local Wi-Fi hotspot/LAN hosting and reconnect/host migration policy.
- Final landscape selection screen and HUD connected to current 3D/2.5D renderer.
- Server-side validation of progression transactions using approved economy configuration.
