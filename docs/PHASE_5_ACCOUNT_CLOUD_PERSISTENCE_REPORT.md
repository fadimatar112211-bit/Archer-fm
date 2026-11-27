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


## 6. Implementation update — 2026-11-27

### Implemented in source
- Added `HeroProgressStore` and `MonsterProgressStore` abstractions; existing file adapters now implement them and the persistence services depend on the abstractions.
- Added Supabase mobile SDK integration with environment-based initialization and an Arabic email sign-up/sign-in gate. If no project URL/key is supplied, the existing offline development entry remains available.
- `GameClient` can obtain a fresh access token before each create/join/resume socket handshake; the match loadout screen supplies the configured Supabase session token.
- Added a server-side verifier that asks Supabase Auth's `/auth/v1/user` endpoint to validate the bearer token and returns the verified user UUID. No locally decoded, unverified JWT claims are trusted.
- Added account-bound room joins and resume-token ownership checks. A token issued to one account cannot resume another account's match slot.
- Added a separate authenticated gateway entry point that refuses non-loopback binding and is intended to sit behind a TLS-terminating WSS reverse proxy. The loopback development gateway remains separate.
- Added Supabase schema for profiles, hero progression, monster progression, currency ledger and match results; enabled RLS and restricted client writes.
- Added backend-only revision-checked RPCs and server-only REST adapters for hero and monster progression.
- Added the Supabase CLI/setup guide and enabled CI workflows on this isolated Phase 5 branch.

### Important boundary
The code is **not production-deployed or fully cloud-wired yet**. No Supabase project or credentials were available in this session. The production gateway currently verifies account identity, but its match session is not yet composed with the Supabase progression stores; currency ledger settlement, match-result writes, existing-save import and second-device recovery still require integration and staging tests. Long-lived socket token expiry/revocation also needs a defined enforcement policy. Do not expose the gateway or claim Phase 5 complete until those items and the acceptance checklist pass.

### Validation
- An initial Android validation run exposed two source errors (a malformed callback line and an interface capability cast); both were corrected.
- The current source validation on commit `a58e9bcb3471bd90c90543c95e60ec7b7ca66e38` passed Match Rules analysis and all **303 Flutter tests** (run [45908292761](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908292761)). Android validation on the same commit also passed dependency setup, analysis and the full Flutter test step; the debug APK build was still running at the time of this update (run [45908292769](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908292769)). Earlier intermediate runs failed on issues that were fixed before this validated commit. Do not claim the Android artifact is ready until build and upload both complete.


## 7. Review and verification checkpoint — 2026-11-27

- Opened draft PR [#21](https://github.com/fadimatar112211-bit/Archer-fm/pull/21) targeting `feature/match-rules-foundation`; it is intentionally unmerged. PR #20 and `main` remain untouched.
- Source spot-check confirmed the Arabic email account gate, environment-only Supabase URL/publishable key configuration, server-side Auth user lookup, account-bound room join/resume checks, and revision-checked hero progression REST adapter are present on this branch.
- The cloud adapter uses a service-role key and must remain server-only. The mobile app uses only the publishable key.
- The branch currently has no reported combined commit status checks at the PR head. A live CI result has not been confirmed in this checkpoint; do not treat the source spot-check as a passing test run.
- The production gateway and Supabase project are not deployed from this session. No project URL, publishable key, service-role key, or database credentials were available. Live database migration, cloud runtime composition, reward/match-result settlement, save import, cross-device recovery, and expiry/revocation acceptance remain blockers.
- The Android workflow's pull-request trigger is restricted to base branch `heroes-complete`; PR #21 currently targets `feature/match-rules-foundation`. Its push trigger includes the Phase 5 branch, but a successful run must be explicitly verified before acceptance.

**Current acceptance status: IN PROGRESS — not ready for production or phase closure.**


## 8. CI follow-up — 2026-11-27

- Corrected the Android workflow pull-request target filter to include `feature/match-rules-foundation`, the actual base of PR #21. Previously, the PR event filter only named `heroes-complete`, so PR #21 would not receive that workflow through its pull-request event.
- The Phase 5 head commit `a58e9bcb3471bd90c90543c95e60ec7b7ca66e38` completed the `match-rules` workflow successfully (analysis and full Flutter test steps passed).
- Android validation run `45908292769` has completed dependency resolution, analysis and Flutter tests successfully; APK build was still running at the latest check. Do not mark Android package validation complete until build and artifact steps finish.
- The PR now points at head commit `275f06a054eeedb800940cf7e395f5823ed77f32`; a fresh Android run is expected for this workflow change.

**Acceptance remains IN PROGRESS.** Passing source CI does not substitute for staging Supabase deployment, service-role runtime wiring, atomic reward settlement, cross-device recovery, or account-isolation E2E tests.


## 9. Atomic match settlement foundation — 2026-11-27

- Added the backend-only `finalize_match_player_result` PostgreSQL RPC. It locks the authenticated player's hero-progression row, records the match result, appends the currency ledger transaction, updates the permanent currency balance and increments the progression revision in one database transaction.
- Repeated settlement for the same match/player returns the existing receipt without awarding currency again. A retry with conflicting result fields, reward amount or idempotency key is rejected.
- The RPC validates placement, score, remaining crystals, finish reason, reward amount and idempotency key, and is executable only by `service_role`; anon/authenticated/public execution is revoked.
- Added `SupabaseRestClient.finalizeMatchPlayerResult`, typed `SupabaseMatchSettlementStore` / `MatchSettlementReceipt`, and receipt parsing tests.
- This is a durable database primitive, **not yet connected to the live match-finalization callback**. The authoritative match session and production gateway still need account-to-standing mapping, approved reward calculation, retry/outbox behavior, and invocation of this RPC. Do not treat the new RPC as live reward settlement until that composition and a staging database test pass.
- Latest Android workflow for the current branch head is running (run [45908839341](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908839341)); prior intermediate runs were cancelled as newer commits arrived. The latest completed Match Rules run on this branch remains the successful run [45908590238](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908590238), before the settlement changes. The new settlement code has not yet received a completed green CI run.
- Supabase migration execution, live database concurrency/idempotency verification, production runtime wiring, save import, second-device restore and account-isolation E2E remain open.

**Current acceptance status: IN PROGRESS — not ready for production or phase closure.**


## 10. CI correction after settlement client addition — 2026-11-27

- The first Match Rules run for settlement commit `804d3e1969464352545eb5fd1e24869613201b9c` failed during analysis because the REST client method insertion was malformed. The workflow logs were inspected; this was a source-editing defect, not a test or backend failure.
- Rebuilt `supabase_rest_client.dart` as a complete file and verified the final method boundaries and regular expressions in the fetched source. Fix commit: `19306b11ed55f8f719d7f0ed92f69d503b4386ee`.
- Revalidation for that corrected source is running: Match Rules [45908955504](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908955504) and Android validation [45908955588](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908955588). Neither was complete at this checkpoint. Do not claim the correction has passed until both report their final results.
- Android workflow runs [45908962413](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908962413) and [45908955588](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908955588) are both attached to the corrected source commit; verify APK build and artifact upload, not only analysis/tests.

**Acceptance remains IN PROGRESS.**


## 11. Corrected-source CI result — 2026-11-27

- Match Rules CI on corrected source commit `19306b11ed55f8f719d7f0ed92f69d503b4386ee` completed successfully: dependency resolution, `flutter analyze --no-fatal-infos`, and the full Flutter test suite all passed (run [45908955504](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908955504)).
- Android validation on the same source commit has also passed dependency resolution, analysis and the full Flutter test suite; debug APK compilation is still in progress (run [45908955588](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45908955588)). Emulator and artifact-upload steps have not yet run.
- This verifies Dart source/tests for the new settlement adapter, but does not validate the PostgreSQL migration against a live Supabase instance or wire the settlement call into the match lifecycle.

**Acceptance remains IN PROGRESS.**


## 12. Authoritative match lifecycle settlement wiring — 2026-11-27

- Added an account-bound completion callback to `AuthoritativeMatchSession`. It captures the final standings, maps each internal player slot to the account UUID established by the verified handshake, and submits one durable result for every account-bound participant when the match finishes by time or last-crystal-holder/forfeit.
- The room uses a per-session unique match identifier rather than the short join code, preventing collisions with historical match records.
- Production gateway now constructs the server-only Supabase settlement adapter from `SUPABASE_SERVICE_ROLE_KEY` and invokes the atomic settlement RPC. The key is required at server startup and is never part of mobile configuration.
- Failed settlement requests remain queued and are retried on subsequent server ticks. The room is not eligible for removal while durable settlements remain pending. Retries use the database idempotency key so a lost HTTP response does not double-award currency.
- Added `ARCHER_FM_MATCH_REWARDS_BY_RANK` as an optional four-integer server configuration. It defaults to `[0,0,0,0]`; no currency values were invented without an approved economy schedule.
- Added a session-level test proving a finished account-bound match queues durable settlement for all four accounts. The new implementation still needs CI and a real Supabase staging test.
- Cloud hero/monster progression hydration before match start is still not complete; the adapters and revision-checked save APIs exist, but all game profile/upgrade handlers are not yet connected.
- Live Supabase migration deployment, cross-device restore and cross-account isolation E2E remain blocked until an owner-configured staging project and secrets are available.

**Acceptance remains IN PROGRESS; do not merge PR #21 or mark Phase 5 complete yet.**


## 13. Verified cloud hero restore before match entry — 2026-11-27

- Added an account-provisioning handshake hook. The WebSocket host now waits for server-side profile hydration after Supabase verifies the access token and before it sends the player a welcome/snapshot. If restore fails, the player is removed from the slot and the handshake is rejected.
- Production sessions load `hero_progress` through `SupabaseHeroProgressStore` using the verified account UUID. The authoritative match uses the restored hero level, weapon upgrade level and unlocked-weapon set when validating loadouts and constructing combat.
- A single verified account cannot occupy multiple player slots in the same room.
- Match settlement invalidates the hero store's cached revision after the atomic RPC updates currency/revision, so a later progression save reloads the current database revision instead of using a stale cache.
- Added tests for restoring cloud hero levels/unlocked weapons before match start, account ownership mismatch, duplicate account slots, and match completion settlement for all four accounts.
- Monster progression remains stored in Supabase but is not yet applied to match combat: the approved combat JSON currently contains monster base stats but does not define the per-level growth policy needed to interpret saved monster levels. This must be configured and approved rather than guessed.

**Current status: significant local implementation progress; CI for the newest commit and live Supabase acceptance still pending.**


## 14. Security, player-scoped restore and deployment preparation — 2026-11-27

- The verified player's cloud hero progression is now included only in that recipient's private snapshot. Shared room snapshots do not contain currency, unlocked weapons or private profile progression. Tests assert different accounts receive their own balances and that the shared snapshot contains no account progression.
- WebSocket handshake tests cover the order of operations: token verification, account profile hydration, then welcome/snapshot. A failed cloud restore rejects the handshake and removes an empty newly-created room.
- Supabase migration now explicitly revokes broad/default grants from `PUBLIC`, `anon` and `authenticated`, grants only authenticated reads plus the permitted `display_name` column update, and grants the trusted service role the backend table/ledger-sequence access it needs.
- Added read-only staging assertions at `supabase/validation/phase5_privileges.sql` for RLS, client table privileges, server-only RPC execution and ledger sequence permissions. This script has not been run against a live Supabase project yet.
- Added `docs/deployment/PRODUCTION_GATEWAY.md` with systemd, Nginx WSS proxy, firewall, server secret-file, backup and release-acceptance templates. No live server deployment is claimed.
- CI for source commit `c429c4ae0bff7813b529e90b335530a018258ca6`: Flutter analysis and the full Flutter test suite passed. The Android debug APK build is still running in workflow [45911146621](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45911146621).
- A preceding source revision `85b2642649c23eb2f695007a27a306581f3a1ec9` completed Android debug APK build and artifact upload successfully in workflow [45910645194](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45910645194). That successful artifact predates the final player-scoped snapshot test and later SQL/docs hardening; validate the current head's APK run before release.

**Phase 5 remains IN PROGRESS.** Remaining blockers are a connected staging Supabase project and migration/RLS execution, owner-approved hero/monster economy values (including monster growth and upgrade costs), cloud profile/upgrade handlers, cross-device and cross-account E2E, durable recovery across a game-server process restart, and a real WSS deployment/device smoke test. PR #21 remains draft and unmerged.

## 15. Disk-backed match settlement recovery — 2026-11-27

- Added `FileMatchSettlementOutbox` at `lib/game/network/file_match_settlement_outbox.dart`. Each account's finalized result/reward is validated and persisted to a local JSON snapshot before its first Supabase delivery attempt.
- The production gateway now uses the outbox for all match settlement callbacks, retries pending records every five seconds, drains the queue on startup and attempts a final drain on graceful shutdown.
- Pending records survive process restarts. A crash after the database commits but before the local record is removed may cause a replay; the existing match/player idempotency key makes that replay safe against duplicate rewards.
- Successful background delivery invalidates the hero progression store's cached revision, preventing a later save from using a revision made stale by settlement.
- Added tests for persistence before network delivery, failed-delivery retention, recovery in a newly constructed outbox, successful removal after confirmed delivery, and conflicting reuse of an idempotency key.
- The deployment guide now configures a private systemd state directory and documents `ARCHER_FM_SETTLEMENT_OUTBOX_PATH`. The file must live on persistent private storage. This implementation is single-gateway-instance local durability, not a replicated queue; multi-replica deployment needs a database-backed queue/lease.
- The first integration attempt failed analysis because the production entry point was missing its explicit `dart:async` import for `Timer`; this was corrected immediately. The corrected source commit `3a9f9a504a3d5678f80f28e2d236e8f698e5275c` passed Flutter analysis and the full test suite in Android workflow [45911700825](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45911700825). At the latest poll, debug APK compilation was still running; emulator QA is configured as manual-dispatch-only and the artifact upload step is still pending.
- Earlier failed analysis runs [45911672283](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45911672283) and [45911687948](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45911687948) were caused by that missing import, not by test failures. Do not count them as passing.

**Phase 5 remains IN PROGRESS.** This closes the previously identified process-restart gap for already-enqueued settlement records, but live Supabase acceptance, approved progression economy, full profile/upgrade API integration, cross-device E2E and production deployment remain open.

## 16. Player account surface and history — 2026-11-27

- Added `PlayerAccountDataService`, which derives the account UUID only from the active Supabase Auth session; callers cannot pass an arbitrary user ID.
- The client can now read its own profile, wallet balance, immutable currency ledger and recent match results through the migration's authenticated-user RLS policies.
- The only profile mutation exposed to the client is `display_name`; there are no client-side currency, reward, hero progression or monster progression write methods.
- Added strict display-name validation (1–32 visible characters, rejecting control and bidirectional-override characters) and typed parsers for profile, ledger and match history rows.
- Added an Arabic account screen reachable from the home screen when cloud accounts are configured. It shows the player's name/email, balance, recent currency transactions and matches, supports editing the display name, refresh and sign-out.
- The game client now refreshes a Supabase access token when it is within 30 seconds of expiry before reconnect/handshake.
- Added model/validation tests for Arabic display names, malformed profile/ledger rows and match result bounds.
- CI run [45912118016](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45912118016) was triggered while this UI work was being committed. Its status must be checked against the latest branch head before calling the new screen validated.

**Remaining account work:** the screen currently reads account history and profile data, but hero/weapon and monster upgrade commands still need server-authoritative APIs and owner-approved economy costs. The screen also requires a live Supabase deployment to display provisioned data; no live staging verification has occurred.

## 17. Validation follow-up and database-side name safety — 2026-11-27

- Workflow [45912232721](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45912232721) exposed a Dart type-argument typo in the new currency-history query mapper. Flutter analysis stopped before tests or APK build; the diagnostics pointed to the incorrect `.map<...>` expression.
- Corrected both history query mappers to use explicit row-to-model closures in `player_account_data_service.dart` (commit `278b38a45ea2acca7962cdf3cc5a22e5da52d67e`).
- Added a database constraint for display names as well as client-side validation, so direct PostgREST calls cannot store whitespace-padded, control-character or Unicode bidirectional-override names.
- Added a database trigger to maintain `player_profiles.updated_at` without granting the client permission to write timestamp columns, and added a read-only staging assertion for the trigger.
- The correction is committed, but no completed CI run for the newest branch head has been observed yet. The previous failure must not be described as a passing validation.

## 18. Corrected account query validation — 2026-11-27

- The corrected branch triggered [workflow 45912332059](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45912332059).
- Flutter dependency resolution and `flutter analyze --no-fatal-infos` have both completed successfully in that run.
- The full Flutter test suite was still running at the latest poll. Android debug APK build and artifact upload had not started yet.
- This run validates the Dart account screen and service changes up through the corrected query mapping; SQL changes still require a live staging database to validate.

## 19. Display-name validation regression fix — 2026-11-27

- Workflow 45912332059 passed Flutter analysis but reported 322 tests passed and one failed: the test called the pure display-name validator with whitespace-only input, and the validator did not itself reject leading/trailing whitespace (the update method had trimmed it before validation).
- Tightened `validateDisplayName` to reject values that differ from their trimmed form, making the validator consistent with the database constraint and safe when called independently.
- This fix is committed as `e0b257a2c32d0c3615ec6134d64d83d41e1899bb`; a fresh full CI run is still required before the change can be considered green.

## 20. Fresh validation after whitespace fix — 2026-11-27

- A fresh workflow for the whitespace-validation fix is running as [45912518505](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45912518505).
- A second workflow for the latest documentation/branch head is [45912528555](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45912528555).
- At the latest poll, the first run had reached Flutter analysis and the second was still setting up Flutter. Neither had yet reported a final result.

## 21. PostgreSQL migration smoke test — 2026-11-27

- Fixed the profile timestamp trigger function's dollar-quoted PL/pgSQL body. The migration previously contained an invalid delimiter; this was found during a direct source review before a live Supabase rollout.
- Added `.github/workflows/supabase-phase5.yml`, which starts PostgreSQL 16, creates a minimal Supabase Auth-compatible schema/roles, applies the Phase 5 migration, and runs the RLS/privilege assertion script.
- The workflow also inserts a new Auth user and verifies that profile, hero-progress and monster-progress rows are provisioned by the Auth trigger.
- It updates the profile twice and verifies `updated_at` advances, then verifies the database rejects whitespace-padded display names.
- PostgreSQL migration smoke test [45968811877](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45968811877) completed successfully. Migration apply, all privilege assertions, Auth provisioning and profile constraint/timestamp checks passed.
- This validates the SQL against PostgreSQL 16 with a minimal Supabase-compatible Auth schema. It is not a substitute for applying the migration to the actual Supabase staging project and testing its real Auth/RLS configuration.
- Flutter/Android validation for the same branch head is running as [45968811852](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45968811852); it had not completed at the time of this report update.
