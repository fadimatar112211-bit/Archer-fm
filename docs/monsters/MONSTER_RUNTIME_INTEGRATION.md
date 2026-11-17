# Monster Runtime Integration

This document is the integration contract between the monster subsystem and the future match/profile screens. The subsystem is testable independently; the match host still owns player profiles, hero/crystal models, map geometry, camera transforms, and network authority.

## 1. Permanent profile progression

Load the versioned save envelope from the player's permanent profile and restore it with the balance configuration supplied by the game economy:

```dart
final progression = MonsterProgression.fromSaveData(
  catalog: monsterCatalog,
  growth: approvedMonsterUpgradeGrowth,
  costForLevel: approvedMonsterUpgradeCost,
  data: savedProfile['monsterProgression'] as Map<String, Object?>,
);
```

When an upgrade is accepted, persist `progression.toSaveData()` back into the profile in the same profile transaction as the permanent-currency debit. Growth percentages and upgrade prices are intentionally injected; the monster subsystem does not invent balance values.

## 2. Create the match army

The player chooses exactly 20 starting monsters through `InitialArmySelection`. Create one army instance per player. Pass the progression provider so new starting and purchased units receive permanent HP, damage, and speed upgrades:

```dart
final army = MonsterArmy(
  ownerId: player.id,
  idPrefix: matchScopedArmyId,
  catalog: monsterCatalog,
  selection: selectedStartingArmy,
  castleX: castle.x,
  castleY: castle.y,
  statsForType: progression.statsFor,
);
```

Use a match-scoped `idPrefix` if an owner can have more than one army instance during restoration/rebuild. Purchase costs remain in the base catalog; permanent levels do not silently change the match economy.

## 3. Build the authoritative world snapshot every tick

Create fresh adapters from the current hero and crystal models. Include all live monster units. Rebuild the snapshot each authoritative tick so target positions and health reflect the latest match state:

```dart
final world = MonsterMatchWorldSnapshot(
  units: allLiveMonsterUnits,
  externalEntities: [
    ...heroAdapters,
    ...crystalAdapters,
  ],
);

final result = world.step(
  loop: monsterCombatLoop,
  now: matchClock,
  elapsed: delta,
  navigationGrid: currentNavigationGrid,
);
```

External adapters implement `MonsterPositionedDamageTarget`. Use the live getter callbacks (`isAliveNow`, `positionXNow`, `positionYNow`) when multiple monsters may damage or move the same target during one tick. The world snapshot rejects duplicate IDs and invalid initial positions, creates monster-to-monster target adapters, and supplies candidate snapshots plus authoritative damage/position lookups to the combat loop.

Configure `MonsterMatchCombatLoop` with:
- `obstaclesFor`: nearby map collision geometry for steering.
- `movementSpeedMultiplierFor`: the map's per-unit terrain factor (for example, a lower factor while a unit is over water).
- `navigationGrid`: the current grid; it can also be replaced per tick through `world.step`.
- A projectile ID factory and approved projectile speed.

The loop handles target selection, melee damage, ranged projectile creation/flight, attack-slot assignment, spatial queries, and route caching. The host remains responsible for updating the authoritative hero/crystal models through the adapters.

## 4. Remove defeated units from simulation, retain them for presentation

A defeated monster is permanently removed from its army and cannot be revived. Keep a separate presentation list so its death animation can finish:

```dart
for (final unit in army.units.where((unit) => !unit.isAlive).toList()) {
  if (army.removeDefeated(unit.id)) {
    dyingUnits.add(unit);
  }
}
```

Only live army units should be supplied to `MonsterMatchWorldSnapshot`. The `dyingUnits` list is visual-only and is passed to the battle layer below.

## 5. Render monsters and projectiles

Mount `MonsterBattleLayer` inside the match screen's world Stack. The camera/map layer supplies the world-to-screen transform. The combat result supplies successful attack events:

```dart
MonsterBattleLayer(
  units: army.units,
  dyingUnits: dyingUnits,
  projectiles: projectileManager.active,
  worldToScreen: camera.worldToScreen,
  simulationTick: authoritativeTickNumber,
  attackingUnitIds: result.attackingUnitIds,
  onDeathAnimationComplete: (unitId) {
    dyingUnits.removeWhere((unit) => unit.id == unitId);
  },
)
```

Increment `simulationTick` once per authoritative simulation tick, not for unrelated UI rebuilds. The layer derives movement from unit positions between ticks, sorts sprites by world Y, renders health bars and active homing projectiles, and uses one shared animation ticker for the whole monster layer. Successful melee/ranged attack IDs start one-shot attack animations; those animations finish even after the one-tick attack signal clears. Defeated units remain visible until their death animation callback fires.

## 6. Remaining host-owned acceptance work

- Supply actual hero/crystal adapters from the live match models and verify four-player damage authority/network replication.
- Feed the real map navigation grid, obstacle geometry, and approved terrain speed factors each tick.
- Mount the layer in the actual battle screen and verify camera scaling, clipping, Y-depth ordering, and projectile effects on device.
- Connect versioned progression data and permanent currency to the authoritative player-save transaction.
- Replace/review the provisional legacy SVG art with approved original production 2.5D assets. The ranged legacy set still lacks dedicated attack/death sheets.
- Run target-device performance tests with realistic army/projectile counts.

The monster CI workflow covers formatting, analysis, and the subsystem test suites. A green subsystem run does not by itself prove the future match screen, network authority, or production art is complete.
