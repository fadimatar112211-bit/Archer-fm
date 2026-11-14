"""Validate generated Ranger Blender source scene before full rendering.

Run:
  blender -b assets/heroes/ranger/source/ranger_source.blend --python tools/blender/validate_ranger_source.py
"""
from __future__ import annotations
import sys
import bpy

REQUIRED_BONES = {
    "root", "torso", "head", "arm.L", "arm.R", "leg.L", "leg.R",
    "bow", "quiver", "cloak"
}
REQUIRED_ACTIONS = {
    "Ranger_Idle": (1, 25),
    "Ranger_Walk": (1, 9),
    "Ranger_Attack": (1, 18),
    "Ranger_Death": (1, 24),
}

def fail(message):
    print("RANGER_SOURCE_ERROR: " + message, file=sys.stderr)
    raise SystemExit(1)

def main():
    rig = bpy.data.objects.get("Ranger_Rig")
    if rig is None or rig.type != "ARMATURE":
        fail("Ranger_Rig armature is missing")
    missing = REQUIRED_BONES - set(rig.data.bones.keys())
    if missing:
        fail("Missing rig bones: " + ", ".join(sorted(missing)))
    if bpy.context.scene.camera is None:
        fail("Active camera is missing")
    if bpy.context.scene.render.resolution_x != 256 or bpy.context.scene.render.resolution_y != 256:
        fail("Source scene render resolution must be 256x256")
    if not bpy.context.scene.render.film_transparent:
        fail("Transparent film output must be enabled")

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if len(meshes) < 35:
        fail("Expected detailed character mesh parts; found only " + str(len(meshes)))
    unparented = [obj.name for obj in meshes
                  if obj.parent != rig or obj.parent_type != "OBJECT"]
    if unparented:
        fail("Rigid sprite parts must preserve world transforms under Ranger_Rig: " +
             ", ".join(unparented[:12]))
    incorrectly_skinned = []
    for obj in meshes:
        bone_groups = {group.name for group in obj.vertex_groups}
        armature_modifiers = [mod for mod in obj.modifiers
                              if mod.type == "ARMATURE" and mod.object == rig]
        if len(bone_groups) != 1 or not armature_modifiers:
            incorrectly_skinned.append(obj.name)
    if incorrectly_skinned:
        fail("Every rigid mesh part must have one bone vertex group and an armature modifier: " +
             ", ".join(incorrectly_skinned[:12]))
    material_names = {mat.name for mat in bpy.data.materials}
    for required in ("Forest Green Enamel", "Warm Gold Trim", "Chestnut Leather",
                     "Silver White Hair", "Sapphire Blue Eyes", "Emerald Bow Energy"):
        if required not in material_names:
            fail("Required material missing: " + required)

    for action_name, expected_range in REQUIRED_ACTIONS.items():
        action = bpy.data.actions.get(action_name)
        if action is None:
            fail("Animation action missing: " + action_name)
        if not getattr(action, "fcurves", None):
            fail("Animation has no F-curves: " + action_name)
        key_count = sum(len(curve.keyframe_points) for curve in action.fcurves)
        if key_count < 4:
            fail("Animation has too few keyed values: " + action_name)
        actual_start, actual_end = action.frame_range
        if actual_start < expected_range[0] or actual_end > expected_range[1]:
            fail("Unexpected frame range for " + action_name + ": " +
                 str((actual_start, actual_end)))

    print("RANGER_SOURCE_OK")
    print("mesh_parts=" + str(len(meshes)))
    print("bones=" + str(len(rig.data.bones)))
    print("actions=" + str(len(REQUIRED_ACTIONS)))
    print("materials=" + str(len(material_names)))

if __name__ == "__main__":
    main()
