"""Design-review preview: renders four orbit views in one Blender session.

Usage:
  blender -b <hero>_source.blend --python tools/blender/preview_hero.py -- \
    --config assets/heroes/ranger/source/render_config.json \
    --out-dir /tmp/opencode/review

Renders the first idle frame at front (s), three-quarter (sw), side (w) and
back (n), reusing the production camera/framing helpers so the review images
use the same projection the game sprites use. Never writes into the production
render directories or the manifest.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_hero as rh  # noqa: E402


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--state", default="idle")
    parser.add_argument("--frame-index", type=int, default=0)
    parser.add_argument("--resolution", type=int, default=512)
    parser.add_argument("--samples", type=int, default=16)
    parser.add_argument(
        "--views", default="s,sw,w,n",
        help="Comma-separated direction keys to render")
    return parser.parse_args(argv)


def main():
    args = arguments()
    config_path = Path(args.config).resolve()
    config = rh.load_config(config_path)
    require = rh.require
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    scene = bpy.context.scene
    scene.render.engine = config.get("render_engine", "BLENDER_EEVEE")
    scene.render.resolution_x = args.resolution
    scene.render.resolution_y = args.resolution
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    if hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = args.samples

    state = args.state
    require(state in config["states"], f"{state} is not a configured state")
    action = bpy.data.actions[config["actions"][state]]
    frame = rh.sampled_frames(config, state)[args.frame_index]

    camera = scene.camera
    require(camera is not None, "Scene has no active camera")
    camera.data.type = "ORTHO"

    armature = bpy.data.objects[config["armature_object"]]
    require(armature is not None and armature.type == "ARMATURE",
            f"Missing rigged armature object: {config['armature_object']}")

    pivot = config["pivot"]
    pivot_x, pivot_y = float(pivot["x"]), float(pivot["y"])
    margin = float(config.get("pivot_margin", 0.02))
    ground = Vector(config.get("ground_anchor", (0.0, 0.0, 0.0)))
    target = Vector(config.get("camera_target", [0.0, 0.0, 1.45]))

    # Measure the pose, fit the orthographic scale like the production run.
    rh.evaluate_pose(armature, action, frame)
    low, high = rh.union_bounds()
    pose_bounds = {(state, frame): (low, high)}
    base_offset = camera.location.copy() - target
    scale = rh.fit_scale(pose_bounds, base_offset, ground, pivot_x, pivot_y,
                         margin, float(config["orthographic_scale"]))
    camera.data.ortho_scale = scale

    hero = config["hero_id"]
    for direction in [d.strip() for d in args.views.split(",") if d.strip()]:
        rh.evaluate_pose(armature, action, frame)
        degrees = rh.DIRECTIONS[direction]
        offset = rh.orbit_offset(base_offset, degrees)
        rotation, right, up = rh.camera_axes(offset)
        camera_position = target + offset
        camera.matrix_world = (Matrix.Translation(camera_position)
                               @ rotation.to_matrix().to_4x4())
        bpy.context.view_layer.update()
        anchor = world_to_camera_view(scene, camera, ground)
        camera.matrix_world = (Matrix.Translation(camera_position + (
            (anchor.x - pivot_x) * scale * right
            + (anchor.y - (1.0 - pivot_y)) * scale * up))
            @ rotation.to_matrix().to_4x4())
        bpy.context.view_layer.update()
        projected = world_to_camera_view(scene, camera, ground)
        require(abs(projected.x - pivot_x) <= rh.PIVOT_TOLERANCE
                and abs((1.0 - projected.y) - pivot_y) <= rh.PIVOT_TOLERANCE,
                f"{direction}: ground anchor off the pivot "
                f"({projected.x:.4f}, {1.0 - projected.y:.4f})")
        out = out_dir / f"{hero}_{args.state}_{direction}.png"
        scene.render.filepath = str(out)
        bpy.ops.render.render(write_still=True)
        print(f"PREVIEW_WROTE: {out}")


main()
