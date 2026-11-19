"""Generate four original, low-poly, rigged Archer FM monster GLBs.

Run with Blender 3.x or newer:
  blender -b -noaudio --python tools/monsters/generate_monsters_blender.py -- --output build/monster-glb

The models are procedural production prototypes, not replacements for final art
approval. They include distinct silhouettes, face details, weapons, skinning,
and named gameplay animation clips. No external assets or paid services.
"""
import bpy
import math
import json
import os
import sys
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = "build/monster-glb"
if "--output" in ARGS:
    OUT = ARGS[ARGS.index("--output") + 1]
os.makedirs(OUT, exist_ok=True)

PALETTES = {
    "runner": {"body": (0.82,0.22,0.055,1), "accent": (1.0,0.62,0.16,1), "dark": (0.20,0.07,0.035,1), "eye": (1.0,0.92,0.56,1), "metal": (0.42,0.28,0.12,1)},
    "tank": {"body": (0.25,0.16,0.10,1), "accent": (0.72,0.48,0.22,1), "dark": (0.10,0.075,0.055,1), "eye": (1.0,0.48,0.12,1), "metal": (0.72,0.58,0.36,1)},
    "stalker": {"body": (0.20,0.11,0.38,1), "accent": (0.62,0.43,0.92,1), "dark": (0.055,0.035,0.10,1), "eye": (0.72,0.95,1.0,1), "metal": (0.55,0.45,0.72,1)},
    "ranged": {"body": (0.055,0.30,0.34,1), "accent": (0.30,0.82,0.88,1), "dark": (0.025,0.10,0.14,1), "eye": (0.70,1.0,0.95,1), "metal": (0.58,0.76,0.72,1)},
}
REQUIRED = {
    "runner": ["Idle","Walk","Run","Attack","Hit","Death"],
    "tank": ["Idle","Walk","Attack","Hit","Death"],
    "stalker": ["Idle","Walk","Attack","Hit","Death"],
    "ranged": ["Idle","Walk","Attack","Cast","Release","Hit","Death"],
}

def material(name, rgba, metallic=0.0, roughness=0.72, emission=0.0):
    m=bpy.data.materials.new(name); m.diffuse_color=rgba
    m.use_nodes=True
    bs=m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value=rgba
    bs.inputs["Metallic"].default_value=metallic
    bs.inputs["Roughness"].default_value=roughness
    if emission:
        # Blender 3.x calls this socket "Emission"; Blender 4.x renamed it.
        emission_color = bs.inputs.get("Emission Color") or bs.inputs.get("Emission")
        if emission_color is not None:
            emission_color.default_value=rgba
        emission_strength = bs.inputs.get("Emission Strength")
        if emission_strength is not None:
            emission_strength.default_value=emission
    return m

def clear_scene():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.actions, bpy.data.armatures, bpy.data.meshes):
        for item in list(datablocks): datablocks.remove(item)

def make_rig(name):
    data=bpy.data.armatures.new(name+"_Skeleton")
    rig=bpy.data.objects.new(name+"_Rig",data); bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig; rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones={
      "root":((0,0,0),(0,0,0.72),None),
      "spine":((0,0,0.72),(0,0,1.55),"root"),
      "head":((0,0,1.55),(0,0,2.05),"spine"),
      "upper_arm.L":((0,0,1.40),(-0.42,0,1.12),"spine"),
      "forearm.L":((-0.42,0,1.12),(-0.55,-0.02,0.88),"upper_arm.L"),
      "upper_arm.R":((0,0,1.40),(0.42,0,1.12),"spine"),
      "forearm.R":((0.42,0,1.12),(0.55,-0.02,0.88),"upper_arm.R"),
      "thigh.L":((0,0,0.72),(-0.22,0,0.40),"root"),
      "shin.L":((-0.22,0,0.40),(-0.24,-0.04,0.10),"thigh.L"),
      "thigh.R":((0,0,0.72),(0.22,0,0.40),"root"),
      "shin.R":((0.22,0,0.40),(0.24,-0.04,0.10),"thigh.R"),
    }
    for n,(h,t,parent) in bones.items():
        b=data.edit_bones.new(n); b.head=h; b.tail=t
        if parent: b.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT"); rig.select_set(False)
    return rig

def bind(obj, rig, bone):
    obj.parent=rig
    mod=obj.modifiers.new("Armature","ARMATURE"); mod.object=rig
    vg=obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))),1.0,"REPLACE")
    return obj

def primitive(kind, name, loc, scale, mat, rig, bone, bevel=0.0):
    if kind=="sphere": bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, location=loc)
    elif kind=="cube": bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind=="cone": bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=scale[0], radius2=0.0, depth=scale[2]*2, location=loc)
    elif kind=="cylinder": bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=scale[0], depth=scale[2]*2, location=loc)
    elif kind=="ico": bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=loc)
    obj=bpy.context.object; obj.name=name
    obj.dimensions=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel and kind=="cube":
        mod=obj.modifiers.new("Soft bevel","BEVEL"); mod.width=bevel; mod.segments=2
        # Keep the low-poly bevel shading deterministic across Blender 3.x/4.x;
        # Weighted Normal requires Auto Smooth and is unnecessary for these meshes.
    return bind(obj,rig,bone)

def build(kind):
    clear_scene()
    p=PALETTES[kind]
    mats={k:material(kind+"_"+k,v,0.5 if k=="metal" else 0.0,0.5,2.0 if k=="eye" else (1.2 if k=="accent" and kind=="ranged" else 0.0)) for k,v in p.items()}
    rig=make_rig(kind)
    body_w={"runner":0.72,"tank":1.22,"stalker":0.72,"ranged":0.78}[kind]
    primitive("sphere",kind+"_torso",(0,0,1.12),(body_w,0.52,0.92),mats["body"],rig,"spine")
    primitive("sphere",kind+"_head",(0,-0.025,1.82),(0.70,0.62,0.68),mats["body"],rig,"head")
    # Face is on -Y, toward the gameplay camera.
    primitive("sphere",kind+"_muzzle",(0,-0.315,1.67),(0.34,0.24,0.22),mats["accent"],rig,"head")
    for side in (-1,1):
        primitive("sphere",kind+"_eye_"+str(side),(side*0.19,-0.325,1.91),(0.14,0.09,0.17),mats["eye"],rig,"head")
        primitive("sphere",kind+"_pupil_"+str(side),(side*0.19,-0.402,1.91),(0.055,0.035,0.09),mats["dark"],rig,"head")
        primitive("sphere",kind+"_shoulder_"+str(side),(side*0.42,0,1.39),(0.35,0.42,0.34),mats["accent"] if kind=="tank" else mats["body"],rig,"upper_arm.L" if side<0 else "upper_arm.R")
        primitive("cylinder",kind+"_upperarm_"+str(side),(side*0.47,0,1.13),(0.16,0.16,0.31),mats["body"],rig,"upper_arm.L" if side<0 else "upper_arm.R")
        primitive("sphere",kind+"_hand_"+str(side),(side*0.55,-0.02,0.88),(0.23,0.22,0.22),mats["accent"],rig,"forearm.L" if side<0 else "forearm.R")
        primitive("cylinder",kind+"_thigh_"+str(side),(side*0.22,0,0.48),(0.18,0.18,0.31),mats["body"],rig,"thigh.L" if side<0 else "thigh.R")
        primitive("sphere",kind+"_boot_"+str(side),(side*0.24,-0.09,0.12),(0.25,0.38,0.18),mats["dark"],rig,"shin.L" if side<0 else "shin.R")
    if kind=="runner":
        # Swept ears/scarf and light twin short blades.
        for s in (-1,1):
            ear=primitive("cone",kind+"_ear_"+str(s),(s*0.30,0.02,2.25),(0.13,0.13,0.36),mats["accent"],rig,"head")
            ear.rotation_euler[1]=s*-0.42
        for s in (-1,1):
            blade=primitive("cone",kind+"_dagger_"+str(s),(s*0.62,-0.08,0.92),(0.075,0.075,0.34),mats["metal"],rig,"forearm.L" if s<0 else "forearm.R")
            blade.rotation_euler[1]=math.pi
        primitive("cube",kind+"_scarf",(0,0.18,1.38),(0.24,0.66,0.16),mats["accent"],rig,"spine")
    elif kind=="tank":
        primitive("cube",kind+"_chestplate",(0,-0.28,1.18),(0.88,0.16,0.66),mats["metal"],rig,"spine",0.10)
        for s in (-1,1):
            primitive("cube",kind+"_shoulder_plate_"+str(s),(s*0.48,-0.02,1.52),(0.50,0.55,0.28),mats["metal"],rig,"upper_arm.L" if s<0 else "upper_arm.R",0.08)
            primitive("cube",kind+"_gauntlet_"+str(s),(s*0.57,-0.11,0.88),(0.35,0.36,0.28),mats["accent"],rig,"forearm.L" if s<0 else "forearm.R",0.06)
        primitive("cone",kind+"_helmet_spike",(0,0,2.25),(0.17,0.17,0.34),mats["metal"],rig,"head")
    elif kind=="stalker":
        primitive("cone",kind+"_hood",(0,0.02,2.12),(0.48,0.50,0.55),mats["dark"],rig,"head")
        for s in (-1,1):
            blade=primitive("cone",kind+"_short_blade_"+str(s),(s*0.70,-0.04,0.91),(0.09,0.09,0.39),mats["metal"],rig,"forearm.L" if s<0 else "forearm.R")
            blade.rotation_euler[1]=math.pi
        primitive("cube",kind+"_cloak",(0,0.26,1.10),(0.72,0.20,0.86),mats["dark"],rig,"spine",0.08)
    elif kind=="ranged":
        primitive("cone",kind+"_hood",(0,0.02,2.10),(0.46,0.48,0.55),mats["dark"],rig,"head")
        primitive("cylinder",kind+"_staff",(0.72,0.02,1.15),(0.055,0.055,0.88),mats["metal"],rig,"forearm.R")
        primitive("ico",kind+"_fire_orb",(0.72,-0.01,2.10),(0.30,0.30,0.30),mats["eye"],rig,"forearm.R")
        primitive("cube",kind+"_robe",(0,0.20,0.88),(0.78,0.55,0.70),mats["body"],rig,"spine",0.12)
    # Ensure GLB exporter sees the rig and meshes, with no camera/light clutter.
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in bpy.context.scene.objects:
        if obj.type=="MESH": obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    # One NLA strip per named gameplay clip.
    scene=bpy.context.scene
    for clip in REQUIRED[kind]:
        action=bpy.data.actions.new(kind+"_"+clip)
        rig.animation_data_create()
        rig.animation_data.action=action
        scene.frame_start=1; scene.frame_end=24
        poses={
          "Idle": [(1,0.0),(12,0.025),(24,0.0)],
          "Walk": [(1,-0.28),(7,0.28),(13,-0.28),(19,0.28),(24,-0.28)],
          "Run": [(1,-0.48),(5,0.48),(9,-0.48),(13,0.48),(17,-0.48),(21,0.48),(24,-0.48)],
          "Attack": [(1,0.0),(8,-0.72),(13,0.30),(18,0.0),(24,0.0)],
          "Cast": [(1,0.0),(9,-0.40),(16,0.40),(24,0.0)],
          "Release": [(1,0.0),(7,0.75),(12,-0.25),(18,0.0),(24,0.0)],
          "Hit": [(1,0.0),(5,0.55),(12,0.0),(24,0.0)],
          "Death": [(1,0.0),(8,0.55),(16,1.15),(24,1.35)],
        }[clip]
        for bone_name in ("spine","head","upper_arm.L","upper_arm.R","forearm.L","forearm.R","thigh.L","thigh.R"):
            pb=rig.pose.bones[bone_name]
            for frame,angle in poses:
                factor=1.0
                if bone_name=="head": factor=-0.25
                elif bone_name.startswith("upper_arm"): factor=1.0 if bone_name.endswith("R") else -1.0
                elif bone_name.startswith("forearm"): factor=0.65 if bone_name.endswith("R") else -0.65
                elif bone_name.startswith("thigh"): factor=0.85 if bone_name.endswith("R") else -0.85
                pb.rotation_mode="XYZ"
                pb.rotation_euler[0]=angle*factor
                pb.keyframe_insert(data_path="rotation_euler",frame=frame,group=bone_name)
        # Locomotion bob and death collapse via root/spine.
        for frame,offset in ([(1,0.0),(7,0.045),(13,0.0),(19,0.045),(24,0.0)] if clip in ("Walk","Run") else [(1,0.0),(24,0.0)]):
            rig.pose.bones["root"].location=(0,0,offset)
            rig.pose.bones["root"].keyframe_insert(data_path="location",frame=frame,group="root")
        if clip=="Death":
            for frame,angle in ((1,0.0),(8,0.35),(16,1.1),(24,1.35)):
                rig.pose.bones["root"].rotation_euler[1]=angle
                rig.pose.bones["root"].keyframe_insert(data_path="rotation_euler",frame=frame,group="root")
        track=rig.animation_data.nla_tracks.new(); track.name=clip
        strip=track.strips.new(clip,1,action)
        strip.action=action
        rig.animation_data.action=None
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT,kind,"monster.glb"),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_nla_strips=True,
        export_skins=True,
        export_materials="EXPORT",
        export_apply=True,
    )

def main():
    manifest={"schemaVersion":1,"units":"meters","coordinateSystem":"Blender Z-up exported as glTF Y-up","monsters":{}}
    for kind in REQUIRED:
        os.makedirs(os.path.join(OUT,kind),exist_ok=True)
        build(kind)
        clips={state.lower():state for state in REQUIRED[kind]}
        entry={"file":kind+"/monster.glb","scale":1.0,"forward":"-Y","groundOffset":[0,0,0],"clips":clips}
        if kind=="ranged": entry["events"]={"projectileRelease":0.58}
        manifest["monsters"][kind]=entry
    with open(os.path.join(OUT,"manifest.json"),"w",encoding="utf-8") as f:
        json.dump(manifest,f,ensure_ascii=False,indent=2)
    print("Generated four rigged monster GLBs and manifest at",OUT)

if __name__=="__main__":
    main()
