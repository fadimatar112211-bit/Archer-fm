# Match Rules Foundation

This package implements only the confirmed four-player FFA match rules:
- Approved match lengths: 10, 20, 30, 45, and 60 minutes.
- A single remaining non-forfeited player who still owns crystals wins immediately.
- At time expiry, rank by score, then by living crystal count.
- A complete tie remains explicitly unresolved; no hidden tiebreaker is invented.
- Leaving an active match is a forfeit/loss.
- Score values are supplied by the authoritative gameplay systems; this package does not invent reward amounts.

## Integration boundary
The engine does not own the map, castles, crystals, hero, monster, economy, UI, network, or persistence systems. The match host must call `setLivingCrystals` with the castle authority's current count and `addScore` with points already computed by the approved scoring rules.

## Deliberately unresolved
The product requirements do not define what should happen if all players lose every crystal, nor how to break a tie after both score and crystal count are equal. The engine exposes `allRemainingPlayersHaveNoCrystals` and returns a tied result rather than guessing.

Hero death/respawn, 20% resource loss, 10-second respawn delay and 5-second protection belong to the hero/match runtime, not this match-result rules module.
