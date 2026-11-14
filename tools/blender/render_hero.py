"""Blender batch renderer for the complete 2.5D hero sprite set.

Run with:
  blender -b ranger_source.blend --python tools/blender/render_hero.py -- \
    --config assets/heroes/ranger/source/render_config.json

The source .blend must contain a rigged hero, named Actions, and a camera-ready
scene. This script intentionally fails on missing production inputs; it never
silently emits placeholder art.

Framing is measured instead of guessed. The renderer evaluates every sampled
pose, projects the union bounds through every orbit direction, and picks the
smallest orthographic scale that keeps the whole animation inside the configured
pivot margins. The ground anchor is pinned to the manifest pivot, so the stored
pivot is where the feet actually land for all eight directions.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


DIRECTIONS = {
    "s": 0.0, "sw": 45.0, "w": 90.0, "nw": 135.0,
    "n": 180.0, "ne": 225.0, "e": 270.0, "se": 315.0,
}
STATES = ("idle", "walk", "attack", "death")
PIVOT_TOLERANCE = 0.005


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    return parser.parse_args(argv)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def reset_pose(armature):
    """Clear every pose channel before evaluating an Action.

    Blender only drives the F-curves that exist in the active Action, so any
    channel the previous Action left behind (the Death action's root rotation,
    for example) survives an Action switch and silently deforms the next state.
    """
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.location = (0.0, 0.0, 0.0)
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)


def sampled_frames(config, state):
    start, end = map(int, config["action_ranges"][state])
    count = int(config["frame_counts"][state])
    require(end >= start, f"Invalid frame range for {state}")
    require(count > 1, f"frame_counts.{state} must define at least two frames")
    return [round(start + (end - start) * i / (count - 1)) for i in range(count)]


def evaluate_pose(armature, action, frame):
    reset_pose(armature)
    armature.animation_data_create()
    armature.animation_data.action = action
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def union_bounds():
    """World-space AABB of every evaluated mesh in the current frame."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    low = Vector((math.inf, math.inf, math.inf))
    high = Vector((-math.inf, -math.inf, -math.inf))
    found = False
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        matrix = evaluated.matrix_world
        for corner in evaluated.bound_box:
            point = matrix @ Vector(corner)
            low = Vector((min(low.x, point.x), min(low.y, point.y), min(low.z, point.z)))
            high = Vector((max(high.x, point.x), max(high.y, point.y), max(high.z, point.z)))
            found = True
    require(found, "Scene contains no mesh geometry to frame")
    return low, high


def bounds_corners(low, high):
    return [Vector((x, y, z))
            for x in (low.x, high.x)
            for y in (low.y, high.y)
            for z in (low.z, high.z)]


def orbit_offset(base_offset, degrees):
    angle = math.radians(-degrees)
    return Vector((
        base_offset.x * math.cos(angle) - base_offset.y * math.sin(angle),
        base_offset.x * math.sin(angle) + base_offset.y * math.cos(angle),
        base_offset.z,
    ))


def camera_axes(offset):
    """Return (rotation, screen-right, screen-up) for a camera at target + offset."""
    rotation = (-offset).to_track_quat("-Z", "Y")
    matrix = rotation.to_matrix()
    return rotation, matrix.col[0].copy(), matrix.col[1].copy()


def projected_extents(corners, ground, right, up):
    u = [(corner - ground).dot(right) for corner in corners]
    v = [(corner - ground).dot(up) for corner in corners]
    return min(u), max(u), min(v), max(v)


def fit_scale(pose_bounds, base_offset, ground, pivot_x, pivot_y, margin, floor_scale):
    """Smallest orthographic scale that keeps every pose inside the margins."""
    needed = 0.0
    for degrees in DIRECTIONS.values():
        _, right, up = camera_axes(orbit_offset(base_offset, degrees))
        for low, high in pose_bounds.values():
            u_min, u_max, v_min, v_max = projected_extents(
                bounds_corners(low, high), ground, right, up)
            if u_min < 0:
                needed = max(needed, -u_min / (pivot_x - margin))
            if u_max > 0:
                needed = max(needed, u_max / (1.0 - pivot_x - margin))
            if v_min < 0:
                needed = max(needed, -v_min / (1.0 - pivot_y - margin))
            if v_max > 0:
                needed = max(needed, v_max / (pivot_y - margin))
    # A little breathing room so rounding in the pixel grid cannot clip an edge.
    return max(floor_scale, needed * 1.01)


def check_direction_framing(pose_bounds, ground, right, up, scale,
                            pivot_x, pivot_y, margin, direction):
    """Fail loudly instead of writing a frame that violates the pivot margins."""
    for (state, frame), (low, high) in pose_bounds.items():
        u_min, u_max, v_min, v_max = projected_extents(
            bounds_corners(low, high), ground, right, up)
        left = pivot_x + u_min / scale
        right_px = pivot_x + u_max / scale
        top = pivot_y - v_max / scale
        bottom = pivot_y - v_min / scale
        require(min(left, top) >= margin and max(right_px, bottom) <= 1.0 - margin,
                f"{state}_{direction}[{frame}] exceeds pivot margins "
                f"(u={u_min:.3f}..{u_max:.3f}, v={v_min:.3f}..{v_max:.3f}, "
                f"pixels={left:.3f},{top:.3f}..{right_px:.3f},{bottom:.3f})")


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

    camera = scene.camera
    require(camera is not None, "Production scene has no active camera")
    camera.data.type = "ORTHO"

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
    pivot_x, pivot_y = float(pivot["x"]), float(pivot["y"])
    require(0 <= pivot_x <= 1 and 0 <= pivot_y <= 1,
            "Normalized pivot must be within 0..1")
    margin = float(config.get("pivot_margin", 0.02))
    require(0 < margin < 0.1, "pivot_margin must be a small normalized fraction")
    require(pivot_x - margin > 0 and 1.0 - pivot_x - margin > 0
            and pivot_y - margin > 0 and 1.0 - pivot_y - margin > 0,
            "pivot margins leave no room around the pivot")
    ground = Vector(config.get("ground_anchor", (0.0, 0.0, 0.0)))

    output_root = (root / config["output_directory"]).resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema_version": 1,
        "hero_id": hero_id,
        "frame_size": {"width": resolution, "height": resolution},
        "pivot": {"x": pivot_x, "y": pivot_y},
        "atlases": [],
        "animations": {},
        "source": {
            "blend_file": bpy.data.filepath,
            "fps": fps,
            "render_engine": scene.render.engine
        }
    }

    # Measure every sampled pose once. Bounds are independent of the orbit
    # direction, so one evaluation per state/frame is enough for all directions.
    pose_bounds = {}
    for state in STATES:
        action = bpy.data.actions[actions[state]]
        for frame in sampled_frames(config, state):
            evaluate_pose(armature, action, frame)
            pose_bounds[(state, frame)] = union_bounds()
    for (state, frame), (low, high) in sorted(pose_bounds.items()):
        print(f"POSE_BOUNDS {state}[{frame}] "
              f"x={low.x:.2f}..{high.x:.2f} y={low.y:.2f}..{high.y:.2f} "
              f"z={low.z:.2f}..{high.z:.2f}")
    rest_frame = sampled_frames(config, "idle")[0]
    evaluate_pose(armature, bpy.data.actions[actions["idle"]], rest_frame)
    print("POSE_DEBUG idle[%d] %s" % (rest_frame, ", ".join(
        f"{bone.name}={tuple(round(value, 3) for value in bone.rotation_euler)}"
        for bone in armature.pose.bones)))

    # Orbit the camera instead of rotating the rig. This preserves the authored
    # pose under the same camera elevation and avoids direction-dependent clipping.
    target = Vector(config.get("camera_target", [0.0, 0.0, 1.45]))
    base_camera_location = camera.location.copy()
    base_offset = base_camera_location - target
    scale = fit_scale(pose_bounds, base_offset, ground, pivot_x, pivot_y,
                      margin, float(config["orthographic_scale"]))
    camera.data.ortho_scale = scale
    manifest["source"]["orthographic_scale"] = round(scale, 6)
    print(f"FRAMING measured orthographic_scale={scale:.3f} "
          f"(configured minimum {float(config['orthographic_scale']):.3f})")

    for direction, degrees in DIRECTIONS.items():
        offset = orbit_offset(base_offset, degrees)
        rotation, right, up = camera_axes(offset)
        # Pin the ground anchor to the manifest pivot for every direction.
        shift = ((pivot_x - 0.5) * scale * right
                 + (0.5 - pivot_y) * scale * up)
        camera.location = ground - shift
        camera.rotation_euler = rotation.to_euler()
        bpy.context.view_layer.update()

        projected = world_to_camera_view(scene, camera, ground)
        require(abs(projected.x - pivot_x) <= PIVOT_TOLERANCE
                and abs((1.0 - projected.y) - pivot_y) <= PIVOT_TOLERANCE,
                f"{direction}: ground anchor lands at "
                f"({projected.x:.4f}, {1.0 - projected.y:.4f}) instead of the "
                f"configured pivot ({pivot_x:.4f}, {pivot_y:.4f})")
        check_direction_framing(pose_bounds, ground, right, up, scale,
                                pivot_x, pivot_y, margin, direction)

        for state in STATES:
            action = bpy.data.actions[actions[state]]
            frame_numbers = sampled_frames(config, state)
            ids = []
            for index, frame in enumerate(frame_numbers):
                evaluate_pose(armature, action, frame)
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

    render_count = sum(len(animation["frames"]) for animation in manifest["animations"].values())
    require(render_count == len(pose_bounds) * len(DIRECTIONS),
            f"Rendered {render_count} frames, expected "
            f"{len(pose_bounds) * len(DIRECTIONS)}")
    manifest_path = output_root / "ranger_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                              encoding="utf-8")
    print(f"Rendered {render_count} frames across {len(STATES)} states and "
          f"{len(DIRECTIONS)} directions. Manifest: {manifest_path}")
    print("Next: run pack_hero_atlases.py in Blender to create atlas PNGs and metadata.")


if __name__ == "__main__":
    main()
