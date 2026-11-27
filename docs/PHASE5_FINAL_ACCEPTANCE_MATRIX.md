# Archer FM Phase 5 — final acceptance matrix

**Checked:** 2026-11-27  
**Branch:** `feature/phase-5-account-cloud-persistence`  
**Pull request:** [#21](https://github.com/fadimatar112211-bit/Archer-fm/pull/21) — draft, open, unmerged.

This document separates implemented source and repeatable local CI evidence from deployment and owner-input blockers. Phase 5 must not be labelled production-complete until every required external acceptance item below is verified.

## Implemented in the branch

- Supabase email sign-up/sign-in gate in Arabic; mobile configuration uses only the public publishable key.
- Server-side access-token verification for WebSocket create/join/resume, account-bound room ownership, and resume-token rotation.
- Active authenticated sockets revalidate the original bearer token every 60 seconds; rejected, identity-changed, or unverifiable sessions fail closed.
- Hero and monster progression models, store abstractions, Supabase REST adapters, revision checks, and account-private snapshot projection.
- Match result/reward settlement through a server-only RPC, idempotency checks, and a disk-backed retry outbox for one gateway instance.
- Account screen reads profile, wallet, hero levels, weapon ownership/upgrade summary, monster levels, currency ledger, and match history; only display name is client-editable.
- SQL migration provisions both existing and future Auth accounts, applies RLS and least-privilege grants, and limits mutation RPCs to `service_role`.
- Deployment templates document loopback binding, TLS/WSS reverse proxy, secret handling, persistent outbox storage, backup and restore requirements.

## Verified automated checks

| Check | Evidence | Result |
|---|---|---|
| Flutter static analysis | Latest PR validation on `389f379b1b3bdb7b2702342008282c3f53afdf4a` | Passed |
| Full Flutter tests | Same commit | 330 tests passed |
| Match-rules tests | Run [45972701304](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45972701304) | Passed |
| PostgreSQL 16 migration, grants/RLS, account backfill, settlement idempotency and two-account isolation | Run [45973257865](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45973257865) | Passed |
| Android debug APK build | Run [45973257832](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45973257832) | Failed at Gradle plugin resolution (`org.gradle.kotlin.kotlin-dsl:6.4.2`); Flutter tests had passed. A second build attempt is being checked separately. |
| Android emulator | Earlier run [45971636930](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45971636930) | Started on an earlier commit before active-session revalidation; it is not accepted as final Phase 5 emulator evidence. |

The PostgreSQL job uses local PostgreSQL 16 and a minimal Supabase-compatible Auth schema. It is not a live Supabase staging test.

## Remaining acceptance blockers

1. **Live Supabase staging:** owner must create/link the project, apply the migration, configure Auth email policy/redirects, and test two real accounts, token expiry/revocation, concurrent writes, and account isolation.
2. **Progression economy approval:** weapon unlock/upgrade prices, weapon upgrade caps/scaling, monster upgrade prices, and per-level monster health/damage/speed growth must be approved. Existing service abstractions intentionally have no invented defaults.
3. **Authoritative upgrade endpoints and UI:** persistent hero/monster progression services exist, but player-facing unlock/upgrade commands are not yet connected end-to-end to authenticated server requests and the wallet/ledger.
4. **Monster match hydration:** cloud monster levels are stored and displayed, but production match loadouts still need the approved growth policy and trusted account loader wired into the authoritative match factory.
5. **Production durability and operations:** the JSON outbox is single-instance only. Multi-replica service requires a shared database queue/lease; configure monitoring, alerting, protected storage, backups, and complete a restore drill.
6. **TLS/WSS deployment:** deploy the gateway behind the real TLS proxy and verify public WSS create/join/resume/reconnect.
7. **Final Android runtime:** after source/build work is frozen, run the emulator smoke test once against the final branch commit, then verify install, launch, resumed activity, screenshots, and logcat. Physical-device smoke test remains separate.

## Release decision

**Phase 5 status: IN PROGRESS — not production-ready.**

Do not merge PR #21 or claim completion based only on local PostgreSQL compatibility tests, Flutter tests, or APK compilation. PR #20 and `main` are outside this phase and must remain untouched.
