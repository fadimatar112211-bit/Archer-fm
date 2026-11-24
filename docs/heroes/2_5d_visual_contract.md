# Archer FM — 2.5D Hero Visual Contract

This is a required art/runtime constraint for Ranger, Flame, Shadow and Storm.

## Target presentation
- The game is a 2.5D isometric/elevated arena, not a free-camera 3D character showcase.
- Heroes must read as polished, dimensional chibi characters: sculpted faces, readable eyes and expressions, layered hair, armor, cloth, weapons, bevels, painted materials and controlled highlights.
- Keep each hero's approved silhouette, palette, face, armor, weapon identity and proportions consistent in every direction and animation.
- Match the hero scale, ground contact, lighting direction, shadow softness and camera perspective to the approved gameplay screenshot and arena environment.

## Asset pipeline
- The authored rigged Blender/GLB model is the editable high-detail source asset. It is not, by itself, proof of in-game completion.
- The intended mobile gameplay representation is a directional 2.5D render/atlas set with a consistent orthographic camera and transparent background. Do not place a freely rotating perspective GLB camera in the arena as the default presentation.
- Each hero must provide the same eight animation states: idle, walk, run, attack, skill, dodge, hit and death.
- Each state must provide eight directions: south, south-west, west, north-west, north, north-east, east and south-east (64 directional clips per hero).
- Keep frame dimensions, pivot/ground anchor, scale, camera framing, frame timing and atlas metadata consistent across all four heroes.
- Render animation poses, not repeated still frames. Include weapons and effects in bounds; do not crop hands, faces, feet or weapon arcs.
- Keep the 5-hit manual combo separate from the four Ultimate abilities. Ultimate unlock levels remain 1, 10, 20 and 30.

## Acceptance gates
1. Validate each source scene has the intended mesh, materials, rig and eight distinct authored actions.
2. Render and pack all 64 directional clips for each hero.
3. Validate manifests, atlas dimensions, frame rectangles, unique frame content, pivots and animation coverage.
4. Compare contact sheets for all four heroes side by side at the same scale against the approved hero reference and gameplay screenshot. Reject mismatched faces, colors, armor, weapons or camera framing.
5. Integrate the validated 2.5D atlases into the actual arena renderer and verify movement, direction changes, attacks, hit/death states and Ultimate effects in-game.
6. Run Flutter analysis/tests and a real Android landscape visual test before calling the hero batch complete.

## Status rule
A GLB export, manifest, atlas, or passing asset validator alone does not mean the heroes are complete. Completion requires all four heroes to pass the visual comparison and actual arena integration gates above. If a reference image is unavailable in the branch, record the visual comparison as blocked rather than guessing.
