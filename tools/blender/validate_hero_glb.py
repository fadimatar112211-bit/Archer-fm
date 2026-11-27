#!/usr/bin/env python3
"""Import and validate a hero GLB: real mesh, skin, rig and eight distinct clips."""
import argparse,re,sys
from pathlib import Path
import bpy

def main():
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    p=argparse.ArgumentParser()
    p.add_argument("--hero",required=True,choices=("ranger","flame","shadow","storm"))
    p.add_argument("--model",required=True)
    a=p.parse_args(argv)
    model=Path(a.model).resolve()
    if not model.is_file() or model.stat().st_size<100_000:
        raise RuntimeError(f"{a.hero}: missing or suspiciously small GLB {model}")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(model))
    rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if not rigs or not meshes:
        raise RuntimeError(f"{a.hero}: GLB must contain both armature and mesh objects")
    rig=rigs[0]
    if len(rig.data.bones)<15:
        raise RuntimeError(f"{a.hero}: rig has only {len(rig.data.bones)} bones")
    skinned=[o for o in meshes if any(m.type=="ARMATURE" and m.object==rig for m in o.modifiers)]
    if not skinned:
        raise RuntimeError(f"{a.hero}: no mesh is skinned to imported armature")
    names=[re.sub(r"[^a-z]","",x.name.lower()) for x in bpy.data.actions]
    states=("idle","walk","run","attack","skill","dodge","hit","death")
    missing=[s for s in states if not any(s in n for n in names)]
    if missing:
        raise RuntimeError(f"{a.hero}: GLB is missing animation clips {missing}; imported={names}")
    matched={s:next(n for n in names if s in n) for s in states}
    if len(set(matched.values()))!=8:
        raise RuntimeError(f"{a.hero}: clips are not eight distinct animations: {matched}")
    print(f"HERO_GLB_VALID hero={a.hero} meshes={len(meshes)} bones={len(rig.data.bones)} skinned_meshes={len(skinned)} actions={len(bpy.data.actions)} matched={matched}")

if __name__=="__main__":
    try: main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
