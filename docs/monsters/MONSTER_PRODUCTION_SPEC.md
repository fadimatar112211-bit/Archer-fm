> **2026-11-19 VISUAL AUTHORITY OVERRIDE:** The four visual concepts described in this older document (orange Runner, brown Tank, violet Stalker, teal Ranged) are superseded and must not be used as art references. The user supplied the exact four monster designs in a reference sheet. The only approved visual source is `docs/references/USER_APPROVED_VISUAL_REFERENCES.md`, especially `assets/references/approved/monsters/monster_types.png`. Rebuild the four monster models to match the supplied green sword goblin, skeleton dual-blade enemy, horned heavy armored mace enemy, and purple hooded violet-blade enemy exactly. Do not generate substitutions or alter their appearance to fit the older visual briefs. Gameplay stats/logic in this file are not automatically changed by this visual override; inspect and map gameplay roles separately without changing the source art.

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

### 1. Runner — العدّاء
- Gameplay identity: fastest unit; short-range pressure and dash/burst approach.
- Existing level-1 baseline: 64 HP, speed 138, damage 9, radius 11, attack range 30, cooldown 900 ms, purchase price 30.
- Existing palette: warm orange body with light amber accents.
- Silhouette: lean, compact, forward-leaning body; long swept-back ears/scarf details; visibly light feet/legs.
- Face: alert, energetic eyes; readable head shape at normal phone zoom.
- Weapon/read: retain a light, fast close-range strike; avoid a heavy shield or bulky armor silhouette.

### 2. Tank — المدرّع
- Gameplay identity: slowest, highest durability and strong close-range hit.
- Existing level-1 baseline: 190 HP, speed 72, damage 18, radius 16, attack range 36, cooldown 1300 ms, purchase price 55.
- Existing palette: earthy brown armor with pale bronze accents.
- Silhouette: broad torso, oversized shoulder plates, thick limbs, heavy stance and clear armor plates.
- Face: sturdy, intimidating expression; horned/helmeted outline may remain if it reads clearly.
- Weapon/read: heavy fist/gauntlet or blunt impact; make weight and impact readable.

### 3. Stalker — المتربّص
- Gameplay identity: flanking/harassing melee fighter; medium mobility and damage.
- Existing level-1 baseline: 88 HP, speed 108, damage 12, radius 11, attack range 30, cooldown 1000 ms, purchase price 40.
- Existing palette: deep violet body with lavender accents.
- Silhouette: narrow hooded cloak, asymmetric stance and paired short blades.
- Face: partially shadowed but eyes must remain visible; distinguish from Ranged by a close-combat posture and dual-blade read.
- Weapon/read: two short blades, one on each side; preserve a clear dual-wield outline.

### 4. Ranged — الرامي
- Gameplay identity: ranged attacker; maintains preferred distance and fires projectiles.
- Existing level-1 baseline: 78 HP, speed 92, damage 10, radius 11, attack range 210, cooldown 2400 ms, preferred range 135, purchase price 45.
- Existing palette: teal/blue-green body with pale cyan accents and warm fire-orb effect.
- Silhouette: upright hooded caster/archer with a staff held visibly away from the body.
- Face: readable eyes beneath hood; distinguish clearly from Stalker.
- Weapon/read: staff with a glowing fire orb; projectile launch and impact must be visible and not confused with melee attacks.

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

## Next batch: steps 6–10

1. Establish a reproducible, free model-production pipeline and a canonical monster asset folder/manifest format.
2. Produce the Runner model and validate its rig, face, silhouette and required clips.
3. Produce the Tank model and validate its rig, face, silhouette and required clips.
4. Produce the Stalker model and validate its rig, face, silhouette and required clips.
5. Produce the Ranged model and validate its rig, face, staff, projectile pose and required clips.

Do not proceed to runtime replacement until all four model files pass asset validation. Keep the Canvas renderer available as fallback.
