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


## Crystal visual specification — approved update (2026-11-18)

All castle crystals must be **large, tall, prominent crystal pillars/spires** (the user's intended shape: a large elongated crystal column), never small loose gemstones or tiny floor decorations. Each of the seven crystals per player must:
- Have a substantial vertical silhouette and be readable from the normal gameplay camera distance.
- Use a faceted, sharp-edged crystal form with a visible grounded base; feel like a major castle objective, not a pickup.
- Emit a strong but controlled internal glow and matching energy/light accents in the owning player's color.
- Keep a clearly visible health bar and ownership/team color cue without obscuring the crystal.
- Show progressive damage through visible cracks/energy disruption, then a distinctive large destruction/break-apart effect.
- Remain visually distinct from mines, pickups, rocks, and decorative props.

This is a visual specification only: preserve the seven-crystal count, current HP values (500, 700, 900, 1200, 1500, 1800, 2200), targeting rules, rebuild rules, and gameplay collision/balance unless separately approved. Apply the same large-pillar language consistently to all players and map placements. Validate visibility, screen-space size, occlusion, performance, and readability at mobile gameplay zoom.


## Crystal visual standard — mandatory (2026-11-18)

- All seven crystals belonging to each player must be **large, tall, prominent crystal pillars/columns**, not small loose crystal stones or tiny shards.
- Each crystal has a strong vertical silhouette, multiple sharp faceted planes, a clearly visible planted base, internal glow/energy and a distinct player/team color.
- Each must be easy to identify from normal gameplay camera distance and at mobile resolution; its health bar must be readable without obscuring combat.
- Damage feedback: visible cracks and unstable energy. Destruction: a clear collapse/shatter sequence with a strong but brief effect.
- Preserve the existing seven-crystal count and HP values (500, 700, 900, 1200, 1500, 1800, 2200), exposed/walled placement rules, direct-targeting rules and rebuild gameplay. This is a visual specification only; do not silently alter balance or rules.
- Apply the same large-pillar visual language to original and rebuilt crystals. Validate scale against heroes, monsters, walls and camera framing so the crystals feel monumental without hiding objectives or blocking the battlefield.


## Approved gameplay-result reference — detailed implementation specification (2026-11-20)

The user has supplied and approved a third reference image for the **actual in-match presentation** of Archer FM. The repository copy is:
- `assets/references/approved_all/file_000000005c8c81f9ab4ccbb80ea59d5e.png`

This image has a different purpose from the hero and enemy reference sheets:
- The hero sheet defines the exact appearance of Ranger, Flame Knight, Shadow and Storm.
- The enemy sheet defines the exact appearance of the four enemy archetypes.
- This gameplay screenshot defines the target **camera, battlefield composition, scale, combat readability, HUD arrangement and moment-to-moment visual result**. It does not replace either character reference sheet.

### A. Screen format and camera
- Target a full-screen landscape mobile composition, approximately 16:9, with no portrait-mode layout.
- Use an elevated three-quarter/isometric camera looking down enough to show paths, troops, objectives and terrain, while keeping character faces and bodies recognizable.
- The camera must be close enough that the controlled hero, nearby enemy units and allied troops occupy meaningful screen space; do not pull back so far that characters become tiny.
- Keep the controlled hero near the lower-middle/left-middle gameplay area as in the reference, with smooth camera follow and enough forward view to see approaching threats.
- Preserve a useful view of the battlefield around the hero. Avoid excessive zoom, camera shake or effects that hide units.
- Camera projection, world-to-screen mapping, touch coordinates, minimap and safe areas must remain consistent at supported landscape aspect ratios.

### B. Battlefield environment and composition
- Build a rich, readable fantasy arena with a walkable stone/cobblestone path winding through natural ground.
- Mix stone paving, grass, flower patches, bushes, tall grass/reeds, trees, rocks and low stone ruins/walls. Use the reference's natural, lived-in environment rather than a flat empty arena.
- Include a visible water feature/river or stream and a wooden bridge as recognizable environmental landmarks where the map layout permits.
- Use terrain height, rocks and vegetation to frame the playable lanes, but never let decoration obscure heroes, monsters, crystal objectives, health bars or attack telegraphs.
- Use coherent stylized 3D materials, lighting, contact shadows and scale across terrain, props, characters and structures.
- Keep paths wide and readable enough for groups of troops to move and fight without visually merging into the environment.

### C. Crystals and objective structures
- Show large, tall, faceted, glowing crystal structures on substantial stone bases, visually prominent from normal gameplay distance.
- Crystal color communicates ownership/team (the screenshot illustrates blue and red); use the actual player/team palette in the match.
- Place crystals as meaningful battlefield objectives, not as tiny pickups. Their bases and vertical silhouettes must be visible.
- Display a clear crystal health bar when the UI/game state calls for it. Make ownership and damage state readable.
- Maintain the previously approved seven-crystal-per-player gameplay specification and existing objective rules; the sample image's visible crystal counts are illustrative only.

### D. Character, troop and monster presentation
- The controlled hero must be a clearly identifiable 3D character, with a visible team/selection ring beneath the feet and a readable level indicator and health bar nearby.
- Keep the hero's exact approved design from the hero reference sheet. The gameplay screenshot is not permission to replace the approved Ranger design or redesign the other three heroes.
- Show allied and enemy troops in distinguishable team colors, with compact silhouettes, readable weapons and clear movement/attack poses.
- Show large/heavy monsters with noticeably greater body mass and screen presence than ordinary troops. Fast and ranged enemies should remain distinguishable by silhouette and attack behavior.
- Use the exact four approved enemy designs from the enemy reference sheet. Do not infer a new permanent fifth monster type from incidental creatures in this gameplay illustration.
- Enemy heroes/units may display their level and health bar above their head; keep bars aligned with the moving actor and avoid overlap where possible.
- Use selection/team rings sparingly and consistently to clarify ownership or target state.

### E. Combat feedback and moment-to-moment readability
- Attacks should produce readable weapon motion, projectile/energy trails or impact flashes that visually connect attacker and target.
- Show damage numbers briefly above the hit target, with strong contrast and a short, non-obstructive animation.
- Health bars should update immediately and remain legible against busy terrain.
- Telegraph heavy attacks and area effects with clear ground indicators, but do not cover the whole battlefield with bright effects.
- Maintain the approved combat rules: one tap produces one basic attack; holding the attack control must not auto-repeat; dodge is separate; the five-hit combo remains separate from the four Ultimates.
- Skill effects should use each hero's established signature palette and must remain readable at the target gameplay zoom.

### F. HUD layout — match the reference's hierarchy
- **Top-left player panel:** circular hero portrait, player name, current/max HP bar, and a compact hero-level badge. Keep it inside the landscape safe area.
- **Top-center match strip:** team crystal/objective counters on either side of a central match timer; a match/combat icon may separate the counters. The exact sample values are not fixed gameplay rules.
- **Top-right:** a compact minimap in a framed panel, plus a separate settings button near it. The minimap must show arena boundaries, player/team markers and relevant objectives using clear symbols/colors.
- **Above battlefield actors:** contextual level badges and health bars for the controlled hero, enemy heroes and important monsters; show damage numbers only when a hit occurs.
- **Bottom-left:** large translucent virtual movement joystick with a clear thumb area and directional response.
- **Bottom-right:** large, separate, circular combat controls with distinct icons and color identity. The reference places a prominent basic attack/sword button at the lower-right, with skill/ability buttons arranged above and to its left.
- **Bottom area near the controls:** a potion/consumable button with a visible remaining-count badge.
- Keep all touch targets comfortably tappable on phones. Reserve screen space so the HUD does not unnecessarily cover the controlled hero, nearby enemies or objective lanes.
- Arabic-first UI remains mandatory. The screenshot's sample Arabic player label and numeric HUD are visual examples; localize all labels and accessible names consistently in Arabic.

### G. Responsive layout and interaction requirements
- Preserve the same hierarchy at different phone aspect ratios; scale and reposition panels rather than cropping essential controls.
- The joystick must remain reachable by the left thumb; attack and skill controls must remain reachable by the right thumb.
- Support simultaneous movement and attack inputs without pointer conflicts.
- Ensure button presses trigger exactly the intended action and do not repeat attacks because a pointer remains held.
- Keep minimap, settings, player panel and top counters clear of notches/cutouts and system gesture areas.
- Test the real game at 16:9 and narrower/wider landscape aspect ratios, with small and large device resolutions.

### H. What must not be copied as fixed rules from the screenshot
The screenshot is a visual target, not a source of balance constants. Do not hardcode its sample player level (18), enemy level (17), HP (850/850), match time (07:24), crystal counters (2 and 1), damage number (126), potion count (3), troop counts, unit colors or exact actor positions as game rules. Use the actual Archer FM match state, team assignment, combat data and approved economy/objective rules.

### I. Visual acceptance checklist
A gameplay capture can pass review only when:
1. It is landscape and the full battlefield/HUD hierarchy is visible.
2. Camera angle and distance clearly show the hero, nearby troops, enemies, paths and objectives.
3. Hero and monster appearances match their own approved source sheets.
4. Terrain has the reference's rich stone/grass/water/bridge/vegetation language without harming navigation or visibility.
5. Crystal structures read as tall glowing objectives with visible ownership and health feedback.
6. Top-left player panel, top-center timer/objective strip, top-right minimap/settings, bottom-left joystick and bottom-right combat controls are all present and legible.
7. Damage, health, levels, team ownership and attack effects are readable during active combat.
8. The controls remain functional and preserve one-press/one-attack semantics.
9. No visual element obscures critical gameplay information at common phone resolutions.
10. The reviewed screenshot comes from the actual running game build; concept images or mockups alone do not count as implementation evidence.

