# Phase 5 — Account Identity, Cloud Persistence & Production Networking

**Status:** Started — architecture audit and implementation boundary established  
**Branch:** `feature/phase-5-account-cloud-persistence`  
**Baseline commit:** `8520dfb2ead3bbbabbb3f838c98e5f03cbdd6c0f`  
**Previous work:** `feature/match-rules-foundation` / Draft PR #20 remains untouched and unmerged.

## 1. Verified starting point

The repository already contains useful progression logic, but not production account persistence:

- `HeroProgress` models permanent currency, weapon ownership/upgrades, hero levels and XP.
- `FileHeroProgressStore` persists hero progress as atomic JSON files on one server node.
- `PersistentHeroProgressionService` serializes progression mutations per account in-process.
- `FileMonsterProgressStore` and `PersistentMonsterProgressionService` do the same for monster levels.
- Both file stores explicitly require a trusted account ID and document that they are development/single-node adapters, not cloud databases.
- `GameClient` currently sends an optional client-generated `profile` key during room creation/join. This is not authentication and must never authorize access to another player's save.
- `WebSocketGameHost` currently has no authentication verifier, TLS termination, account binding or production persistence integration.
- `tool/dev_game_server.dart` binds to loopback by default and explicitly warns that it has no TLS or account authentication.
- `pubspec.yaml` currently has no authentication, database or cloud SDK dependency.
- No backend service, database migration directory or production deployment configuration was found in the audited tree.

Existing progression calculations and tests must be reused, not rewritten.

## 2. Target architecture

Keep gameplay rules authoritative on the server. The mobile client may authenticate and display profile data, but it must not decide balances, unlocks, upgrades, match rewards or ownership.

### Identity and sessions
1. A real identity provider issues a short-lived access token after sign-in.
2. The backend verifies signature, issuer, audience, expiry and key rotation against the provider's trusted keys.
3. The verified subject becomes the only source of the internal account ID.
4. WebSocket room creation/join/resume binds to that verified identity; client-supplied `profile` strings are never proof of identity.
5. Session expiry, refresh, logout/revocation and reconnect behavior are explicit and tested.

### Durable data
Persist at minimum:
- account identity mapping and profile metadata;
- permanent currency and an append-only currency transaction ledger;
- hero levels and XP;
- weapon ownership and upgrade levels;
- monster levels;
- inventory/equipment ownership and equipped slots when those systems are introduced;
- match results, placements, score, finish reason and reward transaction IDs;
- schema version and timestamps.

Use database transactions and idempotency keys for reward, unlock and upgrade operations. Enforce account ownership in the backend/database. Never trust a client-provided account ID, price, reward amount or balance.

### Production networking
- HTTPS/WSS only at the public edge; TLS termination and trusted-proxy configuration documented.
- Separate development gateway from production startup.
- Rate limits, payload validation, origin policy, health/readiness endpoints and structured logs.
- Reconnect tokens are short-lived, rotated and bound to the authenticated account and match.
- Match state recovery and durable match-result finalization are tested.
- Backups, restore drill and forward-only schema migrations are documented.

## 3. Implementation batches

### Batch A — repository and security boundary
- [x] Audit current stores, client identity fields and server entry point.
- [x] Create an isolated Phase 5 branch without changing `main` or PR #20.
- [ ] Define provider-neutral authentication and persistence interfaces.
- [ ] Ensure untrusted profile strings cannot be treated as authenticated account IDs.
- [ ] Add tests for missing/invalid/expired credentials and account binding.

### Batch B — authentication integration
- [ ] Select and configure the identity provider using environment-only secrets.
- [ ] Add sign-in, sign-out, token refresh and session restoration on mobile.
- [ ] Verify tokens on the server and bind authenticated identity to room players.
- [ ] Add authorization tests for cross-account access and replayed/expired tokens.

### Batch C — cloud database and migration
- [ ] Add versioned schema migrations and account-scoped tables.
- [ ] Implement transactional cloud stores for hero and monster progression.
- [ ] Add currency ledger, idempotent rewards, purchases and upgrades.
- [ ] Add migration/import tooling for existing local development saves.
- [ ] Test concurrent updates, retries, rollback and restore behavior.

### Batch D — production gateway
- [ ] Add production startup/configuration separate from the loopback development tool.
- [ ] Enforce authenticated WSS connections and account-bound reconnect.
- [ ] Add health/readiness, rate limits, structured diagnostics and safe shutdown.
- [ ] Add match-result persistence and crash/restart recovery tests.

### Batch E — acceptance
- [ ] Verify a player can sign in on a second device and recover the same profile.
- [ ] Verify reinstall does not erase cloud progression.
- [ ] Verify a player cannot read or mutate another account's data.
- [ ] Verify duplicate reward/upgrade requests cannot double-spend or double-award.
- [ ] Verify expired/revoked sessions cannot join or resume.
- [ ] Run formatter, analyzer, full tests and Android build.
- [ ] Perform live backend and multi-client reconnect tests.

## 4. External configuration boundary

No cloud provider credentials, production domain, database URL, signing secret or service-role key were found in the repository. These must be injected as deployment secrets/environment variables and must never be committed.

Provider choice must be explicit before adding provider-specific SDKs or schema. Until that is configured, local JSON stores remain development-only; they must not be mislabeled as cloud persistence.

## 5. Acceptance rule

Phase 5 is **not complete** until authentication is verified server-side, account data is durably stored remotely, second-device recovery works, authorization/isolation tests pass, reconnect and recovery are tested, and production transport is encrypted. A green unit-test suite or a successful APK build alone is insufficient.
