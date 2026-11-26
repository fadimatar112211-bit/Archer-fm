# Weapons and Combat Foundation

This branch adds a testable domain layer for weapons and explicit basic attacks.

## Included
- Three weapon definitions per hero (12 total).
- Damage type, delivery style, damage, range, cooldown, target cap and unlock level.
- Weapon progression from level 1 to 40.
- Manual attack commands only; no automatic basic-fire loop.
- Range filtering, nearest-target ordering, cooldown and duplicate attack-ID protection.

## Integration boundary
The current checked-in Flutter app is a hero animation viewer. It does not yet contain a live arena, target entities, match loop, health component or weapon UI. CombatEngine therefore returns deterministic hit results; it does not mutate live game entities.

The five-hit combo and four special/Ultimate abilities are intentionally not reimplemented. The future runtime must call this engine at the existing combo hit windows and preserve the existing ability handlers. Those handlers are not exposed in the current main-branch Dart source, so compatibility remains an integration gate.

## Balance
All numeric weapon values are initial tuning values, not approved final balance.

## Next gates
1. Connect combo hit events to one ManualAttackCommand per actual hit.
2. Connect special ability handlers without replacing combo input.
3. Add health mutation and authoritative team/ownership validation.
4. Add Arabic RTL weapon selection, equip, upgrade UI and persistence.
5. Run Flutter analyze, tests and Android build in a real Flutter checkout.
