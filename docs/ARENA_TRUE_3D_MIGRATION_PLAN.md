# True 3D Arena Migration Plan

## Verified current renderer state

- `ArenaBattlefield` is a Flutter `CustomPainter` projection. Ground height is sampled from the packaged 96×96 `assets/maps/arena/height_map.csv`, bilinearly interpolated, and painted as camera-culled triangles.
- Rivers, bridges, walls, crystals, biome landforms and other map features are currently drawn with Canvas paths/vertices and screen-space offsets. Their visual extrusion is not a scene-space mesh.
- Heroes and monsters are not currently rendered by a scene graph or depth buffer. `Hero3D` and `Monster3D` decode packed `.bin` vertex/triangle/animation data, CPU-skin/project it, then draw it through Flutter's canvas.
- Runtime hero assets currently include `assets/heroes3d/{ranger,flame,shadow,storm}.bin`; monster models are also packed `.bin` assets. The arena source package contains `archer_fm_map.json`, `height_map.csv`, and `nav_grid.txt`.
- `pubspec.yaml` currently has no dedicated 3D scene/rendering dependency. Adding a renderer is therefore an architectural migration, not a small terrain-painter change.

## Required target

A true 3D arena means world-space meshes and camera transforms, GPU depth testing, perspective projection, material/light response, real occlusion between terrain/structures/actors, and a mobile-tested frame budget. A painter that extrudes polygons in screen space must not be described as a true 3D scene.

## Safe migration sequence

1. **Renderer spike in isolation**: compare maintained Flutter-compatible GPU scene options against the current Android/iOS target, GLB/skinning support, texture/material support, licensing, maintenance, and Android device support. Do not add a dependency until the spike proves it can render a test mesh with a depth buffer on the project's CI emulator.
2. **Scene adapter**: define a renderer-neutral adapter that consumes the existing authoritative match snapshot and map JSON. Server positions, collision, pathfinding, combat, fog-of-war and networking remain unchanged.
3. **Terrain prototype**: convert the existing height map to a world-space indexed mesh with normals, UVs and biome material regions. Add a test scene containing a hill, river bank and bridge crossing to verify depth ordering.
4. **Structures and water**: replace castle, wall, bridge, crystal and river painter shapes with world-space meshes/materials. Keep the same gameplay IDs, health and interaction coordinates.
5. **Actor bridge**: import or convert the existing source hero/monster models and animations to the selected renderer. Preserve the current `.bin` Canvas renderer as a temporary fallback while matching scale, orientation, animation names and hit positions.
6. **Parity and performance**: capture the same 16:9 match scene in both renderers; verify four heroes, monster groups, seven crystals per player, minimap, health bars, projectiles and fog. Profile on Android at target resolution and enforce a stable frame-time/memory budget.
7. **Switch only after proof**: enable the new renderer behind a feature flag, test on Android, then make it default. Remove the old painter path only after parity and regression tests pass.

## Non-negotiable compatibility constraints

- Do not change authoritative world coordinates or server-owned match state as part of rendering.
- Do not regenerate or replace the existing height map, nav grid, map JSON, hero or monster source assets without evidence they are defective.
- Keep a functional fallback until the new renderer has passed the same visual and gameplay test suite.
- Never mark the map "true 3D complete" based only on Canvas triangle captures. Require depth-buffer occlusion and a successful Android runtime test.

## Current status

The project is still in the Canvas/CPU-projected 2.5D stage. The height-map terrain refinement and visual capture tests are in place. The true 3D renderer spike and migration steps above remain outstanding; no 3D dependency has been added and no engine migration is claimed.

## Renderer candidate review (26 November 2026)

The repository currently declares Dart SDK `>=3.4.0 <4.0.0` and only `flutter_svg` as a runtime package. The Android workflow uses the current stable Flutter channel, so the exact SDK version must be read from CI before choosing a renderer.

| Candidate | Relevant capabilities | Risks / decision |
|---|---|---|
| `flutter_scene` | Flutter GPU renderer; glTF, PBR, shadows, skinned animation and physics | Current package documentation says Flutter 3.47.1+; do not adopt until CI's Flutter version is confirmed and Android GPU support is proven. |
| `stage_3d` | Android Filament backend; GLB, animation, lighting, procedural terrain and spatial queries | Early beta and Android-first; promising prototype candidate, but validate plugin build, device/emulator support, lifecycle and license before adoption. |
| `three_js` | Three.js-style scene graph, Android OpenGL/Vulkan and model viewing | Its package notes say GPU support is under development; not the preferred production candidate for a GPU-heavy arena yet. |
| `flutter_fiber` | Native OpenGL ES scene graph and GLB loading | Documented limitations include no shadows, no directional/spot lights and glTF animation still on the roadmap; unsuitable for the required final visual target without substantial missing features. |

### Current decision

Do not add any of these packages to the production dependency graph yet. The next experiment should be an isolated Android-only prototype using Stage 3D/Filament, because its documented feature set most closely matches the immediate needs (GLB animation, terrain mesh, lights and shadows). In parallel, confirm the CI Flutter SDK before reconsidering Flutter GPU-based `flutter_scene`.

A candidate is accepted only after a standalone CI test proves: Android compilation, emulator/device launch, a depth-tested terrain mesh, one animated skinned GLB, a shadow-casting light, resize/lifecycle recovery, and acceptable frame time. If the beta plugin fails any of these gates, discard the spike without changing the live battlefield renderer.


## Isolated Android Filament spike — 26 November 2026

A standalone experiment now lives under `tools/arena_3d_spike/`; it is not imported by the production app and does not modify the production `pubspec.yaml` or renderer.

- Candidate pinned for the experiment: `stage_3d 0.1.0-beta.2`, MIT licensed. Its documented Android backend is Google Filament and advertises GLB model instances, skinned animation playback, directional/point lights, procedural meshes and shadows. The package is explicitly experimental beta, with an unverified publisher and API stability risk; this is why it is isolated rather than a production dependency.
- The spike scene loads the existing Ranger animated GLB and Stone Golem GLB directly from the repository. CI copies them into the spike app's temporary asset folder at runtime, so no duplicate binary assets are committed.
- The scene contains a procedural ground plane, two separated GLB actors, a directional light, orbit camera, environment settings, and a visible renderer/animation status label. The Ranger animation clip is queried and the first available clip is started.
- Added workflow `.github/workflows/arena-3d-spike.yml`: creates an Android runner only inside the isolated spike folder, resolves its own dependency graph, analyzes it, builds a debug APK, boots the API 30 emulator, installs/launches the app, checks its process, captures a screenshot, and uploads APK + screenshot as artifacts.
- The spike dependency does not enter the production app dependency graph, and no production rendering path is switched.

### Acceptance gates still pending

The spike is **implemented but not yet validated**. Do not accept Stage 3D until its dedicated workflow proves Android compilation and launch, a non-empty Ranger animation list with successful playback, visible Filament output/screenshot, depth-tested actor/terrain occlusion, and acceptable frame time. The first screenshot must be reviewed; a process ID alone is not visual proof. If dependency resolution or native compilation fails, record the exact error and discard/replace the spike without changing the production app.

### External package evidence reviewed

- pub.dev package page and feature/platform/status disclosure: https://pub.dev/packages/stage_3d
- Example scene and viewport lifecycle: https://pub.dev/packages/stage_3d/example
- Package license: https://pub.dev/packages/stage_3d/license

