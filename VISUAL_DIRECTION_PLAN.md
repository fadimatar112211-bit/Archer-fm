# Archer FM — New Visual & Combat Direction

## Decision (2026-11-18)

Move the **whole battlefield presentation** toward a polished, readable, isometric 3D action look inspired by League of Legends: heroes, monsters, attacks, abilities, terrain, props, shadows and combat feedback must share one coherent visual language.

This is a visual/presentation upgrade, **not** a conversion into a MOBA and **not** a rebuild. Preserve Archer FM's mobile action-game identity and the proven simple controls.

## Non-negotiable gameplay stays

- Landscape mobile arena and Arabic-first HUD.
- Left virtual joystick for free movement; right-side manual attack input.
- One press = one attack. Holding the attack control must never auto-repeat.
- Dodge remains a separate action.
- Five-hit combo remains separate from the four Ultimate abilities.
- Four Ultimates per hero unlock at levels 1 / 10 / 20 / 30.
- Existing four playable heroes, three weapons per hero, level cap 40, health parity at equal level, and hero-specific movement/abilities remain.
- Keep current arena rules, monsters, crystals, economy and multiplayer direction. No rules change is implied by this visual plan.
- Keep the existing GLB hero pipeline and legacy atlas/SVG fallback until replacements are proven.
- Do not change main; work on `ranger-reference-work`.

## Visual target

A three-quarter/isometric camera and composition with enough screen space to read the hero and nearby enemies. The target is inspired by LoL's clarity and presentation, adapted to a mobile screen and Archer FM's compact arena gameplay; it is not a claim that the current renderer is already a full 3D LoL-style engine.

### 1. Camera, scale and framing
- Establish a consistent elevated three-quarter view across the entire scene.
- Increase hero and monster visual prominence without changing their gameplay hitboxes or balance stats.
- Keep the controlled hero near the readable center/lower-center of the viewport; smoothly follow movement.
- Preserve touch-to-world coordinate correctness, minimap/HUD safe areas, and map-edge clamping.
- Test landscape aspect ratios and ensure large models/effects do not obscure objectives or enemy telegraphs.

### 2. Heroes
- Render all four production GLB heroes consistently: Ranger, Flame, Shadow and Storm.
- Improve face, head silhouette, weapon silhouette and material readability at actual gameplay zoom.
- Ensure facing direction, locomotion, attack, skill, hit and death states read clearly.
- Weapon motion must align with hands; attack release/hit timing must remain tied to animation events where authored.
- Compare close-up front and three-quarter captures against `assets/heroes/reference/heroes_reference_sheet.jpg`; record per-hero defects before modifying source meshes.

### 3. Monsters (same visual direction)
- Bring all four approved monster roles into the same 3D/isometric presentation language: runner, tank, stalker and ranged.
- Each role needs a distinct silhouette, readable scale/weight, facing, locomotion and attack wind-up.
- Preserve existing role identity and stats: runner = fast dash, tank = durable slow unit, stalker = flanking harasser, ranged = ranged attacker.
- Make damage, stun/freeze, death and team ownership legible with restrained materials, outlines/shadows and effects.
- Do not replace the four archetypes or invent new gameplay roles as part of this visual pass.
- Audit current monster renderer first. If current monsters are procedural 2D shapes, plan a staged migration to production 3D assets with a tested fallback; do not pretend they are already 3D.

### 4. Combat readability and effects
- Make basic attacks visually distinct per hero and weapon.
- Add clear anticipation, active frames, impact, hit reaction and recovery; preserve one-tap/one-attack semantics.
- Give all 16 Ultimates a recognizable signature silhouette/color/effect, readable area/target indication and consistent timing.
- Improve projectile trails, slash arcs, lightning, fire, poison, area telegraphs, damage numbers and hit feedback without covering the battlefield.
- Effects must communicate gameplay, not merely add screen clutter.

### 5. Arena and environment
- Improve terrain depth, biome materials, lighting, cast/contact shadows, rocks, trees, walls, bridges, crystals and castle structures.
- Maintain clear walkable lanes and objective visibility.
- Use consistent scale, light direction, material roughness/value contrast and team colors across heroes, monsters and environment.
- Keep the battlefield legible at mobile resolution; decorative detail must not compete with combat silhouettes.

### 6. HUD and touch controls
- Preserve current joystick and manual attack layout and Arabic-first labels.
- Increase visual hierarchy and touch-target clarity without shrinking the arena unnecessarily.
- Keep dodge, combo, four Ultimates, HP/energy, objective indicators and minimap readable.
- Validate multi-touch: movement while attacking, pointer cancellation, and no repeated attacks from a held pointer.

## Implementation sequence (do not skip evidence gates)

1. **Baseline audit:** inspect current code paths and capture artifacts for camera, heroes, monsters and arena. Produce a defect list. Record current test/build state.
2. **Camera and composition prototype:** tune camera angle/framing and actor presentation scale without changing simulation coordinates, collision radii or damage. Add capture tests for hero/enemy scale, map edges and touch-coordinate mapping.
3. **Hero presentation:** close-up and gameplay-distance captures for all four heroes, eight facings, and core animation states. Fix only defects proven by comparison to the reference.
4. **Monster presentation:** audit the existing painter/model pipeline; prototype one representative monster role first, then bring all four roles to the same standard. Keep fallback until each asset and animation is validated.
5. **Combat/VFX pass:** verify attack timing and one-press semantics, then improve impact and signature effects for all 16 Ultimates.
6. **Arena/environment pass:** terrain, lighting, props, castles/crystals and depth cues, while preserving readability/performance.
7. **HUD and mobile polish:** Arabic layout, touch targets, aspect ratios, accessibility of visual feedback.
8. **Performance and release gate:** profile Android-class performance; run analyze, all tests, capture suite, release APK build and verification on the same commit. Inspect fresh captures and APK artifact before calling the batch complete.

## Acceptance criteria

- The player can still move with the left joystick and attack manually with one press per hit.
- Camera, heroes, monsters and environment read as one coherent elevated/isometric scene.
- All four heroes and four monster roles are distinguishable at normal phone viewing size.
- Face/weapon/attack/monster-animation claims are supported by actual inspected captures, not only file presence or triangle-count tests.
- All 16 Ultimates remain separate from the five-hit combo and show their intended gameplay effect.
- No regression in world coordinates, collision, combat balance, objectives, minimap, controls or match rules.
- CI and release APK are green on the exact HEAD being reported; visual captures are reviewed from that same commit.

## Known starting point

At the time this plan was added, the game uses a Flutter custom-painted 960×540 logical arena with a smoothed camera origin; the player has a 3D GLB render path, while monsters are currently rendered through the arena painter/procedural animation path. The four monster roles are defined in `lib/game/monsters/monster_models.dart`. This is why the plan starts with an audit and staged migration rather than assuming the whole game is already a full 3D scene.
