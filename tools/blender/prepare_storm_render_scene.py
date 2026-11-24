"""Build a camera-ready Blender scene from Storm's shipped animated GLB.

Storm's original .blend authoring source is not present on this branch. The
checked-in storm_animated.glb already contains the rig, mesh, materials and
eight exported animation actions, so use that production asset as the render
source instead of requiring a missing .blend file.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(argv)


def look_at(obj, point):
    direction = Vector(point) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def main():
    options = args()
    source = Path(options.input).resolve()
    output = Path(options.output).resolve()
    if not source.is_file() or source.stat().st_size < 1024:
        raise RuntimeError(f"Storm animated GLB is missing or empty: {source}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(armatures) != 1 or not meshes:
        raise RuntimeError(
            f"Expected one Storm armature and visible mesh; got "
            f"{len(armatures)} armatures, {len(meshes)} meshes"
        )
    rig = armatures[0]
    rig.name = "Storm_Rig"
    rig.data.name = "Storm_RigData"

    # The glTF importer may prefix exported action names with the armature.
    # Normalize only the known Storm action suffixes; never borrow another hero.
    required = (
        "Storm_Idle", "Storm_Walk", "Storm_Run", "Storm_Attack",
        "Storm_Skill", "Storm_Dodge", "Storm_Hit", "Storm_Death",
    )
    available = list(bpy.data.actions)
    for expected in required:
        matches = [a for a in available if a.name == expected or a.name.endswith("|" + expected)]
        if len(matches) != 1:
            raise RuntimeError(
                f"Expected exactly one imported action {expected}; "
                f"found {[a.name for a in matches]}; all={[a.name for a in available]}"
            )
        matches[0].name = expected
    rig.animation_data_clear()
    rig.data.pose_position = "POSE"

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 192
    scene.render.resolution_y = 192
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.fps = 12

    # Center the camera on the mesh bounds while preserving the game's front
    # convention (Storm faces -Y). The render pipeline re-orbits this camera
    # for all eight directions.
    bpy.context.view_layer.update()
    corners = []
    for mesh in meshes:
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        corners.extend(mesh.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    if not corners:
        raise RuntimeError("Storm GLB has no renderable mesh bounds")
    low = Vector(tuple(min(p[i] for p in corners) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in corners) for i in range(3)))
    center = (low + high) * 0.5
    height = max(0.5, high.z - low.z)

    camera_data = bpy.data.cameras.new("Storm_RenderCamera")
    camera = bpy.data.objects.new("Storm_RenderCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = center + Vector((0.0, -height * 4.0, height * 1.8))
    look_at(camera, center)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(height * 1.65, 1.2)
    scene.camera = camera

    key_data = bpy.data.lights.new("Storm_Key", type="AREA")
    key = bpy.data.objects.new("Storm_Key", key_data)
    scene.collection.objects.link(key)
    key.location = center + Vector((-height * 2.5, -height * 3.0, height * 4.0))
    key.data.energy = 650
    key.data.shape = "DISK"
    key.data.size = height * 3.0
    look_at(key, center)

    fill_data = bpy.data.lights.new("Storm_Fill", type="AREA")
    fill = bpy.data.objects.new("Storm_Fill", fill_data)
    scene.collection.objects.link(fill)
    fill.location = center + Vector((height * 3.0, height * 1.5, height * 2.0))
    fill.data.energy = 300
    fill.data.size = height * 2.5
    look_at(fill, center)

    scene.world.color = (0.18, 0.18, 0.18)
    # The render script expects its feet at the shared world-space ground
    # anchor, so normalize the whole imported model to z=0.
    for obj in meshes:
        obj.location.z -= low.z
    rig.location.z -= low.z
    bpy.context.view_layer.update()

    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    print("STORM_RENDER_SOURCE_READY", output, "actions=", required,
          "mesh_count=", len(meshes), "bounds_height=", round(height, 4))


if __name__ == "__main__":
    main()
