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
import shutil
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector


DIRECTIONS = {
    "s": 0.0, "sw": 45.0, "w": 90.0, "nw": 135.0,
    "n": 180.0, "ne": 225.0, "e": 270.0, "se": 315.0,
}
PIVOT_TOLERANCE = 0.005


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    return parser.parse_args(argv)


def active_hero_id():
    """The hero this CI run renders, chosen by a checked-in marker file."""
    marker = Path(__file__).resolve().parent / "active_hero.txt"
    if not marker.is_file():
        return "ranger"
    value = marker.read_text(encoding="utf-8").strip().lower()
    return value or "ranger"


def load_config(path):
    """Merge the shared defaults with the active hero's configuration.

    Keeping all four heroes in one config file means the CI workflow can keep
    passing the same `--config` path without being edited.
    """
    raw = json.loads(path.read_text(encoding="utf-8"))
    if "heroes" not in raw:
        return raw
    hero_id = active_hero_id()
    require(hero_id in raw["heroes"],
            f"active_hero.txt names {hero_id!r}, which is not in the config")
    config = dict(raw.get("defaults", {}))
    config.update(raw["heroes"][hero_id])
    config.setdefault("hero_id", hero_id)
    return config


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def reset_pose(armature, action=None):
    """Clear every pose channel before evaluating an Action.

    Blender only drives the F-curves that exist in the active Action, so any
    channel the previous Action left behind (the Death action's root rotation,
    for example) survives an Action switch and silently deforms the next state.

    The rotation channels must stay in the mode the Action actually authored:
    forcing Euler here made every quaternion F-curve (the GLB-exported rigs)
    silently inert, so posed frames rendered as the rest pose. When an Action
    is given, each bone's mode is aligned with the curves that Action drives.
    """
    paths = {fc.data_path for fc in action.fcurves} if action else set()
    for bone in armature.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
        prefix = f'pose.bones["{bone.name}"]'
        if f"{prefix}.rotation_quaternion" in paths:
            bone.rotation_mode = "QUATERNION"
        elif f"{prefix}.rotation_euler" in paths:
            bone.rotation_mode = "XYZ"


def assert_render_colors(path):
    """Fail fast when EEVEE fell back to its magenta invalid-material colour.

    The atlases are checked for alpha and framing, so a uniformly magenta
    character can pass every silhouette gate. Inspecting the first real render
    aborts a broken-material run in seconds instead of after the full frame set.
    """
    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        pixels = list(image.pixels)
    finally:
        bpy.data.images.remove(image)
    opaque = magenta = 0
    for index in range(0, len(pixels), 4):
        if pixels[index + 3] < 0.9:
            continue
        opaque += 1
        r, g, b = pixels[index], pixels[index + 1], pixels[index + 2]
        if r > 0.55 and b > 0.55 and g < 0.2:
            magenta += 1
    ratio = magenta / max(1, opaque)
    print(f"COLOR_CHECK {path.name} opaque={opaque} magenta={ratio:.2f}")
    if opaque > 100 and ratio > 0.25:
        print("COLOR_ERROR: EEVEE rendered invalid-material magenta; "
              "check material Surface links before rendering the full set.",
              file=sys.stderr)
        raise SystemExit(1)


def sampled_frames(config, state):
    start, end = map(int, config["action_ranges"][state])
    count = int(config["frame_counts"][state])
    require(end >= start, f"Invalid frame range for {state}")
    require(count > 1, f"frame_counts.{state} must define at least two frames")
    return [round(start + (end - start) * i / (count - 1)) for i in range(count)]


def evaluate_pose(armature, action, frame):
    reset_pose(armature, action)
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
        points = [matrix @ Vector(corner) for corner in evaluated.bound_box]
        # Inactive FX parts are scaled to zero by their bone, but a zero-scale
        # object still reports a degenerate AABB at the bone position. That
        # phantom point follows the root bone below the floor during Death and
        # used to force a much wider orthographic scale for the whole set.
        extent = max(
            max(point[i] for point in points) - min(point[i] for point in points)
            for i in range(3)
        )
        if extent < 1e-4:
            continue
        for point in points:
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
    """Return (rotation, screen-right, screen-up) for a camera at target + offset.

    The basis is built explicitly instead of with `to_track_quat` so all eight
    orbit angles share one horizon convention: screen-right is perpendicular to
    both the view direction and world up, and screen-up is what remains. A
    rolled camera would change which way is up between directions and make the
    ground anchor useless as a shared pivot.
    """
    view = (-offset).normalized()
    world_up = Vector((0.0, 0.0, 1.0))
    right = view.cross(world_up)
    if right.length < 1e-6:  # Looking straight down or up.
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    up = right.cross(view)
    rotation = Matrix((right, up, -view)).transposed().to_quaternion()
    return rotation, right, up


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
    config = load_config(config_path)
    root = config_path.parents[4]
    hero_id = config["hero_id"]
    resolution = int(config["resolution"])
    fps = int(config["fps"])
    require(bool(hero_id), "The config must identify the hero")
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
    # Flat cel-shaded art needs no 64-sample accumulation. Software EEVEE on a
    # CI runner is ~8x slower at the default sample count, and the result is
    # visually identical at this resolution.
    if hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = int(config.get("samples", 12))

    camera = scene.camera
    require(camera is not None, "Production scene has no active camera")
    camera.data.type = "ORTHO"

    armature_name = config["armature_object"]
    armature = bpy.data.objects.get(armature_name)
    require(armature is not None and armature.type == "ARMATURE",
            f"Missing rigged armature object: {armature_name}")
    actions = config["actions"]
    states = tuple(config["states"])
    require(states and all(state in actions for state in states),
            "The config must declare at least one state and an action for each")
    for state in states:
        require(state in actions, f"Missing configured action: {state}")
        require(actions[state] in bpy.data.actions,
                f"Missing Blender Action: {actions[state]}")

    frame_counts = config["frame_counts"]
    require(all(state in frame_counts and int(frame_counts[state]) > 1 for state in states),
            "frame_counts must define at least two frames for every state")
    loop_states = set(config.get("loop_states", ()))
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

    # The CI workflow's validation, packing and upload steps are pinned to the
    # Ranger directories and cannot be edited (the push token has no `workflow`
    # scope). Every hero therefore renders into that fixed directory; the
    # packer publishes non-Ranger output under `renders/_bundle/<hero>/`, which
    # the existing artifact upload already carries to the committing machine.
    output_root = (root / "assets/heroes/ranger/renders").resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    # Stale frames from an older frame count silently inflate the atlas input
    # set and make the visual validator inspect images that are no longer part
    # of the manifest. Rebuild each configured state directory from scratch.
    for state in states:
        state_dir = output_root / state
        if state_dir.exists():
            shutil.rmtree(state_dir)
    manifest = {
        "schema_version": 1,
        "hero_id": hero_id,
        "frame_size": {"width": resolution, "height": resolution},
        "pivot": {"x": pivot_x, "y": pivot_y},
        "output_directory": config["output_directory"],
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
    for state in states:
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
        # Orbit the camera position too, not just its rotation: keeping the
        # authored position while turning to face east or north points the
        # camera across the character, and the flattened view plane slices
        # through the model (which is exactly how a 56x80 sprite turned into a
        # thin sliver). `target + offset` keeps the authored distance and
        # elevation for every direction.
        camera_position = target + offset
        camera.matrix_world = (Matrix.Translation(camera_position)
                               @ rotation.to_matrix().to_4x4())
        bpy.context.view_layer.update()
        # Measure where the ground anchor currently projects, then slide the
        # camera parallel to the image plane until it lands on the manifest
        # pivot. The shift uses right/up only, never the view axis, so the
        # camera keeps its orbit distance and the rig stays in front of the
        # view plane for all eight directions.
        anchor = world_to_camera_view(scene, camera, ground)
        camera.matrix_world = (Matrix.Translation(camera_position + (
            (anchor.x - pivot_x) * scale * right
            + (anchor.y - (1.0 - pivot_y)) * scale * up))
            @ rotation.to_matrix().to_4x4())
        bpy.context.view_layer.update()

        projected = world_to_camera_view(scene, camera, ground)
        # Guard against the camera sliding behind the character. An orthographic
        # camera still clips geometry that is behind its view plane, which
        # silently replaces the sprite with a thin sliver of the model.
        depths = [(world_to_camera_view(scene, camera, Vector(corner)).z, corner)
                  for low, high in pose_bounds.values()
                  for corner in bounds_corners(low, high)]
        nearest_depth, nearest_corner = min(depths, key=lambda item: item[0])
        print(f"CAMERA {direction} loc=({camera.location.x:.3f},"
              f"{camera.location.y:.3f},{camera.location.z:.3f}) "
              f"anchor=({anchor.x:.4f},{anchor.y:.4f}) "
              f"projected=({projected.x:.4f},{projected.y:.4f}) "
              f"nearest={nearest_depth:.3f}@"
              f"({nearest_corner.x:.2f},{nearest_corner.y:.2f},{nearest_corner.z:.2f})")
        require(abs(projected.x - pivot_x) <= PIVOT_TOLERANCE
                and abs((1.0 - projected.y) - pivot_y) <= PIVOT_TOLERANCE,
                f"{direction}: ground anchor lands at "
                f"({projected.x:.4f}, {1.0 - projected.y:.4f}) instead of the "
                f"configured pivot ({pivot_x:.4f}, {pivot_y:.4f})")
        check_direction_framing(pose_bounds, ground, right, up, scale,
                                pivot_x, pivot_y, margin, direction)
        require(nearest_depth > 0.5,
                f"{direction}: camera view plane intersects the character "
                f"(nearest corner is {nearest_depth:.3f} units in front)")

        low, high = pose_bounds[(states[0], sampled_frames(config, states[0])[0])]
        predicted = [world_to_camera_view(scene, camera, Vector(corner))
                     for corner in bounds_corners(low, high)]
        xs = [point.x * resolution for point in predicted]
        ys = [(1.0 - point.y) * resolution for point in predicted]
        print(f"FRAMING {direction} ortho_scale={camera.data.ortho_scale:.3f} "
              f"res={scene.render.resolution_x}x{scene.render.resolution_y}"
              f"@{scene.render.resolution_percentage}% "
              f"predicted_idle_px=x{min(xs):.1f}..{max(xs):.1f} "
              f"y{min(ys):.1f}..{max(ys):.1f}")

        for state in states:
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
                if index == 0 and state == states[0] and direction == "s":
                    assert_render_colors(file_path)
                ids.append(frame_id)
            events = []
            for event in config.get("events", {}).get(state, []):
                source_frame = int(event["frame"])
                source_index = min(range(len(frame_numbers)),
                                   key=lambda i: abs(frame_numbers[i] - source_frame))
                events.append({"frame": source_index, "name": event["name"]})
            duration = int(config.get("frame_durations_ms", {}).get(
                state, round(1000 / fps)))
            manifest["animations"][f"{state}_{direction}"] = {
                "loop": state in loop_states,
                "frame_duration_ms": duration,
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
    print(f"Rendered {render_count} frames across {len(states)} states and "
          f"{len(DIRECTIONS)} directions. Manifest: {manifest_path}")
    print("Next: run pack_hero_atlases.py in Blender to create atlas PNGs and metadata.")


if __name__ == "__main__":
    main()
