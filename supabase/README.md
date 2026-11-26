# Supabase setup for Archer FM Phase 5

## Create and link the project

1. Create a Supabase project for Archer FM.
2. Enable Email authentication and decide whether email confirmation is required.
3. Install the Supabase CLI and link the project:
   ```sh
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```
4. Confirm the migration `202611270001_phase5_player_persistence.sql` is applied.
5. In the Supabase dashboard, keep Row Level Security enabled for every public table.

## Mobile build configuration

Use the project URL and publishable key only. They are public client configuration, not secrets:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

When these values are absent, the game remains in offline development mode. When present, the app initializes Supabase and requires an authenticated account before entering the home screen. The Arabic account screen supports email sign-up and sign-in.

## Trusted game-server configuration

The server verifies every WebSocket create/join/resume access token by calling Supabase Auth's `/auth/v1/user` endpoint. Configure these variables only in the server environment:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` — public anon/publishable key used for the Auth API request
- `SUPABASE_SERVICE_ROLE_KEY` — server-only secret used by the cloud persistence adapters; never add it to the mobile app, repository, or logs
- `ARCHER_FM_MATCH_REWARDS_BY_RANK` — optional JSON array of four non-negative integer rewards for ranks 1–4, for example `[0,0,0,0]`; omitted means no currency reward until the owner approves a balance schedule
- `ARCHER_FM_COMBAT_CONFIG` — path to the approved combat JSON
- `ARCHER_FM_BIND_ADDRESS=127.0.0.1`
- `ARCHER_FM_PORT=8080`

Run the authenticated internal gateway with:

```sh
dart run tool/prod_game_server.dart
```

Place it behind a trusted reverse proxy that terminates TLS and exposes only WSS to clients. Do not expose the loopback HTTP listener directly. The development gateway remains separate.

## Database access model

- Authenticated users can read only their own progression, currency ledger and match results.
- Clients may update only their profile display name.
- Clients cannot insert/update/delete hero progression, monster progression, currency transactions or match results.
- The two revision-checked progression RPCs and atomic match-result/reward settlement RPC are executable only by `service_role`.
- The Supabase service-role/secret key is server-only. Never put it in Dart defines, APKs, assets, GitHub source or client logs.

## Current implementation boundary

Implemented in this branch:
- Supabase mobile initialization and Arabic email sign-in/sign-up gate.
- Access-token refresh callback on every game socket handshake/reconnect.
- Server-side Supabase Auth token verification.
- Match room player slots and reconnect tokens bound to the verified account UUID.
- RLS schema, account profile bootstrap trigger, currency ledger and match-result tables.
- Provider-neutral progression store interfaces and Supabase REST adapters for hero/monster JSON saves.
- Revision-checked backend save RPCs to reject cross-server stale writes.
- Atomic, idempotent match-result and currency-reward settlement RPC, typed server adapter, and an authoritative match-finish callback that retries failed writes while the room remains alive.

Still required before production use:
- Create/link the actual Supabase project and apply the migration.
- Wire cloud hero/monster progression loading and saving into all account profile and upgrade handlers; the stores exist, but the current match session does not yet hydrate all saved progression before match start.
- Approve the rank reward schedule and configure `ARCHER_FM_MATCH_REWARDS_BY_RANK`; the default is zero rewards, not an invented economy balance.
- Load cloud profile on login and migrate existing local saves with a tested conflict policy.
- Add end-to-end tests against a staging Supabase project, including second-device recovery, concurrent/idempotent settlement and cross-account isolation.
- Add production TLS proxy deployment, monitoring, backups and a restore drill.
- Test token expiry/revocation during long-lived WebSocket sessions.

No real cloud project, credentials or staging environment were available during this code pass. The database schema and adapters are source changes only until an owner creates and configures the Supabase project.
