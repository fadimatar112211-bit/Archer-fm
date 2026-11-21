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
- No production monster model, rig, animation pack, or in-game visual acceptance has been demonstrated by the evidence reviewed for this audit.
- Therefore all four monster visuals remain **NOT READY**. Do not display generic placeholders as approved monster art.

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

- Inventory the repository for every monster-related source/model/script and record exact paths.
- Confirm the four current gameplay actor IDs, stats, attack patterns, collision sizes, and animation event contracts without changing them.
- Establish a monster-specific Blender render/build profile based on existing tools only after source availability is confirmed.
- Start with the ordinary green sword enemy as a pilot only if its exact source/reference and model are available; otherwise stop and report the missing source rather than inventing a model.
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
