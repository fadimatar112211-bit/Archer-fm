# Exports a hero's Blender source (.blend) into a skinned GLB consumable by
# the game's dependency-free glTF parser (lib/game/render3/glb.dart).
#
# Usage:
#   blender -b assets/heroes/flame/source/flame_source.blend \
#     --python tools/blender_export_glb.py -- assets/heroes/flame/model/flame_animated.glb
#
# The source meshes are bone-parented (rigid binding) or vertex-group skinned;
# the stock glTF exporter handles both. The Dart parser merges the exported
# meshes' primitives into one vertex buffer, so no mesh surgery is done here
# (joining + armature modifier crashes Blender 4.0.2's exporter). Only:
#   1. force the armature to REST so the bind pose is the saved pose,
#   2. bake each material's diffuse colour into a corner COLOR_0 attribute
#      (the Principled nodes in these sources export black base colour —
#      the baked attribute is the reliable colour path),
#   3. export every action as its own animation (GLB, Y-up).

import bpy
import sys

argv = sys.argv[sys.argv.index('--') + 1:]
dst = argv[0]

for arm_obj in [o for o in bpy.data.objects if o.type == 'ARMATURE']:
    arm_obj.data.pose_position = 'REST'
bpy.context.view_layer.update()

glow_keys = ('energy', 'glow', 'flame', 'aura', 'streak', 'venom', 'shadow')
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    me = o.data
    attr = me.color_attributes.new(name='baked_col', type='FLOAT_COLOR',
                                   domain='CORNER')
    for poly in me.polygons:
        mat = me.materials[poly.material_index] if me.materials else None
        if mat is not None:
            r, g, b = mat.diffuse_color[:3]
            # Bright accent materials get a lift so they read as glowing on
            # the phone's dark arena.
            if any(k in mat.name.lower() for k in glow_keys):
                r = min(1.0, r * 1.35 + 0.1)
                g = min(1.0, g * 1.35 + 0.1)
                b = min(1.0, b * 1.35 + 0.1)
        else:
            r, g, b = 0.8, 0.8, 0.8
        for li in poly.loop_indices:
            attr.data[li].color = (r, g, b, 1.0)

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
    export_yup=True,
)
print('EXPORTED', dst)
