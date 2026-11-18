# Archer FM — Repository Gap Audit for the Approved MOBA-Style Result

**Audit date:** 2026-11-19  
**Audited branch:** `ranger-reference-work`  
**Audited code/documentation HEAD:** `481140e635730dfa82dcae4666b40fd01176677f`  
**Audit scope:** recursive repository tree (3,206 tracked paths; tree was not truncated), core world/camera/render/input/monster/hero/combat/minimap files, relevant tests, project status and Android workflow.

This is a code-and-file audit, not a claim that the game has already reached the approved image. It distinguishes existing foundations from missing work.

## Executive result

Archer FM already has several useful foundations: a generated world larger than the screen, free analog movement, a smoothed follow camera, fog of war, rivers/bridges, four castles, mines, a full-world minimap, four GLB hero assets, combat systems and a sizeable automated test/capture suite.

However, the current implementation is **not yet the approved close-camera MOBA-style result**:

- The world is only about 2–2.5 camera-widths wide and 2–2.67 camera-heights tall (roughly 4–6.2 viewport areas), not yet a convincingly expansive world.
- The map generator creates scattered biome patches, a single river, bridges and randomly placed props; it does not yet create designed lanes/roads, connected jungle routes, readable monster camps or strong navigational landmarks.
- The battlefield is still primarily a **2D custom-painted world**. The player hero is a skinned GLB drawn into that 2D canvas with its own tilted/perspective projection. This is not one unified 3D/isometric world camera.
- All four monsters are drawn procedurally with Canvas shapes in `arena_painter.dart`; the repository tree contains no production monster GLB/model asset directory.
- The current camera window is fixed at 960×540 world units. The hero is drawn at a presentation target around 120 logical pixels, but monster sizes come from small gameplay radii. The requested close framing and hero/common-monster relative scale have not been proven in captures at phone resolution.
- The minimap shows the whole generated map and important markers, but is passive/non-interactive and currently very small (156×92 by default).
- Current capture tests prove that map/actors can be painted, not that the game matches the approved image or is readable on a real phone.

**Conclusion:** this is a staged world/camera/rendering upgrade on top of existing gameplay—not a blank-slate rebuild, but also not a camera-only tweak.

## 1. What is already present

| Area | Verified repository foundation | What that does and does not prove |
|---|---|---|
| World size | `arena_map.dart`: randomized map width 1,920–2,400 and height 1,080–1,440; camera window 960×540 | The map is larger than the screen, but the total travel/exploration space is still modest for the approved target. |
| World features | Four biome kinds, one meandering river with bridges, 8 mines, 52 intended tree placements, 20 intended rock placements, pickups/chests, four castle anchors | These are present as generated data and painter primitives; designed lanes, paths, jungle camps and environmental depth are not present as a complete map layout. |
| Movement | Analog `setMoveInput`, direct world movement, obstacle sliding, map-edge clamping, water speed modifier | Free movement exists. There is no verified navigation/pathfinding layer for units moving around a much more complex map. |
| Camera | Camera follows the hero with a smoothing lerp and clamps at map edges | It is a centered 2D camera window, not yet the approved close MOBA camera with a unified projection and configurable world viewport. |
| Fog | Cell-based exploration reveal and distance-based enemy visibility | Foundation exists; visibility and minimap behavior need retuning after the world/camera scale changes. |
| Minimap | Full-map scaling, explored terrain, rivers, four castles, mines, crystals and local player marker | Useful foundation; no current camera viewport rectangle, teammate/enemy markers, route/camp information or tap-to-navigate behavior was found in the inspected painter. |
| Heroes | Four production GLB paths for Ranger, Flame, Shadow and Storm; 3D skinned mesh renderer/controller; animation and capture tests | Hero model loading/rendering exists. The model is composited into a 2D arena and needs gameplay-distance face/weapon review against the reference sheet. |
| Monsters | Four approved roles with separate stats, AI/animation state, hit bars and procedural walk/attack poses | They are not production 3D models; they are custom-painted 2D characters and need a visual/asset pipeline upgrade. |
| Bases/crystals | Four castles, seven crystals each, HP values and rebuild logic; crystal monolith renderer was added | Gameplay foundations exist. Need inspect current capture at the new camera distance and fit the bases into a larger designed world. |
| Combat | Manual attack input, five-hit combo, four Ultimates per hero at levels 1/10/20/30, three weapons per hero in data | Preserve these. Re-test targeting, range, projectiles and effects after projection/scale changes. |
| UI | Landscape HUD, joystick, action cluster, minimap, Arabic labels/settings | Existing layout is dense; closer camera/world view must be protected from HUD overlap and minimap/control placement may need redesign. |
| Tests/CI | Map/world/monster/hero/combat/widget/capture tests and Android workflow | Coverage exists, but no acceptance suite yet asserts approved camera zoom, isometric ground projection, large-world routes, actor relative screen scale or real-device readability. |

## 2. Critical technical findings to address early

### A. Camera and coordinate mapping must be unified

- `ArenaPainter.paint` paints a fixed `arenaWidth × arenaHeight` (960×540) viewport, scales it to the widget, then translates by `world.cameraOrigin`.
- The camera origin is smoothed in `GameWorld.update`.
- `arenaToWorld` currently converts taps using `arenaCameraOrigin(world)` (the instant hero-centered origin), while the painter uses the smoothed `world.cameraOrigin`. During camera movement these can differ. This needs a regression test and one shared camera transform before adding zoom or isometric projection.
- Joystick movement is direct world-space movement and currently does not depend on camera projection; tap/targeting/projectile visual alignment does.

### B. The 3D effect is currently limited to the hero

- `hero3d_painter.dart` performs CPU skinning and its own model yaw/tilt/perspective before drawing triangles onto Canvas.
- `arena_painter.dart` still paints terrain, water, trees, rocks, castles, mines, monsters and effects using 2D Canvas primitives.
- A closer/isometric presentation must decide and implement a consistent ground-plane projection for **all** world entities. Applying a tilt only to the hero will make feet, monsters, projectiles, walls and collision cues disagree.
- Recommended path: first create a shared camera/projection abstraction and a controlled 2.5D/isometric prototype; do not jump into a full engine rewrite without a tested prototype proving the current Flutter renderer cannot meet the target.

### C. Monster models are the largest missing art pipeline

- `MonsterType` and gameplay definitions exist for runner/tank/stalker/ranged.
- `_paintMonster` and type-specific body methods in `arena_painter.dart` draw these as procedural Canvas characters.
- No `assets/monsters/**` production model folder appeared in the audited repository tree.
- Create a model/rig/animation specification for the four existing roles, then produce and validate one representative 3D monster first. Only after scale, animation, materials, performance and fallback are proven should the other three be produced.
- Preserve current stats, AI roles, hitboxes and spawn/economy rules.

### D. World generation needs designed structure, not just more random props

- Current generator places four castles around quadrants, one river, biome circles, mines, trees and rocks.
- It does not define explicit main paths/lanes, side routes, jungle loops, monster camp locations, chokepoints or navigation landmarks.
- The approved world should be generated from a layout graph/template with controlled random variation, ensuring every base has viable routes to the shared map and objectives.
- Increase world dimensions only after designing travel time, spawn separation, route lengths, fog reveal, enemy visibility, AI target acquisition and network payload/performance implications.

### E. Screen-space scale and phone readability need measurable acceptance tests

- Current monster drawing derives from `monster.radius × 2.35`; current hero rendering uses a target-height scale. These independent systems do not guarantee similar apparent sizes.
- Define target screen-space height ranges for hero, runner, stalker, ranged and tank at default zoom. Tank can be bulkier; ordinary monsters must remain close to the hero's apparent size.
- Test at representative landscape phone sizes and safe areas. Do not tune only a 960×540 golden image.
- Measure visible playfield area after HUD/control overlays and ensure nearby combat remains readable.

## 3. Required implementation steps — ordered dependency plan

### Phase 0 — Lock baseline and protect existing gameplay

1. Re-check the branch HEAD and current CI before coding.
2. Capture the current game at multiple landscape aspect ratios with hero, all four monster types, castle/crystals, river, bridges, fog and HUD.
3. Record current hero/monster screen-space heights, camera visible-world dimensions, movement speed/travel time between bases, render cost and frame time.
4. Add baseline tests for camera transforms, tap-to-world mapping during camera smoothing, joystick movement, collision, minimap mapping and one-tap attack behavior.
5. Keep all existing GLB files, reference sheets, atlases and fallback paths.

**Exit gate:** reproducible baseline captures and passing coordinate/input tests.

### Phase 1 — Build a unified close isometric camera/projection

1. Introduce one camera model describing viewport size in world units, zoom, projection/tilt, camera center/origin and screen safe area.
2. Route painter transforms, tap conversion, target selection, projectile rendering, world labels and minimap viewport indicators through the same camera transform.
3. Make the default camera closer than the current 960×540 world-unit view, using the second approved image as the composition guide.
4. Keep smooth hero follow, map-edge clamping and enough forward visibility to navigate.
5. Add camera zoom/edge/letterbox tests and test the camera while the hero is moving, not only while stationary.
6. Render the hero feet anchor and ground contact consistently; avoid a separate hero-only projection.

**Exit gate:** hero, ground, monsters, projectiles and taps all agree in world/screen position; hero is visibly larger without HUD overlap.

### Phase 2 — Design and expand the large world

1. Replace purely scattered random placement with a world layout/template or graph that guarantees connected traversable routes.
2. Expand dimensions based on measured travel time and desired exploration, not arbitrary multiplication.
3. Define clear main routes, side routes, jungle/forest loops, river crossings, open battle clearings, chokepoints and landmarks.
4. Place four castles, eight mines, seven crystals per castle and resource/chest sites without blocking routes.
5. Define monster camps and spawn regions for the existing four roles without changing their stats or introducing new gameplay types.
6. Add deterministic seeded generation and validation that every base/objective is reachable.
7. Tune fog cell size/reveal radius and enemy visibility radius to the new world and close camera.
8. Add map navigation/pathfinding for autonomous units if the denser terrain makes direct steering insufficient.

**Exit gate:** several seeds produce readable, connected, balanced maps; no castle, mine or crystal is trapped behind unwalkable terrain.

### Phase 3 — Build the world presentation

1. Convert ground, rivers, bridges, paths, trees, rocks, walls, bases and props to a consistent elevated/isometric 2.5D presentation.
2. Add depth sorting/occlusion rules so objects in front can cover feet while never hiding critical health bars or combat warnings.
3. Add height cues, contact shadows, lighting/material response and biome transitions.
4. Add map landmarks and camp visuals that remain identifiable at the close camera distance.
5. Add culling/visible-region rendering so the larger map does not draw every object every frame.
6. Preserve the 2D fallback during the transition.

**Exit gate:** environment and actors share one ground plane/projection; routes and obstacles visually match collision.

### Phase 4 — Upgrade the four monsters to the target quality

1. Write a production spec for runner/tank/stalker/ranged: silhouette, size class, colors, face, materials, rig, clips and attack telegraph.
2. Prototype one monster (recommended runner or stalker) as a true 3D model with bones and idle/walk/run/attack/hit/death clips.
3. Integrate the prototype through a shared actor renderer using the same projection as the hero and ground.
4. Compare its screen-space size with the hero at default zoom and tune all actor scales.
5. Test all animations, facing directions, hit reaction, bars, team ownership, fog visibility and performance.
6. Produce the other three only after the prototype passes.
7. Retain procedural fallback until each model is validated.

**Exit gate:** all four roles are distinguishable and animate correctly at normal phone gameplay zoom; relative scale is proven in inspected captures.

### Phase 5 — Finish hero presentation at gameplay distance

1. Inspect all four GLBs and reference sheet side by side.
2. Capture close and normal gameplay views for all eight facings and idle/walk/run/attack/skill/hit/dodge/death states where supported.
3. Fix face visibility, proportions, armor palette, weapon attachment, foot contact and animation clipping at the source/model level.
4. Verify the 3D hero uses the same ground projection, depth ordering and lighting as monsters and environment.
5. Tune hero scale together with ordinary monster scale, not in isolation.

**Exit gate:** each hero is identifiable and faithful to the reference sheet at default gameplay zoom, supported by inspected captures.

### Phase 6 — Combat, objectives and UI integration

1. Revalidate manual one-press/one-attack and no held-button auto-repeat.
2. Revalidate five-hit combo separately from each hero's four Ultimates at levels 1/10/20/30.
3. Re-test melee range, projectile paths, targeting, collision, AoE and effects under the new projection.
4. Keep seven crystal pillars per player and HP values 500/700/900/1200/1500/1800/2200; relocate only through a validated map layout.
5. Add minimap camera viewport rectangle and readable player/team/objective markers; decide whether tap-to-ping or tap-to-navigate is required before implementing it.
6. Rework Arabic HUD/control placement to preserve a large playfield and comfortable touch zones.
7. Test multi-touch movement/attack/ability/dodge and pause/resume on devices.

**Exit gate:** no gameplay regressions and no important actor/objective obscured by HUD or effects.

### Phase 7 — Performance, multiplayer and release proof

1. Profile CPU skinning, Canvas draw calls, map culling, actor counts, particles and memory on a mid-range Android device.
2. Test large-world seed synchronization and world generation determinism for online/LAN clients.
3. Check network state size and update cost after adding paths/camps/actors.
4. Run formatting, analyze, all tests, camera/map/actor capture suite and Android release APK build on one commit.
5. Inspect captures at actual landscape phone resolutions and test the APK on a real device.
6. Report separately what is implemented, automated-tested, visually inspected and manually device-tested.

**Exit gate:** same-commit CI/APK/captures pass, with a real-device play session and acceptable performance.

## 4. Files and areas expected to change

| Area | Existing files | Expected work |
|---|---|---|
| Camera/projection | `lib/game/world/game_world.dart`, `lib/game/arena_painter.dart`, `lib/game/game_screen.dart` | Shared camera transform, zoom/viewport, coordinate conversion, input/render alignment. |
| Map generation | `lib/game/world/arena_map.dart` | Layout graph/templates, paths, camps, connected routes, expanded world and deterministic placement. |
| World rendering | `lib/game/arena_painter.dart` (or extracted render modules) | Isometric ground plane, environment depth/occlusion, culling, actor depth sorting. |
| Hero rendering | `lib/game/render3/glb.dart`, `hero3d_painter.dart`, `hero3d_controller.dart`, hero assets/manifests | Shared actor projection, gameplay-distance visual fixes and captures. |
| Monster rendering/assets | `lib/game/monsters/monster_models.dart`, `lib/game/arena_painter.dart`, new `assets/monsters/**`, new renderer/controller | Four 3D monster assets and animations with procedural fallback. |
| Minimap/fog | `lib/game/minimap.dart`, `lib/game/world/fog_of_war.dart` | Camera viewport, map landmarks, scale-tuned reveal/visibility, optional navigation interaction. |
| Objectives | `lib/game/world/castle_system.dart`, crystal painter section in `arena_painter.dart` | Place/scale crystals and bases in new layout; preserve rules and HP. |
| Controls/HUD | `lib/game/game_screen.dart`, settings | Keep movement/attack controls; improve screen space and touch tests. |
| Validation | `test/arena_map_test.dart`, `map_capture_test.dart`, `monster_capture_test.dart`, `hero3d_game_capture_test.dart`, `game_screen_test.dart`, new camera/projection tests | Add objective acceptance coverage and fresh multi-resolution captures. |
| CI | `.github/workflows/flutter-android.yml` | Upload new camera/world/monster captures and verify APK from same commit. |

## 5. Explicitly preserve

- Four-player free-for-all and existing match/victory rules.
- Four heroes and their GLB assets/reference sheet.
- Four monster roles and existing stats/AI/economy unless separately approved.
- Four castles, seven crystals each, existing crystal HP values and rebuild/targeting rules.
- Eight mines and current capture/economy rules.
- Manual attack: one press = one attack; holding never auto-repeats.
- Separate Dodge; separate five-hit combo; four Ultimates at levels 1/10/20/30.
- Three weapons per hero, hero level cap 40, equal HP at equal level.
- Arabic-only initial UI, landscape mobile, no ads.
- Existing online/LAN direction; do not claim multiplayer complete without end-to-end device evidence.

## 6. Validation status at audit time

- The latest code-related workflow found on `ranger-reference-work` was run `44398235818`, commit `c05605f62a7b387f390f98fc6e7a6a48b3afe65d`, conclusion **success**. Its job `build-release-apk` succeeded.
- The branch HEAD `481140e635730dfa82dcae4666b40fd01176677f` is a later documentation/checkpoint commit whose parent is that tested code commit.
- This confirms the crystal-renderer code commit passed its Android workflow; it does **not** validate the proposed close MOBA camera, enlarged world, isometric terrain or 3D monsters, because those changes have not been implemented.
- Existing tests include map generation/movement/fog, map captures, monster captures/system, hero GLB/captures, game-world and game-screen tests. New acceptance tests listed in Phases 1–7 are still required.

## 7. Recommended first implementation batch

Do not begin by generating all monster models or randomly enlarging the map. The safest first batch is:

1. Add a shared camera/projection model and fix the render-vs-tap camera-origin mismatch.
2. Add camera/coordinate regression tests and a capture showing hero + each monster type at the intended close framing.
3. Prototype one controlled isometric ground-plane transform for terrain, hero, monsters, projectiles and crystals.
4. Set measurable hero/common-monster screen-space size targets and verify them at two or more phone aspect ratios.
5. Produce a small designed map-layout prototype with connected paths and one camp, then test reachability and movement.

Once this prototype proves the approved look without breaking input/collision, expand the map and produce the remaining art assets in the dependency order above.
