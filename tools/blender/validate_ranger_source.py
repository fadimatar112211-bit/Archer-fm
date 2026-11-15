"""Validate generated Ranger Blender source scene before full rendering.

Run:
  blender -b assets/heroes/ranger/source/ranger_source.blend --python tools/blender/validate_ranger_source.py
"""
from __future__ import annotations
import sys
import bpy

REQUIRED_BONES = {
    "root", "hips", "spine", "chest", "neck", "head",
    "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R",
    "forearm.L", "forearm.R", "hand.L", "hand.R",
    "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
    "cloak_a", "cloak_b", "cloak_c", "bow", "string_rest", "string_drawn",
    "fx", "fx_draw", "aura", "quiver",
}
REQUIRED_ACTIONS = {
    "Ranger_Idle": (1, 25),
    "Ranger_Walk": (1, 25),
    "Ranger_Run": (1, 25),
    "Ranger_Attack": (1, 25),
    "Ranger_Skill": (1, 33),
    "Ranger_Dodge": (1, 17),
    "Ranger_Hit": (1, 9),
    "Ranger_Death": (1, 33),
}
REQUIRED_MATERIALS = (
    "Forest Green Cloth",
    "Lit Green Cloth",
    "Aged Bronze Plate",
    "Chestnut Leather",
    "Brass Buckle",
    "Warm Skin",
    "Hair Body",
    "Sapphire Iris",
    "Energy Core",
    "Energy Glow",
)

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
    if len(meshes) < 100:
        fail("Expected detailed character mesh parts; found only " + str(len(meshes)))
    incorrectly_parented = [
        obj.name for obj in meshes
        if obj.parent != rig or obj.parent_type != "BONE"
        or obj.parent_bone not in REQUIRED_BONES
    ]
    if incorrectly_parented:
        fail("Every rigid mesh part must be parented directly to its intended rig bone: " +
             ", ".join(incorrectly_parented[:12]))
    double_deformed = [
        obj.name for obj in meshes
        if any(mod.type == "ARMATURE" for mod in obj.modifiers)
        or len(obj.vertex_groups) > 0
    ]
    if double_deformed:
        fail("Bone-parented mesh parts must not also use vertex weights or Armature modifiers: " +
             ", ".join(double_deformed[:12]))
    material_names = {mat.name for mat in bpy.data.materials}
    for required in REQUIRED_MATERIALS:
        if required not in material_names:
            fail("Required material missing: " + required)
    # `node.type` is the RNA enum id (BSDF_PRINCIPLED), not the Python class
    # name (ShaderNodeBsdfPrincipled). A colour socket wired straight into
    # Surface has type RGB/VALTORGB/MIX_RGB and is rejected here.
    shader_node_types = {
        "BSDF_PRINCIPLED", "EMISSION", "BSDF_DIFFUSE", "BSDF_GLOSSY",
        "BSDF_TRANSPARENT", "ADD_SHADER", "MIX_SHADER", "BSDF_TOON",
        "BSDF_ANISOTROPIC", "BSDF_GLASS", "BSDF_REFRACTION", "BSDF_TRANSLUCENT",
        "SUBSURFACE_SCATTERING", "HAIR_BSDF", "BSDF_SHEEN", "BSDF_VELVET",
        "BSDF_HOLOGRAM", "BSDF_HAIR_PRINCIPLED",
    }
    broken_materials = []
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        outputs = [n for n in mat.node_tree.nodes
                   if n.type == "OUTPUT_MATERIAL" and n.is_active_output]
        if not outputs:
            broken_materials.append(mat.name + " (no active output)")
            continue
        surface = outputs[0].inputs["Surface"]
        if not surface.is_linked:
            broken_materials.append(mat.name + " (unconnected surface)")
            continue
        source = surface.links[0].from_node
        if source.type not in shader_node_types:
            # EEVEE renders a colour jacked into Surface as flat magenta, which
            # silently ships an unrecognisable hero. Fail here instead.
            broken_materials.append(mat.name + " (" + source.type + ")")
    if broken_materials:
        fail("Materials whose Surface input is not a shader: " +
             ", ".join(sorted(broken_materials)))

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
