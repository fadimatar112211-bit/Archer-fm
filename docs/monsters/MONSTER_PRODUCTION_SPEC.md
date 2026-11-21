> **2026-11-21 VISUAL AUTHORITY:** Use only the approved four-monster reference sheet at `assets/references/approved_all/archer_fm_monsters_reference.png` and the pointer document `docs/references/USER_APPROVED_VISUAL_REFERENCES.md`. The exact visual-to-gameplay mapping is: green sword goblin = Runner; ivory skeleton with paired swords = Stalker; horned heavy armored mace brute = Tank; purple masked infiltrator with violet energy blades = Ranged. This is a visual mapping only: preserve each existing gameplay role, stats, targeting, attack range, economy and progression. In particular, Ranged must continue to use its existing projectile attack even though its reference silhouette carries violet blades; do not silently convert it to melee.

---

# Archer FM — Monster Production Specification

> Stage 2, batch 1 (steps 1–5). Audit and approved production brief.
> Branch: `ranger-reference-work`.
> This document is the source of truth for the four existing monster roles during the visual/model production pass.

## Scope lock

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
- Heroes use GLB models, but monsters are still drawn procedurally with Flutter Canvas.
- The repository tree contains no dedicated monster GLB/BLEND production assets or monster rig/animation manifests.
- The capture test creates all four friendly and hostile types, a walking pose, an attacking pose and a corpse. However, the current Android workflow artifact from run 44465905653 contains hero/arena captures only; it does not provide fresh monster close-ups for visual acceptance.
- The current painter has basic silhouettes, colors, eyes, weapons, team rings, hit flash, burning indicator and HP bars. These are a useful fallback, not evidence of reference-quality 3D monsters.

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

## Shared model and animation requirements (step 5 source gate)

Each final monster asset must provide:
- A clean, centered, ground-aligned mesh with consistent scale and readable face/weapon.
- A usable skeleton/rig (or a documented animation-ready equivalent).
- Embedded or correctly referenced materials/textures with no missing-texture fallback.
- Gameplay clips: idle, walk, attack, hit and death. A run/dash clip is additionally required for Runner; a ranged cast/release pose is required for Ranged.
- Stable facing/orientation and feet contact with the arena ground.
- No mesh self-intersection, detached weapon, floating feet, or broken deformation at key poses.
- A manifest mapping gameplay states to clip names and timing/events, plus a validated fallback.

### Asset source decision and prototype status
- The free Blender pipeline now generates four rigged prototype GLBs in the CI artifact folder `build/monster-glb/` and emits a manifest plus preview PNGs. The generated files are CI artifacts; they are not committed as runtime assets under `assets/monsters/3d/`.
- The current generator maps the approved designs to Runner/green goblin, Tank/horned mace brute, Stalker/skeleton, and Ranged/purple masked infiltrator. A dedicated GitHub Actions workflow builds and validates these prototypes. The first run exposed a missing NumPy dependency in the Ubuntu Blender exporter; the workflow now installs `python3-numpy`, and the corrected run is pending. No visual or runtime acceptance is implied.
- The first preview set (run `44487374412`) was rejected for toy-like spherical bodies, disconnected-looking limbs and weak role detail.
- The face pass (commit `e82dad4`, run `44487884841`) improved eye/pupil/brow/mouth readability, but visual inspection still rejects the set as final art: limbs remain visibly segmented and the Stalker/Ranged hood and weapon silhouettes are not strong enough.
- Follow-up geometry work (commit `324c574`) adds bridging geometry, shins, Runner scarf details, a fuller Stalker hood/cloak, and a tapered Ranged robe/staff assembly. Its artifact must be visually reviewed before acceptance.
- Passing GLB structure validation is only a technical gate. Do not call these models final, integrate them into runtime, or remove the procedural fallback until faces, silhouettes, weapons, animation deformation and gameplay-distance captures are approved.
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
- No new monster model has been produced or integrated in batch 1.
- Therefore batch 1 is an audit/specification completion, not a claim that the monsters are visually finished.

## Next batch: prototype validation and acceptance

1. Complete the Blender-to-GLB build and validate all four exported files, skeletons, embedded materials and required animation clips.
2. Review the four preview renders side-by-side against the approved reference sheet; reject any face, silhouette, color or weapon mismatch.
3. Inspect gameplay-distance captures at the actual arena camera scale, including friendly/enemy colors, health bars and projectile effects.
4. Fix any deformations, detached weapons, floating feet, animation clipping or unreadable faces; rebuild and revalidate.
5. Only after explicit visual acceptance, prepare runtime asset integration while retaining the procedural Canvas renderer as a fallback.

Do not proceed to runtime replacement based on structural validation alone. Keep the Canvas renderer available as fallback.
