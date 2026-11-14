# Ranger full-production asset pipeline

This is the production render pipeline for the complete Ranger set, not a sample renderer.

## Reuse inventory
- The 4 legacy SVG sheets are retained in `assets/heroes/ranger/` as reference/fallback material. They are 4-frame 2D vector sheets, not the approved 2.5D Chibi production art.
- The legacy sprite clipping widget and timer-driven auto-fire logic are not copied. They do not support the agreed directional atlas, stable pivot, or the single `projectile_release` event.
- No rigged 3D source model or Blender scene was present in the audited legacy files. The renderer therefore requires the real production Ranger .blend source and refuses to fabricate substitute frames.

## Production source scene contract
Create `assets/heroes/ranger/source/ranger_source.blend` with:
- A complete Ranger model matching `RANGER_PRODUCTION_SPEC.md` (green hood/cloak with gold trim, silver-white hair, blue eyes, brown/green leather armor, quiver, signature green-energy bow).
- A production armature object named `Ranger_Rig`.
- Actions named `Ranger_Idle`, `Ranger_Walk`, `Ranger_Attack`, `Ranger_Death`.
- Active orthographic camera, fixed lighting, transparent-background-compatible materials, ground contact and consistent framing.
- Attack action must draw, aim, release, and recover; release frame must be authored and confirmed by animation review.
- Death action must settle and hold; idle/walk must loop cleanly.

## Full render
Use Blender's background mode with `tools/blender/render_hero.py` and `assets/heroes/ranger/source/render_config.json`. The configuration defines all 8 directions and all 4 states. It outputs every configured frame and a manifest. The default frame counts and timing in the config are production starting values and must be reviewed against the final authored Actions before a release build; do not alter them by creating disposable preview exports.

Blender supports PNG RGBA rendering and glTF animation export; see the official [Blender pipeline](https://www.blender.org/features/pipeline/) and [glTF manual](https://docs.blender.org/manual/en/latest/addons/scene_gltf2.html).

## Release gates
1. Verify the source model and rig exist and all named Actions are authored.
2. Review the complete eight-direction/four-state render for silhouette, consistency, pivots, clipping, and transparent edges.
3. Pack frames into atlas metadata without rotating frames; validate all referenced frame IDs and dimensions with `tools/validate_hero_assets.py`.
4. Verify exactly one authored `projectile_release` event per attack direction.
5. Measure the complete package size and runtime memory on target Android hardware.
6. Integrate into the selected runtime engine and run combat/transition tests.
7. Run the Android emulator acceptance suite and fix/retest all critical issues.

A renderer script and config are pipeline infrastructure; they do not mean the model or animation assets have already been produced.
