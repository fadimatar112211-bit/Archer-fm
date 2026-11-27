# Production gateway deployment template

This is an operator template, not a claim that Archer FM has been deployed. Replace every placeholder, provision TLS, and test the full WSS path before allowing players to connect.

## 1. Runtime host

- Use a supported Linux LTS host in the same region as the Supabase project where practical.
- Install the Dart SDK version pinned by the repository's CI/toolchain policy.
- Create a dedicated unprivileged `archerfm` user and a read-only checkout at `/opt/archer-fm`.
- Keep the internal game server bound to `127.0.0.1`; only the reverse proxy may reach it.
- Restrict inbound firewall access to SSH from operator IPs and HTTPS/WSS on TCP 443. Do not expose TCP 8080.

## 2. Secret environment file

Create `/etc/archer-fm/server.env` as root with mode `0600`. Do not commit it or copy it into a mobile build.

```sh
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVER_ONLY_SERVICE_ROLE_SECRET
ARCHER_FM_COMBAT_CONFIG=/etc/archer-fm/match-combat.json
ARCHER_FM_MATCH_REWARDS_BY_RANK=[0,0,0,0]
ARCHER_FM_BIND_ADDRESS=127.0.0.1
ARCHER_FM_PORT=8080
ARCHER_FM_SETTLEMENT_OUTBOX_PATH=/var/lib/archer-fm/pending-match-settlements.json
```

The reward array above intentionally grants zero currency until the game owner approves and tests a rank reward schedule. Store the combat configuration outside the repository and review all gameplay/economy values before deployment.

## 3. systemd service template

Save as `/etc/systemd/system/archer-fm.service` and replace the Dart executable path if needed.

```ini
[Unit]
Description=Archer FM authenticated game gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=archerfm
Group=archerfm
WorkingDirectory=/opt/archer-fm
EnvironmentFile=/etc/archer-fm/server.env
ExecStart=/usr/bin/dart run tool/prod_game_server.dart
Restart=on-failure
RestartSec=5
StateDirectory=archer-fm
StateDirectoryMode=0700
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true
RestrictSUIDSGID=true
UMask=0077

[Install]
WantedBy=multi-user.target
```

Then run `systemctl daemon-reload`, `systemctl enable --now archer-fm`, and inspect `journalctl -u archer-fm`. Confirm the process reports a loopback listener and never prints environment secrets.

## 4. Nginx WSS reverse-proxy template

Use a real DNS name and certificates from your chosen certificate authority. This server block is a template; validate it with `nginx -t` before reload.

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 443 ssl http2;
    server_name YOUR_GAME_DOMAIN;

    ssl_certificate     /etc/letsencrypt/live/YOUR_GAME_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/YOUR_GAME_DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
    }
}
```

Configure DNS, certificate renewal, HSTS after validating the HTTPS site, request/connection limits appropriate for WebSockets, and firewall rules. Clients must use `wss://YOUR_GAME_DOMAIN`; never connect to the internal HTTP listener from the public internet.

## 5. Supabase operational controls

- Apply `supabase/migrations/202611270001_phase5_player_persistence.sql` to a staging project first, then verify RLS and service-role-only RPC grants.
- Configure email confirmation/password policy and allowed redirect URLs in Supabase Auth.
- Enable an appropriate backup/PITR plan for the project and document its retention window.
- Test restoring a backup into a separate project before production launch.
- Rotate the service-role secret immediately if it is exposed; never place it in GitHub source, issue comments, logs, or Dart defines.

## 6. Release acceptance checklist

- [ ] Supabase staging migration applied and `supabase/validation/phase5_privileges.sql` passes.
- [ ] Auth sign-up, sign-in, token refresh, expiry and active-WebSocket revalidation tested against a staging project; confirm the provider's exact revocation semantics.
- [ ] WSS handshake, reconnect and account ownership tested through the real TLS proxy.
- [ ] Cross-account data isolation tested with two real test users.
- [ ] Cross-device hero progression restore tested.
- [ ] Match settlement and retry/idempotency tested against staging PostgreSQL.
- [ ] Approved rank reward schedule configured and reconciled with the currency ledger.
- [ ] Android release APK built, installed and smoke-tested on physical devices.
- [ ] Monitoring, log retention, alerting, backup and restore drill completed.

Match settlements are first written to a disk-backed JSON outbox at `ARCHER_FM_SETTLEMENT_OUTBOX_PATH` (default `/var/lib/archer-fm/pending-match-settlements.json`) before being sent to Supabase. The service retries queued items after restart and every five seconds; keep this path on persistent private storage, include it in protected backups, and do not place it under the web root. Database idempotency keys make replay after a crash between database commit and local queue deletion safe. This is single-instance local durability, not a replicated queue; do not run multiple gateway replicas against the same outbox file.

The current gateway does not expose a dedicated HTTP health endpoint or built-in metrics exporter. Until those are implemented, monitor the systemd process, proxy errors, Supabase availability and structured service logs; do not mistake an open TCP port for full game readiness.
