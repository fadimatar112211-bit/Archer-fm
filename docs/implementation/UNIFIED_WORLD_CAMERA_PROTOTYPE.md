# Unified World Camera & Ground-Projection Prototype

Status: **design contract / implementation gate**. This document does not claim the renderer has been converted.

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
