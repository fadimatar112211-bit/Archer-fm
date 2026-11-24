#!/usr/bin/env python3
"""Render Storm's real animated GLB into eight-direction sprite frames.

The GLB is fetched from the existing implementation branch by CI. This script
fails closed if the rig or any of the eight required actions is absent.
"""
import bpy
import json
import math
import os
import re
import sys
from pathlib import Path
from mathutils import Vector

STATES = ["idle", "walk", "run", "attack", "skill", "dodge", "hit", "death"]
DIRECTIONS = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
COUNTS = {"idle": 5, "walk": 9, "run": 9, "attack": 7, "skill": 9, "dodge": 9, "hit": 5, "death": 9}
DURATIONS = {"idle": 140, "walk": 83, "run": 66, "attack": 70, "skill": 90, "dodge": 60, "hit": 70, "death": 120}
EVENTS = {
    "attack": [{"frame": 1, "name": "weapon_windup"}, {"frame": 3, "name": "melee_impact"}],
    "skill": [{"frame": 2, "name": "storm_charge"}, {"frame": 4, "name": "thunder_strike"}],
    "dodge": [{"frame": 2, "name": "dodge_start"}, {"frame": 8, "name": "dodge_end"}],
    "hit": [{"frame": 2, "name": "hit_react"}],
    "death": [{"frame": 8, "name": "death_complete"}],
}
ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "assets/heroes/storm/model/storm_animated.glb"
OUT = ROOT / "assets/heroes/storm/renders"
FRAMES = Path("/tmp/archer_storm_frames")

def fail(message):
    raise RuntimeError(message)

def action_for(state):
    matches = [a for a in bpy.data.actions if state in re.sub(r"[^a-z]", "", a.name.lower())]
    if not matches:
        fail("Missing Storm animation action for state: " + state + "; found: " + ", ".join(a.name for a in bpy.data.actions))
    # Prefer an action whose normalized name ends with the requested state.
    matches.sort(key=lambda a: (not re.sub(r"[^a-z]", "", a.name.lower()).endswith(state), a.name))
    return matches[0]

def bounds_of_meshes(meshes):
    bpy.context.view_layer.update()
    pts = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        pts.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    if not pts:
        fail("Storm GLB contains no mesh geometry")
    low = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    high = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return low, high

def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()

def main():
    if not MODEL.is_file():
        fail(f"Missing source model: {MODEL}")
    # Empty scene, then import the animated GLB.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(MODEL))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not rigs:
        fail("Storm GLB has no armature; refusing to render fake animation")
    rig = rigs[0]
    actions = {state: action_for(state) for state in STATES}
    if len({a.name for a in actions.values()}) != 8:
        fail("Storm action mapping is not one unique action per state")
    print("STORM_RIG", rig.name, "bones", len(rig.data.bones))
    print("STORM_ACTIONS", {k: v.name for k, v in actions.items()})

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys() else "BLENDER_EEVEE"
    scene.render.resolution_x = 192
    scene.render.resolution_y = 192
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.fps = 12
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.camera = None

    # Three soft lights preserve the GLB's materials while keeping alpha.
    def area_light(name, loc, power, size):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = loc
        return obj
    target = (0.0, 0.0, 0.48)
    lights = [
        area_light("Storm_Key", (3.5, -4.0, 5.0), 520, 4.0),
        area_light("Storm_Fill", (-4.0, -1.0, 2.8), 300, 3.5),
        area_light("Storm_Rim", (0.0, 4.0, 4.0), 450, 3.0),
    ]
    for light in lights:
        look_at(light, target)
    world = bpy.data.worlds.new("Storm_Render_World") if not bpy.data.worlds else bpy.data.worlds[0]
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.12, 0.15, 0.18, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35

    camera_data = bpy.data.cameras.new("Storm_Ortho_Camera")
    camera = bpy.data.objects.new("Storm_Ortho_Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    scene.camera = camera

    # Determine framing from the rest pose, with feet pinned at 86% of frame.
    rig.animation_data_create()
    rig.animation_data.action = None
    scene.frame_set(0)
    low, high = bounds_of_meshes(meshes)
    center = (low + high) * 0.5
    height = max(0.5, high.z - low.z)
    target = Vector((center.x, center.y, low.z + height * 0.46))
    camera.data.ortho_scale = max(height * 1.42, (high.x-low.x) * 1.35, (high.y-low.y) * 1.35, 1.0)
    FRAMES.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema_version": 2,
        "hero_id": "storm",
        "frame_size": {"width": 192, "height": 192},
        "pivot": {"x": 0.5, "y": 0.86},
        "source": {"model": "assets/heroes/storm/model/storm_animated.glb", "fps": 12},
        "atlases": [],
        "animations": {},
    }

    direction_angles = {"s": 0, "sw": 45, "w": 90, "nw": 135, "n": 180, "ne": 225, "e": 270, "se": 315}
    for state in STATES:
        action = actions[state]
        start, end = [float(x) for x in action.frame_range]
        if end <= start:
            fail(f"Storm action {action.name} has invalid frame range {action.frame_range}")
        count = COUNTS[state]
        samples = [round(start + (end - start) * i / (count - 1)) for i in range(count)]
        if len(set(samples)) != count:
            fail(f"Storm action {action.name} is too short for {count} distinct rendered frames: {samples}")
        for direction in DIRECTIONS:
            radians = math.radians(direction_angles[direction])
            offset = Vector((math.sin(radians) * 4.2, -math.cos(radians) * 4.2, 1.45))
            camera.location = target + offset
            look_at(camera, target)
            frames = []
            for index, frame in enumerate(samples):
                rig.animation_data.action = action
                # Preserve authored pose channels; evaluate the selected action directly.
                scene.frame_set(frame)
                bpy.context.view_layer.update()
                frame_id = f"storm_{state}_{direction}_{index:03d}"
                path = FRAMES / f"{frame_id}.png"
                scene.render.filepath = str(path)
                bpy.ops.render.render(write_still=True)
                frames.append(frame_id)
            name = f"{state}_{direction}"
            manifest["animations"][name] = {
                "loop": state in ("idle", "walk", "run"),
                "frame_duration_ms": DURATIONS[state],
                "frames": frames,
                "events": EVENTS.get(state, []),
            }
            manifest["atlases"].append({
                "animation": name,
                "image": f"atlases/{name}.png",
                "meta": f"atlases/{name}.json",
            })
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "storm_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("STORM_RENDER_COMPLETE", len(manifest["animations"]), "clips", sum(len(v["frames"]) for v in manifest["animations"].values()), "frames")

if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
