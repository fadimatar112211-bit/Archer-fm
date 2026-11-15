"""Build the reference-matched, cel-shaded Ranger production scene.

Run:
  blender -b --python tools/blender/build_ranger_source.py

The character is original procedural geometry authored from the reference at
assets/heroes/ranger/ranger_reference_crop.png: a chibi male archer with short
thick brown hair, blue eyes, a knee-length green cloak, layered bronze-brown
armour over a green tunic, green bracers and boots, a glowing green energy
recurve bow with green energy effects, a quiver of arrows, and a brass cloak
clasp. Nothing is downloaded or traced; every mesh is generated here.

The rig is a rigid-part rig: each visible mesh is parented to exactly one bone.
Cloth secondary motion uses three overlapping cloak sections so the cloak can
flow without vertex-weight deformation.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/heroes/ranger/source/ranger_source.blend"

HEAD_CENTER = Vector((0.0, 0.0, 2.60))
HRX, HRY, HRZ = 0.44, 0.40, 0.45

BONES = (
    "root", "hips", "spine", "chest", "neck", "head",
    "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R",
    "forearm.L", "forearm.R", "hand.L", "hand.R",
    "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
    "cloak_a", "cloak_b", "cloak_c", "bow", "string_rest", "string_drawn",
    "fx", "fx_draw", "aura", "quiver",
)

FX_BONES = ("fx", "fx_draw", "aura", "string_drawn")
DEFAULT_SCALE = {
    bone: (0.0, 0.0, 0.0) if bone in FX_BONES else (1.0, 1.0, 1.0)
    for bone in BONES
}


def srgb(hex_value: str) -> tuple[float, float, float]:
    value = hex_value.lstrip("#")
    channels = [int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(
        channel / 12.92 if channel <= 0.04045
        else ((channel + 0.055) / 1.055) ** 2.4
        for channel in channels
    )


def tint(color, factor):
    return tuple(min(1.0, max(0.0, channel * factor)) for channel in color)


PALETTE = {
    "green": "#2E7D32",
    "green_light": "#4F9E2E",
    "green_deep": "#1A5A1E",
    "green_bright": "#7CC33A",
    "trouser": "#39442A",
    "leather": "#714E42",
    "leather_dark": "#3E2723",
    "bronze": "#A9844E",
    "bronze_light": "#D9BE86",
    "gold": "#C9A227",
    "skin": "#F6D5B4",
    "skin_shadow": "#DFA983",
    "skin_light": "#FFE8CF",
    "hair_dark": "#4C2411",
    "hair_mid": "#713B20",
    "hair_light": "#955733",
    "hair_shine": "#C08552",
    "eye_blue": "#3C8FBF",
    "eye_light": "#7CC7EC",
    "eye_dark": "#16232E",
    "white": "#F2F5F2",
    "bow_glow": "#7CFF3A",
    "bow_core": "#E6FFB0",
    "energy": "#55F02A",
}

MATS: dict[str, bpy.types.Material] = {}


def toon(name, base, shadow=None, light=None, rim=None):
    color = srgb(PALETTE[base]) if isinstance(base, str) else base
    shade = tint(color, 0.48) if shadow is None else (
        srgb(PALETTE[shadow]) if isinstance(shadow, str) else shadow)
    highlight = tint(color, 1.42) if light is None else (
        srgb(PALETTE[light]) if isinstance(light, str) else light)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    diffuse.inputs["Roughness"].default_value = 0.0
    shader_to_rgb = nodes.new("ShaderNodeShaderToRGB")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*shade, 1.0)
    ramp.color_ramp.elements[1].position = 0.50
    ramp.color_ramp.elements[1].color = (*color, 1.0)
    third = ramp.color_ramp.elements.new(0.82)
    third.color = (*highlight, 1.0)
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value = 1.0
    links.new(diffuse.outputs[0], shader_to_rgb.inputs[0])
    links.new(shader_to_rgb.outputs["Color"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], emission.inputs["Color"])
    surface = emission.outputs[0]
    if rim is not None:
        rim_color = srgb(PALETTE[rim]) if isinstance(rim, str) else rim
        layer = nodes.new("ShaderNodeLayerWeight")
        layer.inputs["Blend"].default_value = 0.35
        rim_ramp = nodes.new("ShaderNodeValToRGB")
        rim_ramp.color_ramp.interpolation = "EASE"
        rim_ramp.color_ramp.elements[0].position = 0.70
        rim_ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
        rim_ramp.color_ramp.elements[1].position = 0.97
        rim_ramp.color_ramp.elements[1].color = (*rim_color, 1.0)
        add = nodes.new("ShaderNodeMixRGB")
        add.blend_type = "ADD"
        add.inputs["Fac"].default_value = 0.42
        links.new(layer.outputs["Facing"], rim_ramp.inputs["Fac"])
        links.new(emission.outputs[0], add.inputs[1])
        links.new(rim_ramp.outputs["Color"], add.inputs[2])
        surface = add.outputs[0]
    links.new(surface, output.inputs["Surface"])
    return mat


def glow(name, base, strength, alpha=1.0):
    color = srgb(PALETTE[base]) if isinstance(base, str) else base
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1.0:
        mat.blend_method = "BLEND"
        mat.show_transparent_back = False
    return mat


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                       bpy.data.cameras, bpy.data.lights, bpy.data.actions,
                       bpy.data.armatures, bpy.data.images):
        for item in list(collection):
            try:
                collection.remove(item)
            except Exception:
                pass


def attach(obj, bone):
    world = obj.matrix_world.copy()
    obj.parent = ARM
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def finish_mesh(mesh, recalc=True):
    mesh.validate()
    if recalc:
        form = bmesh.new()
        form.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(form, faces=form.faces)
        form.to_mesh(mesh)
        form.free()
    mesh.update()


def smooth(obj, auto=True):
    if obj.type != "MESH":
        return
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    if auto and hasattr(obj.data, "use_auto_smooth"):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(58)


def obj_from(name, verts, faces, materials, bone=None, face_materials=None,
             recalc=True, smooth_shade=True, solidify=None, bevel=None,
             bevel_segments=2):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    finish_mesh(mesh, recalc)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for key in materials:
        mesh.materials.append(MATS[key])
    if face_materials:
        for polygon, index in zip(mesh.polygons, face_materials):
            polygon.material_index = min(index, len(materials) - 1)
    if smooth_shade:
        smooth(obj)
    if solidify is not None:
        thickness, inner_offset = solidify
        modifier = obj.modifiers.new("Cloth thickness", "SOLIDIFY")
        modifier.thickness = thickness
        modifier.offset = 0.0
        modifier.use_rim = True
        modifier.material_offset = inner_offset
        modifier.material_offset_rim = inner_offset
    if bevel is not None:
        modifier = obj.modifiers.new("Soft crafted edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = bevel_segments
        modifier.limit_method = "ANGLE"
    if bone:
        attach(obj, bone)
    return obj


def apply_object_scale(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)


def sphere(name, center, scale, material, bone=None, segments=32, rings=20,
           rotation=None, bevel=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    if rotation:
        obj.rotation_euler = rotation
    apply_object_scale(obj)
    obj.data.materials.append(MATS[material])
    smooth(obj)
    if bevel is not None:
        modifier = obj.modifiers.new("Rim", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    if bone:
        attach(obj, bone)
    return obj


def box(name, center, dimensions, material, bone=None, bevel=0.02,
        rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    if rotation:
        obj.rotation_euler = rotation
    apply_object_scale(obj)
    obj.data.materials.append(MATS[material])
    if bevel:
        modifier = obj.modifiers.new("Soft edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    if bone:
        attach(obj, bone)
    return obj


def torus(name, center, major, minor, material, bone=None, scale=(1, 1, 1),
          rotation=(0, 0, 0), major_segments=36, minor_segments=10):
    bpy.ops.mesh.primitive_torus_add(
        location=center, rotation=rotation, major_radius=major,
        minor_radius=minor, major_segments=major_segments,
        minor_segments=minor_segments)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    apply_object_scale(obj)
    obj.data.materials.append(MATS[material])
    smooth(obj)
    if bone:
        attach(obj, bone)
    return obj


def loft(name, sections, material, bone=None, sides=28, cap=True,
         face_materials=None):
    """Vertical loft: sections are (z, center_x, center_y, rx, ry)."""
    verts = []
    for z, cx, cy, rx, ry in sections:
        for j in range(sides):
            angle = 2.0 * math.pi * j / sides
            verts.append((cx + rx * math.cos(angle),
                          cy + ry * math.sin(angle), z))
    faces = []
    for i in range(len(sections) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            c = (i + 1) * sides + (j + 1) % sides
            d = (i + 1) * sides + j
            faces.append((a, b, c, d))
    if cap:
        bottom = len(verts)
        z, cx, cy, _, _ = sections[0]
        verts.append((cx, cy, z))
        top = len(verts)
        z, cx, cy, _, _ = sections[-1]
        verts.append((cx, cy, z))
        for j in range(sides):
            faces.append((bottom, (j + 1) % sides, j))
            base = (len(sections) - 1) * sides
            faces.append((top, base + j, base + (j + 1) % sides))
    return obj_from(name, verts, faces, [material], bone,
                    face_materials=face_materials)


def sweep(name, points, widths, material, bone=None, sides=8, thickness=None,
          flats=None, tip=False, cap_start=True, cap_end=True,
          material_stops=None):
    """Sweep an elliptical cross-section along a polyline.

    material_stops is a list of (fraction, material_key); the material of each
    quad is chosen from the fraction along the path, which paints hair roots
    dark and tips light.
    """
    pts = [Vector(point) for point in points]
    count = len(pts)
    if thickness is None:
        thickness = [width * 0.34 for width in widths]
    rings = []
    for i, point in enumerate(pts):
        if i == 0:
            tangent = pts[1] - pts[0]
        elif i == count - 1:
            tangent = pts[-1] - pts[-2]
        else:
            tangent = pts[i + 1] - pts[i - 1]
        tangent.normalize()
        flat = Vector(flats[i]) if flats is not None else Vector((0.0, 1.0, 0.0))
        flat = flat - tangent * flat.dot(tangent)
        if flat.length < 1e-6:
            flat = tangent.orthogonal()
        flat.normalize()
        side = tangent.cross(flat).normalized()
        thick = side.cross(tangent).normalized()
        ring = []
        for j in range(sides):
            angle = 2.0 * math.pi * j / sides
            ring.append(point
                        + side * (math.cos(angle) * widths[i] * 0.5)
                        + thick * (math.sin(angle) * thickness[i] * 0.5))
        rings.append(ring)
    verts = [vertex for ring in rings for vertex in ring]
    faces = []
    stops = material_stops or [(0.0, material)]
    keys = [key for _, key in stops]
    face_materials = []
    for i in range(count - 1):
        fraction = (i + 0.5) / max(1, count - 1)
        index = max((n for n, (stop_fraction, _) in enumerate(stops)
                     if fraction >= stop_fraction), default=0)
        for j in range(sides):
            a = i * sides + j
            d = (i + 1) * sides + j
            c = (i + 1) * sides + (j + 1) % sides
            b = i * sides + (j + 1) % sides
            faces.append((a, d, c, b))
            face_materials.append(index)
    if cap_start:
        center = len(verts)
        verts.append(pts[0])
        for j in range(sides):
            faces.append((center, j, (j + 1) % sides))
            face_materials.append(0)
    if tip:
        base = (count - 1) * sides
        end = len(verts)
        extension = (pts[-1] - pts[-2]).normalized() * max(0.015, widths[-1] * 0.35)
        verts.append(pts[-1] + extension)
        for j in range(sides):
            faces.append((base + (j + 1) % sides, base + j, end))
            face_materials.append(len(stops) - 1)
    elif cap_end:
        center = len(verts)
        verts.append(pts[-1])
        base = (count - 1) * sides
        for j in range(sides):
            faces.append((center, base + (j + 1) % sides, base + j))
            face_materials.append(len(stops) - 1)
    return obj_from(name, verts, faces, keys, bone,
                    face_materials=face_materials)


def grid_sheet(name, rows, materials, bone=None, solidify=None, recalc=False,
               face_materials=None):
    """Build a quad sheet from rows of points (top to bottom, left to right)."""
    width = len(rows[0])
    verts = [point for row in rows for point in row]
    faces = []
    for i in range(len(rows) - 1):
        for j in range(width - 1):
            a = i * width + j
            b = i * width + j + 1
            c = (i + 1) * width + j + 1
            d = (i + 1) * width + j
            faces.append((a, b, c, d))
    return obj_from(name, verts, faces, materials, bone,
                    face_materials=face_materials, recalc=recalc,
                    solidify=solidify)
# ---------------------------------------------------------------- head -----

def shaped_head(x, y, z):
    """Shape a unit sphere into the reference's soft chibi head."""
    low = max(0.0, -z)
    jaw = 1.0 - 0.36 * low ** 1.7
    px = HRX * x * jaw
    py = HRY * y * jaw
    pz = HRZ * z
    if y < 0.0:
        py -= 0.050 * low ** 2
    if y > 0.0:
        py *= 0.94
    cheek = math.exp(-((z + 0.18) / 0.30) ** 2) * abs(x) ** 0.6
    px += 0.018 * cheek
    return Vector((px, py, pz)) + HEAD_CENTER


def head_point(az_deg, el_deg, inflate=0.0):
    az, el = math.radians(az_deg), math.radians(el_deg)
    x = math.sin(az) * math.cos(el)
    y = -math.cos(az) * math.cos(el)
    z = math.sin(el)
    point = shaped_head(x, y, z)
    if inflate:
        point = point + head_normal(az_deg, el_deg) * inflate
    return point


def head_normal(az_deg, el_deg):
    point = head_point(az_deg, el_deg)
    right = head_point(az_deg + 0.4, el_deg) - point
    up = head_point(az_deg, el_deg + 0.4) - point
    return right.cross(up).normalized()


def build_head():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32,
                                         radius=1.0, location=(0, 0, 0))
    obj = bpy.context.object
    obj.name = "Face_Head"
    for vertex in obj.data.vertices:
        vertex.co = shaped_head(*vertex.co)
    obj.data.materials.append(MATS["skin"])
    smooth(obj)
    attach(obj, "head")
    return obj


def surface_patch(name, az, el, radius_az, radius_el, material, inflate,
                  tilt_deg=0.0, bone="head", rings=3, segments=30):
    verts = [head_point(az, el, inflate)]
    faces = []
    tilt = math.radians(tilt_deg)
    for ring in range(1, rings + 1):
        radius = ring / rings
        for j in range(segments):
            angle = 2.0 * math.pi * j / segments
            u = radius_az * radius * math.cos(angle)
            v = radius_el * radius * math.sin(angle)
            d_az = u * math.cos(tilt) - v * math.sin(tilt)
            d_el = u * math.sin(tilt) + v * math.cos(tilt)
            verts.append(head_point(az + d_az, el + d_el, inflate))
    for j in range(segments):
        faces.append((0, 1 + j, 1 + (j + 1) % segments))
    for ring in range(rings - 1):
        base = 1 + ring * segments
        nxt = base + segments
        for j in range(segments):
            faces.append((base + j, nxt + j,
                          nxt + (j + 1) % segments,
                          base + (j + 1) % segments))
    return obj_from(name, verts, faces, [material], bone, recalc=False)


def surface_strip(name, path, half_widths, material, inflate, bone="head",
                  thickness=0.002):
    """Ribbon laid on the head surface: path is [(az, el), ...]."""
    verts = []
    for i, (az, el) in enumerate(path):
        if i == 0:
            tangent = (path[1][0] - az, path[1][1] - el)
        elif i == len(path) - 1:
            tangent = (az - path[-2][0], el - path[-2][1])
        else:
            tangent = (path[i + 1][0] - path[i - 1][0],
                       path[i + 1][1] - path[i - 1][1])
        length = math.hypot(*tangent) or 1.0
        perp = (-tangent[1] / length, tangent[0] / length)
        half = half_widths[i]
        verts.append(head_point(az + perp[0] * half, el + perp[1] * half,
                                inflate))
        verts.append(head_point(az - perp[0] * half, el - perp[1] * half,
                                inflate))
    faces = []
    for i in range(len(path) - 1):
        a = i * 2
        b = i * 2 + 1
        c = (i + 1) * 2 + 1
        d = (i + 1) * 2
        faces.append((a, b, c, d))
    return obj_from(name, verts, faces, [material], bone, recalc=False,
                    solidify=(thickness, 0))


def build_face():
    for side, sign in (("L", 1.0), ("R", -1.0)):
        az = 25.0 * sign
        surface_patch(f"Eye_White_{side}", az, 1.4, 12.6, 9.2, "white", 0.006)
        surface_patch(f"Eye_Iris_{side}", az - 0.6 * sign, 0.4, 7.6, 8.0,
                      "eye_blue", 0.009)
        surface_patch(f"Eye_Iris_Low_{side}", az - 0.6 * sign, -2.0, 5.6, 4.6,
                      "eye_light", 0.0095)
        surface_patch(f"Eye_Pupil_{side}", az - 0.6 * sign, 0.6, 3.3, 3.8,
                      "eye_dark", 0.011)
        surface_patch(f"Eye_Glint_{side}", az - 3.2 * sign, 3.6, 2.2, 2.0,
                      "white", 0.013)
        surface_patch(f"Eye_Glint_Small_{side}", az + 2.4 * sign, -2.0, 1.0,
                      0.9, "white", 0.013)
        lash = [(az - 12.0 * sign + 12.0 * sign * (t / 10.0),
                 1.4 + 9.0 * math.sin(math.pi * 0.08 + math.pi * 0.84 * t / 10.0))
                for t in range(11)]
        surface_strip(f"Eye_Lash_{side}", lash, [1.35] * 11, "hair_dark",
                      0.012, thickness=0.003)
        brow = [(az - 12.0 * sign + 24.0 * sign * (t / 6.0),
                 15.0 - 2.0 * sign * (t / 6.0) * 0.0 + 2.2 * (t / 6.0) - 1.1)
                for t in range(7)]
        surface_strip(f"Brow_{side}", brow, [1.55, 1.65, 1.55, 1.4, 1.2, 0.95, 0.5],
                      "hair_dark", 0.011, thickness=0.003)
        ear = sphere(f"Ear_{side}", head_point(82.0 * sign, -4.0, 0.005),
                     (0.045, 0.075, 0.105), "skin", "head", 20, 12)
        sphere(f"Ear_Inner_{side}",
               head_point(86.0 * sign, -4.0, 0.012),
               (0.020, 0.038, 0.060), "skin_shadow", "head", 16, 10)
    sphere("Nose", head_point(0.0, -10.0, 0.020),
           (0.032, 0.040, 0.028), "skin_shadow", "head", 16, 10)
    mouth = [(-4.6 + 9.2 * t / 8.0,
              -26.2 + 1.5 * (abs(-4.6 + 9.2 * t / 8.0) / 4.6) ** 1.4)
             for t in range(9)]
    surface_strip("Mouth", mouth, [0.55] * 9, "leather_dark", 0.010,
                  thickness=0.0025)


def hairline(az_deg):
    """Elevation of the hairline for an azimuth (0 = face, 180 = nape)."""
    a = abs(((az_deg + 180.0) % 360.0) - 180.0)
    anchors = ((0.0, 36.0), (55.0, 30.0), (115.0, -6.0), (180.0, -42.0))
    for (a0, e0), (a1, e1) in zip(anchors, anchors[1:]):
        if a <= a1:
            t = (a - a0) / (a1 - a0)
            t = 0.5 - 0.5 * math.cos(math.pi * t)
            return e0 + (e1 - e0) * t
    return -42.0


def build_hair():
    columns = 49
    rows = 16
    verts = []
    for r in range(rows):
        t = r / (rows - 1.0)
        for j in range(columns):
            az = -180.0 + 360.0 * j / (columns - 1)
            line = hairline(az)
            el = line + t * (88.0 - line)
            inflate = 0.048 + 0.014 * (1.0 - t)
            verts.append(head_point(az, el, inflate))
    faces = []
    face_materials = []
    for r in range(rows - 1):
        for j in range(columns - 1):
            a = r * columns + j
            b = r * columns + j + 1
            c = (r + 1) * columns + j + 1
            d = (r + 1) * columns + j
            faces.append((a, b, c, d))
            if r < 4:
                face_materials.append(0)
            elif r < 11:
                face_materials.append(1)
            else:
                face_materials.append(2)
    pole = len(verts)
    verts.append(head_point(0.0, 90.0, 0.050))
    top_base = (rows - 1) * columns
    for j in range(columns - 1):
        faces.append((top_base + j, top_base + j + 1, pole))
        face_materials.append(2)
    obj_from("Hair_Cap", verts, faces,
             ["hair_dark", "hair_mid", "hair_light"], "head",
             face_materials=face_materials, recalc=False,
             solidify=(0.012, 0))
    make_locks()


def lock(name, path, widths, thickness=None, stops=None):
    points = [head_point(az, el, inflate) for az, el, inflate in path]
    flats = [head_normal(az, el) for az, el, _ in path]
    return sweep(name, points, widths, "hair_mid", "head", sides=6,
                 thickness=thickness or [width * 0.30 for width in widths],
                 flats=flats, tip=True,
                 material_stops=stops or [(0.0, "hair_dark"),
                                          (0.34, "hair_mid"),
                                          (0.70, "hair_light")])


def make_locks():
    bangs = [
        ((-8, 64, .05), (-4, 46, .06), (6, 30, .065), (18, 18, .07),
         (.120, .105, .070, .012)),
        ((10, 63, .05), (20, 46, .06), (30, 32, .065), (40, 20, .06),
         (.115, .100, .065, .012)),
        ((-26, 60, .05), (-20, 43, .06), (-10, 30, .065), (2, 20, .06),
         (.110, .100, .070, .012)),
        ((26, 57, .05), (36, 42, .06), (48, 28, .065), (58, 16, .055),
         (.105, .095, .060, .012)),
        ((-42, 54, .05), (-38, 38, .06), (-30, 24, .065), (-20, 14, .05),
         (.100, .090, .055, .010)),
        ((-56, 48, .05), (-56, 30, .06), (-52, 14, .06), (-44, 2, .05),
         (.095, .085, .050, .010)),
        ((44, 52, .05), (52, 36, .06), (62, 22, .06), (70, 10, .05),
         (.100, .085, .050, .010)),
        ((-18, 66, .05), (-8, 58, .06), (6, 50, .065), (20, 42, .06),
         (.110, .095, .060, .012)),
    ]
    for index, (a, b, c, d, widths) in enumerate(bangs):
        lock(f"Hair_Bang_{index}", [a, b, c, d], list(widths))
    for side, sign in (("L", 1.0), ("R", -1.0)):
        lock(f"Hair_Side_{side}", [
            (66 * sign, 26, .05), (70 * sign, 6, .06),
            (72 * sign, -14, .06), (70 * sign, -36, .05)],
            [.115, .105, .075, .015])
        lock(f"Hair_Side_Outer_{side}", [
            (80 * sign, 20, .05), (86 * sign, -2, .06),
            (88 * sign, -22, .05), (84 * sign, -40, .04)],
            [.095, .085, .055, .012])
    spikes = [
        (-150, .11), (-110, .105), (-70, .10), (-25, .12),
        (15, .115), (55, .105), (95, .10), (135, .105),
    ]
    for index, (az, width) in enumerate(spikes):
        lock(f"Hair_Crown_{index}", [
            (az, 82, .04), (az + 6, 72, .12),
            (az + 14, 60, .20), (az + 18, 52, .24)],
            [width, width * .85, width * .45, .012])
    for index, az in enumerate((120, 145, 165, 195, 215, 240)):
        lock(f"Hair_Back_{index}", [
            (az, 70, .05), (az, 40, .06), (az, 10, .07),
            (az, -20, .07), (az, -44, .06)],
            [.115, .105, .085, .055, .014])
    shines = [
        ((-2, 52, .085), (8, 38, .095), (20, 24, .10)),
        ((18, 50, .085), (30, 36, .095), (42, 24, .10)),
        ((-34, 46, .085), (-26, 32, .095), (-16, 22, .09)),
    ]
    for index, path in enumerate(shines):
        points = [head_point(*p) for p in path]
        flats = [head_normal(p[0], p[1]) for p in path]
        sweep(f"Hair_Shine_{index}", points, [.022, .030, .010],
              "hair_shine", "head", sides=4,
              thickness=[.008, .010, .004], flats=flats, tip=True)
# ----------------------------------------------------------------- rig -----

def make_armature():
    global ARM
    data = bpy.data.armatures.new("Ranger_Armature")
    ARM = bpy.data.objects.new("Ranger_Rig", data)
    bpy.context.collection.objects.link(ARM)
    bpy.context.view_layer.objects.active = ARM
    ARM.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = {
        "root": ((0, 0, 0.0), (0, 0, 0.25), None),
        "hips": ((0, 0, 1.18), (0, 0, 1.40), "root"),
        "spine": ((0, 0, 1.40), (0, 0, 1.72), "hips"),
        "chest": ((0, 0, 1.72), (0, 0, 2.06), "spine"),
        "neck": ((0, 0, 2.06), (0, 0, 2.16), "chest"),
        "head": ((0, 0, 2.16), (0, 0, 3.06), "neck"),
        "shoulder.L": ((0.10, 0, 2.02), (0.33, 0, 2.00), "chest"),
        "shoulder.R": ((-0.10, 0, 2.02), (-0.33, 0, 2.00), "chest"),
        "upper_arm.L": ((0.33, 0, 2.00), (0.47, 0, 1.73), "shoulder.L"),
        "upper_arm.R": ((-0.33, 0, 2.00), (-0.47, 0, 1.73), "shoulder.R"),
        "forearm.L": ((0.47, 0, 1.73), (0.545, -0.02, 1.45), "upper_arm.L"),
        "forearm.R": ((-0.47, 0, 1.73), (-0.545, -0.02, 1.45), "upper_arm.R"),
        "hand.L": ((0.545, -0.02, 1.45), (0.565, -0.05, 1.33), "forearm.L"),
        "hand.R": ((-0.545, -0.02, 1.45), (-0.565, -0.05, 1.33), "forearm.R"),
        "thigh.L": ((0.18, 0, 1.22), (0.20, 0, 0.78), "hips"),
        "thigh.R": ((-0.18, 0, 1.22), (-0.20, 0, 0.78), "hips"),
        "shin.L": ((0.20, 0, 0.78), (0.21, 0, 0.34), "thigh.L"),
        "shin.R": ((-0.20, 0, 0.78), (-0.21, 0, 0.34), "thigh.R"),
        "foot.L": ((0.21, 0, 0.34), (0.21, -0.22, 0.12), "shin.L"),
        "foot.R": ((-0.21, 0, 0.34), (-0.21, -0.22, 0.12), "shin.R"),
        "cloak_a": ((0, 0.17, 2.03), (0, 0.25, 1.53), "chest"),
        "cloak_b": ((0, 0.25, 1.53), (0, 0.32, 0.98), "cloak_a"),
        "cloak_c": ((0, 0.32, 0.98), (0, 0.40, 0.38), "cloak_b"),
        "bow": ((0.56, -0.06, 1.40), (0.56, -0.06, 1.85), "hand.L"),
        "string_rest": ((0.56, -0.13, 1.40), (0.56, -0.13, 1.85), "bow"),
        "string_drawn": ((0.56, 0.18, 1.40), (0.56, 0.18, 1.85), "bow"),
        "fx": ((0.56, -0.15, 1.40), (0.56, -0.15, 1.85), "bow"),
        "fx_draw": ((0.56, 0.18, 1.40), (0.56, -0.10, 1.40), "bow"),
        "aura": ((0, 0, 0.10), (0, 0, 1.30), "hips"),
        "quiver": ((-0.20, 0.26, 1.55), (-0.33, 0.33, 2.10), "chest"),
    }
    for name, (head, tail, parent) in bones.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = data.edit_bones[parent]
            bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    ARM.select_set(False)
    ARM.show_in_front = True
    return ARM


# -------------------------------------------------------------- helpers -----

def ring_at(name, a, b, t, major, minor, material, bone=None):
    a, b = Vector(a), Vector(b)
    center = a.lerp(b, t)
    direction = (b - a).normalized()
    rotation = direction.to_track_quat("Z", "Y").to_euler()
    return torus(name, center, major, minor, material, bone,
                 rotation=rotation, major_segments=28, minor_segments=8)


def front_band(name, z0, z1, rx, ry, az0, az1, material, bone,
               columns=20, thickness=0.016, bulge=0.012):
    rows = []
    for (z, extra) in ((z0, 0.0), ((z0 + z1) * 0.5, bulge), (z1, 0.0)):
        row = []
        for j in range(columns):
            az = math.radians(az0 + (az1 - az0) * j / (columns - 1))
            row.append(Vector(((rx + extra) * math.sin(az),
                               -(ry + extra) * math.cos(az), z)))
        rows.append(row)
    return grid_sheet(name, rows, [material], bone,
                      solidify=(thickness, 0))


def arc_band(name, rows_spec, material, bone, az0, az1, columns=16,
             thickness=0.014):
    rows = []
    for z, extra in rows_spec:
        row = []
        for j in range(columns):
            az = math.radians(az0 + (az1 - az0) * j / (columns - 1))
            row.append(Vector(((0.30 + extra) * math.sin(az),
                               -(0.22 + extra) * math.cos(az), z)))
        rows.append(row)
    return grid_sheet(name, rows, [material], bone,
                      solidify=(thickness, 0))


# --------------------------------------------------------------- body ------

def build_torso():
    lower = [
        (1.12, 0, 0, 0.250, 0.190), (1.26, 0, 0, 0.278, 0.205),
        (1.40, 0, 0, 0.268, 0.202), (1.54, 0, 0, 0.272, 0.206),
        (1.66, 0, 0, 0.282, 0.212),
    ]
    upper = [
        (1.58, 0, 0, 0.276, 0.208), (1.72, 0, 0, 0.292, 0.218),
        (1.86, 0, 0, 0.320, 0.232), (1.98, 0, 0, 0.342, 0.242),
        (2.06, 0, 0, 0.276, 0.216), (2.10, 0, 0, 0.190, 0.170),
    ]
    loft("Torso_Lower", lower, "green_deep", "spine")
    loft("Torso_Upper", upper, "green_deep", "chest")
    loft("Pelvis", [(1.04, 0, 0, 0.222, 0.180),
                    (1.14, 0, 0, 0.268, 0.200),
                    (1.30, 0, 0, 0.280, 0.206),
                    (1.38, 0, 0, 0.262, 0.198)], "trouser", "hips")
    for index, (z0, z1, broad) in enumerate((
            (1.57, 1.68, 0.0), (1.69, 1.80, 0.012),
            (1.81, 1.92, 0.020), (1.93, 2.01, 0.018))):
        front_band(f"Chest_Band_{index}", z0, z1, 0.335 + broad,
                   0.240 + broad * 0.65, -78, 78, "leather", "chest",
                   thickness=0.014, bulge=0.010)
        front_band(f"Chest_Trim_{index}", z1 - 0.012, z1 + 0.004,
                   0.342 + broad, 0.246 + broad * 0.65, -78, 78,
                   "bronze", "chest", thickness=0.008, bulge=0.008)
    front_band("Chest_Center_Plate", 1.62, 2.01, 0.352, 0.252, -15, 15,
               "leather_dark", "chest", columns=8, thickness=0.020,
               bulge=0.020)
    front_band("Chest_Center_Trim", 1.98, 2.015, 0.360, 0.258, -15, 15,
               "bronze_light", "chest", columns=8, thickness=0.010)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        for index, (z, scale, material) in enumerate((
                (2.02, (0.255, 0.270, 0.165), "bronze"),
                (1.93, (0.215, 0.240, 0.110), "bronze"),
                (1.85, (0.175, 0.205, 0.080), "leather_dark"))):
            sphere(f"Pauldron_{side}_{index}",
                   (0.365 * sign, 0.0, z), scale, material, "chest",
                   segments=28, rings=16)
        sphere(f"Pauldron_Inset_{side}", (0.335 * sign, -0.01, 2.115),
               (0.150, 0.175, 0.055), "green", "chest", 24, 12)
        torus(f"Pauldron_Rim_{side}", (0.365 * sign, 0.0, 1.990),
              0.215, 0.012, "bronze_light", "chest",
              scale=(1.0, 1.05, 0.68), major_segments=32)
    torus("Belt", (0, 0, 1.395), 0.278, 0.055, "leather_dark", "hips",
          scale=(1.0, 0.80, 0.9), major_segments=40)
    box("Buckle", (0, -0.250, 1.395), (0.165, 0.055, 0.130),
        "gold", "hips", bevel=0.012)
    box("Buckle_Pin", (0, -0.280, 1.395), (0.020, 0.020, 0.085),
        "bronze_light", "hips", bevel=0.006)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        az0, az1 = (22, 66) if sign > 0 else (-66, -22)
        front_band(f"Hip_Plate_{side}", 1.10, 1.30, 0.285, 0.205,
                   az0, az1, "bronze", "hips", columns=12,
                   thickness=0.020)
        front_band(f"Hip_Trim_{side}", 1.285, 1.305, 0.290, 0.210,
                   az0, az1, "bronze_light", "hips", columns=12,
                   thickness=0.010)
    torus("Collar", (0, 0.020, 2.075), 0.155, 0.055, "green_deep",
          "chest", scale=(1.15, 1.0, 0.75), major_segments=32)
    sphere("Hood_Down", (0, 0.195, 2.225), (0.265, 0.175, 0.235),
           "green", "chest", 28, 16)
    torus("Cloak_Clasp", (0, -0.245, 2.045), 0.045, 0.017, "gold",
          "chest", rotation=(math.radians(90), 0, 0), major_segments=28)
    sphere("Cloak_Gem", (0, -0.268, 2.045), (0.030, 0.020, 0.030),
           "green_bright", "chest", 16, 10)
    for index, (az, z) in enumerate(((-30, 1.70), (30, 1.70),
                                     (-30, 1.90), (30, 1.90))):
        stud = math.radians(az)
        sphere(f"Chest_Stud_{index}",
               ((0.352) * math.sin(stud), -(0.256) * math.cos(stud), z),
               (0.018, 0.010, 0.018), "bronze_light", "chest", 12, 8)


# --------------------------------------------------------------- limbs -----

def build_limbs():
    for side, sign in (("L", 1.0), ("R", -1.0)):
        shoulder = Vector((0.34 * sign, 0, 2.00))
        elbow = Vector((0.47 * sign, 0, 1.73))
        wrist = Vector((0.545 * sign, -0.02, 1.45))
        hand = Vector((0.559 * sign, -0.045, 1.375))
        sweep(f"Sleeve_{side}", [shoulder, elbow], [0.240, 0.192],
              "green", f"upper_arm.{side}", sides=16,
              thickness=[0.224, 0.182])
        sweep(f"Bracer_{side}", [elbow, wrist], [0.222, 0.176],
              "leather", f"forearm.{side}", sides=16,
              thickness=[0.210, 0.168])
        ring_at(f"Bracer_Strap_{side}_0", elbow, wrist, 0.34,
                0.106, 0.013, "leather_dark", f"forearm.{side}")
        ring_at(f"Bracer_Strap_{side}_1", elbow, wrist, 0.72,
                0.094, 0.012, "leather_dark", f"forearm.{side}")
        box(f"Bracer_Buckle_{side}", (0.525 * sign, -0.118, 1.585),
            (0.026, 0.018, 0.040), "gold", f"forearm.{side}",
            bevel=0.005)
        sphere(f"Glove_{side}", hand, (0.096, 0.100, 0.112),
               "green", f"hand.{side}", 24, 14)
        sphere(f"Thumb_{side}", (0.492 * sign, -0.108, 1.365),
               (0.038, 0.052, 0.048), "green", f"hand.{side}", 16, 10)
        ring_at(f"Glove_Cuff_{side}", wrist, hand, 0.10,
                0.090, 0.015, "leather_dark", f"hand.{side}")

        hip = Vector((0.18 * sign, 0, 1.23))
        knee = Vector((0.20 * sign, 0, 0.79))
        ankle = Vector((0.21 * sign, 0, 0.36))
        boot_low = Vector((0.21 * sign, 0, 0.20))
        sweep(f"Thigh_{side}", [hip, knee], [0.270, 0.228],
              "trouser", f"thigh.{side}", sides=16,
              thickness=[0.252, 0.214])
        sweep(f"Boot_Shaft_{side}", [knee, ankle, boot_low],
              [0.236, 0.204, 0.172], "green", f"shin.{side}", sides=16,
              thickness=[0.226, 0.196, 0.164])
        sphere(f"Knee_Plate_{side}", (0.20 * sign, -0.082, 0.795),
               (0.112, 0.070, 0.092), "bronze", f"thigh.{side}",
               24, 14)
        sphere(f"Knee_Cap_{side}", (0.20 * sign, -0.116, 0.806),
               (0.060, 0.028, 0.052), "bronze_light", f"thigh.{side}",
               18, 10)
        front_band(f"Shin_Plate_{side}", 0.48, 0.70, 0.118, 0.104,
                   -55, 55, "bronze", f"shin.{side}", columns=12,
                   thickness=0.014)
        torus(f"Boot_Cuff_{side}", (0.204 * sign, 0, 0.735),
              0.108, 0.022, "leather", f"shin.{side}",
              major_segments=28)
        ring_at(f"Boot_Strap_{side}", knee, ankle, 0.55,
                0.094, 0.013, "leather_dark", f"shin.{side}")
        foot_center = (0.21 * sign, -0.085, 0.110)
        sphere(f"Boot_Foot_{side}", foot_center, (0.136, 0.216, 0.102),
               "green", f"foot.{side}", 24, 14)
        box(f"Sole_{side}", (0.21 * sign, -0.095, 0.034),
            (0.252, 0.410, 0.068), "leather_dark", f"foot.{side}",
            bevel=0.024)
        sphere(f"Toe_Cap_{side}", (0.21 * sign, -0.272, 0.102),
               (0.118, 0.072, 0.068), "leather", f"foot.{side}", 20, 12)


# --------------------------------------------------------------- cloak -----

def cloak_rows(v0, v1, rows=10, columns=33):
    out = []
    for i in range(rows):
        v = v0 + (v1 - v0) * i / (rows - 1)
        row = []
        for j in range(columns):
            u = -1.0 + 2.0 * j / (columns - 1)
            x = u * (0.40 + 0.31 * v)
            y = 0.155 + 0.275 * v + 0.045 * math.sin(u * 9.0 + 0.7) * (0.25 + 0.75 * v)
            z = 2.075 - 1.70 * v + 0.055 * math.cos(u * 6.0) * v ** 5
            row.append(Vector((x, y, z)))
        out.append(row)
    return out


def build_cloak():
    for index, (bone, v0, v1) in enumerate((
            ("cloak_a", 0.0, 0.42), ("cloak_b", 0.32, 0.74),
            ("cloak_c", 0.64, 1.0))):
        grid_sheet(f"Cloak_{index}", cloak_rows(v0, v1),
                   ["green", "green_deep"], bone,
                   solidify=(0.028, 1), recalc=False)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        rows = []
        for i in range(5):
            u = i / 4.0
            row = []
            for j in range(9):
                step = j if sign < 0 else 8 - j
                v = step / 8.0
                x = sign * (0.065 + 0.355 * u)
                y = -0.225 + 0.48 * v
                z = 2.090 - 0.085 * math.sin(math.pi * v) - 0.105 * u
                z += 0.018 * math.sin(u * 7.0 + v * 3.0)
                row.append(Vector((x, y, z)))
            rows.append(row)
        grid_sheet(f"Shoulder_Mantle_{side}", rows, ["green"],
                   "chest", solidify=(0.020, 1), recalc=False)


# ---------------------------------------------------------------- gear -----

def build_quiver():
    start = Vector((-0.20, 0.255, 1.52))
    end = Vector((-0.335, 0.330, 2.10))
    sweep("Quiver", [start, end], [0.150, 0.135], "leather_dark",
          "quiver", sides=16, thickness=[0.145, 0.130])
    ring_at("Quiver_Rim", start, end, 0.97, 0.072, 0.016, "bronze", "quiver")
    axis = (end - start).normalized()
    for index in range(5):
        offset = Vector((0.030 * math.cos(index * 1.7),
                         0.020 * math.sin(index * 1.3), 0.0))
        base = end - axis * 0.10 + offset
        tip = end + axis * (0.24 + 0.018 * index) + offset
        sweep(f"Arrow_{index}", [base, tip], [0.016, 0.014],
              "bronze_light", "quiver", sides=6, thickness=[0.016, 0.014])
        fletch = tip - axis * 0.10
        sphere(f"Fletch_{index}", fletch, (0.030, 0.016, 0.080),
               "green_bright", "quiver", 12, 8)


def build_bow():
    up = [Vector((0.56, -0.06, 1.40)), Vector((0.56, -0.20, 1.58)),
          Vector((0.56, -0.30, 1.78)), Vector((0.56, -0.26, 1.96)),
          Vector((0.56, -0.13, 2.10))]
    down = [Vector((0.56, -0.06, 1.40)), Vector((0.56, -0.20, 1.22)),
            Vector((0.56, -0.30, 1.02)), Vector((0.56, -0.26, 0.84)),
            Vector((0.56, -0.13, 0.70))]
    widths = [0.045, 0.036, 0.031, 0.024, 0.014]
    for index, limb in enumerate((up, down)):
        sweep(f"Bow_Limb_{index}", limb, widths, "energy_core", "bow",
              sides=8, thickness=widths, tip=True)
    for index, limb in enumerate((up, down)):
        sweep(f"Bow_Glow_{index}", limb, [w * 2.35 for w in widths],
              "energy_soft", "bow", sides=8,
              thickness=[w * 2.35 for w in widths], tip=True)
    sweep("Bow_Grip", [Vector((0.56, -0.06, 1.31)),
                       Vector((0.56, -0.06, 1.49))],
          [0.075, 0.075], "leather_dark", "bow", sides=12,
          thickness=[0.075, 0.075])
    ring_at("Bow_Grip_Ring_0", Vector((0.56, -0.06, 1.31)),
            Vector((0.56, -0.06, 1.49)), 0.10, 0.043, 0.010,
            "gold", "bow")
    ring_at("Bow_Grip_Ring_1", Vector((0.56, -0.06, 1.31)),
            Vector((0.56, -0.06, 1.49)), 0.90, 0.043, 0.010,
            "gold", "bow")
    sphere("Bow_Gem", (0.56, -0.105, 1.40), (0.030, 0.028, 0.050),
           "green_bright", "bow", 16, 10)
    sweep("String_Rest", [Vector((0.56, -0.13, 2.105)),
                          Vector((0.56, -0.13, 0.695))],
          [0.007, 0.007], "string_glow", "string_rest", sides=4,
          thickness=[0.007, 0.007])
    nock = Vector((0.56, 0.185, 1.40))
    sweep("String_Drawn", [Vector((0.56, -0.13, 2.105)), nock,
                           Vector((0.56, -0.13, 0.695))],
          [0.007, 0.007, 0.007], "string_glow", "string_drawn",
          sides=4, thickness=[0.007, 0.007, 0.007])
    # Nocked energy arrow: from the drawn nock towards the bow.
    sweep("Nocked_Arrow", [Vector((0.56, 0.30, 1.40)),
                           Vector((0.56, -0.20, 1.40))],
          [0.020, 0.014], "energy_core", "fx_draw", sides=6,
          thickness=[0.020, 0.014])
    cone = bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.045,
                                           radius2=0.0, depth=0.13,
                                           location=(0.56, -0.255, 1.40),
                                           rotation=(math.radians(90), 0, 0))
    arrow_tip = bpy.context.object
    arrow_tip.name = "Arrow_Head"
    arrow_tip.data.materials.append(MATS["energy_core"])
    smooth(arrow_tip)
    attach(arrow_tip, "fx_draw")
    sphere("Draw_Glow", (0.56, 0.185, 1.40), (0.070, 0.060, 0.070),
           "energy_soft", "fx_draw", 16, 10)


def build_fx():
    torus("Release_Ring", (0.56, -0.12, 1.40), 0.27, 0.014,
          "energy_soft", "fx", rotation=(0, math.radians(90), 0),
          major_segments=36)
    for index, angle in enumerate((15, 70, 125, 200, 255, 310)):
        rad = math.radians(angle)
        start = Vector((0.56 + 0.10 * math.cos(rad), -0.16,
                        1.40 + 0.10 * math.sin(rad)))
        mid = Vector((0.56 + 0.28 * math.cos(rad), -0.20,
                      1.40 + 0.28 * math.sin(rad)))
        end = Vector((0.56 + 0.44 * math.cos(rad), -0.28,
                      1.40 + 0.44 * math.sin(rad)))
        sweep(f"Release_Streak_{index}", [start, mid, end],
              [0.035, 0.022, 0.006], "energy", "fx", sides=5,
              thickness=[0.020, 0.012, 0.004], tip=True)
    torus("Aura_Ring", (0, 0, 0.045), 0.52, 0.020, "energy_soft",
          "aura", scale=(1.0, 0.85, 1.0), major_segments=48)
    for index, angle in enumerate((0, 60, 120, 180, 240, 300)):
        rad = math.radians(angle)
        base = Vector((0.52 * math.cos(rad), 0.44 * math.sin(rad), 0.06))
        mid = base + Vector((0.05 * math.cos(rad), 0.04 * math.sin(rad), 0.42))
        top = base + Vector((0.12 * math.cos(rad), 0.09 * math.sin(rad), 0.78))
        sweep(f"Aura_Flame_{index}", [base, mid, top],
              [0.075, 0.045, 0.006], "energy", "aura", sides=5,
              thickness=[0.030, 0.020, 0.004], tip=True)
    sphere("Draw_Spark", (0.56, 0.185, 1.40), (0.050, 0.045, 0.050),
           "energy_core", "fx_draw", 14, 8)
# ----------------------------------------------------------- materials -----

def build_materials():
    MATS.update({
        "green": toon("Forest Green Cloth", "green", rim="green_bright"),
        "green_light": toon("Lit Green Cloth", "green_light"),
        "green_deep": toon("Deep Green Cloth", "green_deep"),
        "green_bright": toon("Bright Green Accent", "green_bright"),
        "trouser": toon("Olive Trousers", "trouser"),
        "leather": toon("Chestnut Leather", "leather", rim="bronze_light"),
        "leather_dark": toon("Dark Leather", "leather_dark"),
        "bronze": toon("Aged Bronze Plate", "bronze", rim="bronze_light"),
        "bronze_light": toon("Bronze Edge", "bronze_light"),
        "gold": toon("Brass Buckle", "gold", rim="bronze_light"),
        "skin": toon("Warm Skin", "skin", rim="skin_light"),
        "skin_shadow": toon("Skin Shadow", "skin_shadow"),
        "hair_dark": toon("Hair Roots", "hair_dark"),
        "hair_mid": toon("Hair Body", "hair_mid", rim="hair_shine"),
        "hair_light": toon("Hair Tips", "hair_light"),
        "hair_shine": toon("Hair Highlight", "hair_shine"),
        "eye_blue": toon("Sapphire Iris", "eye_blue"),
        "eye_light": toon("Iris Glow", "eye_light"),
        "eye_dark": toon("Pupil", "eye_dark"),
        "white": toon("Eye White", "white"),
        "energy_core": glow("Energy Core", "bow_core", 7.0),
        "energy": glow("Energy Streak", "energy", 5.0),
        "energy_soft": glow("Energy Glow", "bow_glow", 2.6, 0.34),
        "string_glow": glow("Bow String", "bow_core", 4.0),
    })


# ---------------------------------------------------------- animations -----

def P(rot=None, loc=None, scale=None):
    return dict(rot or {}), dict(loc or {}), dict(scale or {})


BASE = {
    "upper_arm.L": (-3, 0, 4), "forearm.L": (-6, 0, 0),
    "upper_arm.R": (3, 0, -4), "forearm.R": (-6, 0, 0),
    "thigh.L": (-2, 0, 0), "thigh.R": (2, 0, 0),
    "cloak_a": (2, 0, 0), "cloak_b": (3, 0, 0), "cloak_c": (4, 0, 0),
}


def merged(*parts):
    out = {}
    for part in parts:
        out.update(part)
    return out


def build_actions():
    idle = [
        (1, *P(BASE)),
        (7, *P(merged(BASE, {
            "chest": (1.8, 0, 0), "head": (-1.2, 0, 0),
            "upper_arm.L": (-5, 0, 5), "upper_arm.R": (5, 0, -5),
            "cloak_a": (4, 0, 0), "cloak_b": (6, 0, 0), "cloak_c": (8, 0, 0),
        }), loc={"root": (0, 0.012, 0)})),
        (13, *P(BASE)),
        (19, *P(merged(BASE, {
            "chest": (-1.0, 0, 0), "head": (1.0, 0, 0),
            "cloak_a": (1, 0, 0), "cloak_b": (2, 0, 0), "cloak_c": (2.5, 0, 0),
        }), loc={"root": (0, -0.004, 0)})),
        (25, *P(BASE)),
    ]
    walk_left = merged(BASE, {
        "thigh.L": (-30, 0, 0), "shin.L": (10, 0, 0), "foot.L": (18, 0, 0),
        "thigh.R": (24, 0, 0), "shin.R": (28, 0, 0), "foot.R": (-20, 0, 0),
        "upper_arm.L": (22, 0, 4), "forearm.L": (-14, 0, 0),
        "upper_arm.R": (-22, 0, -4), "forearm.R": (-26, 0, 0),
        "chest": (3, -4, 0), "head": (-2, 4, 0),
        "cloak_a": (7, 0, 0), "cloak_b": (10, 0, 0), "cloak_c": (13, 0, 0),
    })
    walk_right = merged(BASE, {
        "thigh.R": (-30, 0, 0), "shin.R": (10, 0, 0), "foot.R": (18, 0, 0),
        "thigh.L": (24, 0, 0), "shin.L": (28, 0, 0), "foot.L": (-20, 0, 0),
        "upper_arm.R": (22, 0, -4), "forearm.R": (-14, 0, 0),
        "upper_arm.L": (-22, 0, 4), "forearm.L": (-26, 0, 0),
        "chest": (3, 4, 0), "head": (-2, -4, 0),
        "cloak_a": (7, 0, 0), "cloak_b": (10, 0, 0), "cloak_c": (13, 0, 0),
    })
    walk_pass_a = merged(BASE, {
        "thigh.L": (-6, 0, 0), "shin.L": (22, 0, 0), "foot.L": (-8, 0, 0),
        "thigh.R": (-8, 0, 0), "shin.R": (14, 0, 0), "foot.R": (2, 0, 0),
        "upper_arm.L": (4, 0, 4), "upper_arm.R": (-4, 0, -4),
        "forearm.L": (-10, 0, 0), "forearm.R": (-12, 0, 0),
        "cloak_a": (4, 0, 0), "cloak_b": (6, 0, 0), "cloak_c": (8, 0, 0),
    })
    walk_pass_b = merged(BASE, {
        "thigh.R": (-6, 0, 0), "shin.R": (22, 0, 0), "foot.R": (-8, 0, 0),
        "thigh.L": (-8, 0, 0), "shin.L": (14, 0, 0), "foot.L": (2, 0, 0),
        "upper_arm.R": (4, 0, -4), "upper_arm.L": (-4, 0, 4),
        "forearm.R": (-10, 0, 0), "forearm.L": (-12, 0, 0),
        "cloak_a": (4, 0, 0), "cloak_b": (6, 0, 0), "cloak_c": (8, 0, 0),
    })
    walk = [
        (1, *P(walk_left, loc={"root": (0, 0.008, 0)})),
        (4, *P(walk_pass_a, loc={"root": (0, 0.032, 0)})),
        (7, *P(walk_right, loc={"root": (0, 0.008, 0)})),
        (10, *P(walk_pass_b, loc={"root": (0, 0.032, 0)})),
        (13, *P(walk_left, loc={"root": (0, 0.008, 0)})),
        (16, *P(walk_pass_a, loc={"root": (0, 0.032, 0)})),
        (19, *P(walk_right, loc={"root": (0, 0.008, 0)})),
        (22, *P(walk_pass_b, loc={"root": (0, 0.032, 0)})),
        (25, *P(walk_left, loc={"root": (0, 0.008, 0)})),
    ]
    run_left = merged(BASE, {
        "thigh.L": (-52, 0, 0), "shin.L": (26, 0, 0), "foot.L": (22, 0, 0),
        "thigh.R": (42, 0, 0), "shin.R": (72, 0, 0), "foot.R": (-28, 0, 0),
        "upper_arm.L": (38, 0, 6), "forearm.L": (-72, 0, 0),
        "upper_arm.R": (-46, 0, -6), "forearm.R": (-88, 0, 0),
        "chest": (14, -6, 0), "head": (-10, 6, 0),
        "cloak_a": (18, 0, 0), "cloak_b": (26, 0, 0), "cloak_c": (34, 0, 0),
    })
    run_right = merged(BASE, {
        "thigh.R": (-52, 0, 0), "shin.R": (26, 0, 0), "foot.R": (22, 0, 0),
        "thigh.L": (42, 0, 0), "shin.L": (72, 0, 0), "foot.L": (-28, 0, 0),
        "upper_arm.R": (38, 0, -6), "forearm.R": (-72, 0, 0),
        "upper_arm.L": (-46, 0, 6), "forearm.L": (-88, 0, 0),
        "chest": (14, 6, 0), "head": (-10, -6, 0),
        "cloak_a": (18, 0, 0), "cloak_b": (26, 0, 0), "cloak_c": (34, 0, 0),
    })
    run_air_a = merged(BASE, {
        "thigh.L": (-12, 0, 0), "shin.L": (34, 0, 0), "foot.L": (8, 0, 0),
        "thigh.R": (-24, 0, 0), "shin.R": (58, 0, 0), "foot.R": (-10, 0, 0),
        "upper_arm.L": (10, 0, 6), "forearm.L": (-60, 0, 0),
        "upper_arm.R": (-12, 0, -6), "forearm.R": (-66, 0, 0),
        "chest": (16, 0, 0), "head": (-12, 0, 0),
        "cloak_a": (28, 0, 0), "cloak_b": (38, 0, 0), "cloak_c": (48, 0, 0),
    })
    run_air_b = merged(BASE, {
        "thigh.R": (-12, 0, 0), "shin.R": (34, 0, 0), "foot.R": (8, 0, 0),
        "thigh.L": (-24, 0, 0), "shin.L": (58, 0, 0), "foot.L": (-10, 0, 0),
        "upper_arm.R": (10, 0, -6), "forearm.R": (-60, 0, 0),
        "upper_arm.L": (-12, 0, 6), "forearm.L": (-66, 0, 0),
        "chest": (16, 0, 0), "head": (-12, 0, 0),
        "cloak_a": (28, 0, 0), "cloak_b": (38, 0, 0), "cloak_c": (48, 0, 0),
    })
    run = [
        (1, *P(run_left, loc={"root": (0, 0.02, 0)})),
        (4, *P(run_air_a, loc={"root": (0, 0.10, 0)})),
        (7, *P(run_right, loc={"root": (0, 0.02, 0)})),
        (10, *P(run_air_b, loc={"root": (0, 0.10, 0)})),
        (13, *P(run_left, loc={"root": (0, 0.02, 0)})),
        (16, *P(run_air_a, loc={"root": (0, 0.10, 0)})),
        (19, *P(run_right, loc={"root": (0, 0.02, 0)})),
        (22, *P(run_air_b, loc={"root": (0, 0.10, 0)})),
        (25, *P(run_left, loc={"root": (0, 0.02, 0)})),
    ]
    raised = merged(BASE, {
        "upper_arm.L": (-55, 0, 12), "forearm.L": (-18, 0, 0),
        "upper_arm.R": (-40, 0, -25), "forearm.R": (-70, 0, 0),
        "chest": (0, 8, 0), "head": (0, -6, 0),
        "bow": (55, 0, -8), "cloak_a": (5, 0, 0),
    })
    drawn = merged(BASE, {
        "upper_arm.L": (-78, 0, 10), "forearm.L": (-10, 0, 0),
        "upper_arm.R": (-58, 0, -38), "forearm.R": (-112, 0, 0),
        "chest": (-2, 14, 0), "head": (2, -10, 0),
        "bow": (78, 0, -10), "cloak_a": (8, 0, 0),
    })
    release = merged(BASE, {
        "upper_arm.L": (-74, 0, 8), "forearm.L": (-14, 0, 0),
        "upper_arm.R": (-28, 0, -18), "forearm.R": (-55, 0, 0),
        "chest": (-4, 8, 0), "head": (3, -6, 0),
        "bow": (74, 0, -8), "cloak_a": (12, 0, 0),
    })
    attack = [
        (1, *P(BASE, scale={"string_rest": (1, 1, 1)})),
        (5, *P(raised, scale={"string_drawn": (1, 1, 1),
                              "string_rest": (0, 0, 0),
                              "fx_draw": (1, 1, 1)})),
        (9, *P(drawn, scale={"string_drawn": (1, 1, 1),
                             "string_rest": (0, 0, 0),
                             "fx_draw": (1, 1, 1)})),
        (13, *P(release, scale={"fx": (1.25, 1.25, 1.25)})),
        (17, *P(merged(BASE, {
            "upper_arm.L": (-46, 0, 6), "upper_arm.R": (-8, 0, -8),
            "forearm.R": (-22, 0, 0), "bow": (46, 0, -6),
            "cloak_a": (7, 0, 0),
        }))),
        (21, *P(merged(BASE, {
            "upper_arm.L": (-18, 0, 5), "upper_arm.R": (0, 0, -5),
            "bow": (18, 0, -3),
        }))),
        (25, *P(BASE)),
    ]
    charge = merged(BASE, {
        "upper_arm.L": (-96, 0, -10), "forearm.L": (-24, 0, 0),
        "upper_arm.R": (-96, 0, 10), "forearm.R": (-24, 0, 0),
        "chest": (-8, 0, 0), "head": (-10, 0, 0),
        "thigh.L": (-14, 0, 0), "thigh.R": (-14, 0, 0),
        "shin.L": (28, 0, 0), "shin.R": (28, 0, 0),
        "bow": (96, 0, 0), "cloak_a": (16, 0, 0),
        "cloak_b": (22, 0, 0), "cloak_c": (28, 0, 0),
    })
    leap = merged(charge, {
        "thigh.L": (-30, 0, 0), "thigh.R": (16, 0, 0),
        "shin.L": (46, 0, 0), "shin.R": (34, 0, 0),
        "chest": (-12, 0, 0),
    })
    volley = merged(BASE, {
        "upper_arm.L": (-60, 0, 6), "forearm.L": (-12, 0, 0),
        "upper_arm.R": (-18, 0, -10), "forearm.R": (-40, 0, 0),
        "chest": (10, 0, 0), "head": (4, 0, 0),
        "bow": (60, 0, -4), "cloak_a": (22, 0, 0),
        "cloak_b": (30, 0, 0), "cloak_c": (38, 0, 0),
    })
    skill = [
        (1, *P(BASE, scale={"string_rest": (1, 1, 1)})),
        (5, *P(charge, loc={"root": (0, 0.02, 0)},
               scale={"aura": (0.65, 0.65, 0.65), "fx": (0.45, 0.45, 0.45),
                      "fx_draw": (1, 1, 1),
                      "string_rest": (0, 0, 0), "string_drawn": (1, 1, 1)})),
        (9, *P(charge, loc={"root": (0, 0.04, 0)},
               scale={"aura": (1.0, 1.0, 1.0), "fx": (0.8, 0.8, 0.8),
                      "fx_draw": (1, 1, 1),
                      "string_rest": (0, 0, 0), "string_drawn": (1, 1, 1)})),
        (13, *P(leap, loc={"root": (0, 0.20, 0)},
                scale={"aura": (1.35, 1.35, 1.35), "fx": (1.1, 1.1, 1.1),
                       "fx_draw": (1, 1, 1),
                       "string_rest": (0, 0, 0), "string_drawn": (1, 1, 1)})),
        (17, *P(volley, loc={"root": (0, 0.08, 0)},
                scale={"fx": (1.7, 1.7, 1.7)})),
        (21, *P(merged(BASE, {
            "upper_arm.L": (-24, 0, 5), "upper_arm.R": (-4, 0, -5),
            "bow": (24, 0, -3), "thigh.L": (-12, 0, 0),
            "thigh.R": (-12, 0, 0), "shin.L": (24, 0, 0),
            "shin.R": (24, 0, 0),
        }), loc={"root": (0, -0.02, 0)}, scale={"fx": (0.5, 0.5, 0.5)})),
        (25, *P(merged(BASE, {
            "thigh.L": (-6, 0, 0), "thigh.R": (-6, 0, 0),
            "shin.L": (12, 0, 0), "shin.R": (12, 0, 0),
        }))),
        (29, *P(BASE)),
        (33, *P(BASE)),
    ]
    dodge = [
        (1, *P(BASE)),
        (3, *P(merged(BASE, {
            "thigh.L": (-32, 0, 0), "thigh.R": (-32, 0, 0),
            "shin.L": (62, 0, 0), "shin.R": (62, 0, 0),
            "foot.L": (-28, 0, 0), "foot.R": (-28, 0, 0),
            "chest": (18, 0, 0), "head": (6, 0, 0),
            "upper_arm.L": (-24, 0, 12), "upper_arm.R": (-24, 0, -12),
            "cloak_a": (8, 0, 0), "cloak_b": (12, 0, 0), "cloak_c": (16, 0, 0),
        }), loc={"root": (0, -0.12, 0)})),
        (5, *P(merged(BASE, {
            "thigh.L": (-44, 0, 0), "thigh.R": (-18, 0, 0),
            "shin.L": (70, 0, 0), "shin.R": (48, 0, 0),
            "chest": (24, 0, 10), "head": (10, 0, 6),
            "upper_arm.L": (-34, 0, 18), "upper_arm.R": (-20, 0, -8),
            "cloak_a": (24, 0, 0), "cloak_b": (32, 0, 0), "cloak_c": (40, 0, 0),
        }), loc={"root": (0.20, 0.16, 0)})),
        (7, *P(merged(BASE, {
            "thigh.L": (-54, 0, 0), "thigh.R": (-34, 0, 0),
            "shin.L": (92, 0, 0), "shin.R": (78, 0, 0),
            "chest": (28, 0, 8), "head": (12, 0, 4),
            "upper_arm.L": (-18, 0, 26), "upper_arm.R": (-18, 0, -20),
            "cloak_a": (34, 0, 0), "cloak_b": (44, 0, 0), "cloak_c": (54, 0, 0),
        }), loc={"root": (0.30, 0.24, 0)})),
        (9, *P(merged(BASE, {
            "thigh.L": (-24, 0, 0), "thigh.R": (-8, 0, 0),
            "shin.L": (48, 0, 0), "shin.R": (30, 0, 0),
            "chest": (12, 0, 4), "head": (4, 0, 2),
            "cloak_a": (20, 0, 0), "cloak_b": (26, 0, 0), "cloak_c": (32, 0, 0),
        }), loc={"root": (0.32, 0.10, 0)})),
        (11, *P(merged(BASE, {
            "thigh.L": (-36, 0, 0), "thigh.R": (-28, 0, 0),
            "shin.L": (68, 0, 0), "shin.R": (58, 0, 0),
            "foot.L": (-24, 0, 0), "foot.R": (-24, 0, 0),
            "chest": (20, 0, 0),
            "cloak_a": (10, 0, 0), "cloak_b": (14, 0, 0), "cloak_c": (18, 0, 0),
        }), loc={"root": (0.30, -0.10, 0)})),
        (13, *P(merged(BASE, {
            "thigh.L": (-18, 0, 0), "thigh.R": (-14, 0, 0),
            "shin.L": (34, 0, 0), "shin.R": (28, 0, 0),
            "chest": (8, 0, 0),
        }), loc={"root": (0.18, -0.02, 0)})),
        (15, *P(merged(BASE, {}), loc={"root": (0.06, 0.0, 0)})),
        (17, *P(BASE)),
    ]
    hit = [
        (1, *P(BASE)),
        (3, *P(merged(BASE, {
            "chest": (-14, 0, 0), "head": (-14, 0, 0),
            "upper_arm.L": (-18, 0, 20), "upper_arm.R": (-18, 0, -20),
            "forearm.L": (-16, 0, 0), "forearm.R": (-16, 0, 0),
            "cloak_a": (-8, 0, 0), "cloak_b": (-12, 0, 0), "cloak_c": (-16, 0, 0),
        }))),
        (5, *P(merged(BASE, {
            "chest": (-20, 0, 0), "head": (-18, 0, -4),
            "upper_arm.L": (-26, 0, 26), "upper_arm.R": (-26, 0, -26),
            "forearm.L": (-24, 0, 0), "forearm.R": (-24, 0, 0),
            "thigh.L": (6, 0, 0), "thigh.R": (6, 0, 0),
            "cloak_a": (-12, 0, 0), "cloak_b": (-16, 0, 0), "cloak_c": (-20, 0, 0),
        }))),
        (7, *P(merged(BASE, {
            "chest": (-6, 0, 0), "head": (-4, 0, 0),
            "upper_arm.L": (-8, 0, 10), "upper_arm.R": (-8, 0, -10),
            "cloak_a": (2, 0, 0),
        }))),
        (9, *P(BASE)),
    ]
    death = [
        (1, *P(BASE)),
        (5, *P(merged(BASE, {
            "chest": (-12, 0, 0), "head": (-16, 0, 0),
            "upper_arm.L": (-16, 0, 24), "upper_arm.R": (-16, 0, -24),
            "cloak_a": (-10, 0, 0), "cloak_b": (-14, 0, 0), "cloak_c": (-18, 0, 0),
        }), loc={"root": (0, 0.0, 0.04)})),
        (9, *P(merged(BASE, {
            "thigh.L": (-38, 0, 0), "thigh.R": (-38, 0, 0),
            "shin.L": (76, 0, 0), "shin.R": (76, 0, 0),
            "chest": (-8, 0, 0), "head": (-12, 0, 0),
            "upper_arm.L": (-24, 0, 18), "upper_arm.R": (-24, 0, -18),
            "cloak_a": (4, 0, 0), "cloak_b": (8, 0, 0), "cloak_c": (12, 0, 0),
        }), loc={"root": (0, -0.28, 0.02)})),
        (13, *P(merged(BASE, {
            "root": (-38, 0, 0),
            "thigh.L": (-16, 0, 0), "thigh.R": (12, 0, 0),
            "shin.L": (44, 0, 0), "shin.R": (20, 0, 0),
            "upper_arm.L": (-30, 0, 30), "upper_arm.R": (-30, 0, -30),
            "chest": (6, 0, 0), "head": (10, 0, 0),
            "cloak_a": (10, 0, 0), "cloak_b": (16, 0, 0), "cloak_c": (22, 0, 0),
        }), loc={"root": (0, -0.22, 0.35)})),
        (17, *P(merged(BASE, {
            "root": (-74, 0, 0),
            "thigh.L": (-8, 0, 0), "thigh.R": (22, 0, 0),
            "shin.L": (34, 0, 0), "shin.R": (10, 0, 0),
            "upper_arm.L": (-10, 0, 46), "upper_arm.R": (-10, 0, -46),
            "chest": (10, 0, 0), "head": (16, 0, 0),
            "cloak_a": (16, 0, 0), "cloak_b": (24, 0, 0), "cloak_c": (30, 0, 0),
        }), loc={"root": (0, -0.10, 0.55)})),
        (21, *P(merged(BASE, {
            "root": (-90, 0, 0),
            "thigh.L": (-4, 0, 0), "thigh.R": (16, 0, 0),
            "shin.L": (22, 0, 0), "shin.R": (4, 0, 0),
            "upper_arm.L": (0, 0, 54), "upper_arm.R": (0, 0, -54),
            "chest": (12, 0, 0), "head": (20, 0, 0),
            "cloak_a": (20, 0, 0), "cloak_b": (28, 0, 0), "cloak_c": (34, 0, 0),
        }), loc={"root": (0, 0.0, 0.58)})),
        (25, *P(merged(BASE, {
            "root": (-92, 0, 0),
            "thigh.L": (-2, 0, 0), "thigh.R": (12, 0, 0),
            "shin.L": (16, 0, 0), "shin.R": (2, 0, 0),
            "upper_arm.L": (0, 0, 58), "upper_arm.R": (0, 0, -58),
            "chest": (10, 0, 0), "head": (18, 0, 0),
            "cloak_a": (18, 0, 0), "cloak_b": (26, 0, 0), "cloak_c": (32, 0, 0),
        }), loc={"root": (0, 0.0, 0.56)})),
        (29, *P(merged(BASE, {
            "root": (-92, 0, 0),
            "thigh.L": (-2, 0, 0), "thigh.R": (12, 0, 0),
            "shin.L": (16, 0, 0), "shin.R": (2, 0, 0),
            "upper_arm.L": (0, 0, 58), "upper_arm.R": (0, 0, -58),
            "chest": (10, 0, 0), "head": (18, 0, 0),
            "cloak_a": (18, 0, 0), "cloak_b": (26, 0, 0), "cloak_c": (32, 0, 0),
        }), loc={"root": (0, 0.0, 0.56)})),
        (33, *P(merged(BASE, {
            "root": (-92, 0, 0),
            "thigh.L": (-2, 0, 0), "thigh.R": (12, 0, 0),
            "shin.L": (16, 0, 0), "shin.R": (2, 0, 0),
            "upper_arm.L": (0, 0, 58), "upper_arm.R": (0, 0, -58),
            "chest": (10, 0, 0), "head": (18, 0, 0),
            "cloak_a": (18, 0, 0), "cloak_b": (26, 0, 0), "cloak_c": (32, 0, 0),
        }), loc={"root": (0, 0.0, 0.56)})),
    ]
    actions = {
        "Ranger_Idle": idle,
        "Ranger_Walk": walk,
        "Ranger_Run": run,
        "Ranger_Attack": attack,
        "Ranger_Skill": skill,
        "Ranger_Dodge": dodge,
        "Ranger_Hit": hit,
        "Ranger_Death": death,
    }
    for name, keys in actions.items():
        write_action(name, keys)
    clamp_action_to_ground("Ranger_Death", list(range(1, 34)))
    reset_pose()
    ARM.animation_data.action = bpy.data.actions["Ranger_Idle"]
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 33
    scene.frame_set(1)


def write_action(name, keys):
    action = bpy.data.actions.new(name)
    ARM.animation_data_create()
    ARM.animation_data.action = action
    for frame, rotations, locations, scales in keys:
        for bone in BONES:
            pose_bone = ARM.pose.bones[bone]
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = tuple(
                math.radians(value) for value in rotations.get(bone, (0, 0, 0)))
            pose_bone.location = locations.get(bone, (0.0, 0.0, 0.0))
            pose_bone.scale = scales.get(bone, DEFAULT_SCALE[bone])
            pose_bone.keyframe_insert("rotation_euler", frame=frame, group=bone)
            pose_bone.keyframe_insert("location", frame=frame, group=bone)
            pose_bone.keyframe_insert("scale", frame=frame, group=bone)
    for curve in action.fcurves:
        constant = "scale" in curve.data_path and any(
            bone in curve.data_path for bone in FX_BONES + ("string_rest",))
        for key in curve.keyframe_points:
            key.interpolation = "CONSTANT" if constant else "BEZIER"
            if not constant:
                key.handle_left_type = "AUTO_CLAMPED"
                key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    return action


def reset_pose():
    for bone in ARM.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.location = (0.0, 0.0, 0.0)
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)


def scene_mesh_bounds():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    low = Vector((math.inf, math.inf, math.inf))
    high = Vector((-math.inf, -math.inf, -math.inf))
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        matrix = evaluated.matrix_world
        for corner in evaluated.bound_box:
            point = matrix @ Vector(corner)
            low = Vector((min(low.x, point.x), min(low.y, point.y), min(low.z, point.z)))
            high = Vector((max(high.x, point.x), max(high.y, point.y), max(high.z, point.z)))
    return low, high


def clamp_action_to_ground(action_name, frames):
    scene = bpy.context.scene
    action = bpy.data.actions[action_name]
    ARM.animation_data.action = action
    root = ARM.pose.bones["root"]
    axis = root.bone.matrix_local.to_3x3().inverted() @ Vector((0.0, 0.0, 1.0))
    axis.normalize()
    base = {}
    lifts = {}
    for frame in frames:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        base[frame] = root.location.copy()
        low, _ = scene_mesh_bounds()
        lifts[frame] = round(max(0.0, -low.z), 4)
    for frame in frames:
        scene.frame_set(frame)
        root.location = base[frame] + axis * lifts[frame]
        root.keyframe_insert(data_path="location", frame=frame, group="root")
    for frame in frames:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        low, high = scene_mesh_bounds()
        print(f"GROUND_CLAMP {action_name}[{frame}] lift={lifts[frame]:.3f} "
              f"z={low.z:.3f}..{high.z:.3f}")
        if low.z < -0.001:
            print(f"RANGER_SOURCE_ERROR: {action_name}[{frame}] below ground "
                  f"at z={low.z:.3f}", file=sys.stderr)


# ---------------------------------------------------------------- scene -----

def setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.fps = 12
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    if hasattr(scene.eevee, "use_bloom"):
        scene.eevee.use_bloom = True
        scene.eevee.bloom_threshold = 0.85
        scene.eevee.bloom_intensity = 0.08
        scene.eevee.bloom_radius = 4.5
        scene.eevee.bloom_color = (0.62, 1.0, 0.55)
    if hasattr(scene.eevee, "use_gtao"):
        scene.eevee.use_gtao = True

    bpy.ops.object.camera_add(location=(0, -8.0, 2.85))
    camera = bpy.context.object
    camera.name = "Ranger_Orthographic_Camera"
    target = Vector((0, 0, 1.62))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.8
    scene.camera = camera

    lights = (
        ("Key_Softbox", (-4.0, -5.0, 6.0), 4.2, (1.0, 0.96, 0.88)),
        ("Fill_Softbox", (4.5, -3.0, 3.0), 1.5, (0.72, 0.84, 1.0)),
        ("Rim_Softbox", (0.0, 4.5, 5.0), 3.0, (0.86, 1.0, 0.82)),
    )
    for name, location, energy, color in lights:
        bpy.ops.object.light_add(type="SUN", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.angle = math.radians(12)
        light.rotation_euler = (Vector((0, 0, 1.55)) - light.location).to_track_quat("-Z", "Y").to_euler()


def main():
    global ARM
    clear_scene()
    build_materials()
    make_armature()
    build_head()
    build_face()
    build_hair()
    build_torso()
    build_limbs()
    build_cloak()
    build_quiver()
    build_bow()
    build_fx()
    build_actions()
    setup_scene()
    for name in ("root", "head", "upper_arm.L", "thigh.L", "bow", "cloak_a"):
        matrix = ARM.data.bones[name].matrix_local.to_3x3()
        print("BONE_AXES", name,
              [tuple(round(value, 3) for value in matrix.col[i]) for i in range(3)])
    print("MESH_PARTS", len([obj for obj in bpy.data.objects if obj.type == "MESH"]))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
    print(f"Saved reference-matched Ranger source: {OUT}")


if __name__ == "__main__":
    main()
