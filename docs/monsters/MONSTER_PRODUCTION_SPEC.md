> **SUPERSEDING RUNTIME DECISION — 2026-11-23:** The approved runtime direction is defined by `docs/2D_5D_SPRITE_CONVERSION_PLAN.md`. All four monsters ship as reference-faithful **2D/2.5D sprite actors** in the lightweight 3D world; they do **not** ship as live GLB actors. Existing procedural Canvas drawing remains a temporary fallback until each sprite pack passes visual and technical acceptance. Blender/GLB files may be retained as source/diagnostic inputs or review-only prototypes, but must be rendered into sprite assets before runtime use. The older “fully 3D” runtime instructions and GLB promotion steps below are superseded wherever they conflict with this decision. Preserve the exact approved monster sheet, all four gameplay roles, stats, projectile behavior, targeting, economy and progression.

> **2026-11-21 VISUAL AUTHORITY:** Use only the approved four-monster reference sheet at `assets/references/approved_all/archer_fm_monsters_reference.png` and the pointer document `docs/references/USER_APPROVED_VISUAL_REFERENCES.md`. The exact visual-to-gameplay mapping is: green sword goblin = Runner; ivory skeleton with paired swords = Stalker; horned heavy armored mace brute = Tank; purple masked infiltrator with violet energy blades = Ranged. This is a visual mapping only: preserve each existing gameplay role, stats, targeting, attack range, economy and progression. In particular, Ranged must continue to use its existing projectile attack even though its reference silhouette carries violet blades; do not silently convert it to melee.

---

# Archer FM — Monster Production Specification

> Stage 2, batch 1 (steps 1–5). Audit and approved production brief.
> Branch: `ranger-reference-work`.
> This document is the source of truth for the four existing monster roles during the visual/model production pass.

## Scope lock

## Final runtime art direction — reference-faithful 2D/2.5D sprites

All four monster types ship as camera-facing sprite actors in the lightweight 3D arena. Their rendered frames must preserve the exact approved reference designs: head/face, anatomy, armor/clothing, proportions, signature weapons, palette and effects. The sprites must read as dimensional 2.5D artwork at the actual gameplay camera scale; do not substitute generic recolored bodies or the rejected low-poly GLB previews.

The production pack must cover the directions and states required by the game's actual facing/animation system. Required states are idle, locomotion, attack, hit and death; Runner also needs a readable fast-run treatment, and Ranged needs a clear cast/release pose while retaining its projectile gameplay. Keep damage, projectile release and other combat events owned by the simulation. Validate frame bounds, alpha, pivots, scale, animation continuity and gameplay-distance readability. Keep the procedural Canvas renderer as a safe fallback until each monster's sprite pack passes visual and technical review. Promote one monster at a time only after acceptance.

Blender/GLB sources may be retained for source inspection or offline sprite rendering, but are not live runtime actors.


- Keep exactly four types: Runner, Tank, Stalker, Ranged.
- Preserve the current game rules, target selection, army roster, purchases, progression, crystal objectives, and resource economy.
- Do not add new monster classes, minion waves, shops, towers, lanes, or win conditions.
- Keep the existing procedural renderer as a fallback until each replacement asset is verified.
- Monster upgrades remain independently capped at level 40.
- The player's starting army remains 20 units, distributed among the four types.

## Audit findings (step 1)

### Existing source of truth
- Type/catalog/stats/progression: `lib/game/monsters/monster_models.dart`.
- Arena rendering and procedural silhouettes: `lib/game/arena_painter.dart`, especially `_paintMonster`, the four body painters, head/limb helpers, weapon painter, HP bar and corpse rendering.
- World movement, targeting, combat and army lifecycle: `lib/game/world/game_world.dart` and related world files.
- Behaviour/economy regression suite: `test/monster_system_test.dart`.
- Current procedural visual capture test: `test/monster_capture_test.dart`.

### Current visual pipeline
- The approved target for both heroes and monsters is 2D/2.5D sprite actors; the current monster production route still draws procedural placeholders with Flutter Canvas.
- The repository tree has no accepted monster sprite production packs. Any Blender/GLB prototype is review/source material only and must not be mistaken for a runtime-ready sprite pack.
- The capture test creates all four friendly and hostile types, a walking pose, an attacking pose and a corpse. However, the current Android workflow artifact from run 44465905653 contains hero/arena captures only; it does not provide fresh monster close-ups for visual acceptance.
- The current painter has basic silhouettes, colors, eyes, weapons, team rings, hit flash, burning indicator and HP bars. These are gameplay placeholders, not reference-approved 2D/2.5D art.

## Approved four-role visual brief (steps 2–4)

### 1. Runner — العدّاء (green sword goblin)
- Gameplay identity and level-1 baseline remain unchanged: fastest unit; 64 HP, speed 138, damage 9, radius 11, attack range 30, cooldown 900 ms, purchase price 30.
- Visual authority: green goblin body, pointed ears, clearly readable face and one short sword.
- Keep the silhouette compact and agile; avoid the old orange palette and scarf-led design.
- The short sword is a close-range visual weapon and must animate with the existing fast melee strike.

### 2. Tank — المدرّع (horned armored mace brute)
- Gameplay identity and level-1 baseline remain unchanged: slowest and toughest unit; 190 HP, speed 72, damage 18, radius 16, attack range 36, cooldown 1300 ms, purchase price 55.
- Visual authority: large horned head/helmet, broad layered armor, oversized shoulders and a heavy spiked mace.
- Keep the weight and impact readable at normal phone zoom; do not use the former plain brown humanoid brief as the art target.

### 3. Stalker — المتربّص (ivory skeleton dual-blade fighter)
- Gameplay identity and level-1 baseline remain unchanged: flanking melee fighter; 88 HP, speed 108, damage 12, radius 11, attack range 30, cooldown 1000 ms, purchase price 40.
- Visual authority: exposed ivory skull and bone structure, dark eye sockets and two short blades.
- Preserve a fast, lean close-combat silhouette; do not restore the superseded purple-hood palette.

### 4. Ranged — الرامي (purple masked infiltrator)
- Gameplay identity and level-1 baseline remain unchanged: ranged attacker; 78 HP, speed 92, damage 10, radius 11, attack range 210, cooldown 2400 ms, preferred range 135, purchase price 45.
- Visual authority: purple hood/mask, readable glowing violet eyes and violet energy blades from the approved reference.
- Preserve the existing ranged projectile behavior, projectile timing and attack distance. The blades define the character's approved appearance; they do not authorize changing the unit into a melee attacker.
- Projectile launch and impact must remain visually distinct from melee strikes and be visible in gameplay captures.

## Shared sprite and animation requirements (step 5 production gate)

Each final monster sprite pack must provide:
- A transparent atlas (or clearly documented set of directional frame images) with stable frame dimensions and consistent character scale.
- Readable face, silhouette and signature weapon at actual gameplay size.
- The genuine directions required by the runtime facing system; do not fake missing directions by mirroring unless the source and design are truly symmetric and the visual review approves it.
- Idle, locomotion, attack, hit and death states; Runner's fast movement and Ranged's projectile cast/release must be visually distinct.
- Stable ground pivot, feet contact, alpha edges and frame-to-frame placement.
- A manifest mapping each runtime state/direction to its actual source frames, with no blank, unrelated or placeholder frames.
- A validated Canvas fallback retained until the sprite pack is accepted.

### Asset source decision and prototype status
- The free Blender generator has been revised to direct the four prototype silhouettes and palettes toward the approved reference: Runner/green sword goblin, Tank/horned mace brute, Stalker/ivory skeleton with paired blades, and Ranged/purple masked infiltrator. These are procedural prototype changes, not a guarantee of reference fidelity.
- The workflow definition `.github/workflows/monster-reference-prototypes.yml` is committed on `ranger-reference-work`; it installs Blender plus NumPy, runs Python syntax checks, exports GLBs/previews to `build/monster-glb/`, validates required clips, and uploads a review-only artifact. The current successful technical run is recorded below (run `44943441131`). Do not describe the prototypes as visually accepted or integrate them into runtime until a human reviews the previews against the approved reference sheet.
- The first preview set (run `44487374412`) was rejected for toy-like spherical bodies, disconnected-looking limbs and weak role detail.
- The face pass (commit `e82dad4`, run `44487884841`) improved eye/pupil/brow/mouth readability, but visual inspection still rejects the set as final art: limbs remain visibly segmented and the Stalker/Ranged hood and weapon silhouettes are not strong enough.
- Follow-up geometry work (commit `324c574`) adds bridging geometry, shins, Runner scarf details, a fuller Stalker hood/cloak, and a tapered Ranged robe/staff assembly. Its artifact must be visually reviewed before acceptance.
- Passing GLB structure validation is only a technical gate. Do not call these models final, integrate them into runtime, or remove the procedural fallback until faces, silhouettes, weapons, animation deformation and gameplay-distance captures are approved.
## First visual preview review — rejected for production

Reviewed the four PNG previews from Monster Reference Prototype Build run 5
(artifact `monster-reference-prototypes`, commit `4047616`). The GLBs pass
container/skin/clip validation, but the actual images are not close enough to
the approved character quality target and must remain prototypes only.

Observed defects:
- Runner: tunic and weapon read as detached rectangular primitives; the goblin
  face and silhouette need more organic shape and a clearly held short sword.
- Tank: chest plate and shoulders are oversized box-like slabs; the mace spikes
  look detached rather than integrated into a heavy weapon.
- Stalker: the skull/rib idea reads, but the face is too blank and the limbs
  still look like stacked toy pieces rather than a cohesive skeleton.
- Ranged: the face wrap is a flat rectangular block that obscures the lower
  face; hood and violet eye details need a cleaner readable silhouette.

Follow-up commit `217dbc2` replaces several box-like torso/armor/mask parts
with rounded forms, improves the Runner sword placement, and adds skull/hood
facial details. This is a targeted prototype refinement, not visual approval.
The new CI preview must be reviewed before any runtime integration.

## Existing mechanics that must not regress

- Exactly four `MonsterType` values.
- Runner remains fastest; Tank remains toughest; Ranged retains the longest attack range.
- Starting army totals exactly 20 and contains all four types.
- Purchases spend match resources and spawn beside the owner's castle.
- Dead army units are permanently lost; corpses are temporary visual remnants only.
- Automatic movement, target choice, melee/ranged attacks, XP/resource rewards and independent upgrades continue to work.
- Level cap remains 40.

## Batch 1 acceptance record

| Step | Result | Evidence |
|---|---|---|
| 1. Audit current files and pipeline | Complete | Source files and existing tests listed above; painter confirmed procedural |
| 2. Confirm four roles and direction | Complete | Four role briefs above, consistent with current catalog |
| 3. Lock baseline gameplay stats | Complete | Exact level-1 values copied from `MonsterCatalog` |
| 4. Lock colors, silhouettes, faces and weapons | Complete | Per-type visual brief above |
| 5. Audit model/rig/animation sources | Complete with blocker | No dedicated monster GLB/BLEND assets or manifests found in active branch |

### Evidence limitations
- Existing test coverage proves mechanics and renderer execution, not final art quality.
- No monster visual capture was included in the latest run 44465905653 artifact.
- No reference-approved monster sprite pack has been produced or integrated in batch 1.
- Therefore batch 1 is an audit/specification completion, not a claim that the monsters are visually finished.

## Next batch: prototype validation and acceptance

1. Inventory and preserve any original monster source art, meshes, Blender scenes and animation inputs; do not overwrite approved references.
2. Build the green goblin Runner sprite pack first from the exact approved reference and verified source material; stop rather than invent geometry if the required source is unavailable.
3. Validate atlas dimensions, alpha, frame rectangles, pivots, direction coverage and state mapping automatically.
4. Capture the sprites beside the hero in the real 16:9 arena and compare them directly with the approved monster reference at gameplay scale.
5. Promote only the individually accepted sprite pack; keep the procedural Canvas fallback for every unaccepted monster.

Do not proceed to runtime replacement based on structural validation alone. Keep the Canvas renderer available as fallback.


## 2026-11-22 implementation checkpoint

- Generator reference-direction update: commit `2ea2682546fb1f2a17896fb552bc0cbea75951fb`.
- Review-only prototype workflow definition: commit `bc2cdf790df652a8e159c443f8e4b9f78beea14c`.
- Flutter analyzer blocker discovered during the latest release workflow: an unused local `socket` paint variable in `lib/game/arena_painter.dart`. Removed in commit `bd362f2cfa09f30a6ff3a7cc7e2bf0b0acc86919`. A fresh CI result is still required to confirm the analyzer passes.
- The prior Storm sprite render completed rendering but failed the frame validation step; atlas packing/publication was skipped. Do not treat Storm's new sprite pack as complete. The precise failing frame diagnostics still need a smaller targeted extraction from the job output.


## 2026-11-22 prototype build result

- Workflow run [44943441131](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/44943441131) completed successfully on commit `217dbc2`.
- Blender exported four GLBs and the validator passed the required structure/clip checks:
  - Runner: 461,356 bytes, 33 meshes, 1 skin, 6 animations.
  - Tank: 519,700 bytes, 43 meshes, 1 skin, 5 animations.
  - Stalker: 549,632 bytes, 39 meshes, 1 skin, 5 animations.
  - Ranged: 547,612 bytes, 39 meshes, 1 skin, 7 animations.
- Review artifact: [monster-reference-prototypes](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/44943441131/artifacts/14722861316) (GLBs, previews and manifest; 14-day retention).
- This is a successful technical export, not visual acceptance. The validator explicitly does not prove visual quality, animation playback or Android performance. The four previews still require comparison with the approved reference sheet before runtime integration.

## 2026-11-22 hero asset validation repair

- The previous all-hero CI gate failed because it scanned unrelated checked-in manifests: Shadow's manifest reuses the same physical atlas/metadata pair across animation entries, and Storm's manifest had omitted the required `schema_version: 1` field.
- `tools/validate_hero_assets.py` now validates only the manifest produced by the current hero build by default; repository-wide audits can explicitly pass `--all-manifests`. It also validates each unique physical atlas/metadata pair once, so intentional reuse does not create false duplicate-frame errors.
- Storm's manifest now declares schema version 1.
- Rebuild/revalidation runs [45059816186](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45059816186) and [45059922294](https://github.com/fadimatar112211-bit/Archer-fm/actions/runs/45059922294) are running; do not mark the four-hero pack green until all four jobs finish successfully.
