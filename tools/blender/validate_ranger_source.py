"""Validate a generated hero .blend before the expensive render pass.

Run:
  blender -b assets/heroes/ranger/source/ranger_source.blend --python tools/blender/validate_ranger_source.py

The builder writes `hero_id`, `hero_prefix` and `rig_object` into the scene, so
one validator covers every hero in the shared pipeline. It checks the rig, the
single-bone skinning contract, the shaded material network, and the eight
authored Actions with their expected frame ranges.
"""
from __future__ import annotations

import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hero_profiles  # noqa: E402

REQUIRED_BONES = {
    "root", "hips", "spine", "chest", "neck", "head",
    "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R",
    "forearm.L", "forearm.R", "hand.L", "hand.R",
    "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
    "cloak_a", "cloak_b", "cloak_c", "bow", "string_rest", "string_drawn",
    "fx", "fx_draw", "aura", "quiver",
}
ACTION_RANGES = {
    "Idle": (1, 25),
    "Walk": (1, 25),
    "Run": (1, 25),
    "Attack": (1, 25),
    "Skill": (1, 33),
    "Dodge": (1, 17),
    "Hit": (1, 9),
    "Death": (1, 33),
}
REQUIRED_MATERIALS = (
    "Cloth Primary",
    "Cloth Lit",
    "Metal Plate",
    "Leather Gear",
    "Brass Accent",
    "Warm Skin",
    "Hair Body",
    "Iris",
    "Energy Core",
    "Energy Glow",
)


def fail(message):
    print("HERO_SOURCE_ERROR: " + message, file=sys.stderr)
    raise SystemExit(1)


def main():
    scene = bpy.context.scene
    hero_id = scene.get("hero_id", "ranger")
    marker = Path(__file__).resolve().parent / "active_hero.txt"
    expected_hero = ((marker.read_text(encoding="utf-8").strip().lower()
                      if marker.is_file() else "ranger") or "ranger")
    if hero_id != expected_hero:
        fail(f"Scene builds {hero_id!r} but active_hero.txt asks for "
             f"{expected_hero!r}; the .blend is stale")
    if hero_id not in hero_profiles.PROFILES:
        fail(f"Scene declares unknown hero_id: {hero_id}")
    profile = hero_profiles.PROFILES[hero_id]
    prefix = scene.get("hero_prefix", profile["prefix"])
    if prefix != profile["prefix"]:
        fail(f"Scene action prefix {prefix!r} does not match profile "
             f"{profile['prefix']!r}")

    rig = bpy.data.objects.get(profile["rig"])
    if rig is None or rig.type != "ARMATURE":
        fail(profile["rig"] + " armature is missing")
    missing = REQUIRED_BONES - set(rig.data.bones.keys())
    if missing:
        fail("Missing rig bones: " + ", ".join(sorted(missing)))
    if bpy.context.scene.camera is None:
        fail("Active camera is missing")
    if (bpy.context.scene.render.resolution_x != 256
            or bpy.context.scene.render.resolution_y != 256):
        fail("Source scene render resolution must be 256x256")
    if not bpy.context.scene.render.film_transparent:
        fail("Transparent film output must be enabled")

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if len(meshes) < hero_profiles.MIN_MESH_PARTS:
        fail(f"{hero_id}: expected detailed character mesh parts; found only "
             f"{len(meshes)} (minimum {hero_profiles.MIN_MESH_PARTS})")
    rigging_errors = []
    for obj in meshes:
        bone_name = obj.get("rig_bone")
        if obj.parent is not None:
            rigging_errors.append(f"{obj.name}: mesh object is still parented")
        if not isinstance(bone_name, str) or bone_name not in rig.data.bones:
            rigging_errors.append(f"{obj.name}: missing or invalid rig_bone binding")
            continue
        if not rig.data.bones[bone_name].use_deform:
            rigging_errors.append(f"{obj.name}: target bone {bone_name} is not deforming")

        armature_modifiers = [modifier for modifier in obj.modifiers
                              if modifier.type == "ARMATURE"]
        if len(armature_modifiers) != 1 or armature_modifiers[0].object is not rig:
            rigging_errors.append(
                f"{obj.name}: expected exactly one Armature modifier targeting {rig.name}")
        else:
            modifier = armature_modifiers[0]
            if not modifier.use_vertex_groups or modifier.use_bone_envelopes:
                rigging_errors.append(
                    f"{obj.name}: Armature modifier must use vertex groups, not envelopes")

        groups = list(obj.vertex_groups)
        if len(groups) != 1:
            rigging_errors.append(f"{obj.name}: expected exactly one vertex group, found {len(groups)}")
            continue
        group = groups[0]
        if group.name != bone_name:
            rigging_errors.append(
                f"{obj.name}: vertex group {group.name!r} does not match rig_bone {bone_name!r}")
            continue
        if not obj.data.vertices:
            rigging_errors.append(f"{obj.name}: mesh has no vertices to weight")
            continue
        for vertex in obj.data.vertices:
            memberships = [entry for entry in vertex.groups if entry.group == group.index]
            if len(memberships) != 1 or abs(memberships[0].weight - 1.0) > 1e-5:
                rigging_errors.append(
                    f"{obj.name}: vertex {vertex.index} is not weighted 1.0 to {bone_name}")
                break

    if rigging_errors:
        fail("Every mesh must be unparented and bound to one deform bone by exactly "
             "one 1.0-weight vertex group and one Armature modifier: " +
             "; ".join(rigging_errors[:12]))
    for part in profile["required_parts"]:
        obj = bpy.data.objects.get(part)
        if obj is None or obj.type != "MESH":
            fail(f"{hero_id}: signature mesh part missing: {part}")
        if obj.parent is not None or obj.get("rig_bone") not in rig.data.bones:
            fail(f"{hero_id}: signature part {part} must be unparented and carry a valid rig_bone binding")

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

    actions = set()
    for state, expected_range in ACTION_RANGES.items():
        action_name = f"{prefix}_{state}"
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
        actions.add(action.name)

    print("HERO_SOURCE_OK")
    print("hero_id=" + hero_id)
    print("mesh_parts=" + str(len(meshes)))
    print("bones=" + str(len(rig.data.bones)))
    print("actions=" + str(len(actions)))
    print("materials=" + str(len(material_names)))


if __name__ == "__main__":
    main()
