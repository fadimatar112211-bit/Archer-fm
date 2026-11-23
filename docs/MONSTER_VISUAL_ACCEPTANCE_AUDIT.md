## SUPERSEDING FINAL DIRECTION — 2.5D sprite actors (2026-11-23)

The binding final presentation is **the four approved monster designs as 2D sprite actors with a polished 2.5D appearance inside a lightweight 3D world**, per `VISUAL_DIRECTION_PLAN.md` and `docs/2D_5D_SPRITE_CONVERSION_PLAN.md` (approved 2026-11-21). This supersedes later 3D-only wording in the historical audit below.

- Use only the exact four monsters in `assets/references/approved_all/archer_fm_monsters_reference.png`.
- Keep the existing four gameplay roles, stats, targeting, prices, XP and army rules unchanged.
- Required monster states are idle, locomotion, attack, hit and death, with direction coverage appropriate to the conversion plan.
- Current Canvas painters and rejected low-poly GLB prototypes remain transitional/review-only; neither is final art.
- Do not generate substitute character art or wire rejected prototypes into production.
- Promote only after reference comparison, sprite/manifest validation and real in-game 16:9 capture review.

Historical 3D-only requirements below are retained for traceability; the approved 2.5D conversion plan is authoritative wherever they conflict.

---

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


## 2026-11-23 — First Blender prototype visual review (not accepted)

Review artifact: workflow run `45146774825`, artifact `monster-reference-prototypes` (four GLBs, four 768×768 previews). The Blender build, Python syntax check, GLB structural validation and artifact upload all passed. This proves the prototype pipeline executes; it does **not** prove visual acceptance.

Visual inspection of the four generated previews found:

| Prototype | Visible result | Decision |
|---|---|---|
| runner / green sword goblin | Green chibi body is recognizable by palette and ears, but the body is assembled from smooth primitive blobs; face, tunic and short sword are generic and do not reproduce the approved goblin silhouette/details | **REJECT — redesign from reference** |
| stalker / skeleton dual blade | Skull and exposed bones are identifiable, but ribs/spine read as separated beads and the paired weapons are thin generic spikes rather than the reference blades | **REJECT — redesign anatomy and weapons** |
| tank / horned mace brute | Horns and heavy palette are present, but armor is spherical shoulder/chest pieces; mace and spikes do not read as the approved oversized spiked weapon silhouette | **REJECT — redesign armor and mace** |
| ranged / violet hooded blades | Purple palette and two hand-held shapes are present, but there is no convincing hood/mask silhouette and the weapons do not read as violet energy blades | **REJECT — redesign hood, mask and energy blades** |

All four prototypes remain review-only and must not be copied into production assets or runtime routing. The current Canvas painters remain the safe gameplay fallback. Next iteration must prioritize matching the approved reference's distinct silhouette and signature gear before adding more animation polish.

## 2026-11-23 — Resolve conflicting monster runtime-art direction

The authoritative user-approved reference record at `docs/references/USER_APPROVED_VISUAL_REFERENCES.md` explicitly requires **actual 3D assets with real geometry/materials**, followed by rigging and animation only after the base models match the approved monster sheet. The 2026-11-20 consolidated reference set is the latest visual authority.

This decision supersedes the older, conflicting paragraph in `docs/monsters/MONSTER_PRODUCTION_SPEC.md` titled “Final runtime art direction — 2.5D”, which incorrectly says the final monsters should be sprite actors rendered from GLB sources. The final production target is now unambiguous:

- Four reference-faithful, genuinely 3D skinned monster actors in the arena: green goblin sword, ivory skeleton dual blades, horned armored mace brute, and purple hooded masked fighter with violet energy blades.
- Use the actual approved reference image for geometry, proportions, face/headgear, armor/clothing, colors and signature weapons. Do not substitute generated generic designs.
- Required genuine clips: idle, walk/locomotion, attack, hit and death; preserve gameplay timing and events in simulation.
- Keep the existing Flutter Canvas monsters as a temporary safe fallback until each 3D actor passes source, rig, animation, face/weapon silhouette, gameplay-scale and in-game review.
- The rejected low-poly prototype GLBs remain review-only and must not be wired into runtime.
- Do not change monster stats, targeting, purchase prices, army composition, XP, or the existing four gameplay roles during the art migration.

The renderer/import implementation must be chosen to support these approved 3D actors; do not force the final assets through an 8-direction sprite-atlas requirement. This audit decision is the current monster visual authority until the older production-spec wording is corrected.


## 2026-11-23 — Current in-game monster capture review (run 45194460668)

Reviewed `20_monster_lineup.png` and the four
`24_monster_*_isolated_review.png` images from visual artifact
`14827820391`. The images are produced by the current `ArenaPainter`
monster painters; they are **not** GLB actors and do not close the 3D asset gate.

Observed at the isolated review scale:
- Runner: simple green upright figure with a small sword; it does not reproduce
  the approved goblin's head/face, clothing and sword silhouette in enough detail.
- Stalker: simple ivory skeleton with two narrow blades; the anatomy and blade
  shape remain generic compared with the approved skeleton reference.
- Tank: generic grey/blue body with round shoulders and a small mace-like
  weapon; it does not read as the large horned armored brute with oversized
  spiked mace.
- Ranged: purple hooded body and two violet blades are recognizable by palette,
  but the hood/mask silhouette and energy blades remain simplified placeholders.

The lineup capture also confirms that all four units are still rendered by the
procedural 2D Canvas path at gameplay scale. Keep the four current painters as
the safe fallback; do not promote them as final art and do not wire the rejected
low-poly prototype GLBs into runtime. No monster combat stats, roles, prices,
targeting, XP or army composition changed.
