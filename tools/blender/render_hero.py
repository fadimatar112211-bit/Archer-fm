"""Blender batch renderer for the complete 2.5D hero sprite set.

Run with:
  blender -b ranger_source.blend --python tools/blender/render_hero.py -- \
    --config assets/heroes/ranger/source/render_config.json

The source .blend must contain a rigged hero, named Actions, and a camera-ready
scene. This script intentionally fails on missing production inputs; it never
silently emits placeholder art.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Euler


DIRECTIONS = {
    "s": 0.0, "sw": 45.0, "w": 90.0, "nw": 135.0,
    "n": 180.0, "ne": 225.0, "e": 270.0, "se": 315.0,
}
STATES = ("idle", "walk", "attack", "death")


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    return parser.parse_args(argv)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    args = arguments()
    config_path = Path(args.config).resolve()
    config = json.loads(config_path.read_text(encoding="utf-8"))
    root = config_path.parents[4]
    hero_id = config["hero_id"]
    resolution = int(config["resolution"])
    fps = int(config["fps"])
    require(hero_id == "ranger", "This production config must identify ranger")
    require(resolution >= 128 and fps > 0, "Invalid resolution or FPS")

    scene = bpy.context.scene
    scene.render.engine = config.get("render_engine", "BLENDER_EEVEE_NEXT")
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.fps = fps
    scene.render.film_transparent = True

    camera = scene.camera
    require(camera is not None, "Production scene has no active camera")
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = float(config["orthographic_scale"])

    armature_name = config["armature_object"]
    armature = bpy.data.objects.get(armature_name)
    require(armature is not None and armature.type == "ARMATURE",
            f"Missing rigged armature object: {armature_name}")
    actions = config["actions"]
    for state in STATES:
        require(state in actions, f"Missing configured action: {state}")
        require(actions[state] in bpy.data.actions,
                f"Missing Blender Action: {actions[state]}")

    frame_counts = config["frame_counts"]
    require(all(state in frame_counts and int(frame_counts[state]) > 1 for state in STATES),
            "frame_counts must define at least two frames for every state")
    pivot = config["pivot"]
    require(0 <= float(pivot["x"]) <= 1 and 0 <= float(pivot["y"]) <= 1,
            "Normalized pivot must be within 0..1")

    output_root = (root / config["output_directory"]).resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema_version": 1,
        "hero_id": hero_id,
        "frame_size": {"width": resolution, "height": resolution},
        "pivot": {"x": float(pivot["x"]), "y": float(pivot["y"])},
        "atlases": [],
        "animations": {},
        "source": {
            "blend_file": bpy.data.filepath,
            "fps": fps,
            "render_engine": scene.render.engine
        }
    }

    original_rotation = armature.rotation_euler.copy()
    for direction, degrees in DIRECTIONS.items():
        armature.rotation_euler = Euler((original_rotation.x, original_rotation.y,
                                         original_rotation.z + math.radians(degrees)), "XYZ")
        for state in STATES:
            action = bpy.data.actions[actions[state]]
            armature.animation_data_create()
            armature.animation_data.action = action
            start, end = map(int, config["action_ranges"][state])
            count = int(frame_counts[state])
            require(end >= start, f"Invalid frame range for {state}")
            frame_numbers = [round(start + (end - start) * i / (count - 1))
                             for i in range(count)]
            ids = []
            for index, frame in enumerate(frame_numbers):
                scene.frame_set(frame)
                frame_id = f"{hero_id}_{state}_{direction}_{index:03d}"
                file_path = output_root / state / direction / f"{frame_id}.png"
                file_path.parent.mkdir(parents=True, exist_ok=True)
                scene.render.filepath = str(file_path)
                bpy.ops.render.render(write_still=True)
                ids.append(frame_id)
            events = []
            if state == "attack":
                release_frame = int(config["projectile_release_frame"])
                release_index = min(range(len(frame_numbers)),
                                    key=lambda i: abs(frame_numbers[i] - release_frame))
                events.append({"frame": release_index, "name": "projectile_release"})
            manifest["animations"][f"{state}_{direction}"] = {
                "loop": state in ("idle", "walk"),
                "frame_duration_ms": round(1000 / fps),
                "frames": ids,
                "events": events
            }

    armature.rotation_euler = original_rotation
    manifest_path = output_root / "ranger_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                              encoding="utf-8")
    print(f"Rendered complete frame sequence. Manifest: {manifest_path}")
    print("Next: run pack_hero_atlases.py in Blender to create atlas PNGs and metadata.")


if __name__ == "__main__":
    main()
