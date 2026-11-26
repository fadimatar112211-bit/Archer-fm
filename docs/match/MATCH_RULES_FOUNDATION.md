# Match Rules Foundation

This package implements only the confirmed four-player FFA match rules:
- Approved match lengths: 10, 20, 30, 45, and 60 minutes.
- A single remaining non-forfeited player who still owns crystals wins immediately.
- At time expiry, rank by score, then by living crystal count.
- A complete tie remains explicitly unresolved; no hidden tiebreaker is invented.
- Forfeits remove a player from eligibility; the last remaining crystal holder wins if exactly one remains.
- Leaving an active match is a forfeit/loss.
- Score values are supplied by the authoritative gameplay systems; this package does not invent reward amounts.

## Integration boundary
The engine does not own the map, castles, crystals, hero, monster, economy, UI, network, or persistence systems. The match host must call `setLivingCrystals` with the castle authority's current count and `addScore` with points already computed by the approved scoring rules.

## Deliberately unresolved
The product requirements do not define what should happen if all players lose every crystal, nor how to break a tie after both score and crystal count are equal. The engine exposes `allRemainingPlayersHaveNoCrystals` and returns a tied result rather than guessing.

Hero lifecycle is owned by the authoritative combat runtime: a defeated hero loses 20% of the current wallet (integer loss rounded down), waits 10 seconds, respawns at the server-recorded spawn position with full health, and receives 5 seconds of damage protection. A death transition applies the wallet penalty once; reconnecting does not repeat it. Kill points/rewards remain intentionally unconfigured until their values and eligible kill events are approved.
