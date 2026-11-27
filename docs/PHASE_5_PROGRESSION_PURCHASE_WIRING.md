# Phase 5 — Weapon and Monster Purchase Wiring

## Implemented server flow

- The production gateway exposes authenticated `GET /v1/account/progression/catalog` and `POST /v1/account/progression/purchase`.
- Both routes require a Supabase access token in `Authorization: Bearer ...`; the gateway derives the account UUID from the verified token subject.
- The mobile request accepts `purchaseType`, `targetId`, `idempotencyKey`, and the displayed `quotedCost`. The quote is only a stale-price check: the server independently recalculates the current cost from its protected catalog and rejects a changed quote. It rejects extra fields such as account IDs, authoritative prices, max levels, and row revisions.
- The server reads both progression rows, derives their current revisions and calculates the price from a protected operator-supplied economy file. The client never supplies or controls price, account identity, or revisions.
- The existing service-role-only `purchase_player_progression` RPC performs the debit, progression update and ledger insert atomically. The service-role key remains exclusively in the server process.
- The Arabic player account screen displays all 12 canonical weapons and four monster types, their current ownership/level, and the server-quoted next cost. It requires confirmation before spending, refreshes account/wallet/history after a successful purchase, and maps common rejection codes to Arabic feedback.
- The mobile client stores pending idempotency keys in device preferences so retries retain the same key across screen changes and app restarts; keys are scoped by account, purchase type and target and cleared only after a confirmed receipt or explicit idempotency conflict. The SQL RPC also treats the key as authoritative when a retry sees a newer level-dependent quote, so a lost response cannot cause a second debit.

## Required deployment configuration — intentionally no invented economy

The gateway now requires:

`ARCHER_FM_PROGRESSION_ECONOMY_CONFIG=/secure/path/progression-economy.json`

The file must be mounted/readable by the server process and must not be packaged in the mobile app or committed with secret deployment data. Its JSON schema is:

- `version`: integer `1`
- `weapons`: exactly the 12 launch weapon IDs. Each entry contains a positive integer `unlockCost` and an `upgradeCosts` object with positive integer entries for every target level `1` through `40`.
- `monsters`: exactly `runner`, `tank`, `stalker`, and `ranged`. Each entry contains an `upgradeCosts` object with positive integer entries for every target level `2` through `40`.

Canonical weapon IDs:
- Ranger: `ranger_greenbow`, `ranger_longbow`, `ranger_twinshot`
- Flame: `flame_greatsword`, `flame_cleaver`, `flame_dualblades`
- Shadow: `shadow_twinfangs`, `shadow_nightfang`, `shadow_soulblades`
- Storm: `storm_spear`, `storm_halberd`, `storm_lance`

The decoder fails closed if any item/level is missing, unknown, zero, negative, or malformed. No economy values were selected in this implementation. The game operator must approve and populate the actual prices before the gateway can start.

## Monster upgrades must affect live combat

The production combat config must include a complete `monsterProgressionPolicy` with owner-approved `healthPerLevel`, `damagePerLevel`, and `speedPerLevel` for all four monster types, plus target-level costs from 2–40. The server refuses to start if this policy is missing or if its monster upgrade prices differ from the purchase economy file. This prevents purchases from changing account levels without changing actual in-match monster stats.

The purchase economy file and combat config are separate protected operator files, but their monster upgrade prices must match exactly.

The Flutter build must receive the public HTTPS gateway origin (no path/query) using:

`--dart-define=ARCHER_FM_API_URL=https://your-game-gateway.example`

The public reverse proxy must forward both the WebSocket traffic and the two `/v1/account/progression/*` HTTP routes to the same internal loopback gateway. Keep TLS/WSS enabled.

## Verification still required

- CI must pass Flutter analyze/tests and the PostgreSQL purchase smoke test, including changed-quote idempotency.
- A real approved economy file and protected server environment must be installed.
- Deploy Supabase migrations to the actual project, then deploy the gateway behind TLS.
- Build the mobile app with the HTTPS gateway origin and test weapon unlock, weapon upgrade, monster upgrade, insufficient balance, stale revision, retry after lost response, and two-account isolation on devices.
