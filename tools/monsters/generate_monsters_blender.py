"""Generate four reference-directed, low-poly, rigged Archer FM monster prototypes.

Run with Blender 3.x or newer:
  blender -b -noaudio --python tools/monsters/generate_monsters_blender.py -- --output build/monster-glb

Visual authority: assets/references/approved_all/archer_fm_monsters_reference.png
Order-to-role mapping for this prototype:
  runner = green goblin (ordinary), stalker = skeleton (fast),
  tank = horned mace brute (heavy), ranged = purple masked infiltrator.
These are technical prototypes only; never mark them visually accepted without
side-by-side human review against the source image.
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
    # Green goblin sword wielder — ordinary enemy.
    "runner": {"body": (0.12,0.43,0.16,1), "accent": (0.34,0.72,0.22,1), "dark": (0.035,0.13,0.055,1), "eye": (1.0,0.82,0.28,1), "metal": (0.34,0.39,0.31,1)},
    # Horned, heavily armoured brute — heavy enemy.
    "tank": {"body": (0.24,0.20,0.17,1), "accent": (0.48,0.37,0.25,1), "dark": (0.07,0.065,0.06,1), "eye": (1.0,0.35,0.12,1), "metal": (0.62,0.55,0.42,1)},
    # Exposed bone and dark eye sockets — fast skeleton.
    "stalker": {"body": (0.78,0.75,0.63,1), "accent": (0.94,0.89,0.73,1), "dark": (0.09,0.075,0.07,1), "eye": (0.16,0.12,0.11,1), "metal": (0.48,0.49,0.52,1)},
    # Purple hood, face wrap and violet energy blades — infiltrator.
    "ranged": {"body": (0.20,0.08,0.34,1), "accent": (0.55,0.25,0.82,1), "dark": (0.055,0.025,0.095,1), "eye": (0.76,0.36,1.0,1), "metal": (0.35,0.22,0.48,1)},
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
    # Smooth organic forms (heads, eyes, limbs) so triangulation does not
    # dominate the small in-game silhouette. Keep armor/cubes crisp.
    if kind in ("sphere", "ico", "cylinder"):
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    obj.data.materials.append(mat)
    if bevel and kind=="cube":
        mod=obj.modifiers.new("Soft bevel","BEVEL"); mod.width=bevel; mod.segments=2
        # Keep the low-poly bevel shading deterministic across Blender 3.x/4.x;
        # Weighted Normal requires Auto Smooth and is unnecessary for these meshes.
    return bind(obj,rig,bone)

def bridge(name, start, end, diameter, mat, rig, bone):
    """Add a tapered-looking organic connector between two limb joints."""
    a=Vector(start); b=Vector(end); delta=b-a
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, location=(a+b)*0.5)
    obj=bpy.context.object; obj.name=name
    obj.dimensions=(diameter,diameter,delta.length+diameter*0.45)
    obj.rotation_mode="QUATERNION"
    obj.rotation_quaternion=delta.to_track_quat("Z","Y")
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons: polygon.use_smooth=True
    obj.data.materials.append(mat)
    return bind(obj,rig,bone)

def build(kind):
    clear_scene()
    p=PALETTES[kind]
    mats={k:material(kind+"_"+k,v,0.5 if k=="metal" else 0.0,0.5,2.0 if k=="eye" else (1.2 if k=="accent" and kind=="ranged" else 0.0)) for k,v in p.items()}
    rig=make_rig(kind)
    body_w={"runner":0.78,"tank":1.30,"stalker":0.72,"ranged":0.82}[kind]
    # A compact chibi silhouette: broad readable head, connected shoulders,
    # and a slightly tapered body. All face pieces sit on the forward (-Y) side.
    primitive("sphere",kind+"_torso",(0,0,1.10),(body_w,0.66 if kind=="tank" else 0.58,0.96),mats["body"],rig,"spine")
    primitive("sphere",kind+"_neck",(0,-0.015,1.52),(0.34,0.36,0.34),mats["body"],rig,"spine")
    primitive("sphere",kind+"_head",(0,-0.055,1.88),(0.84,0.70,0.78),mats["body"],rig,"head")
    primitive("sphere",kind+"_muzzle",(0,-0.365,1.66),(0.25,0.15,0.14),mats["accent"],rig,"head")
    primitive("sphere",kind+"_mouth",(0,-0.405,1.535),(0.15,0.035,0.045),mats["dark"],rig,"head")
    for side in (-1,1):
        primitive("sphere",kind+"_eye_"+str(side),(side*0.225,-0.365,1.98),(0.165,0.105,0.19),mats["eye"],rig,"head")
        primitive("sphere",kind+"_pupil_"+str(side),(side*0.225,-0.458,1.98),(0.066,0.035,0.105),mats["dark"],rig,"head")
        primitive("sphere",kind+"_brow_"+str(side),(side*0.225,-0.405,2.17),(0.17,0.045,0.055),mats["dark"],rig,"head")
        # Continuous tapered limbs: avoid stacked spherical joints at arena scale.
        bridge(kind+"_upperarm_bridge_"+str(side),(side*0.40,0,1.42),(side*0.47,0,1.13),0.29,mats["body"],rig,"upper_arm.L" if side<0 else "upper_arm.R")
        bridge(kind+"_forearm_bridge_"+str(side),(side*0.47,0,1.13),(side*0.56,-0.07,0.82),0.23,mats["body"],rig,"forearm.L" if side<0 else "forearm.R")
        primitive("sphere",kind+"_hand_"+str(side),(side*0.56,-0.07,0.80),(0.16,0.18,0.16),mats["accent"],rig,"forearm.L" if side<0 else "forearm.R")
        bridge(kind+"_thigh_bridge_"+str(side),(side*0.22,0,0.68),(side*0.22,0,0.43),0.34,mats["body"],rig,"thigh.L" if side<0 else "thigh.R")
        bridge(kind+"_shin_bridge_"+str(side),(side*0.22,0,0.43),(side*0.24,-0.09,0.13),0.25,mats["body"],rig,"shin.L" if side<0 else "shin.R")
        primitive("sphere",kind+"_boot_"+str(side),(side*0.24,-0.09,0.11),(0.21,0.30,0.15),mats["dark"],rig,"shin.L" if side<0 else "shin.R")

    if kind=="runner":
        # Green goblin: pointed ears, broad nose, one readable short sword.
        for side in (-1,1):
            ear=primitive("cone",kind+"_pointed_ear_"+str(side),(side*0.43,0.02,2.08),(0.18,0.15,0.38),mats["accent"],rig,"head")
            ear.rotation_euler[1]=side*-0.70
        primitive("sphere",kind+"_goblin_nose",(0,-0.49,1.77),(0.18,0.16,0.16),mats["accent"],rig,"head")
        primitive("cube",kind+"_sword_grip",(0.58,-0.08,0.88),(0.12,0.13,0.30),mats["dark"],rig,"forearm.R")
        primitive("cube",kind+"_sword_guard",(0.58,-0.10,1.06),(0.34,0.12,0.09),mats["metal"],rig,"forearm.R")
        primitive("cone",kind+"_single_sword",(0.58,-0.10,1.36),(0.12,0.12,0.40),mats["metal"],rig,"forearm.R")
        primitive("cube",kind+"_leather_tunic",(0,-0.34,1.12),(0.58,0.12,0.42),mats["dark"],rig,"spine")
        primitive("sphere",kind+"_belt",(0,-0.39,0.91),(0.52,0.08,0.10),mats["accent"],rig,"spine")
    elif kind=="tank":
        # Horned heavy brute with oversized spiked mace and layered armour.
        primitive("cube",kind+"_heavy_chestplate",(0,-0.36,1.18),(0.96,0.18,0.58),mats["metal"],rig,"spine",0.16)
        for side in (-1,1):
            horn=primitive("cone",kind+"_horn_"+str(side),(side*0.34,-0.02,2.28),(0.18,0.18,0.48),mats["accent"],rig,"head")
            horn.rotation_euler[1]=side*-0.55
            primitive("cube",kind+"_massive_shoulder_"+str(side),(side*0.55,-0.03,1.48),(0.52,0.48,0.38),mats["metal"],rig,"upper_arm.L" if side<0 else "upper_arm.R",0.12)
            primitive("cube",kind+"_arm_bracer_"+str(side),(side*0.59,-0.12,0.91),(0.42,0.40,0.34),mats["accent"],rig,"forearm.L" if side<0 else "forearm.R",0.08)
        primitive("sphere",kind+"_mace_head",(0.80,-0.10,1.03),(0.52,0.52,0.52),mats["metal"],rig,"forearm.R")
        primitive("cylinder",kind+"_mace_handle",(0.68,-0.08,0.66),(0.095,0.095,0.62),mats["dark"],rig,"forearm.R")
        for i in range(8):
            a=i*math.pi/4
            spike=primitive("cone",kind+"_mace_spike_"+str(i),(0.80+math.cos(a)*0.40,-0.10,1.03+math.sin(a)*0.40),(0.11,0.11,0.23),mats["accent"],rig,"forearm.R")
            spike.rotation_euler[1]=a
    elif kind=="stalker":
        # Fast skeleton: exposed ivory skull, rib cage and paired short blades.
        primitive("sphere",kind+"_skull",(0,-0.08,1.94),(0.72,0.62,0.68),mats["accent"],rig,"head")
        primitive("sphere",kind+"_eye_socket_L",(-0.20,-0.405,2.00),(0.19,0.09,0.22),mats["dark"],rig,"head")
        primitive("sphere",kind+"_eye_socket_R",(0.20,-0.405,2.00),(0.19,0.09,0.22),mats["dark"],rig,"head")
        primitive("sphere",kind+"_jaw",(0,-0.36,1.69),(0.38,0.18,0.16),mats["body"],rig,"head")
        for rib in range(4):
            z=1.30-rib*0.13
            primitive("sphere",kind+"_rib_"+str(rib),(0,-0.34,z),(0.48-rib*0.035,0.09,0.07),mats["accent"],rig,"spine")
        primitive("sphere",kind+"_pelvis_bone",(0,-0.28,0.78),(0.48,0.16,0.20),mats["accent"],rig,"root")
        for side in (-1,1):
            blade=primitive("cone",kind+"_dual_blade_"+str(side),(side*0.70,-0.10,0.92),(0.12,0.12,0.50),mats["metal"],rig,"forearm.L" if side<0 else "forearm.R")
            blade.rotation_euler[1]=math.pi
            primitive("sphere",kind+"_wrist_bone_"+str(side),(side*0.53,-0.06,0.88),(0.13,0.13,0.14),mats["accent"],rig,"forearm.L" if side<0 else "forearm.R")
    elif kind=="ranged":
        # Purple infiltrator: deep hood, face wrap and twin violet energy blades.
        primitive("sphere",kind+"_hood_shell",(0,0.16,1.96),(1.02,0.52,0.96),mats["dark"],rig,"head")
        primitive("sphere",kind+"_hood_crown",(0,0.18,2.34),(0.70,0.46,0.34),mats["body"],rig,"head")
        primitive("cube",kind+"_face_mask",(0,-0.43,1.78),(0.62,0.12,0.30),mats["dark"],rig,"head",0.08)
        for side in (-1,1):
            primitive("sphere",kind+"_violet_eye_"+str(side),(side*0.21,-0.505,1.99),(0.10,0.045,0.075),mats["eye"],rig,"head")
            blade=primitive("cone",kind+"_violet_energy_blade_"+str(side),(side*0.70,-0.12,1.06),(0.105,0.105,0.62),mats["accent"],rig,"forearm.L" if side<0 else "forearm.R")
            blade.rotation_euler[1]=math.pi
            primitive("cube",kind+"_blade_guard_"+str(side),(side*0.70,-0.12,0.77),(0.30,0.10,0.10),mats["metal"],rig,"forearm.L" if side<0 else "forearm.R",0.04)
        primitive("cone",kind+"_hood_cloak",(0,0.25,0.94),(0.52,0.48,0.84),mats["body"],rig,"spine")
        primitive("sphere",kind+"_cloak_trim",(0,-0.34,1.35),(0.56,0.09,0.12),mats["accent"],rig,"spine")
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

    # Preview rendering is opt-in because headless Blender builds on CI can
    # abort inside the render backend. GLB export/validation must not depend on
    # a display or GPU renderer. Enable locally with ARCHER_MONSTER_PREVIEWS=1.
    if os.environ.get("ARCHER_MONSTER_PREVIEWS") == "1":
        # Produce a consistent front three-quarter preview for human art review.
        # Camera/light objects are added only after the GLB export, so they never
        # become part of the runtime model.
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.object.camera_add(location=(2.0, -8.2, 3.0))
        camera=bpy.context.object
        camera.name=kind+"_PreviewCamera"
        camera.rotation_euler=(Vector((0,-0.02,1.28))-camera.location).to_track_quat("-Z","Y").to_euler()
        scene.camera=camera
        bpy.ops.object.light_add(type="AREA", location=(-3.5,-4.5,5.5))
        key=bpy.context.object; key.data.energy=520; key.data.shape="DISK"; key.data.size=4.0
        bpy.ops.object.light_add(type="AREA", location=(3.0,1.5,3.6))
        fill=bpy.context.object; fill.data.energy=260; fill.data.size=3.0
        scene.render.engine="BLENDER_WORKBENCH"
        scene.display.shading.light="STUDIO"
        scene.display.shading.color_type="MATERIAL"
        # Render clean solid surfaces: wire overlays hide the face and material
        # separation that must be judged in the approval preview.
        # Blender 3.0 (Ubuntu runner) and newer releases expose slightly
        # different shading property names. Set only properties available in
        # the installed build so preview rendering cannot abort GLB export.
        shading = scene.display.shading
        for property_name in ("show_wireframe", "show_wireframes",
                              "show_object_outline", "show_cavity"):
            if hasattr(shading, property_name):
                setattr(shading, property_name, False)
        if hasattr(shading, "show_shadows"):
            shading.show_shadows = True
        scene.render.resolution_x=768; scene.render.resolution_y=768
        scene.render.resolution_percentage=100
        scene.camera.data.lens=58
        scene.render.image_settings.file_format="PNG"
        scene.render.film_transparent=False
        scene.world.color=(0.055,0.065,0.085)
        scene.view_settings.view_transform="Standard"
        preview_dir=os.path.join(OUT,"previews")
        os.makedirs(preview_dir,exist_ok=True)
        scene.render.filepath=os.path.join(preview_dir,kind+".png")
        bpy.ops.render.render(write_still=True)
    

def main():
    manifest={"schemaVersion":1,"units":"meters","coordinateSystem":"Blender Z-up exported as glTF Y-up","monsters":{}}
    for kind in REQUIRED:
        os.makedirs(os.path.join(OUT,kind),exist_ok=True)
        build(kind)
        clips={state.lower():kind+"_"+state for state in REQUIRED[kind]}
        entry={"file":kind+"/monster.glb","scale":1.0,"forward":"-Y","groundOffset":[0,0,0],"clips":clips}
        if kind=="ranged": entry["events"]={"projectileRelease":0.58}
        manifest["monsters"][kind]=entry
    with open(os.path.join(OUT,"manifest.json"),"w",encoding="utf-8") as f:
        json.dump(manifest,f,ensure_ascii=False,indent=2)
    print("Generated four rigged monster GLBs and manifest at",OUT)

if __name__=="__main__":
    main()
