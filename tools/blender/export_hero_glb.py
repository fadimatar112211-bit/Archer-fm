#!/usr/bin/env python3
"""Export one authored hero Blender scene as a rigged, animated GLB."""
import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--hero", required=True, choices=("ranger", "flame", "shadow"))
    parser.add_argument("--config", required=True)
    return parser.parse_args(argv)


def _segment_distance_sq(point, start, end):
    segment = end - start
    length_sq = segment.length_squared
    if length_sq <= 1e-12:
        return (point - start).length_squared
    factor = max(0.0, min(1.0, (point - start).dot(segment) / length_sq))
    return (point - (start + factor * segment)).length_squared


def _rigid_bind_mesh(mesh, armature):
    """Fallback for separate armor/effect meshes that cannot receive auto weights."""
    for group in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(group)
    bones = list(armature.data.bones)
    if not bones:
        raise RuntimeError(f"{mesh.name}: cannot bind to an empty armature")
    bone_segments = [(bone.name, bone.head_local.copy(), bone.tail_local.copy())
                     for bone in bones]
    groups = {name: mesh.vertex_groups.new(name=name) for name, _, _ in bone_segments}
    buckets = {name: [] for name, _, _ in bone_segments}
    world_to_armature = armature.matrix_world.inverted()
    for vertex in mesh.data.vertices:
        point = world_to_armature @ (mesh.matrix_world @ vertex.co)
        bone_name = min(
            bone_segments,
            key=lambda item: _segment_distance_sq(point, item[1], item[2])
        )[0]
        buckets[bone_name].append(vertex.index)
    for bone_name, indices in buckets.items():
        if indices:
            groups[bone_name].add(indices, 1.0, "REPLACE")
    modifier = next((m for m in mesh.modifiers
                     if m.type == "ARMATURE" and m.object == armature), None)
    if modifier is None:
        modifier = mesh.modifiers.new(name=f"{armature.name}_Skin", type="ARMATURE")
        modifier.object = armature
    mesh.parent = armature
    mesh.matrix_parent_inverse = armature.matrix_world.inverted()


def bind_meshes(mesh_objects, armature, hero):
    """Keep existing skinning; auto-weight unbound meshes, then rigid-bind tiny parts."""
    bound = []
    for mesh in mesh_objects:
        has_skin = any(mod.type == "ARMATURE" and mod.object == armature
                       for mod in mesh.modifiers)
        if not has_skin:
            try:
                bpy.ops.object.select_all(action="DESELECT")
                mesh.select_set(True)
                armature.select_set(True)
                bpy.context.view_layer.objects.active = armature
                bpy.ops.object.parent_set(type="ARMATURE_AUTO")
            except Exception as exc:
                print(f"{hero}: auto-weight failed for {mesh.name}: {exc}")
        has_skin = any(mod.type == "ARMATURE" and mod.object == armature
                       for mod in mesh.modifiers)
        if not has_skin:
            _rigid_bind_mesh(mesh, armature)
            print(f"{hero}: rigid bone binding fallback applied to {mesh.name}")
        if not any(mod.type == "ARMATURE" and mod.object == armature
                   for mod in mesh.modifiers):
            raise RuntimeError(f"{hero}: failed to bind mesh {mesh.name} to armature")
        if not mesh.parent or mesh.parent != armature:
            mesh.parent = armature
        bound.append(mesh)
    print(f"{hero}: SKIN_BINDING_OK meshes={len(bound)}")


def main():
    a = args()
    root = Path(__file__).resolve().parents[2]
    cfg = json.loads(Path(a.config).read_text(encoding="utf-8"))
    hero = cfg["heroes"][a.hero]
    armature = bpy.data.objects.get(hero["armature_object"])
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError(f"{a.hero}: missing rig {hero['armature_object']}")
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not mesh_objects:
        raise RuntimeError(f"{a.hero}: no meshes in source scene")

    bind_meshes(mesh_objects, armature, a.hero)

    armature.animation_data_create()
    armature.animation_data.action = None
    for track in list(armature.animation_data.nla_tracks):
        armature.animation_data.nla_tracks.remove(track)
    states = ("idle", "walk", "run", "attack", "skill", "dodge", "hit", "death")
    for state in states:
        name = hero["actions"].get(state)
        action = bpy.data.actions.get(name)
        if action is None:
            raise RuntimeError(f"{a.hero}: missing animation action {name}")
        start, end = map(float, action.frame_range)
        if end <= start:
            raise RuntimeError(f"{a.hero}: invalid action range for {name}")
        track = armature.animation_data.nla_tracks.new()
        track.name = f"{a.hero}_{state}"
        strip = track.strips.new(f"{a.hero}_{state}", int(start), action)
        strip.action_frame_start = start
        strip.action_frame_end = end
        strip.blend_type = "REPLACE"
        strip.extrapolation = "NOTHING"
        strip.use_sync_length = True

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for obj in mesh_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature

    out = root / f"assets/heroes/{a.hero}/model/{a.hero}_animated.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    export_options = {
        "filepath": str(out), "export_format": "GLB", "use_selection": True,
        "export_animations": True, "export_nla_strips": True,
        "export_force_sampling": True, "export_skins": True,
        "export_materials": "EXPORT", "export_image_format": "AUTO",
        "export_yup": True, "export_apply": False, "export_texcoords": True,
        "export_normals": True, "export_tangents": True,
        "export_frame_range": False, "export_current_frame": False,
    }
    operator = bpy.ops.export_scene.gltf
    supported = set(operator.get_rna_type().properties.keys())
    required_options = {"filepath", "export_format", "use_selection",
                        "export_animations", "export_nla_strips", "export_skins"}
    missing = required_options - supported
    if missing:
        raise RuntimeError(
            f"Blender glTF exporter is missing required options: {sorted(missing)}"
        )
    ignored = sorted(set(export_options) - supported)
    if ignored:
        print(f"GLTF_EXPORT_OPTIONS_UNAVAILABLE {ignored}")
    result = operator(**{key: value for key, value in export_options.items()
                         if key in supported})
    if "FINISHED" not in result or not out.is_file() or out.stat().st_size < 100_000:
        raise RuntimeError(f"{a.hero}: GLB export failed or output too small: {result}")
    print(
        f"HERO_GLB_EXPORTED hero={a.hero} path={out.relative_to(root)} "
        f"bytes={out.stat().st_size} meshes={len(mesh_objects)} "
        f"bones={len(armature.data.bones)} expected_actions={len(states)}"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
