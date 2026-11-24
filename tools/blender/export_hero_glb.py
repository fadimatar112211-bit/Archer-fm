#!/usr/bin/env python3
"""Export one authored hero Blender scene as a rigged, animated GLB."""
import argparse
import json
import sys
from pathlib import Path
import bpy

def args():
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    p=argparse.ArgumentParser()
    p.add_argument("--hero",required=True,choices=("ranger","flame","shadow"))
    p.add_argument("--config",required=True)
    return p.parse_args(argv)

def main():
    a=args()
    root=Path(__file__).resolve().parents[2]
    cfg=json.loads(Path(a.config).read_text(encoding="utf-8"))
    hero=cfg["heroes"][a.hero]
    armature=bpy.data.objects.get(hero["armature_object"])
    if armature is None or armature.type!="ARMATURE":
        raise RuntimeError(f"{a.hero}: missing rig {hero['armature_object']}")
    mesh_objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if not mesh_objects:
        raise RuntimeError(f"{a.hero}: no meshes in source scene")
    armature.animation_data_create()
    armature.animation_data.action=None
    for track in list(armature.animation_data.nla_tracks):
        armature.animation_data.nla_tracks.remove(track)
    required=("idle","walk","run","attack","skill","dodge","hit","death")
    for state in required:
        name=hero["actions"].get(state)
        action=bpy.data.actions.get(name)
        if action is None:
            raise RuntimeError(f"{a.hero}: missing animation action {name}")
        start,end=map(float,action.frame_range)
        if end<=start:
            raise RuntimeError(f"{a.hero}: invalid action range for {name}")
        track=armature.animation_data.nla_tracks.new()
        track.name=f"{a.hero}_{state}"
        strip=track.strips.new(f"{a.hero}_{state}",int(start),action)
        strip.action_frame_start=start
        strip.action_frame_end=end
        strip.blend_type="REPLACE"
        strip.extrapolation="NOTHING"
        strip.use_sync_length=True
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for obj in mesh_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=armature
    out=root/f"assets/heroes/{a.hero}/model/{a.hero}_animated.glb"
    out.parent.mkdir(parents=True,exist_ok=True)
    result=bpy.ops.export_scene.gltf(
        filepath=str(out),export_format="GLB",use_selection=True,
        export_animations=True,export_nla_strips=True,
        export_force_sampling=True,export_skins=True,
        export_materials="EXPORT",export_image_format="AUTO",
        export_yup=True,export_apply=False,export_texcoords=True,
        export_normals=True,export_tangents=True,export_colors=True,
        export_frame_range=False,export_current_frame=False)
    if "FINISHED" not in result or not out.is_file() or out.stat().st_size<100_000:
        raise RuntimeError(f"{a.hero}: GLB export failed or output too small: {result}")
    print(f"HERO_GLB_EXPORTED hero={a.hero} path={out.relative_to(root)} bytes={out.stat().st_size} meshes={len(mesh_objects)} bones={len(armature.data.bones)} actions={len(required)}")

if __name__=="__main__":
    try: main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
