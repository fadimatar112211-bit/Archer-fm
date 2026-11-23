# Phase 0 renderer route trace and Phase 1 Shadow direction evidence

Repository: `fadimatar112211-bit/Archer-fm`
Branch: `ranger-reference-work`

## Phase 0 — live hero render route trace

Inspected the production path in `lib/game/game_screen.dart`, `lib/hero/hero_render_policy.dart`, `lib/game/arena_painter.dart`, and `lib/game/render3/hero3d_painter.dart`.

1. `GameScreen.initState` starts both `_loadManifest()` and `_loadHero3D()`.
2. `HeroRenderPolicy` currently routes only `shadow` to `approvedSpritePilot`; `ranger_new`, `flame`, and `storm` remain `glbPrimary`.
3. For Shadow, `_loadHero3D()` returns before loading GLB bytes (unless a test explicitly injects a controller or byte loader). This prevents a successful GLB load from overriding the first sprite pilot.
4. For Ranger New, Flame and Storm, the screen tries the documented GLB candidate paths. If a model loads, `ArenaPresentation.hero3d` receives the controller.
5. `ArenaPresentation.heroSpriteApproved` is separately populated from `HeroRenderPolicy.allowsSpriteAtlas`. `ArenaPainter` uses the GLB controller as the hero visual when present and only permits the atlas route when the policy approves it. A missing GLB does not silently promote an unapproved hero atlas.
6. `Hero3DModel` is a custom CPU-skinned GLB-to-Canvas painter; it is not evidence that the arena world itself is a true 3D scene.

### Phase 0 findings / boundaries

- The temporary migration routing is explicit and currently protects the unapproved Ranger New, Flame and Storm atlases.
- Shadow's sprite route is a pilot, not a claim that all Shadow actions have final art. The policy comment itself says action poses may remain safe holds.
- The production arena remains the Canvas `ArenaPainter` with `ArenaWorldProjection`; this route trace does not complete the separate lightweight 3D-world renderer migration.
- No GLB runtime path was removed or changed in this audit.

## Phase 1 — Shadow direction mapping evidence

The production resolver in `lib/game/render3/sprite_actor_clip_resolver.dart` delegates octant selection to `GameWorld.octantIndexOf` and `GameWorld.octantNames`; it does not invent a second art-coordinate convention.

Existing regression coverage in `test/sprite_actor_clip_resolver_test.dart` checks:
- the eight cardinal/diagonal world-facing vectors map to `s, se, e, ne, n, nw, w, sw`;
- zero facing falls back to south;
- exact directional clip lookup does not substitute another direction when art is missing.

The new `test/shadow_walk_reference_test.dart` additionally checks the actual Shadow walk metadata for all eight rows, four ordered frames per row, the shared supplied 768×1536 atlas image, 192×192 cells, and the 0.5/0.86 pivot.

### Phase 1 boundary

These are code/metadata checks. They do not prove the eight poses look correct in the game, that the PNG alpha is clean, or that the feet remain planted during real movement. Those visual/runtime gates remain open until captures are reviewed.

## Commands/results

No Flutter test/analyze/build result is claimed in this report. The test additions are committed, but the repository CI status for the new commits was not available through the current GitHub status query. Run the focused tests and full Phase 0 baseline checks before claiming their execution gates passed.
