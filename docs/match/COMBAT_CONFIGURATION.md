# Match combat configuration

The development gateway now refuses to start in lobby-only mode. Supply a reviewed JSON configuration using `ARCHER_FM_COMBAT_CONFIG`:

```sh
ARCHER_FM_COMBAT_CONFIG=/absolute/path/to/match-combat.json dart run tool/dev_game_server.dart
```

No monster balance, economy price, projectile speed, movement speed, or combo timing is silently selected by the tool. These values remain subject to owner approval and balance testing.

## Required JSON shape

The root object must contain:

| Field | Type | Requirement |
|---|---|---|
| `projectileSpeed` | finite number | Greater than zero |
| `maxActiveProjectiles` | integer | Greater than zero |
| `maxUnitsPerArmy` | integer | At least 20; this is a technical safety limit, not a final game-design cap |
| `worldUnitsPerSecond` | finite number | Greater than zero |
| `comboResetWindowMs` | integer | Greater than zero; time allowed between combo taps |
| `monsterCatalog` | object | Must contain exactly `runner`, `tank`, `stalker`, `ranged` |

Each `monsterCatalog` entry must contain:

- `maxHealth`: finite positive number
- `damage`: finite positive number
- `moveSpeed`: finite positive number
- `attackRange`: finite non-negative number
- `attackCooldownMs`: positive integer
- `purchaseCost`: non-negative integer

Unknown types, missing values, non-finite numbers, invalid cooldowns, and incomplete catalogs are rejected at startup. See `lib/game/network/match_combat_configuration.dart` for the canonical decoder and validation.

## Security and integration boundary

- `tool/dev_game_server.dart` binds to loopback by default and is for development only.
- It does not provide TLS, account authentication, account-linked progression, or production storage.
- Non-starting weapons remain locked unless the host injects a trusted ownership resolver.
- Permanent hero levels can be injected through `heroLevelForPlayer`; the callback must resolve the authenticated account from trusted server context. The current development gateway does not claim to authenticate accounts.
- Permanent XP awards are applied by `PersistentHeroProgressionService.awardHeroExperience` only after trusted post-match reward logic supplies the amount. This phase does not invent reward amounts or score values.
