# Rigs the ORIGINAL uploaded Storm model (assets/heroes/storm/storm.glb — a
# static Tripo-generated GLB: one mesh, embedded textures, no skeleton, no
# animations) onto the house 30-bone rig with the 8 house Storm_* actions,
# then exports the playable, skinned, animated storm_animated.glb.
#
# The original file is never modified. This script only consumes it:
#   1. opens the house source (Storm_Armature, 30 bones, 8 actions),
#   2. removes the house placeholder meshes,
#   3. imports the original storm.glb mesh (its own textures ride along),
#   4. normalizes it to the house convention: standing on z=0, ~0.92 m tall,
#      front facing -Y (the convention every shipped hero uses),
#   5. decimates the 273k-vert / 500k-tri AI mesh down to the house budget
#      (~28k verts) so the CPU-skinned renderer holds 60 fps on the phone,
#   6. binds it rigidly (1.0 weight, flame-style) to the NEAREST of the 20
#      core body bones — overlay bones (aura/bow/fx/cloak/quiver/root) are
#      excluded so no body region ever follows an internal effect bone,
#   7. exports the skinned + animated GLB with the shared export options.
#
# Usage:
#   blender -b assets/heroes/storm/source/storm_source.blend \
#     --python tools/blender_rig_original_storm.py -- \
#     /root/projects/Archer-fm/assets/heroes/storm/storm.glb \
#     assets/heroes/storm/model/storm_animated.glb

import bpy
import sys

argv = sys.argv[sys.argv.index('--') + 1:]
original_glb = argv[0]
dst = argv[1]

TARGET_VERTS = 18000  # collapse decimate lands at ~1.55x this in verts

# Bones a body surface may follow. The rig's overlay bones (aura ring, bow,
# string, fx, cloak, quiver) drive effect props; body vertices must never
# bind to them or the idle aura pulse would wobble the whole torso.
CORE_BONES = {
    'hips', 'spine', 'chest', 'neck', 'head',
    'shoulder.L', 'upper_arm.L', 'forearm.L', 'hand.L',
    'shoulder.R', 'upper_arm.R', 'forearm.R', 'hand.R',
    'thigh.L', 'shin.L', 'foot.L',
    'thigh.R', 'shin.R', 'foot.R',
}

# ---------------------------------------------------------------------------
# 1. house source: keep the rig + actions, drop the placeholder meshes
# ---------------------------------------------------------------------------
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    bpy.data.objects.remove(o, do_unlink=True)
arm_obj = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
print('HOUSE ARMATURE:', arm_obj.name, len(arm_obj.data.bones), 'bones',
      len(bpy.data.actions), 'actions')

# Force the rest pose for binding AND export; the saved actions are untouched.
arm_obj.data.pose_position = 'REST'
for pb in arm_obj.pose.bones:
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
    pb.scale = (1, 1, 1)
bpy.context.view_layer.update()

# ---------------------------------------------------------------------------
# 2. import the original storm.glb
# ---------------------------------------------------------------------------
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=original_glb)
imported = [o for o in set(bpy.data.objects) - before if o.type == 'MESH']
assert len(imported) == 1, f'expected 1 imported mesh, got {imported}'
mesh_obj = imported[0]
print('IMPORTED:', mesh_obj.name, len(mesh_obj.data.vertices), 'verts',
      len(mesh_obj.data.polygons), 'polys')

bpy.ops.object.select_all(action='DESELECT')
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# ---------------------------------------------------------------------------
# 3. normalize into the RIG's frame: feet on the rig's lowest sole, head at
#    the rig's highest bone tip, front facing -Y
# ---------------------------------------------------------------------------
# Tripo characters are authored Y-up facing +Z; the glTF importer maps that
# to Blender -Y — already the house convention (-Y), so NO flip is applied.
# (Verified by the south-facing in-game capture showing the face.)
#
# bpy.ops.object.select_all(action='DESELECT')
# mesh_obj.select_set(True)
# bpy.context.view_layer.objects.active = mesh_obj
# mesh_obj.rotation_euler = (0, 0, 3.141592653589793)
# bpy.ops.object.transform_apply(rotation=True)

rig_bones = [b for b in arm_obj.data.bones if b.name in CORE_BONES]
rig_min_z = min(min(b.head_local.z, b.tail_local.z) for b in rig_bones)
rig_max_z = max(max(b.head_local.z, b.tail_local.z) for b in rig_bones)
print('RIG FRAME: z', round(rig_min_z, 3), '..', round(rig_max_z, 3))

bb = [v.co for v in mesh_obj.data.vertices]
minz = min(v.z for v in bb)
maxz = max(v.z for v in bb)
scale = (rig_max_z - rig_min_z) / (maxz - minz)
bpy.ops.object.select_all(action='DESELECT')
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
mesh_obj.scale = (scale, scale, scale)
mesh_obj.location = (0, 0, rig_min_z - minz * scale)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
print('NORMALIZED: rig-scale', round(scale, 4),
      'mesh z', round(rig_min_z + (maxz - minz) * scale, 3))

# ---------------------------------------------------------------------------
# 4. decimate to the house vertex budget
# ---------------------------------------------------------------------------
ratio = min(1.0, TARGET_VERTS / len(mesh_obj.data.vertices))
dec = mesh_obj.modifiers.new('Decimate', 'DECIMATE')
dec.ratio = ratio
dec.decimate_type = 'COLLAPSE'
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.modifier_apply(modifier='Decimate')
print('DECIMATED: ratio', round(ratio, 4), '->',
      len(mesh_obj.data.vertices), 'verts', len(mesh_obj.data.polygons),
      'polys')

# ---------------------------------------------------------------------------
# 5. bind: parent to the armature, then RIGID nearest-core-bone weights
# ---------------------------------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
mesh_obj.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
# Match the proven Flame configuration exactly: NO object parent (an object
# parent makes the exporter bind every vertex to the root joint), only the
# ARMATURE modifier drives the skin.
mod = mesh_obj.modifiers.new('Armature', 'ARMATURE')
mod.object = arm_obj

# Fresh vertex groups: wipe whatever the import carried, then create one
# group per core bone.
for g in list(mesh_obj.vertex_groups):
    mesh_obj.vertex_groups.remove(g)
for name in CORE_BONES:
    mesh_obj.vertex_groups.new(name=name)

def bone_segment_dist(p, bone):
    h = arm_obj.matrix_world @ bone.head_local
    t = arm_obj.matrix_world @ bone.tail_local
    d = t - h
    l2 = d.length_squared
    if l2 == 0:
        return (p - h).length
    tt = max(0.0, min(1.0, (p - h).dot(d) / l2))
    return (p - h - d * tt).length

core = [b for b in arm_obj.data.bones if b.name in CORE_BONES]
groups = mesh_obj.vertex_groups
mw = mesh_obj.matrix_world
from collections import Counter
diag = Counter()
for i, v in enumerate(mesh_obj.data.vertices):
    p = mw @ v.co
    best, best_d = None, 1e9
    for bone in core:
        d = bone_segment_dist(p, bone)
        if d < best_d:
            best_d, best = d, bone.name
    groups[best].add([i], 1.0, 'REPLACE')
    diag[best] += 1
print('RIGID BOUND:', len(mesh_obj.data.vertices), 'verts')
print('BINDING MAP:', dict(diag.most_common(10)))

# ---------------------------------------------------------------------------
# 6. export the playable GLB (house export options)
# ---------------------------------------------------------------------------
bpy.ops.export_scene.gltf(
    filepath=dst,
    export_format='GLB',
    export_apply=False,          # keep the skin; never bake the pose
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_skins=True,
    export_all_influences=True,
    export_texcoords=True,
    export_normals=True,
    export_colors=True,
    export_materials='EXPORT',
    export_image_format='AUTO',  # keep the original embedded textures
    export_yup=True,
)
print('EXPORTED', dst, 'verts', len(mesh_obj.data.vertices))
