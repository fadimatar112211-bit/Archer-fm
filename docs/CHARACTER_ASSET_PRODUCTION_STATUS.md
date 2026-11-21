# Archer FM — Character Asset Production Status

Updated: 2026-11-21
Working branch: `ranger-reference-work`

This file records verified production evidence. A populated manifest, a successful Blender scene build, or a running workflow is not visual approval.

## Approved visual authorities

- Heroes: `assets/references/approved_all/hero_roster_concept.jpg`
- Monsters: `assets/references/approved_all/archer_fm_monsters_reference.png`
- Match presentation: `assets/references/approved_all/file_000000005c8c81f9ab4ccbb80ea59d5e.png`

Do not invent replacement character designs, recolor reference images, or promote generated/procedural art without a side-by-side visual review against the approved source.

## Hero status

| Hero | Verified repository evidence | Current disposition |
|---|---|---|
| Ranger | Existing Ranger New source/atlases and manifest; 64 clips are declared | Not visually signed off across all directions/actions. Preserve current work; do not assume complete. |
| Flame | `assets/heroes/flame/model/flame_animated.glb` and existing sprite manifest/atlases | Not approved for production sprite use; current art has previously been recorded as inconsistent with the approved red-haired, red/gold, flaming-sword identity. |
| Shadow | User-supplied 8-direction, 4-frame walk sheet and `shadow_manifest.json` | Walk source is the approved 2.5D pilot. Other states currently reuse held walk frames in the manifest and are placeholders, not finished action art. Shadow is NOT complete. |
| Storm | Preserved animated GLB source and existing manifest/atlases | Existing blue placeholder atlases are rejected. Regeneration from source is required; visual sign-off remains open. |

### Current Storm render attempt

GitHub Actions run `44940626160` (“Build Selected Hero 2.5D Sprite Pack”) is rendering the selected Storm profile. At the latest check:
- Blender installation succeeded.
- Selected hero validation and source-scene build succeeded.
- The eight-direction/state render step was still running.
- Frame validation, atlas packing and artifact upload had not yet completed.
- No artifact was available at the latest check.

Do not report Storm as rendered or complete until the workflow finishes successfully, its validation step passes, and the artifact is available for review.

### Important pipeline limitation

The shared Blender builder uses `tools/blender/hero_profiles.py` and creates per-hero geometry procedurally. The approved reference policy requires actual reference-matched character identity. Therefore, a technically successful profile render is not automatically acceptable artwork. Review its actual output against the approved hero sheet before enabling it in production. Keep all original GLB and Blender source assets.

## Monster status

The approved monster reference sheet defines exactly four designs, in left-to-right order:
1. Green goblin-like sword enemy.
2. Skeleton dual-blade enemy.
3. Horned heavy armored enemy with oversized spiked mace.
4. Purple hooded masked fighter with violet energy blades.

The current repository audit found no `assets/monsters/` production image directory and no verified monster rendering/atlas pipeline. The approved reference image exists, but that alone is not a rigged model or an animation source.

Required next steps:
- Locate any existing monster GLB/Blend source assets before creating new models.
- If no source model exists, report that clearly; do not claim that the reference sheet can supply full 8-direction animation by itself.
- Build/rig each monster to the approved reference only after the actual source image is reviewed.
- Produce idle, locomotion, attack, hit and death states in eight directions as supported by each source rig.
- Validate transparent PNG frames, consistent scale/feet pivot, frame motion, manifests and in-game captures.
- Keep the four monster identities distinct; do not replace them with generic runner/tank/stalker/ranged designs.

## Acceptance gates

A character is technically generated only when its frame files, manifest and automated validation exist. It is visually accepted only after the actual frames are displayed and compared against the approved reference. It is production-ready only after both gates pass and the in-game capture is reviewed.

Never use held poses or repeated frames as evidence of a completed animation. Never enable rejected or unreviewed sprite atlases as production fallback.
