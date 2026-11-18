# Archer FM — Approved Large-Map MOBA Camera & World Direction

## Final visual decision (approved 2026-11-19)

The approved target is the **closer-camera, large-world, isometric MOBA presentation** shown in the user's second approved concept image. The game world must feel broad and explorable like a classic lane-based fantasy MOBA, while the camera stays close enough that the controlled hero, nearby monsters, faces, weapons, attack poses and hit effects are easy to read on a phone.

This replaces the earlier compact-arena / Archero-like framing as the visual target. Do not interpret the first wide concept image as the target. Do not use a far zoom that makes heroes and monsters look tiny.

The concept image is a direction reference, not evidence that the current game already implements this world or camera.

## 1. Core experience and camera

- Build toward a **large, continuous, explorable battlefield**. The visible screen is only a portion of the world; the player travels through it rather than seeing the entire battlefield at once.
- Use an elevated three-quarter/isometric camera inspired by League of Legends.
- Keep the camera relatively close to the controlled hero. It follows the hero smoothly while preserving enough forward visibility to navigate, spot enemies and react to attacks.
- Use the second approved image as the framing guide: hero and nearby monsters occupy meaningful screen space, with clear silhouettes and visible animation details.
- The hero and ordinary combat monsters must have **similar on-screen visual scale**. A monster may be larger or smaller according to its established role, but ordinary monsters must not be tiny beside the hero. Large boss/tank variants may be larger for a clear gameplay reason.
- Do not achieve readability by enlarging only the hero while leaving monsters miniature. Tune actor scale, camera distance, projection and framing together.
- Keep the world larger than the viewport, with meaningful travel distance, exploration, paths and areas beyond the current camera frame.
- Use camera bounds at the world edges, smooth follow, stable zoom and no sudden camera jumps. Avoid excessive camera shake.
- Preserve accurate world-to-screen and screen-to-world coordinate conversion for joystick movement, attacks, targeting, projectiles, minimap taps and collision.
- Provide a configurable camera zoom/scale for testing, but choose the approved close framing as the default. Do not expose a confusing zoom control unless it is deliberately designed into the game.
- Validate on real mobile landscape aspect ratios and safe areas. The camera must never hide the controlled hero behind HUD elements.

## 2. World and map layout

- Replace the feeling of a small boxed arena with a large MOBA-style map containing connected routes, open combat spaces, forest/jungle areas, monster camps, river/water features, bridges, rocks, walls, ruins, towers and team bases.
- Use readable main paths/lanes and side routes. The map should support movement, pursuit, retreat, flanking and exploration rather than forcing every fight into one tiny central space.
- Make landmarks and terrain silhouettes clear from the close gameplay camera. Use environmental variety without cluttering combat.
- Keep all routes navigable and ensure collision boundaries match what the player sees. No invisible walls across apparently open paths.
- Place monster camps and objectives deliberately across the world; show enough visual cues that players can understand where they are and where to travel.
- Use the minimap to communicate the full world layout, player/team positions, objectives and discovered/active threats. The minimap represents the larger world, not just the current viewport.
- Preserve the established four-player / team / crystal objective direction unless a separate gameplay decision explicitly changes it. Do not invent new win conditions, lanes-based economy, towers or minion systems simply because the visual reference resembles a MOBA.
- All seven crystals per player remain major objectives. Their locations must fit the larger world and remain reachable/defensible according to existing rules.

## 3. Heroes and player readability

- Keep the four playable heroes: Ranger, Flame, Shadow and Storm.
- Use the production GLB assets and current animation pipeline:
  - Ranger: `assets/heroes/ranger_new/ranger_animated.glb`
  - Flame: `assets/heroes/flame/model/flame_animated.glb`
  - Shadow: `assets/heroes/shadow/model/shadow_animated.glb`
  - Storm: `assets/heroes/storm/model/storm_animated.glb`
- Match the reference sheet at `assets/heroes/reference/heroes_reference_sheet.jpg` for each hero's face, hair, hood, armor, palette, weapon and overall chibi fantasy 3D identity.
- Faces must remain recognizable at the approved normal gameplay zoom, not only in a close-up model viewer. Eyes, facial shape, hair/hood and expression must not disappear into tiny pixels.
- Weapons must be visible and correctly attached to hands. Their silhouettes and attack motions must remain readable during movement and combat.
- Ensure idle, walk, run, attack, skill, hit, dodge and death states transition cleanly where clips exist. No foot sliding, floating, broken facing or mesh clipping.
- Maintain a consistent apparent scale among all four heroes. Do not change combat stats or collision dimensions just to improve visual size.
- Capture all four heroes at gameplay distance and close-up, from multiple facings, and compare against the reference before declaring visual quality complete.

## 4. Monsters and world creatures

- Retain the four established monster roles: runner, tank, stalker and ranged.
- Present monsters as clearly readable 3D fantasy creatures/units consistent with the hero art direction.
- At normal camera zoom, common monsters should appear close to the hero's visual scale. Their body shape, face/head, weapon or attack feature, locomotion and attack wind-up must be visible.
- Preserve role differences: runner is fast, tank is durable/heavy, stalker harasses/flanks, ranged attacks from distance. A tank can be visibly bulkier; this must not make ordinary monsters look miniature.
- Give each type a distinct silhouette, color/material treatment and attack telegraph.
- Audit the current procedural monster renderer and migrate in stages to validated 3D assets where needed. Keep a tested fallback until each replacement works.
- Preserve monster stats, AI, spawn rules, targeting, damage and rewards unless separately approved. Visual scale must not silently change hitboxes or balance.
- Validate all four types walking, turning, attacking, taking damage and dying at the approved camera distance.

## 5. Movement, controls and combat

- The player must move freely around the large world using the left virtual joystick, with responsive eight-direction/analog movement as supported by the existing implementation.
- The camera follows movement smoothly. Movement must not feel like selecting a lane or moving between fixed screen positions.
- Keep the right-side manual attack control: **one press = one attack**. Holding the attack control must never auto-repeat.
- Keep Dodge as a separate action.
- Keep the five-hit combo separate from the four Ultimate abilities.
- Keep four Ultimates per hero, unlocked at levels 1 / 10 / 20 / 30.
- Keep four heroes, three weapons per hero, level cap 40, equal health at equal level, and hero-specific movement speed/abilities.
- Preserve the current attack, cooldown, energy, damage, hit detection and progression rules. A larger world or MOBA-style camera is not permission to redesign combat balance.
- Make movement, attack, dodge and abilities work together under multi-touch without dropped input, stuck joystick state or accidental repeated attacks.
- Keep clear anticipation, impact and recovery for attacks. Effects must be visible at the closer camera without covering the hero or nearby monsters.

## 6. Crystals, bases and objectives

- All seven crystals belonging to each player must remain **large, tall, prominent faceted crystal pillars/columns**, not small loose gems or pickups.
- Each crystal has a strong vertical silhouette, sharp facets, visible grounded base, internal energy/glow and distinct team color.
- Make crystals readable as major objectives from normal gameplay camera distance and on the minimap.
- Keep health bars legible. Show progressive cracks/energy disruption as health falls and a clear collapse/shatter on destruction.
- Preserve seven crystals per player and existing HP values: 500, 700, 900, 1200, 1500, 1800 and 2200.
- Preserve current crystal placement/ownership/targeting/rebuild and collision/balance rules unless separately approved.
- Design bases, walls and routes around the large world so crystals are visible and accessible without blocking movement or hiding combat.

## 7. Environment, lighting and effects

- Establish one coherent stylized 3D fantasy art direction across heroes, monsters, terrain, props, bases and effects.
- Use terrain layers, ground materials, vegetation, rocks, cliffs, water, bridges, walls and ruins to make the world feel large and explorable.
- Use consistent lighting direction, contact shadows, material response, team colors and scale.
- Prioritize silhouette and gameplay contrast over decorative density. Grass, trees, particles and props must not hide heroes, monsters, projectiles or objective health bars.
- Give each hero and Ultimate distinct, recognizable effects. Use restrained trails, slash arcs, fire, lightning, poison, area indicators, impact flashes and damage feedback.
- Effects must communicate range, target, danger and impact. Do not flood the screen with bloom, particles or damage numbers.
- Maintain mobile performance with sensible LOD/detail reduction, culling and effect limits where needed.

## 8. HUD and mobile layout

- Keep the game in landscape orientation and Arabic-first.
- Preserve the left movement joystick and right-side manual attack/action controls.
- Keep HP/energy, level, dodge, combo/attack, four Ultimate abilities, objective indicators and minimap readable.
- Place the minimap so it communicates the whole large map without covering combat.
- Keep touch targets comfortable and do not shrink the world view unnecessarily.
- The hero and nearby enemies must remain visible between HUD elements. Adapt layout to phone aspect ratios and safe areas.
- Test movement + attack + dodge/ability multi-touch, pointer cancellation, pause/resume and screen resizing.

## 9. Technical architecture and migration safety

- First audit the current Flutter arena renderer, camera, world coordinates, movement, collision, combat, minimap and asset loading. The known starting implementation was a custom-painted arena with a GLB hero render path and procedural monster rendering; verify current HEAD rather than assuming architecture has changed.
- Evolve the existing project in deliberate stages. Do not perform a risky wholesale engine rewrite just to imitate a reference image.
- Preserve simulation coordinates and separate visual scale from collision radius, damage and stats.
- Keep GLB assets and legacy atlas/SVG fallback until replacements are proven in actual gameplay captures and tests.
- Use deterministic capture tests for camera framing, hero/monster relative scale, world-edge camera behavior, minimap mapping, movement coordinates, attacks and objective visibility.
- Do not delete source models, reference images, manifests or fallback assets as part of visual cleanup without a verified replacement and migration plan.

## 10. Implementation order and evidence gates

1. **Baseline and architecture audit**
   - Inspect current branch HEAD, camera, map dimensions, movement, collision, renderer, monster assets, minimap, controls and CI.
   - Capture current gameplay and record exact visual/technical defects.
   - Do not start asset replacement before understanding the current pipeline.

2. **Large-world prototype**
   - Establish world dimensions and connected traversable regions larger than the screen.
   - Add/verify paths, open areas, side routes and representative landmarks.
   - Verify movement, collision and world boundaries.

3. **Close MOBA camera prototype**
   - Implement smooth close follow and elevated isometric framing.
   - Tune hero and ordinary monster apparent scale together.
   - Confirm the hero, nearby monsters and attack effects are readable on a phone.
   - Verify world/screen coordinate mapping, minimap and HUD safe areas.

4. **Hero presentation**
   - Validate all four GLB heroes at actual gameplay zoom, multiple facings and animation states.
   - Fix face, weapon, materials, proportions and animation defects against the reference sheet.
   - Do not accept triangle counts or asset presence as visual proof.

5. **Monster presentation**
   - Prototype and validate one monster role at the target scale, then apply the standard to all four.
   - Check silhouette, scale, animation, attack telegraph, damage and death.
   - Preserve gameplay stats and hitboxes.

6. **Movement and combat integration**
   - Test free movement across the larger world, smooth camera follow and collision.
   - Verify one-press/one-attack, no held-button repeat, Dodge, five-hit combo and all 16 Ultimates.
   - Verify minimap navigation/indicators and objective visibility.

7. **Bases, crystals and environment**
   - Fit all bases and seven large crystal pillars per player into the expanded world.
   - Build readable terrain, routes, vegetation, lighting, shadows and landmarks.
   - Verify no route obstruction or objective occlusion.

8. **HUD, performance and polish**
   - Tune Arabic HUD, touch targets, safe areas, visual effects and minimap.
   - Profile on Android-class hardware; verify frame pacing, memory, loading and long-session stability.

9. **Release gate**
   - Run formatting, Flutter analyze, all tests, capture suite and Android release APK build.
   - Inspect fresh captures visually at the approved close camera distance.
   - Verify APK and CI artifacts belong to the exact same reported commit.
   - Report implemented, tested, visually inspected and still-pending items separately.

## Acceptance criteria — the approved result

- The battlefield feels like a **large explorable MOBA-style world**, not a small fixed arena.
- The camera is close and follows the player smoothly, matching the second approved concept's framing.
- The hero and nearby common monsters are both large and readable, with comparable apparent scale.
- Faces, weapons, movement, attacks and monster behavior are understandable at normal phone viewing size.
- The player can freely walk around the world; the minimap represents the full map.
- Paths, side areas, monster camps, bases and crystal objectives are visible and navigable.
- Existing Archer FM combat rules and progression remain intact: manual one-press attacks, separate Dodge, separate five-hit combo, four Ultimates at levels 1/10/20/30, three weapons per hero and level cap 40.
- All seven large crystal pillars per player retain their existing HP and gameplay rules.
- No regression in collision, targeting, damage, minimap, controls, objective rules or performance.
- Claims of completion are backed by current-HEAD tests, release build and visually inspected gameplay captures.

## Explicit non-goals

- Do not recreate League of Legends characters, maps, names, assets, UI or proprietary designs. Use only the broad genre conventions of a large isometric fantasy MOBA.
- Do not copy the first wide/zoomed-out concept image as the camera target.
- Do not convert the game into a lane-only or auto-battler experience.
- Do not add unapproved minion waves, shops, towers, lane economy, new classes, new monster roles or new win conditions.
- Do not change hero balance, crystal count/HP, attack semantics, combo, Ultimate unlocks or multiplayer rules as a side effect of visual work.
- Do not claim that concept art proves implementation.


## Repository audit and concrete implementation roadmap (2026-11-19)

The complete file/code gap audit is maintained in [`docs/implementation/MOBA_DIRECTION_GAP_AUDIT.md`](docs/implementation/MOBA_DIRECTION_GAP_AUDIT.md). Read it before implementation. It records the audited branch HEAD, existing foundations, technical blockers, exact file areas expected to change, phased work order and evidence gates. The audit clarifies that the current map is already larger than the viewport but still modest, the battlefield is predominantly 2D with a GLB hero composited into it, and all four monsters are currently procedural Canvas drawings with no production monster GLB directory in the audited tree. The first implementation batch must unify camera/projection and input coordinates, then prove one isometric prototype and actor scale before expanding the map or mass-producing monster assets.
