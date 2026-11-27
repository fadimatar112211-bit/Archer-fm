# Protected production economy configuration

These files are **templates only**. Copy them to a server-only directory; never bundle them in Flutter assets or expose them through the public web root.

## Files and runtime wiring

- `config/progression-economy.example.json` → `/etc/archerfm/progression-economy.json`
- `config/match-combat.example.json` → `/etc/archerfm/match-combat.json`
- `config/match-rewards.example.json` → `/etc/archerfm/match-rewards.json`

Set these environment variables for the production gateway:

```sh
ARCHER_FM_PROGRESSION_ECONOMY_CONFIG=/etc/archerfm/progression-economy.json
ARCHER_FM_COMBAT_CONFIG=/etc/archerfm/match-combat.json
ARCHER_FM_MATCH_REWARDS_CONFIG=/etc/archerfm/match-rewards.json
```

The gateway now fails closed if any of the three paths is missing, unreadable, or invalid. It validates the monster purchase costs against the combat progression costs before opening the listener. Match reward values are read only by the server and applied by the existing idempotent match-settlement path.

## Install with restricted permissions

Run on the server as an administrator, then replace the example values only through an approved deployment change:

```sh
sudo install -d -o root -g archerfm -m 0750 /etc/archerfm
sudo install -o root -g archerfm -m 0640 config/progression-economy.example.json /etc/archerfm/progression-economy.json
sudo install -o root -g archerfm -m 0640 config/match-combat.example.json /etc/archerfm/match-combat.json
sudo install -o root -g archerfm -m 0640 config/match-rewards.example.json /etc/archerfm/match-rewards.json
```

The service account must be a member of the `archerfm` group. Do not make these files world-readable. Keep the directory outside the repository, Flutter assets, Docker public volume mounts, and web document roots. Back up the files securely and review changes before restart.

Supabase credentials remain separate environment secrets (for example in a root-owned systemd EnvironmentFile with mode 0600). Never place service-role keys in any JSON configuration or commit them to Git.

## Approved launch economy

### Weapon unlocks

Each hero's first weapon is the free starter weapon and is already unlocked by the account model. The protected config therefore requires `unlockCost: 0` for:
- `ranger_greenbow`
- `flame_greatsword`
- `shadow_twinfangs`
- `storm_spear`

The second weapon costs 1,200 permanent gold and the third costs 2,500 permanent gold for each hero.

### Weapon upgrades

Weapon upgrade target levels are 1–40. Each target level uses:

`round(15 + 3 × (level - 1) + 0.35 × (level - 1)²)`

The same schedule is used for all 12 weapons.

### Monster upgrades

Monster upgrade target levels are 2–40. Each target level uses:

`round(10 + 2 × (level - 2) + 0.25 × (level - 2)²)`

The same price schedule is used for Runner, Tank, Stalker, and Ranged. The purchase file and `monsterProgressionPolicy.upgradeCosts` in the combat file must match exactly; startup validation enforces this.

Monster stat growth per permanent level above level 1:

| Type | Health | Damage | Speed |
|---|---:|---:|---:|
| Runner | +1.5% | +1.2% | +0.153846% |
| Tank | +3.0% | +1.0% | 0% |
| Stalker | +1.8% | +1.8% | +0.102564% |
| Ranged | +1.5% | +1.7% | 0% |

Because the current progression scaler is linear per level, Runner speed reaches +6% and Stalker speed reaches +4% at level 40. Other monster types retain base movement speed.

### Match placement rewards

The protected reward file defines permanent currency by final rank:

| Rank | Gold |
|---|---:|
| 1st | 140 |
| 2nd | 110 |
| 3rd | 85 |
| 4th | 60 |

This is the rank-based settlement reward currently supported by the production settlement interface. Separate participation, objective, kill, and damage bonuses are **not** silently added here; those require authoritative event counters and a separately tested settlement extension before they can be paid.

## Important existing progression rules

- Hero cap remains level 40. Existing source code currently calculates hero XP per next level as `100 + 50 × currentLevel`; do not replace that curve with a different formula without a dedicated migration and tests.
- Four hero Ultimates remain unlocked at levels 1, 10, 20, and 30. They are separate from the five-hit combo.
- These config files do not contain credentials. The Supabase service-role key remains server-only in the process environment.
- The protected files are not deployed by a Git commit. An operator must install them on the actual host and set the environment variables before production startup.
