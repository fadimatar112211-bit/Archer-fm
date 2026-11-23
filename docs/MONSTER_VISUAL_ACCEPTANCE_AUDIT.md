# Archer FM — Monster Visual Acceptance Audit

Date: 2026-11-21  
Branch: `ranger-reference-work`  
Canonical reference: `assets/references/approved_all/archer_fm_monsters_reference.png`

## Non-negotiable art rule

The four monsters must be built from the exact user-approved reference sheet. Do not generate substitute designs, use web/stock art, or reinterpret the silhouettes. Keep the original reference file byte-for-byte unchanged. The four monsters are distinct designs; do not make them share one generic body with recolored materials.

## Canonical roster (left to right)

| ID (provisional) | Approved appearance | Gameplay identity |
|---|---|---|
| goblin_sword | Green goblin-like enemy carrying a sword | Ordinary enemy |
| skeleton_dual_blade | Skeleton wielding two blades | Fast enemy |
| horned_mace_brute | Large horned, heavily armored enemy with an oversized spiked mace | Heavy enemy |
| violet_hood_blades | Purple hooded, masked enemy with violet energy blades | Infiltrator / ranged-style identity as represented in the approved reference |

Do not rename or remap existing gameplay roles until the current monster code and stats have been inspected. These IDs are audit labels, not permission to change combat balance.

## Current evidence

- The approved reference sheet is present at the canonical path above.
- The Phase 0 repository audit recorded no `assets/monsters/` production image directory at that audit point.
- Runtime inspection on 2026-11-23 confirms that `lib/game/arena_painter.dart` still draws all four monsters procedurally with Flutter Canvas (`_paintMonster` and per-type body painters). These are readable gameplay placeholders, not skinned 3D production monsters.
- `tools/monsters/generate_monsters_blender.py` exists and can generate review-only low-poly rigged prototypes, but the generated prototypes have not passed reference comparison and are not wired into the production runtime. Their existence is not production acceptance.
- The four gameplay identities and their current combat stats remain defined in `lib/game/monsters/monster_models.dart`; this visual pass does not alter those gameplay contracts.
- Therefore all four monster visuals remain **NOT READY**. Keep the current painter fallback while the reference-matched 3D assets are built and reviewed; do not label it as final art.

## Required production pipeline

For each of the four reference designs:

1. Locate and preserve any existing source mesh, Blender file, GLB, rig, animation, and texture before creating anything new.
2. Compare the base model in front, three-quarter, side, and back views against the exact reference.
3. Preserve head shape, face/mask, horns, skeleton anatomy, armor silhouette, weapon shape, proportions, signature colors, and energy effects.
4. Rig and animate only after the base model passes a visual comparison.
5. Produce the direction coverage required by the game's actual camera and facing system. Do not assume eight directions until the renderer convention and available source are checked.
6. Required monster states: idle, locomotion, attack, hit, and death. Keep combat timing/events in the game simulation; animation must not independently apply damage.
7. Validate alpha, frame dimensions, frame bounds, ground pivot, scale stability, frame-to-frame motion, and weapon visibility.
8. Capture the monsters at actual in-game scale in the 16:9 arena and review them beside the approved reference.
9. Promote one monster at a time only after all checks pass. Preserve a safe fallback until then.

## Next actions

- Preserve the canonical reference and inspect every source mesh/GLB/Blend before editing or replacing any monster.
- Keep the gameplay mapping unchanged: runner = green goblin sword, stalker = skeleton dual blade, tank = horned mace brute, ranged = violet hooded masked fighter. The code's current labels/stats do not authorize changing the reference roster.
- Use the Blender prototype generator only to create review artifacts. Do not wire its low-poly output into production until it passes the exact-reference checklist.
- Build the green goblin sword enemy first as the pilot, but only from the approved reference and any preserved original source; stop if the exact source geometry is unavailable rather than inventing substitute art.
- Add per-monster tests for manifest completeness, frame validity, and correct runtime identity.
- Update this audit with actual file paths, screenshots, test results, and acceptance status. Never mark a monster ready based on a populated manifest alone.

## Acceptance checklist (each monster)

- [ ] Base model matches the approved reference in front / three-quarter / side / back.
- [ ] Signature face/head, armor/clothing, proportions, palette, and weapon match.
- [ ] Rig is valid and deforms correctly.
- [ ] Idle, locomotion, attack, hit, and death are genuine coherent animations.
- [ ] Required directions are rendered from the actual model, not copied or mirrored substitutes.
- [ ] Feet/pivot and scale are stable.
- [ ] Transparent atlas and metadata pass automated validation.
- [ ] Animation events align with existing gameplay timing.
- [ ] In-game 16:9 captures are legible and reviewed.
- [ ] Production route is explicitly approved in code and covered by regression tests.
