> **STATUS: LEGACY / NON-RUNTIME CONTRACT (2026-11-23).** This GLB import layout is retained only for historical prototypes, source inspection and offline rendering inputs. It is not the production runtime asset contract. The approved runtime uses 2D/2.5D sprite atlases for all four monsters in the lightweight 3D world, as specified in `docs/2D_5D_SPRITE_CONVERSION_PLAN.md`. Do not integrate these GLBs as live monster actors or treat passing GLB validation as sprite acceptance. Keep the procedural Canvas monster painter as fallback until reference-matched sprite packs pass visual, animation, alpha, alignment, gameplay-scale and runtime tests.

---

# Monster 3D asset pipeline contract

This is the required import contract for Stage 2 monster GLB assets. It does not claim that any model currently exists.

## Folder layout

```
assets/monsters/3d/
  runner/monster.glb
  tank/monster.glb
  stalker/monster.glb
  ranged/monster.glb
  manifest.json
```

## Required GLB content

Each GLB must contain:
- One or more mesh primitives with valid positions/normals/UVs.
- Embedded or correctly resolvable materials and textures.
- A named armature/skeleton and skin weights for deforming characters.
- Ground-level origin, consistent forward axis and scale documented in the manifest.
- Named animation clips: `idle`, `walk`, `attack`, `hit`, `death`.
- Runner additionally needs `run` (or a documented mapping from `run` to `walk` only if the sprint is visually acceptable).
- Ranged additionally needs `cast` and `release`, or one `attack` clip with a documented projectile-release event frame.

## Manifest schema

```json
{
  "schemaVersion": 1,
  "coordinateSystem": "Y_UP_Z_FORWARD",
  "units": "meters",
  "monsters": {
    "runner": {
      "file": "runner/monster.glb",
      "scale": 1.0,
      "forward": "+Z",
      "groundOffset": [0, 0, 0],
      "clips": {
        "idle": "Idle",
        "walk": "Walk",
        "run": "Run",
        "attack": "Attack",
        "hit": "Hit",
        "death": "Death"
      }
    },
    "tank": {
      "file": "tank/monster.glb",
      "scale": 1.0,
      "forward": "+Z",
      "groundOffset": [0, 0, 0],
      "clips": {
        "idle": "Idle",
        "walk": "Walk",
        "attack": "Attack",
        "hit": "Hit",
        "death": "Death"
      }
    },
    "stalker": {
      "file": "stalker/monster.glb",
      "scale": 1.0,
      "forward": "+Z",
      "groundOffset": [0, 0, 0],
      "clips": {
        "idle": "Idle",
        "walk": "Walk",
        "attack": "Attack",
        "hit": "Hit",
        "death": "Death"
      }
    },
    "ranged": {
      "file": "ranged/monster.glb",
      "scale": 1.0,
      "forward": "+Z",
      "groundOffset": [0, 0, 0],
      "clips": {
        "idle": "Idle",
        "walk": "Walk",
        "attack": "Attack",
        "cast": "Cast",
        "release": "Release",
        "hit": "Hit",
        "death": "Death"
      },
      "events": {
        "projectileRelease": 0.62
      }
    }
  }
}
```

## Acceptance gate per model

1. GLB parses with a standards-compliant glTF validator.
2. Mesh, skin, skeleton and materials are present; no external missing texture.
3. All required named clips exist, have positive duration and play without invalid transforms.
4. Character faces +Z and feet contact y=0 in idle, walk, attack and death.
5. Face, weapon and silhouette remain legible at gameplay camera scale.
6. Capture turntable and gameplay-distance stills; inspect before integration.
7. Confirm file size and runtime memory are acceptable on Android.
8. Keep procedural Canvas fallback until the model passes all gates.

## Pipeline decision

- Do not silently convert the legacy SVG sheets into GLB and call them 3D models.
- Do not reuse hero GLBs as monster assets.
- Use a free Blender/glTF workflow with reproducible source `.blend` files and export scripts when the actual model sources are available.
- Record provenance/license for any externally sourced mesh, rig, texture or animation.
- No asset file should be marked accepted based only on a filename or successful export.
