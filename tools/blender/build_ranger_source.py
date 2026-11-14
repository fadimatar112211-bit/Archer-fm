"""Build the original stylized Ranger production source scene in Blender.

Run:
  blender -b --python tools/blender/build_ranger_source.py

Creates:
  assets/heroes/ranger/source/ranger_source.blend

This is procedural original geometry, not a downloaded/third-party model.
All visible parts are separate meshes parented to named armature bones so the
scene is editable and its Actions can be refined in Blender.
"""
from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/heroes/ranger/source/ranger_source.blend"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                       bpy.data.cameras, bpy.data.lights, bpy.data.actions):
        pass


def material(name, color, metallic=0.0, roughness=0.55, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1.0)
    bs.inputs["Metallic"].default_value = metallic
    bs.inputs["Roughness"].default_value = roughness
    if emission:
        bs.inputs["Emission Color"].default_value = (*color, 1.0)
        bs.inputs["Emission Strength"].default_value = emission
    return mat


MATS = {}


def uv_sphere(name, loc, scale, mat, bone=None, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(MATS[mat])
    smooth(obj)
    if bone:
        attach(obj, bone)
    return obj


def bevel_cube(name, loc, scale, mat, bevel=0.12, bone=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(MATS[mat])
    mod = obj.modifiers.new("Soft crafted edges", "BEVEL")
    mod.width = bevel
    mod.segments = 3
    obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    if bone:
        attach(obj, bone)
    return obj


def cylinder_between(name, a, b, radius, mat, bone=None, vertices=16):
    a, b = Vector(a), Vector(b)
    delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                         depth=delta.length, location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    obj.data.materials.append(MATS[mat])
    bevel = obj.modifiers.new("Rounded ends", "BEVEL")
    bevel.width = min(radius * 0.22, 0.06)
    bevel.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    if bone:
        attach(obj, bone)
    return obj


def smooth(obj):
    if obj.type == "MESH":
        for poly in obj.data.polygons:
            poly.use_smooth = True


def attach(obj, bone):
    # Preserve the mesh's evaluated world transform while assigning a bone
    # parent. Let Blender calculate the correct local basis for bone parenting;
    # manually inverting PoseBone.matrix omits the rest-bone offset and can
    # scatter the character's parts around the render.
    world_matrix = obj.matrix_world.copy()
    obj.parent = ARM
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = world_matrix


def make_armature():
    global ARM
    data = bpy.data.armatures.new("Ranger_Armature")
    ARM = bpy.data.objects.new("Ranger_Rig", data)
    bpy.context.collection.objects.link(ARM)
    bpy.context.view_layer.objects.active = ARM
    ARM.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = {
        "root": ((0, 0, 0.2), (0, 0, 1.0), None),
        "torso": ((0, 0, 1.0), (0, 0, 2.0), "root"),
        "head": ((0, 0, 2.0), (0, 0, 2.85), "torso"),
        "arm.L": ((-0.42, 0, 1.85), (-0.82, 0, 1.2), "torso"),
        "arm.R": ((0.42, 0, 1.85), (0.82, 0, 1.2), "torso"),
        "leg.L": ((-0.22, 0, 0.95), (-0.25, 0, 0.18), "root"),
        "leg.R": ((0.22, 0, 0.95), (0.25, 0, 0.18), "root"),
        "bow": ((0.75, -0.1, 1.65), (1.0, -0.1, 2.3), "arm.R"),
        "quiver": ((-0.35, 0.18, 1.7), (-0.55, 0.18, 2.35), "torso"),
        "cloak": ((0, 0.18, 1.85), (0, 0.3, 0.55), "torso"),
    }
    for name, (head, tail, parent) in bones.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = data.edit_bones[parent]
            bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    ARM.select_set(False)
    return ARM


def build_character():
    # Boots and legs
    for side, x, bone in (("L", -0.23, "leg.L"), ("R", 0.23, "leg.R")):
        uv_sphere(f"Boot_{side}", (x, -0.02, 0.2), (0.22, 0.34, 0.18), "leather", bone)
        bevel_cube(f"Greave_{side}", (x, 0, 0.57), (0.31, 0.34, 0.62), "green", 0.1, bone)
        uv_sphere(f"Knee_Gold_{side}", (x, -0.19, 0.83), (0.18, 0.09, 0.12), "gold", bone)

    # Compact armored body and shoulder details
    uv_sphere("Body_Tunic", (0, 0, 1.48), (0.62, 0.42, 0.66), "green", "torso")
    bevel_cube("Chest_Leather", (0, -0.365, 1.53), (0.7, 0.16, 0.52), "leather", 0.16, "torso")
    bevel_cube("Chest_Gold_Trim", (0, -0.46, 1.56), (0.56, 0.035, 0.08), "gold", 0.025, "torso")
    uv_sphere("Belt", (0, -0.01, 1.13), (0.57, 0.43, 0.12), "leather", "torso")
    bevel_cube("Buckle", (0, -0.445, 1.14), (0.18, 0.06, 0.16), "gold", 0.035, "torso")
    for side, x in (("L", -0.48), ("R", 0.48)):
        uv_sphere(f"Shoulder_Pad_{side}", (x, 0, 1.88), (0.28, 0.34, 0.23), "gold", "torso")
        uv_sphere(f"Shoulder_Enamel_{side}", (x, -0.19, 1.9), (0.2, 0.18, 0.15), "green", "torso")

    # Head, face, hair and hood
    uv_sphere("Neck", (0, 0, 2.02), (0.22, 0.22, 0.2), "skin", "head")
    uv_sphere("Face", (0, -0.06, 2.38), (0.48, 0.42, 0.53), "skin", "head")
    uv_sphere("Hair_Back", (0, 0.18, 2.5), (0.49, 0.4, 0.5), "silver", "head")
    # Hood shell and crown
    uv_sphere("Hood_Crown", (0, 0.1, 2.68), (0.59, 0.48, 0.49), "green", "head")
    uv_sphere("Hood_Front_Brim", (0, -0.34, 2.64), (0.58, 0.22, 0.16), "gold", "head")
    uv_sphere("Hood_Face_Opening", (0, -0.34, 2.39), (0.43, 0.16, 0.39), "skin", "head")
    for side, x in (("L", -0.19), ("R", 0.19)):
        uv_sphere(f"Eye_{side}", (x, -0.493, 2.43), (0.075, 0.035, 0.09), "blue", "head", 16, 12)
        uv_sphere(f"Pupil_{side}", (x, -0.523, 2.43), (0.028, 0.018, 0.05), "dark", "head", 12, 8)
    uv_sphere("Nose", (0, -0.51, 2.29), (0.07, 0.06, 0.06), "skin", "head")
    # Silver locks visible at sides
    for side, x in (("L", -0.43), ("R", 0.43)):
        uv_sphere(f"Silver_Lock_{side}", (x, -0.23, 2.32), (0.12, 0.16, 0.27), "silver", "head")

    # Arms, gloves and forearm bracers
    for side, x, bone in (("L", -0.68, "arm.L"), ("R", 0.68, "arm.R")):
        cylinder_between(f"Sleeve_{side}", (x*0.58, 0, 1.83), (x, -0.02, 1.27),
                         0.17, "green", bone)
        uv_sphere(f"Bracer_{side}", (x, -0.05, 1.39), (0.2, 0.22, 0.25), "leather", bone)
        uv_sphere(f"Glove_{side}", (x*1.12, -0.04, 1.2), (0.17, 0.18, 0.17), "leather", bone)

    # Flowing cloak: layered tapered beveled panels behind body
    cloak = bevel_cube("Cloak_Main", (0, 0.34, 1.23), (0.92, 0.22, 1.35), "green", 0.18, "cloak")
    cloak.rotation_euler[0] = math.radians(-8)
    bevel_cube("Cloak_Gold_Edge", (0, 0.205, 0.66), (0.78, 0.035, 0.07), "gold", 0.025, "cloak")
    for x in (-0.31, 0.31):
        uv_sphere("Cloak_Clasp", (x, -0.39, 1.91), (0.08, 0.05, 0.08), "gold", "torso")

    # Quiver and visible arrows
    cylinder_between("Quiver", (-0.48, 0.28, 1.55), (-0.61, 0.28, 2.32),
                     0.14, "leather", "quiver", 20)
    for i in range(5):
        x = -0.68 + i * 0.055
        cylinder_between(f"Quiver_Arrow_{i}", (x, 0.22, 2.02), (x, 0.22, 2.52),
                         0.018, "gold", "quiver", 8)

    # Signature bow: curved arc approximated by joined segments and glowing core
    bow_points = []
    for i in range(13):
        t = i / 12
        bow_points.append((0.82 + 0.27 * math.sin(math.pi*t), -0.2,
                           1.45 + 0.92*t))
    for i in range(len(bow_points)-1):
        cylinder_between(f"Bow_Limb_{i}", bow_points[i], bow_points[i+1],
                         0.045, "green_glow", "bow", 12)
    cylinder_between("Bow_String", (0.82, -0.18, 1.45), (0.82, -0.18, 2.37),
                     0.012, "silver", "bow", 8)
    uv_sphere("Bow_Gem", (1.1, -0.23, 1.92), (0.09, 0.08, 0.13), "green_glow", "bow")


def animate():
    scene = bpy.context.scene
    poses = {
        "Ranger_Idle": {
            1: {"torso": (0,0,0), "head": (0,0,0), "arm.L": (0,0,0), "arm.R": (0,0,0), "leg.L": (0,0,0), "leg.R": (0,0,0), "cloak": (0,0,0)},
            13: {"torso": (0,0.018,0), "head": (0,0,0.025), "arm.L": (0.025,0,0), "arm.R": (-0.02,0,0), "leg.L": (0,0,0), "leg.R": (0,0,0), "cloak": (0.025,0,0)},
            25: {"torso": (0,0,0), "head": (0,0,0), "arm.L": (0,0,0), "arm.R": (0,0,0), "leg.L": (0,0,0), "leg.R": (0,0,0), "cloak": (0,0,0)}
        },
        "Ranger_Walk": {
            1: {"leg.L": (0.38,0,0), "leg.R": (-0.38,0,0), "arm.L": (-0.3,0,0), "arm.R": (0.3,0,0), "torso": (0,0.02,0), "cloak": (0.08,0,0)},
            5: {"leg.L": (-0.38,0,0), "leg.R": (0.38,0,0), "arm.L": (0.3,0,0), "arm.R": (-0.3,0,0), "torso": (0,0.04,0), "cloak": (-0.08,0,0)},
            9: {"leg.L": (0.38,0,0), "leg.R": (-0.38,0,0), "arm.L": (-0.3,0,0), "arm.R": (0.3,0,0), "torso": (0,0.02,0), "cloak": (0.08,0,0)}
        },
        "Ranger_Attack": {
            1: {"arm.R": (0,0,0), "arm.L": (0,0,0), "torso": (0,0,0)},
            5: {"arm.R": (-0.65,0,0.25), "arm.L": (0.25,0,0), "torso": (0,-0.04,0.08)},
            9: {"arm.R": (-0.25,0,0.08), "arm.L": (0.1,0,0), "torso": (0,0,0.02)},
            18: {"arm.R": (0,0,0), "arm.L": (0,0,0), "torso": (0,0,0)}
        },
        "Ranger_Death": {
            1: {"root": (0,0,0), "torso": (0,0,0), "head": (0,0,0)},
            8: {"root": (0.25,0,0.15), "torso": (0.7,0,0.1), "head": (0.2,0,0)},
            16: {"root": (1.2,0,0.25), "torso": (1.25,0,0), "head": (0.5,0,0), "cloak": (0.5,0,0)},
            24: {"root": (1.2,0,0.25), "torso": (1.25,0,0), "head": (0.5,0,0), "cloak": (0.5,0,0)}
        }
    }
    for action_name, frames in poses.items():
        action = bpy.data.actions.new(action_name)
        ARM.animation_data_create()
        ARM.animation_data.action = action
        for frame, bone_values in frames.items():
            for bone_name, rotation in bone_values.items():
                pb = ARM.pose.bones[bone_name]
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = rotation
                pb.keyframe_insert(data_path="rotation_euler", frame=frame,
                                   group=bone_name)
        for fc in action.fcurves:
            for key in fc.keyframe_points:
                key.interpolation = "BEZIER"
        if action_name in ("Ranger_Idle", "Ranger_Walk"):
            for fc in action.fcurves:
                for key in fc.keyframe_points:
                    key.handle_left_type = "AUTO"
                    key.handle_right_type = "AUTO"
        action.use_fake_user = True
    ARM.animation_data.action = bpy.data.actions["Ranger_Idle"]
    scene.frame_start, scene.frame_end = 1, 24


def setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"  # Ubuntu 24.04 Blender 4.0 package compatibility
    scene.render.resolution_x = scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.fps = 12
    scene.view_settings.view_transform = "AgX"

    bpy.ops.object.camera_add(location=(0, -8.0, 3.9))
    camera = bpy.context.object
    camera.name = "Ranger_Orthographic_Camera"
    target = Vector((0, 0, 1.45))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.6
    scene.camera = camera

    for name, loc, energy, size in (
        ("Key_Softbox", (4,-4,7), 850, 5),
        ("Fill_Softbox", (-4,-2,4), 500, 4),
        ("Rim_Softbox", (0,4,6), 1000, 3),
    ):
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (Vector((0,0,1.4))-light.location).to_track_quat("-Z","Y").to_euler()


def main():
    global ARM
    clear_scene()
    MATS.update({
        "green": material("Forest Green Enamel", (0.035,0.24,0.105), 0.12, 0.42),
        "gold": material("Warm Gold Trim", (0.82,0.48,0.09), 0.62, 0.28),
        "leather": material("Chestnut Leather", (0.24,0.095,0.045), 0.05, 0.72),
        "skin": material("Warm Light Skin", (0.78,0.48,0.32), 0.0, 0.62),
        "silver": material("Silver White Hair", (0.78,0.84,0.9), 0.18, 0.3),
        "blue": material("Sapphire Blue Eyes", (0.015,0.25,0.9), 0.18, 0.22, 0.15),
        "dark": material("Deep Pupil", (0.008,0.015,0.025), 0.0, 0.25),
        "green_glow": material("Emerald Bow Energy", (0.015,0.8,0.27), 0.3, 0.2, 1.4),
    })
    make_armature()
    build_character()
    animate()
    setup_scene()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
    print(f"Saved editable Ranger production source: {OUT}")


if __name__ == "__main__":
    main()
