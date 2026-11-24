# Storm asset generation validation

The Storm GLB is fetched from the existing implementation branch and must contain one armature plus eight distinct animation actions. The Blender renderer fails rather than creating placeholder frames when any action or rig is missing.

Expected runtime output:
- 8 states: idle, walk, run, attack, skill, dodge, hit, death
- 8 camera directions per state
- 64 distinct animation clips and 64 packed atlases
- 2 or more non-empty, non-identical frames per clip
- 192 × 192 frames with 4-column packed atlas metadata

Generated assets are committed to this branch by the validation workflow only after the render and atlas checks succeed.

CI also installs NumPy into Blender's Python import path for the bundled glTF importer.

The headless runner installs Mesa EGL/OpenGL libraries and forces software rendering for EEVEE.

Camera orbit uses the same clockwise eight-direction convention as the shipped Ranger/Flame/Shadow renderer.
