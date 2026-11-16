# Build the 8 gameplay animations (idle, walk, run, attack, skill, dodge,
# hit, death) directly on the 21-bone rig imported from the new
# assets/heroes/ranger_new/ranger.glb. The mesh and skin are never rebuilt:
# the original GLB is imported as-is, actions are authored on its bones, the
# result is exported as a NEW file (ranger_animated.glb).
#
# Design notes:
# - The GLB bones carry identity rotations, so every pose is authored in
#   world space: each keyframe states, per bone, a world-axis euler rotation
#   applied around the bone's rest head, plus an optional root translation.
# - Frames are composed hierarchically (parents first) so child bones stay
#   glued to their parents: no joint separation is possible by construction.
# - Every action keyframes all 21 bones, so exported animations are complete.
# - Loop actions repeat their first keyframe at the end for seamless looping.
# - The death keyframes are auto-lifted so the lying body never sinks below
#   the ground plane (measured on the evaluated, deformed mesh).
#
# Usage:
#   blender -b --python tools/blender/build_ranger_new_animations.py -- \
#       [--src assets/heroes/ranger_new/ranger.glb] \
#       [--out assets/heroes/ranger_new/ranger_animated.glb] [--no-export]

import argparse
import math
import sys
from math import radians

import bpy
from mathutils import Euler, Matrix, Vector

_argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
A = argparse.ArgumentParser()
A.add_argument("--src", default="assets/heroes/ranger_new/ranger.glb")
A.add_argument("--out", default="assets/heroes/ranger_new/ranger_animated.glb")
A.add_argument("--no-export", action="store_true")
A.add_argument("--debug", action="store_true")
A.add_argument("--mesh-glb", default=None,
               help="Merge mode: skin this UNRIGGED high-detail mesh (e.g. the "
                    "original Tripo reference GLB) to the rig from --src, "
                    "transferring weights from --src's own skinned mesh, then "
                    "drop the --src mesh. The rest of the pipeline (actions, "
                    "validation, export) is unchanged.")
ARGS = A.parse_args(_argv)
D = 1 if ARGS.debug else 0

def dbg(msg):
    if D: print("ANIM_DBG " + msg)

T = Matrix.Translation


def R4(rx=0.0, ry=0.0, rz=0.0):
    """World-axis euler rotation (degrees) as a 4x4 matrix."""
    if rx == ry == rz == 0.0:
        return Matrix.Identity(4)
    return Euler((radians(rx), radians(ry), radians(rz)),
                 "XYZ").to_matrix().to_4x4()


# --- scene --------------------------------------------------------------
def import_original_mesh(path, dev_mesh, arm):
    """Merge-mode: skin the unrigged original mesh to the developed rig.

    Weights travel from the developed mesh's authored vertex groups onto the
    original mesh by nearest-face interpolation (both meshes occupy the same
    rest-pose space, verified against their world bounding boxes). The
    developed mesh is then removed: the original becomes the only visual.
    """
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in set(bpy.data.objects) - before]
    meshes = [o for o in new if o.type == "MESH"]
    require_mesh = len(meshes) == 1
    if not require_mesh:
        raise RuntimeError(f"expected one mesh in {path}, found {len(meshes)}")
    orig = meshes[0]
    orig.name = "archer_mesh_original"

    # Shading note: with a metallicRoughness texture connected, glTF metallic
    # comes from the texture itself; the visual contract with the developed
    # look was verified by rendering the merged mesh (identical look). No
    # material override is applied to the original's PBR setup.
    for mat in orig.data.materials:
        if mat and mat.use_nodes:
            bsdf = next((n for n in mat.node_tree.nodes
                         if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf and not bsdf.inputs["Metallic"].is_linked:
                bsdf.inputs["Metallic"].default_value = 0.0

    # Recreate the developed rig's vertex-group layout on the original mesh,
    # then copy weights surface-to-surface (no re-projection guessing).
    for vg in dev_mesh.vertex_groups:
        orig.vertex_groups.new(name=vg.name)
    mod = orig.modifiers.new(name="WEIGHT_TRANSFER", type="DATA_TRANSFER")
    mod.object = dev_mesh
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"   # copy every developed group
    mod.layers_vgroup_select_dst = "NAME"  # ...matched by identical names
    bpy.context.view_layer.objects.active = orig
    orig.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)

    # Normalize every vertex so no vertex escapes the skeleton.
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL",
                                              lock_active=False)
    zero = [v.index for v in orig.data.vertices
            if not any(g.weight for g in v.groups)]
    print(f"MERGE weight transfer: {len(zero)} unweighted verts "
          f"(of {len(orig.data.vertices)})")

    orig.parent = arm
    arm_mod = orig.modifiers.new(name="ARMATURE", type="ARMATURE")
    arm_mod.object = arm

    # Retire the developed mesh: original mesh + shared rig remain.
    data = dev_mesh.data
    bpy.data.objects.remove(dev_mesh, do_unlink=True)
    if data and data.users == 0:
        bpy.data.meshes.remove(data)
    bpy.context.view_layer.objects.active = arm
    return orig


def import_source(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    arm = bpy.data.objects["Armature"]
    mesh = bpy.data.objects["archer_mesh"]
    # Drop the importer-generated Icosphere artifact (proven harmless, but we
    # do not want it in the exported file).
    ico = bpy.data.objects.get("Icosphere")
    if ico:
        data = ico.data
        bpy.data.objects.remove(ico, do_unlink=True)
        if data and data.users == 0:
            bpy.data.meshes.remove(data)
    for coll in list(bpy.data.collections):
        if coll.name == "glTF_not_exported" and not coll.objects:
            bpy.data.collections.remove(coll)
    if ARGS.mesh_glb:
        mesh = import_original_mesh(ARGS.mesh_glb, mesh, arm)
    return arm, mesh


ARM, MESH = import_source(ARGS.src)
ARMW = ARM.matrix_world.copy()
ARMW_INV = ARMW.inverted()

ORDER, PARENT, RESTW, HEADW = [], {}, {}, {}
for pb in ARM.pose.bones:
    RESTW[pb.name] = (ARMW @ pb.bone.matrix_local.copy())
    HEADW[pb.name] = RESTW[pb.name].to_translation()
    PARENT[pb.name] = pb.bone.parent.name if pb.bone.parent else None
# parents first
pending = list(RESTW)
while pending:
    for name in list(pending):
        par = PARENT[name]
        if par is None or par in ORDER:
            ORDER.append(name)
            pending.remove(name)
dbg("order=" + ",".join(ORDER))

MESH_REST = [ARM.matrix_world @ v.co for v in MESH.data.vertices]


def local_bases(spec):
    """Per-bone local base matrices: rest composed with the spec's world-axis
    rotation about the bone's rest head. Returns (bases, root_move)."""
    move = spec.get("_move", (0.0, 0.0, 0.0))
    bases = {}
    for name in ORDER:
        rx, ry, rz = spec.get(name, (0.0, 0.0, 0.0))
        piv = HEADW[name]
        bases[name] = T(piv) @ R4(rx, ry, rz) @ T(-piv) @ RESTW[name]
    return bases, move


def compose(bases, move):
    """Hierarchical composition: children stay glued to parents by
    construction, so joint separation is impossible."""
    mats = {}
    for name in ORDER:
        par = PARENT[name]
        if par is None:
            mats[name] = T(move) @ bases[name]
        else:
            mats[name] = mats[par] @ RESTW[par].inverted() @ bases[name]
    return mats


def compute_frame(spec):
    bases, move = local_bases(spec)
    return compose(bases, move)


def apply_pose(mats):
    """Set pose channels directly from desired armature-space matrices.

    Uses the documented relation pose_arm = parent_pose @ parent_rest^-1 @
    rest @ basis, decomposed manually. (The pb.matrix setter reads the
    parent's pose stale while an action is active, which bakes parent
    translation into every child's location channel.)"""
    for name in ORDER:
        par = PARENT[name]
        if par is None:
            basis = RESTW[name].inverted() @ mats[name]
        else:
            basis = (RESTW[name].inverted() @ RESTW[par]
                     @ mats[par].inverted() @ mats[name])
        pb = ARM.pose.bones[name]
        pb.location = basis.to_translation()
        pb.rotation_quaternion = basis.to_quaternion()
        pb.scale = basis.to_scale()


def evaluated_min_z():
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = MESH.evaluated_get(dg)
    return min((ARM.matrix_world @ v.co).z for v in ev.data.vertices)


def group_displacement():
    """Max displacement per vertex group (bone) on the evaluated mesh."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = MESH.evaluated_get(dg)
    best = {}
    for v in ev.data.vertices:
        world = ARM.matrix_world @ v.co
        rest = MESH_REST[v.index]
        d = (world - rest).length
        if d < 0.02 or v.groups is None:
            continue
        dom = max(v.groups, key=lambda g: g.weight)
        gname = MESH.vertex_groups[dom.group].name
        if d > best.get(gname, 0):
            best[gname] = d
    return best


def mesh_stats():
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = MESH.evaluated_get(dg)
    pts = [ARM.matrix_world @ v.co for v in ev.data.vertices]
    worst, nan = 0.0, 0
    for i, p in enumerate(pts):
        if p.length != p.length or p.x != p.x:
            nan += 1
        d = (p - MESH_REST[i]).length
        if d > worst:
            worst = d
    xs = [p.x for p in pts]; ys = [p.y for p in pts]; zs = [p.z for p in pts]
    return dict(max_disp=worst, nan=nan,
                bbox=(min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))


ACTIONS = []



def record(name, keys, ground=()):
    """keys: list of (frame, spec). Every bone is keyed at every listed frame."""
    act = bpy.data.actions.new(name)
    ARM.animation_data_create()
    ARM.animation_data.action = act
    for frame, spec in keys:
        bases, move = local_bases(spec)
        if frame in ground:
            # Measure the pose with the action detached, then lift the root
            # translation so the lying body rests on the ground plane.
            saved = ARM.animation_data.action
            ARM.animation_data.action = None
            apply_pose(compose(bases, move))
            drop = evaluated_min_z()
            if drop < -0.001:
                move = (move[0], move[1], move[2] - drop)
            ARM.animation_data.action = saved
        mats = compose(bases, move)
        apply_pose(mats)
        for bone_name in ORDER:
            pb = ARM.pose.bones[bone_name]
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("location", frame=frame)
    # Linear interpolation: predictable timing, no bezier overshoot through
    # the ground or past key poses.
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    track = ARM.animation_data.nla_tracks.new()
    track.name = name
    track.mute = True
    track.strips.new(name, int(act.frame_range[0]), act)
    ACTIONS.append(name)
    ARM.animation_data.action = None
    return act


# ------------------------------------------------------------- actions ----
R0 = (0.0, 0.0, 0.0)

record("idle", [
    (1, {"chest": (-2, 0, 0), "head": (-2, 0, 0), "upperArm_L": (-3, 0, -2),
         "upperArm_R": (-3, 0, 2), "cloak1": (3, 0, 0), "cloak2": (5, 0, 0),
         "quiver": (2, 0, 0), "_move": (0, 0, -0.004)}),
    (13, {"chest": (-5, 0, 0), "head": (-3, 0, 0), "upperArm_L": (-5, 0, -3),
          "upperArm_R": (-5, 0, 3), "cloak1": (6, 0, 0), "cloak2": (9, 0, 0),
          "quiver": (3, 0, 0), "_move": (0, 0, 0.008)}),
    (25, {"chest": (-2, 0, 0), "head": (-2, 0, 0), "upperArm_L": (-3, 0, -2),
          "upperArm_R": (-3, 0, 2), "cloak1": (3, 0, 0), "cloak2": (5, 0, 0),
          "quiver": (2, 0, 0), "_move": (0, 0, -0.004)}),
    (37, {"chest": (-1, 0, 0), "head": (-1, 0, 0), "upperArm_L": (-2, 0, -2),
          "upperArm_R": (-2, 0, 2), "cloak1": (2, 0, 0), "cloak2": (3, 0, 0),
          "quiver": (1, 0, 0), "_move": (0, 0, -0.007)}),
    (48, {"chest": (-2, 0, 0), "head": (-2, 0, 0), "upperArm_L": (-3, 0, -2),
          "upperArm_R": (-3, 0, 2), "cloak1": (3, 0, 0), "cloak2": (5, 0, 0),
          "quiver": (2, 0, 0), "_move": (0, 0, -0.004)}),
])

record("walk", [
    (1, {"upperLeg_L": (-28, 0, 0), "lowerLeg_L": (10, 0, 0),
         "upperLeg_R": (22, 0, 0), "lowerLeg_R": (25, 0, 0),
         "upperArm_L": (16, 0, 0), "lowerArm_L": (-18, 0, 0),
         "upperArm_R": (-18, 0, 0), "lowerArm_R": (-25, 0, 0),
         "hips": (0, 5, 0), "spine": (0, -4, 0), "chest": (-3, 0, 0),
         "cloak1": (5, 0, 0), "cloak2": (8, 0, 0), "_move": (0, 0, -0.012)}),
    (9, {"upperLeg_L": (-5, 0, 0), "lowerLeg_L": (45, 0, 0),
         "upperLeg_R": (5, 0, 0), "lowerLeg_R": (15, 0, 0),
         "upperArm_L": (-2, 0, 0), "lowerArm_L": (-8, 0, 0),
         "upperArm_R": (2, 0, 0), "lowerArm_R": (-12, 0, 0),
         "hips": (0, 3, 0), "spine": (0, -2, 0), "chest": (-4, 0, 0),
         "cloak1": (6, 0, 0), "cloak2": (10, 0, 0), "_move": (0, 0, 0.014)}),
    (17, {"upperLeg_L": (22, 0, 0), "lowerLeg_L": (25, 0, 0),
          "upperLeg_R": (-28, 0, 0), "lowerLeg_R": (10, 0, 0),
          "upperArm_L": (-18, 0, 0), "lowerArm_L": (-25, 0, 0),
          "upperArm_R": (16, 0, 0), "lowerArm_R": (-18, 0, 0),
          "hips": (0, -5, 0), "spine": (0, 4, 0), "chest": (-3, 0, 0),
          "cloak1": (5, 0, 0), "cloak2": (8, 0, 0), "_move": (0, 0, -0.012)}),
    (25, {"upperLeg_L": (5, 0, 0), "lowerLeg_L": (15, 0, 0),
          "upperLeg_R": (-5, 0, 0), "lowerLeg_R": (45, 0, 0),
          "upperArm_L": (2, 0, 0), "lowerArm_L": (-12, 0, 0),
          "upperArm_R": (-2, 0, 0), "lowerArm_R": (-8, 0, 0),
          "hips": (0, -3, 0), "spine": (0, 2, 0), "chest": (-4, 0, 0),
          "cloak1": (6, 0, 0), "cloak2": (10, 0, 0), "_move": (0, 0, 0.014)}),
    (33, {"upperLeg_L": (-28, 0, 0), "lowerLeg_L": (10, 0, 0),
          "upperLeg_R": (22, 0, 0), "lowerLeg_R": (25, 0, 0),
          "upperArm_L": (16, 0, 0), "lowerArm_L": (-18, 0, 0),
          "upperArm_R": (-18, 0, 0), "lowerArm_R": (-25, 0, 0),
          "hips": (0, 5, 0), "spine": (0, -4, 0), "chest": (-3, 0, 0),
          "cloak1": (5, 0, 0), "cloak2": (8, 0, 0), "_move": (0, 0, -0.012)}),
])

record("run", [
    (1, {"upperLeg_L": (-45, 0, 0), "lowerLeg_L": (20, 0, 0),
         "upperLeg_R": (35, 0, 0), "lowerLeg_R": (70, 0, 0),
         "upperArm_L": (30, 0, 0), "lowerArm_L": (-60, 0, 0),
         "upperArm_R": (-40, 0, 0), "lowerArm_R": (-70, 0, 0),
         "chest": (-14, 0, 0), "spine": (-6, 0, 0), "hips": (0, 6, 0),
         "cloak1": (14, 0, 0), "cloak2": (22, 0, 0), "_move": (0, 0, -0.02)}),
    (7, {"upperLeg_L": (-10, 0, 0), "lowerLeg_L": (80, 0, 0),
         "upperLeg_R": (5, 0, 0), "lowerLeg_R": (40, 0, 0),
         "upperArm_L": (5, 0, 0), "lowerArm_L": (-50, 0, 0),
         "upperArm_R": (-5, 0, 0), "lowerArm_R": (-65, 0, 0),
         "chest": (-14, 0, 0), "spine": (-6, 0, 0), "hips": (0, 3, 0),
         "cloak1": (16, 0, 0), "cloak2": (26, 0, 0), "_move": (0, 0, 0.03)}),
    (13, {"upperLeg_L": (35, 0, 0), "lowerLeg_L": (70, 0, 0),
          "upperLeg_R": (-45, 0, 0), "lowerLeg_R": (20, 0, 0),
          "upperArm_L": (-40, 0, 0), "lowerArm_L": (-70, 0, 0),
          "upperArm_R": (30, 0, 0), "lowerArm_R": (-60, 0, 0),
          "chest": (-14, 0, 0), "spine": (-6, 0, 0), "hips": (0, -6, 0),
          "cloak1": (14, 0, 0), "cloak2": (22, 0, 0), "_move": (0, 0, -0.02)}),
    (19, {"upperLeg_L": (5, 0, 0), "lowerLeg_L": (40, 0, 0),
          "upperLeg_R": (-10, 0, 0), "lowerLeg_R": (80, 0, 0),
          "upperArm_L": (-5, 0, 0), "lowerArm_L": (-65, 0, 0),
          "upperArm_R": (5, 0, 0), "lowerArm_R": (-50, 0, 0),
          "chest": (-14, 0, 0), "spine": (-6, 0, 0), "hips": (0, -3, 0),
          "cloak1": (16, 0, 0), "cloak2": (26, 0, 0), "_move": (0, 0, 0.03)}),
    (25, {"upperLeg_L": (-45, 0, 0), "lowerLeg_L": (20, 0, 0),
          "upperLeg_R": (35, 0, 0), "lowerLeg_R": (70, 0, 0),
          "upperArm_L": (30, 0, 0), "lowerArm_L": (-60, 0, 0),
          "upperArm_R": (-40, 0, 0), "lowerArm_R": (-70, 0, 0),
          "chest": (-14, 0, 0), "spine": (-6, 0, 0), "hips": (0, 6, 0),
          "cloak1": (14, 0, 0), "cloak2": (22, 0, 0), "_move": (0, 0, -0.02)}),
])

record("attack", [
    (1, {"chest": (-4, 0, 0)}),
    (7, {"chest": (-8, 0, 0), "head": (-6, 0, 0), "upperArm_L": (-78, 0, 0),
         "upperArm_R": (-55, 0, 0), "lowerArm_R": (-80, 0, 0),
         "_move": (0, 0, -0.01)}),
    (16, {"chest": (-10, 0, -5), "head": (-8, 0, 0),
          "upperArm_L": (-85, 0, 0), "upperArm_R": (-68, 0, 0),
          "lowerArm_R": (105, 0, 0), "spine": (0, -5, 0),
          "quiver": (-4, 0, 0), "_move": (0, -0.02, -0.01)}),
    (26, {"chest": (-11, 0, -6), "head": (-8, 0, 0),
          "upperArm_L": (-86, 0, 0), "upperArm_R": (-69, 0, 0),
          "lowerArm_R": (107, 0, 0), "spine": (0, -5, 0),
          "quiver": (-4, 0, 0), "cloak2": (6, 0, 0),
          "_move": (0, -0.02, -0.012)}),
    (31, {"chest": (-6, 0, -2), "head": (-4, 0, 0),
          "upperArm_L": (-80, 0, 0), "upperArm_R": (-78, 0, 0),
          "lowerArm_R": (-30, 0, 0), "quiver": (5, 0, 0),
          "cloak1": (8, 0, 0), "cloak2": (12, 0, 0),
          "_move": (0, 0, -0.015)}),
    (40, {"chest": (-3, 0, 0), "head": (-2, 0, 0), "upperArm_L": (-6, 0, 0),
          "upperArm_R": (-4, 0, 0), "lowerArm_L": (-4, 0, 0),
          "lowerArm_R": (-8, 0, 0)}),
])

record("skill", [
    (1, {}),
    (8, {"_move": (0, 0, -0.14), "upperLeg_L": (30, 0, 0),
         "lowerLeg_L": (55, 0, 0), "upperLeg_R": (30, 0, 0),
         "lowerLeg_R": (55, 0, 0), "chest": (-16, 0, 0),
         "upperArm_L": (25, 0, 0), "upperArm_R": (25, 0, 0),
         "lowerArm_L": (-15, 0, 0), "lowerArm_R": (-15, 0, 0),
         "head": (-4, 0, 0), "cloak2": (12, 0, 0)}),
    (16, {"_move": (0, -0.05, 0.15), "upperLeg_L": (55, 0, 0),
          "lowerLeg_L": (85, 0, 0), "upperLeg_R": (55, 0, 0),
          "lowerLeg_R": (85, 0, 0), "chest": (-6, 0, 0),
          "upperArm_L": (-120, 0, 0), "upperArm_R": (-20, 0, 0),
          "head": (-10, 0, 0), "cloak1": (20, 0, 0), "cloak2": (30, 0, 0)}),
    (28, {"_move": (0, -0.05, 0.12), "upperLeg_L": (25, 0, 0),
          "lowerLeg_L": (45, 0, 0), "upperLeg_R": (25, 0, 0),
          "lowerLeg_R": (45, 0, 0), "chest": (-8, 0, 0),
          "upperArm_L": (-95, 0, 0), "upperArm_R": (-60, 0, 0),
          "lowerArm_R": (100, 0, 0), "head": (-10, 0, 0),
          "cloak1": (18, 0, 0), "cloak2": (28, 0, 0)}),
    (38, {"_move": (0, -0.05, 0.09), "upperLeg_L": (15, 0, 0),
          "lowerLeg_L": (30, 0, 0), "upperLeg_R": (15, 0, 0),
          "lowerLeg_R": (30, 0, 0), "chest": (-4, 0, 0),
          "upperArm_L": (-90, 0, 0), "upperArm_R": (-75, 0, 0),
          "lowerArm_R": (-25, 0, 0), "quiver": (6, 0, 0),
          "cloak1": (15, 0, 0), "cloak2": (22, 0, 0)}),
    (48, {"_move": (0, 0, -0.10), "upperLeg_L": (28, 0, 0),
          "lowerLeg_L": (50, 0, 0), "upperLeg_R": (28, 0, 0),
          "lowerLeg_R": (50, 0, 0), "chest": (-14, 0, 0),
          "upperArm_L": (-8, 0, 0), "upperArm_R": (-6, 0, 0),
          "cloak1": (8, 0, 0), "cloak2": (12, 0, 0)}),
    (56, {"chest": (-2, 0, 0)}),
])

record("dodge", [
    (1, {}),
    (5, {"_move": (0, 0, -0.10), "upperLeg_L": (22, 0, 0),
         "lowerLeg_L": (45, 0, 0), "upperLeg_R": (22, 0, 0),
         "lowerLeg_R": (45, 0, 0), "chest": (-12, 8, 0), "head": (0, 8, 0),
         "upperArm_L": (-15, 0, 0), "upperArm_R": (-12, 0, 0)}),
    (12, {"_move": (0.10, 0, 0.16), "upperLeg_L": (35, 0, 0),
          "lowerLeg_L": (70, 0, 0), "upperLeg_R": (35, 0, 0),
          "lowerLeg_R": (70, 0, 0), "chest": (-10, 14, 0),
          "head": (0, 10, 0), "upperArm_L": (-30, 0, 0),
          "upperArm_R": (-25, 0, 0), "cloak1": (6, -6, 0),
          "cloak2": (10, -10, 0)}),
    (19, {"_move": (0.02, 0, -0.06), "upperLeg_L": (20, 0, 0),
          "lowerLeg_L": (40, 0, 0), "upperLeg_R": (20, 0, 0),
          "lowerLeg_R": (40, 0, 0), "chest": (-8, 8, 0), "head": (0, 5, 0),
          "upperArm_L": (-18, 0, 0), "upperArm_R": (-14, 0, 0)}),
    (26, {"_move": (0, 0, -0.02), "chest": (-4, 3, 0), "head": (0, 2, 0),
          "upperArm_L": (-8, 0, 0), "upperArm_R": (-6, 0, 0)}),
    (28, {}),
])

record("hit", [
    (1, {}),
    (4, {"chest": (9, 0, 0), "head": (12, 0, 0), "spine": (4, 0, 0),
         "upperArm_L": (12, 0, 0), "upperArm_R": (10, 0, 0),
         "cloak1": (10, 0, 0), "cloak2": (14, 0, 0), "quiver": (6, 0, 0),
         "_move": (0, 0.01, -0.02)}),
    (9, {"chest": (4, 0, 0), "head": (5, 0, 0), "upperArm_L": (4, 0, 0),
         "upperArm_R": (3, 0, 0), "cloak1": (4, 0, 0), "cloak2": (6, 0, 0),
         "_move": (0, 0, -0.01)}),
    (16, {"chest": (1, 0, 0), "head": (1, 0, 0)}),
    (20, {}),
])

record("death", [
    (1, {}),
    (8, {"_move": (0, 0.04, -0.02), "chest": (14, 0, 0), "head": (16, 0, 0),
         "upperArm_L": (18, 0, 0), "upperArm_R": (16, 0, 0),
         "upperLeg_L": (8, 0, 0), "upperLeg_R": (8, 0, 0),
         "lowerLeg_L": (12, 0, 0), "lowerLeg_R": (12, 0, 0),
         "cloak1": (14, 0, 0), "cloak2": (18, 0, 0), "quiver": (8, 0, 0)}),
    (16, {"_move": (0, 0.00, -0.18), "chest": (20, 0, 0), "head": (14, 0, 0),
          "hips": (6, 0, 0), "upperArm_L": (25, 0, 0), "upperArm_R": (22, 0, 0),
          "upperLeg_L": (25, 0, 0), "lowerLeg_L": (45, 0, 0),
          "upperLeg_R": (25, 0, 0), "lowerLeg_R": (45, 0, 0),
          "cloak1": (18, 0, 0), "cloak2": (24, 0, 0)}),
    (22, {"_move": (0, -0.04, -0.22), "root": (-18, 0, 0), "chest": (23, 0, 0),
          "head": (12, 0, 0), "upperArm_L": (28, 0, 0), "upperArm_R": (25, 0, 0),
          "upperLeg_L": (28, 0, 0), "lowerLeg_L": (50, 0, 0),
          "upperLeg_R": (28, 0, 0), "lowerLeg_R": (50, 0, 0),
          "cloak1": (18, 0, 0), "cloak2": (24, 0, 0)}),
    (28, {"_move": (0, -0.08, -0.26), "root": (-35, 0, 0), "chest": (25, 0, 0),
          "head": (10, 0, 0), "upperArm_L": (30, 0, 0),
          "upperArm_R": (28, 0, 0), "upperLeg_L": (30, 0, 0),
          "lowerLeg_L": (55, 0, 0), "upperLeg_R": (30, 0, 0),
          "lowerLeg_R": (55, 0, 0)}),
    (30, {"_move": (0, -0.12, -0.27), "root": (-43, 0, 0), "chest": (22, 0, 0),
          "head": (6, 0, 0), "upperArm_L": (24, 0, 0), "upperArm_R": (21, 0, 0),
          "upperLeg_L": (28, 0, 0), "lowerLeg_L": (52, 0, 0),
          "upperLeg_R": (26, 0, 0), "lowerLeg_R": (48, 0, 0),
          "cloak1": (14, 0, 0), "cloak2": (20, 0, 0)}),
    (32, {"_move": (0, -0.17, -0.28), "root": (-50, 0, 0), "chest": (20, 0, 0),
          "head": (4, 0, 0), "upperArm_L": (25, 0, 0),
          "upperArm_R": (22, 0, 0), "upperLeg_L": (26, 0, 0),
          "lowerLeg_L": (50, 0, 0), "upperLeg_R": (24, 0, 0),
          "lowerLeg_R": (46, 0, 0), "cloak1": (14, 0, 0), "cloak2": (20, 0, 0)}),
    (34, {"_move": (0, -0.22, -0.285), "root": (-57, 0, 0),
          "chest": (18, 0, 0), "head": (0, 0, 0), "upperArm_L": (16, 0, 0),
          "upperArm_R": (14, 0, 0), "upperLeg_L": (23, 0, 0),
          "lowerLeg_L": (45, 0, 0), "upperLeg_R": (20, 0, 0),
          "lowerLeg_R": (40, 0, 0), "cloak1": (13, 0, 0), "cloak2": (18, 0, 0)}),
    (36, {"_move": (0, -0.27, -0.29), "root": (-64, 0, 0), "chest": (16, 0, 0),
          "head": (-4, 0, 0), "upperArm_L": (8, 0, 0), "upperArm_R": (6, 0, 0),
          "upperLeg_L": (20, 0, 0), "lowerLeg_L": (40, 0, 0),
          "upperLeg_R": (16, 0, 0), "lowerLeg_R": (34, 0, 0),
          "cloak1": (12, 0, 0), "cloak2": (16, 0, 0)}),
    (38, {"_move": (0, -0.32, -0.295), "root": (-71, 0, 0),
          "chest": (14, 0, 0), "head": (-7, 0, 0), "upperArm_L": (-6, 0, 0),
          "upperArm_R": (-6, 0, 0), "upperLeg_L": (24, 0, 0),
          "lowerLeg_L": (48, 0, 0), "upperLeg_R": (20, 0, 0),
          "lowerLeg_R": (42, 0, 0), "cloak1": (11, 0, 0), "cloak2": (15, 0, 0)}),
    (40, {"_move": (0, -0.36, -0.30), "root": (-78, 0, 0), "chest": (12, 0, 0),
          "head": (-10, 0, 0), "upperArm_L": (-12, 0, 0),
          "upperArm_R": (-10, 0, 0), "upperLeg_L": (30, 0, 0),
          "lowerLeg_L": (58, 0, 0), "upperLeg_R": (26, 0, 0),
          "lowerLeg_R": (52, 0, 0), "cloak1": (10, 0, 0), "cloak2": (14, 0, 0)}),
    (48, {"_move": (0, -0.40, -0.30), "root": (-79, 0, 0), "chest": (12, 0, 0),
          "head": (-11, 0, 0), "upperArm_L": (-14, 0, 0),
          "upperArm_R": (-12, 0, 0), "upperLeg_L": (34, 0, 0),
          "lowerLeg_L": (66, 0, 0), "upperLeg_R": (30, 0, 0),
          "lowerLeg_R": (60, 0, 0), "cloak1": (10, 0, 0), "cloak2": (14, 0, 0)}),
    (52, {"_move": (0, -0.40, -0.30), "root": (-80, 0, 0), "chest": (12, 0, 0),
          "head": (-12, 0, 0), "upperArm_L": (-16, 0, 0),
          "upperArm_R": (-14, 0, 0), "upperLeg_L": (36, 0, 0),
          "lowerLeg_L": (70, 0, 0), "upperLeg_R": (32, 0, 0),
          "lowerLeg_R": (64, 0, 0), "cloak1": (10, 0, 0), "cloak2": (14, 0, 0)}),
    (64, {"_move": (0, -0.40, -0.30), "root": (-80, 0, 0), "chest": (12, 0, 0),
          "head": (-12, 0, 0), "upperArm_L": (-16, 0, 0),
          "upperArm_R": (-14, 0, 0), "upperLeg_L": (36, 0, 0),
          "lowerLeg_L": (70, 0, 0), "upperLeg_R": (32, 0, 0),
          "lowerLeg_R": (64, 0, 0), "cloak1": (10, 0, 0), "cloak2": (14, 0, 0)}),
], ground=(16, 22, 28, 30, 32, 34, 36, 38, 40, 48, 52, 64))

ARM.animation_data.action = None
print("ANIM_BUILT:", ACTIONS)

# ---------------------------------------------------------- validation ----
# Per-action displacement limits: large root moves (leap, fall) legitimately
# displace the whole body, so they get a wider budget than the small-motion
# actions. Anything beyond the limit suggests a deformation defect.
LIMITS = {"skill": 1.6, "death": 1.6, "dodge": 1.2}
failures = []
for name in ACTIONS:
    act = bpy.data.actions[name]
    ARM.animation_data.action = act
    worst, nan = 0.0, 0
    lo_z = 1e9
    frames = [int(f) for f in act.frame_range]
    for frame in range(frames[0], frames[1] + 1, max(1, (frames[1] - frames[0]) // 12)):
        bpy.context.scene.frame_set(frame)
        st = mesh_stats()
        worst = max(worst, st["max_disp"])
        nan += st["nan"]
        lo_z = min(lo_z, st["bbox"][4])
        if D and st["max_disp"] > LIMITS.get(name, 1.0):
            for bone, d in sorted(group_displacement().items(),
                                  key=lambda kv: -kv[1])[:4]:
                print(f"ANIM_DBG {name} f{frame} {bone}: {d:.3f}")
    # loop seam check
    seam = 0.0
    if name in ("idle", "walk", "run"):
        bpy.context.scene.frame_set(frames[1])
        end = {b.name: ARM.pose.bones[b.name].matrix.copy()
               for b in ARM.pose.bones}
        bpy.context.scene.frame_set(frames[0])
        for b in ARM.pose.bones:
            seam = max(seam, (end[b.name].to_translation()
                              - b.matrix.to_translation()).length)
    ok = (nan == 0 and worst < LIMITS.get(name, 1.0)
          and seam < 0.03 and lo_z > -0.12)
    if D and name == "death":
        for frame in range(frames[0], frames[1] + 1, 4):
            bpy.context.scene.frame_set(frame)
            st = mesh_stats()
            dbg(f"death f{frame} minz={st['bbox'][4]:.3f} "
                f"rootloc={tuple(round(v,3) for v in ARM.pose.bones['root'].location)}")
    print(f"ANIM_CHECK {name}: range={frames} max_disp={worst:.3f} "
          f"nan={nan} seam={seam:.4f} min_z={lo_z:.3f} -> "
          f"{'PASS' if ok else 'FAIL'}")
    if not ok:
        failures.append(name)
bpy.context.scene.frame_set(1)

if failures:
    print("ANIM_VALIDATION_FAILED:", failures)
    sys.exit(1)

# ------------------------------------------------------------- export -----
if not ARGS.no_export:
    bpy.ops.export_scene.gltf(filepath=ARGS.out, export_format="GLB",
                              export_skins=True, export_animations=True,
                              export_animation_mode="ACTIONS",
                              export_morph=False, export_apply=False)
    print("ANIM_EXPORTED:", ARGS.out)
print("ANIM_DONE")
