# Flame — Reference Match Contract

## Visual identity

Use the user-approved Flame hero reference as the source of truth:

- Chibi male fire knight with a large, expressive face and red eyes.
- Voluminous, sharply layered crimson/red hair; not brown or muted orange.
- Red and near-black armor with bright gold edging and readable shoulder, forearm, knee and boot plates.
- Red scarf/collar around the neck and a long red cape trailing behind the body.
- A bright flame emblem centered on the chest.
- A large orange-red greatsword with a gold guard, held on the character's left side and angled down-left.
- Preserve the compact chibi proportions and dimensional, polished 3D shading.

The reference image is available in the user's ChatGPT Library. It is not currently a binary file inside this GitHub repository, so automated CI cannot perform a pixel comparison against it. The high-resolution review renders must be inspected against the approved reference before the hero is signed off.

## Runtime contract

- The editable source is `assets/heroes/flame/source/flame_source.blend`.
- The animated interchange model is `assets/heroes/flame/model/flame_animated.glb`.
- The mobile presentation uses transparent 2.5D directional atlases, not a freely rotating GLB camera in the arena.
- Required states: idle, walk, run, attack, skill, dodge, hit and death.
- Required directions: south, south-west, west, north-west, north, north-east, east and south-east.
- Each state/direction pair must have a real multi-frame clip, atlas metadata and a matching image.
- Flame's three weapons and four Ultimate abilities are separate from the five-hit manual combo. Ultimate unlock levels are 1, 10, 20 and 30.

## Completion gates

1. Validate the source scene, materials, rig, skin weights and eight authored actions.
2. Export and re-import the GLB; verify its mesh, skin, skeleton and eight distinct clips.
3. Render and pack all 64 directional clips; validate all frame rectangles and image data.
4. Inspect the high-resolution front, three-quarter, side and back review renders against the approved reference.
5. Run the Flame acceptance tests, Flutter analysis/tests and Android debug build.
6. Keep the current hero-viewer/combat sandbox clearly distinguished from full arena integration. Do not claim arena integration until Flame is rendered and controlled by the actual arena runtime.
