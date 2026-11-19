# Unified World Camera & Ground-Projection Prototype

Status: **partial prototype implemented; visual/gameplay acceptance gates remain open**. Shared ground compression, reversible camera/input mapping, and one combined hero/monster/corpse depth pass are now wired into the arena painter. This is not a completed 3D world conversion.

## Why this prototype is required

The current arena is rendered in one 2D world-space canvas using a top-down translation/scale camera. The playable GLB hero, however, uses a separate tilted perspective camera inside `Hero3DModel`. Monsters, projectiles, crystals, terrain and structures are still drawn by the 2D painter. Increasing the hero's GLB tilt or scale alone cannot produce one coherent League-style camera.

The current camera transform is valuable and must remain the single authority for widget-to-world input. Preserve that property while adding projection.

## Non-negotiable gameplay invariants

- Keep world simulation, collision, pathing, attack ranges, hit detection, fog cells and saved map coordinates in the existing world coordinate system.
- Keep manual attack semantics (one tap = one attack), Dodge, five-hit combo, Ultimate unlocks, hero stats, crystals, castles, mines and resource rules unchanged.
- Do not add MOBA lanes, minion waves, shops, towers, or new win conditions.
- Keep the landscape HUD and touch controls anchored in screen space; they must not inherit world projection.
- Do not replace the approved hero models or reference sheet as part of this camera task.

## Projection architecture

Introduce one immutable projection value object (suggested name: `ArenaWorldProjection`) with explicit, testable operations:

1. `projectGround(worldPoint, camera)` → screen-space ground anchor and camera depth.
2. `unprojectGround(screenPoint, camera)` → world-space point (inverse of step 1).
3. `projectHeight(worldPoint, worldHeight, camera)` → screen position for elevated geometry, using the same camera basis.
4. `projectRadius(worldPoint, worldRadius, camera)` → screen-space footprint for distance-scaled objects.
5. `visibleWorldBounds(viewport, camera)` → conservative world-space culling bounds.

Camera parameters (yaw, pitch, focal length / orthographic scale, target, zoom) must be explicit configuration, not scattered constants. Use a stable oblique top-down camera first; do not add free camera rotation yet.

The projection must preserve depth ordering. Define one documented depth key from projected ground depth plus a stable tie-breaker. Sort monsters, player, corpses, crystals, pickups and other upright actors by this same key. Keep ground decals/shadows below actors and foreground occluders above actors according to that key.

## Rendering migration order

1. **Projection math only:** add forward/inverse projection, height offset, depth and culling math. Add property-style tests for round trips, center stability, monotonic depth, viewport edges and multiple landscape aspect ratios.
2. **Camera/input integration:** extend `ArenaCameraTransform` to delegate world/screen conversion to the projection. Painting and pointer input must use the exact same transform instance and camera snapshot. Add tests for taps during camera smoothing, letterboxing and zoom changes.
3. **Ground pass:** project the base terrain, biome patches, river centerlines/banks and bridge footprints. Keep all simulation coordinates unchanged. Capture the same deterministic map before/after and verify no geometry disappears at the viewport edges.
4. **One actor prototype:** migrate exactly one representative monster to projected ground anchoring and shared depth sorting. Keep its body upright (do not shear the character sprite/mesh with the ground plane). Add an overlap/occlusion capture with the hero and an obstacle.
5. **Hero alignment:** anchor the GLB feet at the projected ground point. Align the GLB camera yaw/pitch and scale/depth response with the shared projection; remove the current independent camera mismatch only after captures prove alignment.
6. **Combat/objective passes:** migrate projectiles, AoE, FX, castle/crystal anchors, crystal HP bars and pickups. Keep HUD and floating UI readable in screen space where appropriate.
7. **Map traversal:** only after rendering and input are stable, prototype one connected route and one monster camp; verify collision reachability and joystick movement before expanding the map.

## Visual acceptance gates

Capture at minimum three landscape aspect ratios (narrow phone, 16:9, and wide phone/tablet) with:
- hero near screen center and near each viewport edge;
- one monster in front of and behind the hero;
- one tree/rock occluder;
- a river and bridge;
- one castle and its seven crystal objectives;
- a moving projectile and one area effect.

A human visual review must confirm that:
- the camera is closer than the old view while the hero, monsters and crystal structures remain legible;
- faces and weapons remain visible at gameplay distance;
- all actors stand on the same ground plane (no floating or sliding);
- foreground objects correctly occlude actors;
- the minimap, joystick, action buttons and Arabic HUD do not move with the world;
- taps land on the visible target while the camera is moving.

Automated tests and non-empty render captures are not proof of visual quality by themselves.

## Performance and rollback gates

- Record baseline and prototype frame time / CPU skinning time on the same Android device and map seed.
- Avoid per-frame allocations in the projection hot path; cache camera matrices and projected positions per frame where safe.
- Keep a feature flag or a clean commit boundary so the old camera can be restored if touch mapping, collision, readability or frame pacing regresses.
- Do not start the four-monster GLB production pass until the one-monster projection prototype passes the visual, gameplay and performance gates.

## Current evidence

- `ArenaCameraTransform` currently uses a uniform scale, letterbox origin and smoothed `world.cameraOrigin`; its forward/inverse methods are top-down translation/scale.
- `ArenaPainter.paint` currently translates by the camera origin and draws terrain, monsters, projectiles, FX and hero in the same 2D world canvas.
- `Hero3DModel` applies a separate 0.9-radian tilt and perspective divide internally. Its comment explicitly describes a separate tilted top-down camera.
- The current map bounds are 1920–2400 × 1080–1440 world units, while the logical arena viewport is 960 × 540.
- The latest camera regression run has passed all tests and hero capture generation; the release APK build was still running at the time this document was written. Do not call the APK verified until the workflow's verify step succeeds.

## Prototype implementation update (2026-11-19)

Implemented on `ranger-reference-work`:
- Added reversible oblique ground projection math and camera/input integration.
- Applied the same 0.82 ground-depth compression to the arena canvas while locally counter-scaling upright actors.
- Replaced the separate monster-only pass plus always-on-top hero pass with one depth-sorted actor list containing visible enemies, owned units, corpses, the player hero, trees and rocks. Trees/rocks now act as foreground occluders when their ground depth is nearer.
- Removed a per-actor viewport-transform construction from the upright actor path; it now reuses the painter's immutable projection.
- Added a camera regression test that checks viewport-corner and center round trips across three landscape sizes during eight camera-smoothing updates.
- Added a deterministic map capture with a tree placed in front of the player actor (`35_actor_tree_occlusion.png`). The capture exercises the shared painter order, but its `ArenaPresentation` supplies no `Hero3DController`; it is not evidence that the production GLB hero is correctly occluded.

Still not implemented or accepted:
- Terrain/river/bridge geometry has not been migrated to a full yawed 3D/isometric projection; current ground transform is vertical compression only.
- Trees and rocks participate in the same painter-order list as actors. Tree shadow/trunk, main crown, and upper highlight lobe are independently depth-sorted using separate anchors. The canopy is still represented by two filled circular lobes rather than per-branch geometry, so complex silhouette overlaps remain approximate; rocks remain single shapes.
- Projectiles, AoE, castles, crystals, pickups and fog are not all depth-sorted/projected with actors.
- Automated captures are not a substitute for review on physical Android devices.
- No frame-time/CPU-skinning benchmark has been recorded.
- No production monster GLB should start until the single-monster visual prototype passes these gates.

## Occlusion verification limits and next gates

The deterministic tree capture in `map_capture_test.dart` is only a visual artifact and renders the fallback player representation. A separate production-path capture test now loads `ranger_animated.glb`, passes its `Hero3DController` into `ArenaPainter`, and saves foreground-tree, background-tree and foreground-rock scenes at multiple landscape sizes (`test/hero3d_occlusion_capture_test.dart`). These are real GLB inspection captures, but they still do not assert pixel-level occlusion or prove visual acceptance; inspect the generated PNGs before signing off. The next implementation pass must add a GLB-enabled capture (or a stable test double with the same paint bounds), a corresponding no-occluder baseline, and assertions/review that confirm the expected foreground pixels actually cover the actor. Repeat the case with a rock and with the actor on both sides of the obstacle depth anchor. The GLB capture test now creates those cases; the remaining gate is to inspect its images and add pixel-level assertions if stable across the software rasterizer. Then test narrow landscape, 16:9 and wide landscape captures before accepting the camera.

The painter-order implementation has since been refined: tree shadow/trunk, main crown and upper highlight lobe are independently sorted. This improves partial occlusion but is not full mesh-level foliage sorting; the two canopy lobes remain filled circles and rocks remain single depth-sorted shapes.

## Initial capture review (run 44423577850)

Artifact `archer-fm-3d-hero-visual-captures` (artifact ID `14482777856`) was downloaded and inspected. These are automated test captures, not a live-device play session.

Observed in `71_game_3d_hero_idle.png` and `72_game_3d_hero_attack.png`:
- The hero is rendered as a real 3D model and is distinguishable in the arena capture.
- The view is still essentially top-down/flat 2D terrain; it is not yet the requested coherent oblique 3D world camera.
- The hero, monsters and objectives do not yet share a unified projection. The hero is composited over the 2D arena.
- Nearby monsters remain small compared with the large crystal structures; their silhouettes and attack readability need a closer gameplay camera and a consistent actor scale.
- The current crystal objectives are visible and have readable health bars in this capture. Preserve their prominence during camera changes.
- `30_map_world.png` and `31_map_fog.png` show a map rendered as a flat 2D layout with hard-edged fog regions; they do not demonstrate the larger connected, angled world direction.

These observations justify starting with the shared projection prototype. They do not establish that all four hero faces match the reference or that all combat effects are visually polished.


## Split tree depth layers (2026-11-19)

- Tree rendering is now split into a ground shadow/trunk layer and a canopy layer. Each layer is inserted independently into the same depth-sorted actor list; the canopy uses an elevated ground anchor while the trunk keeps the obstacle ground anchor.
- This permits partial occlusion across the canopy/trunk boundary instead of forcing the complete tree to render before or after the hero.
- Added GLB capture `78_glb_tree_split_canopy_trunk_16x9.png`, placing the trunk anchor slightly in front of Ranger while the canopy anchor falls behind him. This capture is a review case, not a pixel-level pass/fail assertion.
- Remaining limits: the canopy itself is still one filled silhouette, not per-branch geometry; large canopy overlaps can still be approximate. Rocks remain single depth-sorted shapes. Inspect the new artifact and test on Android before accepting the result.


## Fine-grained tree canopy ordering (2026-11-19)

The tree canopy is now represented by two independently depth-sorted draw layers: the main crown and its upper highlight lobe. Together with the separately sorted trunk/shadow layer, this reduces the size of each indivisible occlusion region and allows more partial overlaps with the player model. Projection tests verify the expected depth ordering of all three anchors.

The GLB inspection test now also emits `73_glb_hero_no_obstacle_baseline.png`. Compare this baseline with captures 74–78 to determine whether the actual model silhouette is visible and which pixels are covered by the obstacle. These are still review captures; they do not constitute a pixel-level automated occlusion assertion.

The camera suite now includes a yawed-projection pointer round-trip test. This validates the transform math only: the live arena painter currently applies vertical ground compression, not the full yaw rotation to terrain and every world object. The approved oblique 3D world camera remains unfinished.


## Regression expansion after fine-grained canopy work (2026-11-19)

- Added projection invariants for camera focus origin, translation-invariant depth differences, negative height offsets, and linear projected displacement.
- Added camera regressions for letterbox geometry, fixed center under yaw, and inverse-projected viewport corner containment.
- Added two real Ranger GLB review captures for a far-background tree and a background rock, complementing the existing foreground/background tree, split-depth tree, foreground rock and no-obstacle baseline.
- These additions expand mathematical and visual review coverage; they do not establish a full yawed world renderer or visual acceptance. Await CI and inspect the newly generated artifact.


## Render-order and projection boundary audit (2026-11-19)

Source inspection confirms the current pass order in `ArenaPainter.paint`:

1. Terrain, biome patches, rivers, bridges, mines, castles and pickups are painted as ground content.
2. Ground shadows are painted before the actor depth list.
3. Corpses, monsters, army units, tree trunk/canopy layers, rocks and the player are depth-sorted together.
4. Projectiles are painted in a later pass, above the complete actor list.
5. Combat effects, fog and floating labels are separate later passes.

Consequences:
- The actor list has shared depth ordering, but projectiles are not yet interleaved with trees/actors by ground depth. A projectile can therefore appear above an obstacle even when its ground anchor is behind it.
- Terrain and objective structures are still flat ground-pass geometry; they are not yet height-aware 3D meshes.
- The painter currently applies only the shared vertical ground compression (`groundScaleY=0.82`). The live renderer does not apply `yawRadians` to all terrain, actors, projectile paths, fog and effects.
- The camera's yawed inverse mapping is covered by mathematical tests, but must not be mistaken for a live yawed scene.

These are explicit remaining integration tasks, not accepted visual behavior. The next renderer milestone should introduce a single projected ground-anchor/depth record for projectiles and objective/environment actors, then capture crossing cases before enabling any non-zero live yaw.


## Projection edge-case coverage update

Regression coverage now explicitly includes invalid zero scale/depth-compression assertions, very small and large positive depth compression, projected radius behavior, height-vs-depth independence, and finite visible bounds. These tests exercise the math object only; they do not imply that non-zero yaw is enabled in the live painter.


## Camera viewport regression update

Camera tests now cover immutable viewport snapshots, positive scale across supported landscape aspect ratios, logical center alignment, yawed viewport-origin stability, repeat projection idempotence, and separation of letterboxed world viewport from screen-space HUD space. Input transforms remain tied to the same camera snapshot; HUD rendering remains unprojected.


## Explicit remaining renderer blockers

Before enabling yaw in production, migrate every world-space pass together: terrain and biome fills, river/bridge geometry, crystal and castle silhouettes, mines/pickups, shadows, actor anchors, projectile trajectories, combat effects, fog cells and floating labels. Upright actor compensation must use the same projection basis. Keep HUD, joystick, action controls and minimap UI in screen space. Verify touch hit-testing against the exact projected scene and validate map-edge clamping after inverse projection.


## Projectile depth integration acceptance criteria

Projectiles currently render after the combined actor/obstacle pass. The next implementation must represent each projectile with a ground anchor plus visual height, sort its ground anchor against actor and obstacle depth keys, and render the projectile body at its height without changing its ground depth. Required captures: projectile behind trunk, projectile in front of trunk, projectile crossing canopy depth, projectile crossing a monster, and projectile passing above a crystal. Keep trails and impact FX attached to the same projectile state and avoid sorting purely by screen Y.


## Visual evidence checklist

A passing CI run is necessary but insufficient. Review and retain: unobstructed Ranger GLB baseline; foreground and background tree; foreground and background rock; canopy/trunk partial overlap; all four landscape aspect ratios; world edges and letterbox boundaries; projectile/actor crossing cases; fog boundaries; crystal readability; and a full-scene screenshot with terrain, bridge, castle, mine, monsters and player visible. Compare hero face, armor and weapon against `assets/heroes/reference/heroes_reference_sheet.jpg` separately.


## Projectile pass implementation checkpoint (2026-11-19)

The production painter now adds each projectile to the same depth-sorted draw-entry list used by the player, monsters, corpses, and split tree/rock obstacle layers. Projectile depth uses its current world position as the ground anchor and the same `ArenaWorldProjection.depthOf` function as actors. The projectile's glow, edge, core, arrow head, and trail are drawn together as one entry, preserving their internal appearance while changing their relationship to foreground/background actors.

The former unconditional projectile pass after all actors has been removed from the production paint sequence, preventing duplicate rendering and preventing every projectile from automatically appearing above every tree/monster. The compatibility helper remains available for isolated capture tooling.

A defensive guard skips a projectile with effectively zero velocity rather than normalizing a zero-length vector. This avoids NaN geometry during transient/invalid projectile states.

### Current limitations

- Projectile visual height is not yet modeled as a separate state field. The current position is used as the shared ground-depth anchor.
- Projectile trails are sorted with the projectile head as one visual unit; long trails do not yet split across multiple depth layers.
- Crystal/castle/building geometry remains in the earlier ground pass and is not part of the actor depth queue.
- No visual claim is made until the new overlap captures are reviewed.


## Projectile regression tests

Added a painter-level regression that renders a moving projectile through the production arena painter and a second regression for a zero-velocity projectile. These tests check that the new path can render without invalid vector normalization or painter exceptions. They do not replace pixel-level ordering captures for behind/in-front crossings.


### Additional projectile painter cases now covered

The regression suite also covers: multiple simultaneous projectiles; left/up travel direction; very high velocity values; no mutation of position or velocity while painting; no-enemy/no-army scenes; projectiles alongside obstacles/corpses; large projectile styling; and repeated paints with unchanged simulation state. Together with the moving and zero-velocity cases, this gives ten painter-level scenarios. The tests validate safe rendering/state immutability, not pixel-perfect occlusion order.


## Shared yaw projection is now wired into the painter (2026-11-19)

- `ArenaPainter` accepts an immutable `ArenaWorldProjection` snapshot and passes that exact instance to `ArenaCameraTransform` for world-to-widget mapping.
- The world canvas now applies the projection in the same order as the math model: rotate by `yawRadians`, then compress the camera-depth axis by `groundScaleY`.
- Upright actors apply the inverse yaw and inverse depth scale around their own ground anchor. This includes hero/monster/corpse bodies, projectile geometry, split tree trunk/canopy layers, and floating labels.
- The default projection remains yaw zero with `groundScaleY=0.82`; the new non-zero-yaw painter regression exercises the opt-in path. This is not a claim that the shipped game has enabled yaw by default.
- Mines, castles, terrain, bridges, pickups, zones, fire waves, fog and world effects inherit the shared ground transform because they are painted inside the same world canvas.
- Remaining visual review: confirm objective structures and mines remain legible under yaw; rocks are ground-plane silhouettes; confirm crystal labels/HP bars and touch targeting visually; inspect all target landscape aspect ratios. Do not turn on a non-zero production yaw until captures are reviewed.

## Castle occlusion layers (2026-11-19)

The castle renderer no longer submits the complete castle as one oversized depth unit.
The courtyard, keep/banner, each wall arc (including that arc's crenellations), and
each living crystal are separate entries in the same ground-depth queue as the
player, monsters, corpses, obstacles and projectiles.

- Courtyard and keep use the castle anchor.
- Each wall arc uses the midpoint of its own ground-plane arc as its depth anchor.
- Each crystal uses its own base position; its tall body and HP bar remain a single
  upright visual unit.
- Fallen castles and destroyed crystals are omitted using the existing gameplay
  state. No HP, collision, target selection, wall geometry or castle ownership
  rules were changed.
- The castle layer regression suite covers four castles, all 16 wall arcs,
  missing/single wall sets, narrow/wide arcs, fallen castles, destroyed crystals
  and repeated rendering.

This improves coarse wall-segment occlusion, but it is not mesh-level 3D geometry:
individual crenellations, banners, and the keep's vertical surfaces are still
drawn together with their owning layer. Pixel-level capture review is still
required before calling the visual result final.

## Mine and pickup depth integration (2026-11-19)

Mines, loose resource piles and map chests have been removed from the terrain-only
overlay and submitted to the shared world actor depth queue.

- A mine uses its ground center as its depth anchor. Its pit, ore, ownership ring,
  size pips and capture-progress arc remain a single stable visual group.
- Loose mine-output/resource piles use their own world positions.
- Map chests use their own world positions; resource-kind map entries remain
  skipped in this pass because their runtime resource-pile representation is
  supplied by the mine controller.
- Ownership colors, mine size, capture progress, pickup amount/age and all
  gameplay state remain unchanged by painting.
- The regression suite covers neutral/local/rival ownership, all mine sizes,
  capture-ring progress, yawed projections, missing mine/chest/resource sets,
  pickup immutability and repeated paints.
- Real Ranger GLB capture coverage now includes foreground/background mine
  overlap, chest overlap and loose-resource overlap.

This is ground-anchor sorting, not per-ore-chunk or per-pixel 3D occlusion.
River bridges and the continuous terrain/river surface remain in the terrain
pass and still need a dedicated projection/occlusion review.

## Ground, biome and river pass — first five stage-one tasks (2026-11-19)

Completed the first five planned terrain/projection tasks as a focused batch:

1. Added a regression proving the arena painter and pointer/camera transform consume the exact same injected projection snapshot.
2. Added a projection invariant proving the projected vertical ground coordinate and depth-sort key remain consistent across positive, negative and zero yaw.
3. Corrected hero and monster contact-shadow anchors: shadows now sit close to the actor's ground/foot anchor rather than visibly trailing below it.
4. Reworked river banks into three nested shore layers (outer bank shadow, mid bank, inner shoreline) so the edge remains legible after ground compression.
5. Changed water shimmer strokes to follow the local river segment normal, instead of always drawing vertically; this keeps highlights perpendicular to curved/angled river flow.

Added `test/arena_terrain_projection_test.dart` to paint generated biomes, rivers and bridges at multiple yaw/scale settings, verify terrain painting does not mutate river/bridge geometry, and check camera hit-mapping round trips.

Important boundary: production yaw remains zero by deliberate choice until full-scene visual captures are reviewed; the shared projection supports yaw and the tests exercise it, but no unreviewed camera rotation has been forced into gameplay. Bridge deck depth sorting and 3D terrain meshes are not claimed complete.
