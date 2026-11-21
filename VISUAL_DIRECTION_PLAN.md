# SUPERSEDING DECISION — 2.5D Sprite Heroes + Lightweight 3D World (2026-11-21)

**This decision supersedes conflicting hero-rendering directions below.** The approved production direction is:
- Playable heroes and monsters are 2D sprite characters rendered with a polished 2.5D art treatment.
- The arena/world remains a lightweight 3D environment.
- Characters are placed as camera-facing sprite/billboard actors in the 3D world, with grounded shadows, selection rings and correct depth/occlusion.
- Preserve all gameplay rules, combat values, progression, controls, economy, multiplayer requirements, Arabic-first UI and approved character designs.
- Do not delete GLB sources or legacy sprite assets until the replacement is integrated, visually approved and tested on the target branch.
- First prove the complete pipeline with Shadow (8 directions × 4 walk frames), then migrate all four heroes and the four existing monster roles.

The detailed conversion plan is documented in `docs/2D_5D_SPRITE_CONVERSION_PLAN.md`. If any later section in this file says to make production heroes/monsters fully 3D, treat that as historical and superseded by this decision. The approved 3D world/gameplay reference remains valid for composition, camera, environment and HUD; its character-rendering method is superseded.

---

# Archer FM — Historical Visual & Combat Direction (Superseded 2026-11-21)

> **HISTORICAL ONLY:** The full-3D hero/monster instructions in this section are obsolete. The binding production decision is 2D heroes and monsters with a polished 2.5D art treatment inside a lightweight 3D world, as specified at the top of this file and in `docs/2D_5D_SPRITE_CONVERSION_PLAN.md`. Do not resume GLB-based production hero rendering.

## Previous decision (2026-11-18; superseded)

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

## Historical visual target (environment/composition only)

The three-quarter/isometric camera and composition remain useful for the world. Character rendering is superseded: heroes and monsters must be 2D sprites with a polished 2.5D appearance, not production 3D models. The world/arena is planned as lightweight 3D.

### 1. Camera, scale and framing
- Establish a consistent elevated three-quarter view across the entire scene.
- Increase hero and monster visual prominence without changing their gameplay hitboxes or balance stats.
- Keep the controlled hero near the readable center/lower-center of the viewport; smoothly follow movement.
- Preserve touch-to-world coordinate correctness, minimap/HUD safe areas, and map-edge clamping.
- Test landscape aspect ratios and ensure large models/effects do not obscure objectives or enemy telegraphs.

### 2.1 Canonical four-hero roster reference (visual lock)

The only approved roster image for this pass is **`assets/references/approved_all/hero_roster_concept.jpg`**. Use the checked-in image itself for every comparison; do not generate, redraw, recolour, crop or substitute a new reference. The target art language is expressive chibi fantasy: oversized readable heads, large focused eyes, compact bodies, layered silhouettes, saturated signature colours and polished metallic/cloth materials.

Per-hero identity that must remain recognisable:

- **Ranger:** warm brown, strongly spiked/layered hair; bright green eyes; green hooded cloak/high collar and green tunic; brown leather/bronze pieces with gold edging; green-and-gold energy bow and visible arrow quiver. The face stays uncovered and readable.
- **Flame Knight:** vivid flame-red/orange spiked hair; warm red/amber eyes; red scarf and red armour over dark underlayers; prominent gold/brass shoulder and chest armour; large fiery orange-red greatsword. Must read as a knight, not a recoloured Ranger.
- **Shadow:** deep violet/dark-purple hood framing the face; bright violet eyes; layered dark-purple armour and cloak with purple gem accents; paired curved violet energy daggers. Keep the face visible inside the hood; no face mask that hides the reference expression.
- **Storm:** swept white/silver hair; bright blue eyes; blue scarf and blue/white robes/armour with gold trim; blue gem details; concentrated electric-blue lightning orb/energy in the hand. Must read as a lightning mage, not a sword fighter.

**Shared proportions:** preserve the reference's compact chibi body, large head, expressive face, short limbs and chunky readable boots/gauntlets. Do not stretch the models toward realistic human proportions. A visual pass is not accepted from palette alone: face, hair silhouette, costume layers, signature weapon and held/attached FX must all be checked in close-up and at gameplay scale.

### 2. Heroes — historical GLB direction, superseded
- The previous instruction to render production heroes as GLBs is cancelled.
- Production heroes must be 2D sprites with a polished 2.5D look, using the approved eight-direction reference identity and sprite conversion plan.
- GLB files may remain as archived/source/diagnostic assets during migration, but must not override the approved sprite renderer in production.

### 3. Monsters — historical full-3D direction, superseded
- The previous instruction to render all monster roles as production 3D models is cancelled. The four approved monster roles must use 2D sprites with a polished 2.5D look in the lightweight 3D world.
- Bring all four approved monster roles into the same 2.5D/isometric presentation language: runner, tank, stalker and ranged.
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

## Historical implementation sequence — superseded

The following sequence was written for the cancelled full-3D hero/monster direction. Do not execute it as written. Follow `docs/2D_5D_SPRITE_CONVERSION_PLAN.md` instead: Shadow sprite proof → reusable 2D/2.5D sprite system → Flame/Ranger/Storm sprite conversion → monster sprites → lightweight 3D world integration → visual polish and release tests.

1. **Baseline audit (historical):** inspect current code paths and capture artifacts for heroes, monsters, arena and camera. Produce a defect list. Record current test/build state. Keep existing camera fixes; do not spend the final camera-tuning pass yet.
2. **Hero completion — current active batch:** finish Ranger, Flame, Shadow and Storm as production-quality 3D chibi heroes. Audit the exact reference sheet, source meshes, rigs, face readability, materials, weapons, hand alignment, all required clips, eight facings, gameplay scale and performance. Fix and capture each hero individually; no hero passes on GLB presence or triangle counts alone.
3. **Monster presentation:** audit the existing painter/model pipeline; prototype one representative monster role first, then bring all four approved roles to the same standard. Keep fallback until each asset and animation is validated.
4. **Arena/environment pass:** terrain, lighting, props, castles/crystals and depth cues, while preserving readability/performance.
5. **Shared visual polish:** unify lighting, shadows, materials, contact grounding, outlines and restrained VFX across the now-stable heroes, monsters and arena.
6. **Final camera and composition:** tune angle/framing/zoom against the completed scene without changing simulation coordinates, collision radii or damage. Add capture tests for actor scale, map edges and touch-coordinate mapping.
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

