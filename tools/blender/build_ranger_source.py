"""Build the reference-matched, cel-shaded Ranger production scene.

Run:
  blender -b --python tools/blender/build_ranger_source.py

The character is original procedural geometry authored from the reference at
assets/heroes/ranger/ranger_reference_crop.png: a chibi male archer with short
thick brown hair, blue eyes, a knee-length green cloak, layered bronze-brown
armour over a green tunic, green bracers and boots, a glowing green energy
recurve bow with green energy effects, a quiver of arrows, and a brass cloak
clasp. Nothing is downloaded or traced; every mesh is generated here.

The rig is a rigid-skinning rig: every visible mesh remains unparented and is bound to exactly one deform bone by a single 1.0-weight vertex group and one Armature modifier.
Cloth secondary motion uses three overlapping cloak sections so the cloak can
flow without vertex-weight deformation.
"""
from __future__ import annotations

import math
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import hero_profiles  # noqa: E402  (needs the path insert above)


def builder():
    """The module object passed to profile hooks (they reuse our helpers)."""
    return sys.modules[__name__]


def active_hero_id():
    """Which hero this run builds, chosen by a checked-in one-line marker.

    The CI workflow cannot be edited (the push token has no `workflow` scope),
    so it always invokes this filename and the ranger output paths. The marker
    lets one hero at a time flow through that fixed pipeline while sharing the
    entire builder; the outputs are bundled back under the ranger path.
    """
    marker = Path(__file__).resolve().parent / "active_hero.txt"
    if not marker.is_file():
        return "ranger"
    value = marker.read_text(encoding="utf-8").strip().lower()
    return value or "ranger"


ACTIVE_HERO = active_hero_id()
if ACTIVE_HERO not in hero_profiles.PROFILES:
    raise SystemExit(f"Unknown active hero in active_hero.txt: {ACTIVE_HERO}")
PROFILE = hero_profiles.PROFILES[ACTIVE_HERO]

# The workflow renders whatever this fixed path holds, and the artifact upload
# only collects the ranger paths. Each hero is therefore written to the fixed
# CI path, to its own repo path, and into the bundle directory the artifact
# picks up so the downloaded hero survives the read-only CI checkout.
OUT = ROOT / "assets/heroes/ranger/source/ranger_source.blend"
HERO_OUT = ROOT / f"assets/heroes/{ACTIVE_HERO}/source/{ACTIVE_HERO}_source.blend"
BUNDLE = ROOT / f"assets/heroes/ranger/renders/_bundle/{ACTIVE_HERO}"


HEAD_CENTER = Vector((0.0, 0.0, 2.545))
HRX, HRY, HRZ = 0.662, 0.622, 0.732

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
    "green": "#3FA347",
    "green_light": "#6FC53F",
    "green_deep": "#1B6426",
    "green_bright": "#9FE84A",
    "trouser": "#42502A",
    "boot": "#7A4A2B",
    "leather": "#8A5738",
    "leather_dark": "#46261C",
    "bronze": "#C28840",
    "bronze_light": "#F7D78E",
    "gold": "#F0C245",
    "skin": "#EFB183",
    "skin_shadow": "#C68457",
    "skin_light": "#FFD9AE",
    "hair_dark": "#452210",
    "hair_mid": "#7A3C1B",
    "hair_light": "#B47135",
    "hair_shine": "#DA9A55",
    "eye_blue": "#41C863",
    "eye_light": "#9BF07A",
    "eye_dark": "#14232E",
    "eye_rim": "#155A21",
    "white": "#FAFCF8",
    "bow_glow": "#93FF4C",
    "bow_core": "#D2FF70",
    "energy": "#78FF36",
}

PALETTE.update(PROFILE["palette"])

MATS: dict[str, bpy.types.Material] = {}


def toon(name, base, shadow=None, light=None, rim=None):
    color = srgb(PALETTE[base]) if isinstance(base, str) else base
    shade = tint(color, 0.40) if shadow is None else (
        srgb(PALETTE[shadow]) if isinstance(shadow, str) else shadow)
    highlight = tint(color, 1.42) if light is None else (
        srgb(PALETTE[light]) if isinstance(light, str) else light)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_fake_user = True
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
    stops = ramp.color_ramp.elements
    # 4-stop ramp: core shadow -> 72% tone -> base -> highlight. The default
    # second element is pure white, so every stop is written explicitly;
    # leaving it in place made any lit surface render as white.
    stops[0].position = 0.0
    stops[0].color = (*shade, 1.0)
    stops[1].position = 0.86
    stops[1].color = (*highlight, 1.0)
    mid = stops.new(0.30)
    mid.color = (*tint(color, 0.72), 1.0)
    base = stops.new(0.60)
    base.color = (*color, 1.0)
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
        # A colour node cannot drive the Material Output surface input: EEVEE
        # renders that material as flat magenta. The rim has to stay a shader,
        # so route the ramp through its own emission and add the two shaders.
        rim_emission = nodes.new("ShaderNodeEmission")
        rim_emission.inputs["Strength"].default_value = 1.10
        links.new(layer.outputs["Facing"], rim_ramp.inputs["Fac"])
        links.new(rim_ramp.outputs["Color"], rim_emission.inputs["Color"])
        add = nodes.new("ShaderNodeAddShader")
        links.new(emission.outputs[0], add.inputs[0])
        links.new(rim_emission.outputs[0], add.inputs[1])
        surface = add.outputs[0]
    links.new(surface, output.inputs["Surface"])
    return mat


def glow(name, base, strength, alpha=1.0):
    color = srgb(PALETTE[base]) if isinstance(base, str) else base
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_fake_user = True
    mat.diffuse_color = (*color, 1.0)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    # Blender 3.6 calls this socket "Emission"; Blender 4.x renamed it
    # to "Emission Color". Keep the same material output across both versions.
    emission_color = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
    if emission_color is None:
        raise RuntimeError(
            f"{bpy.app.version_string}: Principled BSDF has no emission color socket")
    emission_color.default_value = (*color, 1.0)
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
    """Bind one rigid mesh part to a single deform bone without object parenting."""
    if ARM is None or ARM.type != "ARMATURE":
        raise RuntimeError(f"{obj.name}: the hero armature must exist before binding")
    if bone not in ARM.data.bones:
        raise RuntimeError(f"{obj.name}: rig bone {bone!r} does not exist")
    if obj.vertex_groups or any(mod.type == "ARMATURE" for mod in obj.modifiers):
        raise RuntimeError(f"{obj.name}: refusing to add a duplicate skin binding")

    # Preserve the part's authored world transform while leaving it unparented.
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world

    vertex_indices = [vertex.index for vertex in obj.data.vertices]
    if not vertex_indices:
        raise RuntimeError(f"{obj.name}: cannot bind an empty mesh")
    group = obj.vertex_groups.new(name=bone)
    group.add(vertex_indices, 1.0, "REPLACE")

    modifier = obj.modifiers.new(name="Hero Armature", type="ARMATURE")
    modifier.object = ARM
    modifier.use_vertex_groups = True
    modifier.use_bone_envelopes = False
    obj["rig_bone"] = bone


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
    jaw = 1.0 - 0.40 * low ** 1.7
    px = HRX * x * jaw
    py = HRY * y * jaw
    pz = HRZ * z
    if y < 0.0:
        py -= 0.050 * low ** 2
    if y > 0.0:
        py *= 0.94
    cheek = math.exp(-((z + 0.18) / 0.30) ** 2) * abs(x) ** 0.6
    px += 0.016 * cheek
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
    """Sharp, determined anime face matching the reference sheet.

    The reference eyes are narrow almonds, not round saucers: a large iris fills
    most of the opening, a heavy dark upper lash runs the full width and flicks
    up at the outer corner, and thick brows sit low over the inner corners.
    """
    for side, sign in (("L", 1.0), ("R", -1.0)):
        az = 23.0 * sign
        tilt = 8.0 * sign
        surface_patch(f"Eye_Outline_{side}", az, 2.0, 16.6, 12.8,
                      "eye_rim", 0.0055, tilt_deg=tilt)
        surface_patch(f"Eye_White_{side}", az, 2.0, 15.9, 12.1, "white",
                      0.0062, tilt_deg=tilt)
        surface_patch(f"Eye_Iris_{side}", az - 0.4 * sign, 1.4, 15.0, 11.2,
                      "eye_blue", 0.0086, tilt_deg=tilt)
        surface_patch(f"Eye_Iris_Low_{side}", az - 0.8 * sign, -2.2, 11.6, 6.6,
                      "eye_light", 0.0092, tilt_deg=tilt)
        surface_patch(f"Eye_Pupil_{side}", az - 0.6 * sign, 1.2, 5.4, 7.4,
                      "eye_dark", 0.0104, tilt_deg=tilt)
        surface_patch(f"Eye_Glint_{side}", az - 5.0 * sign, 6.4, 2.9, 2.5,
                      "eye_glint", 0.0126, tilt_deg=tilt)
        surface_patch(f"Eye_Glint_Small_{side}", az + 4.6 * sign, -3.2, 1.7,
                      1.6, "eye_glint", 0.0126, tilt_deg=tilt)
        # Anime under-eye arc: a soft light band under the iris that lifts the
        # whole expression, as in the reference sheet's faces.
        surface_patch(f"Eye_Iris_Glow_{side}", az - 0.5 * sign, 5.6, 7.0, 2.6,
                      "eye_light", 0.0094, tilt_deg=tilt)

        # Heavy upper lash: thick across the iris, rising into an outer flick.
        lash = []
        for t in range(13):
            u = t / 12.0
            la = az + (u - 0.5) * 33.0 * sign
            le = 2.0 + 8.4 * math.sin(math.pi * (0.04 + 0.90 * u))
            le += 3.0 * max(0.0, u - 0.80) / 0.20
            lash.append((la, le))
        widths = [1.35, 1.90, 2.35, 2.65, 2.85, 2.90, 2.85, 2.65,
                  2.35, 1.95, 1.50, 1.00, 0.40]
        surface_strip(f"Eye_Lash_{side}", lash, widths, "hair_dark",
                      0.0115, thickness=0.0046)

        # Lower lid: thin dark line, slightly brighter skin below it.
        lower = [(az + (t / 12.0 - 0.5) * 26.0 * sign,
                  1.8 - 7.8 * math.sin(math.pi * (0.05 + 0.90 * t / 12.0)))
                 for t in range(13)]
        surface_strip(f"Eye_Under_{side}", lower, [0.55] * 13, "skin_shadow",
                      0.0105, thickness=0.0022)

        # Thick, low, inward-sloping brows: the reference's determined scowl.
        brow = [(az + (t / 6.0 - 0.5) * 33.0 * sign,
                 11.4 + 5.2 * (t / 6.0) ** 1.2)
                for t in range(7)]
        surface_strip(f"Brow_{side}", brow,
                      [2.4, 2.8, 2.9, 2.6, 2.1, 1.5, 0.7],
                      "hair_dark", 0.0120, thickness=0.0042)
        ear = sphere(f"Ear_{side}", head_point(96.0 * sign, -8.0, 0.004),
                     (0.020, 0.036, 0.058), "skin_shadow", "head", 20, 12)
        sphere(f"Ear_Inner_{side}", head_point(99.0 * sign, -8.0, 0.012),
               (0.010, 0.022, 0.038), "leather_dark", "head", 16, 10)

    sphere("Nose", head_point(0.0, -13.0, 0.016),
           (0.019, 0.018, 0.014), "skin_shadow", "head", 16, 10)
    mouth = []
    for t in range(9):
        u = t / 8.0
        mouth.append((-8.0 + 16.0 * u, -23.6 - 1.1 * (abs(u - 0.5) * 2.0) ** 1.4))
    surface_strip("Mouth", mouth, [0.85] * 9, "leather_dark", 0.0105,
                  thickness=0.0024)


def hairline(az_deg):
    """Elevation of the hairline for an azimuth (0 = face, 180 = nape)."""
    a = abs(((az_deg + 180.0) % 360.0) - 180.0)
    anchors = ((0.0, 34.0), (55.0, 27.0), (115.0, -6.0), (180.0, -44.0))
    for (a0, e0), (a1, e1) in zip(anchors, anchors[1:]):
        if a <= a1:
            t = (a - a0) / (a1 - a0)
            t = 0.5 - 0.5 * math.cos(math.pi * t)
            return e0 + (e1 - e0) * t
    return -44.0


def build_hair():
    style = PROFILE.get("hair_style", "spiky")
    if PROFILE["hair"] == "none":
        return
    columns = 49
    rows = 16
    verts = []
    for r in range(rows):
        t = r / (rows - 1.0)
        for j in range(columns):
            az = -180.0 + 360.0 * j / (columns - 1)
            line = hairline(az)
            el = line + t * (88.0 - line)
            inflate = 0.090 + 0.030 * (1.0 - t)
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
            if r < 2:
                face_materials.append(0)
            elif r < 10:
                face_materials.append(1)
            else:
                face_materials.append(2)
    pole = len(verts)
    verts.append(head_point(0.0, 90.0, 0.070))
    top_base = (rows - 1) * columns
    for j in range(columns - 1):
        faces.append((top_base + j, top_base + j + 1, pole))
        face_materials.append(2)
    obj_from("Hair_Cap", verts, faces,
             ["hair_dark", "hair_mid", "hair_light"], "head",
             face_materials=face_materials, recalc=False,
             solidify=(0.014, 0))
    if style != "shadow":
        hair_shell("Hair_Mass", PROFILE.get("hair_spikes", RANGER_HAIR_SPIKES),
                   (0.0, 0.034, 3.075), (0.582, 0.548, 0.358), amp=0.28)
    add_hair_locks(style)


def world_lock(name, points, widths, stops=None, bone="head", sides=6):
    """A thick hair lock in head-local world space, with a pointed tip."""
    pts = [Vector(p) for p in points]
    return sweep(name, pts, widths, "hair_mid", bone, sides=sides,
                 thickness=[w * 0.42 for w in widths], tip=True,
                 material_stops=stops or [(0.0, "hair_dark"),
                                          (0.28, "hair_mid"),
                                          (0.62, "hair_light")])


BANGS = (
    ((-2, 62, .14), (-4, 46, .145), (2, 31, .15), (10, 17, .155),
     (0.200, 0.185, 0.135, 0.015)),
    ((16, 60, .14), (20, 45, .145), (26, 31, .15), (32, 17, .155),
     (0.195, 0.180, 0.130, 0.015)),
    ((-20, 58, .14), (-25, 44, .145), (-28, 30, .15), (-26, 16, .155),
     (0.190, 0.175, 0.125, 0.015)),
    ((34, 55, .14), (40, 42, .145), (44, 29, .15), (46, 16, .155),
     (0.185, 0.170, 0.120, 0.014)),
    ((-38, 52, .14), (-44, 39, .145), (-48, 27, .15), (-48, 14, .155),
     (0.180, 0.165, 0.115, 0.014)),
    ((50, 48, .14), (56, 36, .145), (60, 24, .15), (62, 12, .155),
     (0.175, 0.160, 0.110, 0.014)),
    ((-50, 46, .14), (-56, 34, .145), (-60, 22, .15), (-60, 10, .155),
     (0.170, 0.155, 0.105, 0.013)),
    ((4, 66, .14), (2, 55, .145), (6, 44, .15), (12, 34, .155),
     (0.185, 0.170, 0.120, 0.014)),
)

# Hair is built from flat blade locks (azimuth, elevation, sweep direction,
# length, width, extra curve) so the silhouette reads as swept anime hair
# instead of separate cones. Every lock starts inside the skull.
RANGER_HAIR_SPIKES = (
    (-10, 0.52, 32), (46, 0.42, 28), (-56, 0.48, 30),
    (108, 0.36, 28), (-118, 0.38, 28), (172, 0.30, 30),
)

RANGER_BLADES = (
    (6, 72, -0.20, 0.45, 0.90, 0.62, 0.660, 0.050),
    (38, 66, 0.42, 0.50, 0.85, 0.56, 0.620, 0.040),
    (-34, 68, -0.46, 0.50, 0.88, 0.60, 0.640, 0.040),
    (72, 58, 0.55, 0.18, 0.80, 0.36, 0.520, 0.010),
    (-64, 60, -0.55, 0.18, 0.80, 0.40, 0.540, 0.010),
    (108, 62, 0.30, 0.75, 0.85, 0.42, 0.560, 0.000),
    (-124, 58, -0.30, 0.75, 0.85, 0.34, 0.520, 0.000),
    (16, 84, -0.08, 0.50, 0.88, 0.34, 0.470, 0.020),
    (56, 76, 0.24, 0.62, 0.80, 0.28, 0.420, 0.000),
    (-50, 78, -0.26, 0.64, 0.82, 0.32, 0.450, 0.000),
    # Second overlapping layer: shorter locks between the primaries so the
    # silhouette reads as layered anime hair instead of a single spike ring.
    (22, 78, -0.10, 0.40, 0.95, 0.30, 0.380, 0.060),
    (-14, 76, 0.16, 0.44, 0.92, 0.32, 0.400, 0.060),
    (48, 72, 0.36, 0.55, 0.86, 0.26, 0.340, 0.020),
    (-52, 70, -0.36, 0.55, 0.86, 0.28, 0.360, 0.020),
    (86, 66, 0.42, 0.45, 0.78, 0.24, 0.320, 0.000),
    (-96, 64, -0.42, 0.45, 0.78, 0.26, 0.330, 0.000),
)

# Side hair falls down in front of the ears, past the jaw.
SIDE_LOCKS = (
    (72, 34, 0.30, 0.16, -1.00, 0.34, 0.300, 0.000),
    (-72, 34, -0.30, 0.16, -1.00, 0.34, 0.300, 0.000),
    (86, 20, 0.20, 0.10, -1.00, 0.30, 0.280, 0.000),
    (-86, 20, -0.20, 0.10, -1.00, 0.30, 0.280, 0.000),
)


# Flame: taller, more upright flame-shaped blades.
FLAME_BLADES = (
    (0, 62, -0.12, -0.05, 1.00, 0.46, 0.300, 0.030),
    (22, 60, 0.22, 0.00, 1.00, 0.44, 0.290, 0.030),
    (-22, 60, -0.24, 0.00, 1.00, 0.44, 0.290, 0.030),
    (46, 46, 0.55, 0.05, 0.95, 0.38, 0.270, 0.020),
    (-46, 46, -0.55, 0.05, 0.95, 0.38, 0.270, 0.020),
    (145, 60, 0.10, 1.00, 0.65, 0.36, 0.290, 0.000),
    (-145, 60, -0.10, 1.00, 0.65, 0.36, 0.290, 0.000),
    (90, 72, 0.25, 0.45, 0.98, 0.28, 0.250, 0.000),
    (-90, 72, -0.25, 0.45, 0.98, 0.28, 0.250, 0.000),
    (0, 82, -0.04, 0.25, 1.00, 0.30, 0.260, 0.010),
    (32, 76, 0.30, 0.25, 1.00, 0.27, 0.240, 0.000),
    (-32, 76, -0.30, 0.25, 1.00, 0.27, 0.240, 0.000),
)

# Storm: broad silver blades swept up and back.
STORM_BLADES = (
    (0, 63, -0.16, 0.35, 1.00, 0.44, 0.300, 0.020),
    (24, 61, 0.40, 0.40, 0.95, 0.42, 0.290, 0.020),
    (-24, 61, -0.42, 0.40, 0.95, 0.42, 0.290, 0.020),
    (52, 46, 0.85, 0.30, 0.75, 0.36, 0.280, 0.000),
    (-52, 46, -0.85, 0.30, 0.75, 0.36, 0.280, 0.000),
    (148, 60, 0.10, 1.00, 0.55, 0.38, 0.290, 0.000),
    (-148, 60, -0.10, 1.00, 0.55, 0.38, 0.290, 0.000),
    (90, 73, 0.28, 0.60, 0.90, 0.27, 0.255, 0.000),
    (-90, 73, -0.28, 0.60, 0.90, 0.27, 0.255, 0.000),
    (0, 83, -0.05, 0.45, 0.98, 0.25, 0.255, 0.000),
    (34, 76, 0.35, 0.40, 0.98, 0.25, 0.240, 0.000),
    (-34, 76, -0.35, 0.40, 0.98, 0.25, 0.240, 0.000),
)


def lock(name, path, widths, thickness=None, stops=None):
    """Ribbon-like hair lock laid on the head surface."""
    points = [head_point(az, el, inflate) for az, el, inflate in path]
    flats = [head_normal(az, el) for az, el, _ in path]
    return sweep(name, points, widths, "hair_mid", "head", sides=6,
                 thickness=thickness or [width * 0.40 for width in widths],
                 flats=flats, tip=True,
                 material_stops=stops or [(0.0, "hair_dark"),
                                          (0.30, "hair_mid"),
                                          (0.64, "hair_light")])


def hair_fringe():
    """Layered bangs: a sheet with pointed tips plus separate thick locks.

    The reference bangs are big triangular locks that overlap the brows, not a
    thin band. The sheet guarantees coverage, the locks give the pointed edge.
    """
    columns = 29
    rows = []
    for el in (58.0, 48.0, 38.0):
        rows.append([head_point(-70.0 + 140.0 * j / (columns - 1), el, 0.150)
                     for j in range(columns)])
    bottom = []
    for j in range(columns):
        az = -70.0 + 140.0 * j / (columns - 1)
        # Large pointed teeth, uneven in width and depth.
        tooth = abs(((j * 0.62) % 1.0) * 2.0 - 1.0)
        sweep = -9.0 * (j / (columns - 1.0) - 0.5) * 2.0
        el = 29.0 + 6.5 * tooth + sweep * 0.6 + 1.6 * math.sin(j * 0.9 + 0.3)
        bottom.append(head_point(az, el, 0.162))
    rows.append(bottom)
    faces = []
    mats = []
    for i in range(len(rows) - 1):
        for j in range(columns - 1):
            a = i * columns + j
            faces.append((a, a + 1, a + columns + 1, a + columns))
            mats.append(0 if i < 2 else 1)
    obj_from("Hair_Fringe", [v for row in rows for v in row], faces,
             ["hair_mid", "hair_light"], "head", face_materials=mats,
             recalc=False, solidify=(0.018, 0))

    # The reference has one dominant lock swept across the forehead.
    lock("Hair_Sweep", [(-46, 58, .150), (-18, 47, .165),
                        (14, 37, .175), (44, 27, .185)],
         [0.190, 0.205, 0.150, 0.012])

    # Long pointed bangs in front of the sheet, uneven lengths.
    for index, (az, el, width) in enumerate((
            (-54, 20, 0.155), (-34, 23, 0.170), (-14, 18, 0.180),
            (8, 24, 0.175), (30, 28, 0.160), (52, 31, 0.140))):
        lock(f"Hair_Bang_{index}", [
            (az, 58, .155), (az + 1, 46, .165),
            (az + 2, 32, .175), (az + 3, el, .185)],
            [width, width * 0.92, width * 0.62, 0.010])


def hair_shell(name, spikes, centre, radii, base=1.0, amp=0.42):
    """One continuous hair mass with soft spikes around the crown.

    A UV shell whose radius is modulated by a sum of azimuthal Gaussians reads
    as swept anime hair: the spikes are part of the surface instead of separate
    cones, so there are no gaps and no regular sawtooth ring.
    """
    segments, rings = 64, 26
    verts = []
    for r in range(rings):
        v = r / (rings - 1.0)
        el = math.pi * (0.5 - v)          # +90 .. -90 degrees
        for j in range(segments):
            az = 2.0 * math.pi * j / segments
            az_deg = math.degrees(az)
            bump = 0.0
            for c_az, c_amp, c_width in spikes:
                d = ((az_deg - c_az + 180.0) % 360.0) - 180.0
                bump += c_amp * math.exp(-(d / c_width) ** 2)
            # Spikes only grow on the upper half of the skull.
            weight = max(0.0, math.sin(max(0.0, el))) ** 0.7
            scale = base + amp * bump * weight
            x = math.cos(el) * math.cos(az) * scale
            y = math.cos(el) * math.sin(az) * scale
            z = math.sin(el) * scale
            verts.append(Vector((centre[0] + x * radii[0],
                                 centre[1] + y * radii[1],
                                 centre[2] + z * radii[2])))
    faces = []
    for r in range(rings - 1):
        for j in range(segments):
            a = r * segments + j
            b = r * segments + (j + 1) % segments
            c = (r + 1) * segments + (j + 1) % segments
            d = (r + 1) * segments + j
            faces.append((a, b, c, d))
    return obj_from(name, verts, faces, ["hair_mid"], "head", recalc=True,
                    solidify=(0.012, 0))


def blade(name, az, el, direction, length, width, curve=0.0):
    """Flat, pointed hair lock that grows out of the skull."""
    base = head_point(az, el, 0.020)
    shoulder = head_point(az, el, 0.150)
    d = Vector(direction).normalized()
    lift = Vector((0.0, 0.0, curve))
    points = [base,
              shoulder + d * (length * 0.28),
              shoulder + d * (length * 0.62) + lift,
              shoulder + d * length + lift * 1.8]
    widths = [width * 0.55, width, width * 0.66, width * 0.085]
    return sweep(name, points, widths, "hair_mid", "head", sides=6,
                 thickness=[w * 0.30 for w in widths], tip=True,
                 material_stops=[(0.0, "hair_dark"), (0.16, "hair_mid"),
                                 (0.55, "hair_light"), (0.86, "hair_mid")])


def add_hair_locks(style):
    blades = {"flame": FLAME_BLADES, "storm": STORM_BLADES,
              "shadow": ()}.get(style, RANGER_BLADES)
    hair_fringe()
    if style == "shadow":
        # Under-hood bangs only: no spike silhouette outside the hood.
        return
    for index, spec in enumerate(blades):
        az, el, dx, dy, dz, length, width, curve = spec
        blade(f"Hair_Lock_{index}", az, el, (dx, dy, dz), length, width,
              curve)
    for index, spec in enumerate(SIDE_LOCKS):
        az, el, dx, dy, dz, length, width, curve = spec
        blade(f"Hair_Side_{index}", az, el, (dx, dy, dz), length, width,
              curve)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        lock(f"Hair_Side_{side}", [
            (66 * sign, 30, .13), (69 * sign, 10, .14),
            (70 * sign, -10, .145), (67 * sign, -30, .14)],
            [0.165, 0.150, 0.105, 0.014])

# ----------------------------------------------------------------- rig -----

def make_armature():
    global ARM
    data = bpy.data.armatures.new(PROFILE["armature"])
    ARM = bpy.data.objects.new(PROFILE["rig"], data)
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
        (1.58, 0, 0, 0.284, 0.212), (1.72, 0, 0, 0.306, 0.226),
        (1.86, 0, 0, 0.344, 0.242), (1.98, 0, 0, 0.368, 0.252),
        (2.06, 0, 0, 0.296, 0.226), (2.10, 0, 0, 0.202, 0.176),
    ]
    loft("Torso_Lower", lower, "green", "spine")
    loft("Torso_Upper", upper, "green", "chest")
    loft("Pelvis", [(1.04, 0, 0, 0.222, 0.180),
                    (1.14, 0, 0, 0.268, 0.200),
                    (1.30, 0, 0, 0.280, 0.206),
                    (1.38, 0, 0, 0.262, 0.198)], "trouser", "hips")
    front_band("Chest_Plate", 1.56, 2.00, 0.360, 0.252, -56, 56,
               "green", "chest", columns=22, thickness=0.016, bulge=0.014)
    front_band("Chest_Plate_Neck", 1.96, 2.005, 0.364, 0.256, -30, 30,
               "green_bright", "chest", columns=14, thickness=0.010)
    # Single leather baldric across the chest, as in the reference.
    strap = []
    for t in range(9):
        u = t / 8.0
        a = math.radians(48.0 - 96.0 * u)
        strap.append(Vector((0.318 * math.sin(a),
                             -0.238 * math.cos(a),
                             2.000 - 0.560 * u)))
    sweep("Chest_Baldric", strap, [0.056] * 9, "leather", "chest",
          sides=4, thickness=[0.026] * 9, tip=False)
    sweep("Chest_Baldric_Edge", [p + Vector((0.0, -0.010, 0.006))
                                 for p in strap], [0.014] * 9,
          "bronze_light", "chest", sides=4, thickness=[0.010] * 9)
    torus("Baldric_Ring", (0.02, -0.250, 1.660), 0.055, 0.014, "gold",
          "chest", rotation=(math.radians(90), 0, 0), major_segments=24)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        for index, (z, scale, material) in enumerate((
                (2.030, (0.262, 0.274, 0.156), "bronze"),
                (1.945, (0.226, 0.248, 0.106), "bronze_light"),
                (1.870, (0.186, 0.214, 0.078), "leather_dark"))):
            sphere(f"Pauldron_{side}_{index}",
                   (0.385 * sign, 0.0, z), scale, material, "chest",
                   segments=28, rings=16)
        torus(f"Pauldron_Gold_{side}", (0.385 * sign, 0.0, 2.075),
              0.190, 0.020, "gold", "chest", scale=(1.0, 1.05, 0.55),
              major_segments=32)
        sphere(f"Pauldron_Inset_{side}", (0.352 * sign, -0.01, 2.115),
               (0.150, 0.175, 0.055), "green", "chest", 24, 12)
        torus(f"Pauldron_Rim_{side}", (0.385 * sign, 0.0, 1.990),
              0.215, 0.012, "bronze_light", "chest",
              scale=(1.0, 1.05, 0.68), major_segments=32)
    front_band("Tabard", 0.96, 1.42, 0.286, 0.208, -26, 26, "green_deep",
               "hips", columns=12, thickness=0.020, bulge=0.016)
    front_band("Tabard_Hem", 0.955, 0.980, 0.292, 0.214, -26, 26,
               "gold", "hips", columns=12, thickness=0.010)
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
    sphere("Hood_Down", (0, 0.195, 2.225), (0.290, 0.190, 0.250),
           "green", "chest", 28, 16)
    if PROFILE.get("front_mantle"):
        for side, sign in (("L", 1.0), ("R", -1.0)):
            rows = []
            for i in range(4):
                u = i / 3.0
                row = []
                for j in range(7):
                    v = j / 6.0
                    x = sign * (0.030 + (0.400 * u + 0.040) * (0.35 + 0.65 * v))
                    y = -0.150 - 0.120 * u - 0.060 * v
                    z = 2.170 - 0.180 * u - 0.330 * u * v
                    row.append(Vector((x, y, z)))
                rows.append(row)
            grid_sheet(f"Front_Mantle_{side}", rows, ["green", "green_deep"],
                       "chest", solidify=(0.022, 1), recalc=False)
            edge = [rows[i][6] + Vector((0.0, -0.012, -0.006))
                    for i in range(4)]
            sweep(f"Front_Mantle_Trim_{side}", edge, [0.034] * 4,
                  "gold", "chest", sides=4, thickness=[0.016] * 4,
                  tip=False)
        sphere("Cloak_Gem_Rim", (0, -0.268, 2.030), (0.092, 0.030, 0.092),
               "gold", "chest", 24, 14)
        sphere("Cloak_Gem_Rim2", (0, -0.278, 2.030), (0.068, 0.026, 0.068),
               "bronze", "chest", 20, 12)
    torus("Cloak_Clasp", (0, -0.245, 2.045), 0.045, 0.017, "gold",
          "chest", rotation=(math.radians(90), 0, 0), major_segments=28)
    sphere("Cloak_Gem", (0, -0.290, 2.034), (0.056, 0.026, 0.056),
           "green_bright", "chest", 18, 12)
    for index, (az, z) in enumerate(((-30, 1.70), (30, 1.70),
                                     (-30, 1.90), (30, 1.90))):
        stud = math.radians(az)
        sphere(f"Chest_Stud_{index}",
               ((0.352) * math.sin(stud), -(0.256) * math.cos(stud), z),
               (0.018, 0.010, 0.018), "bronze_light", "chest", 12, 8)


# --------------------------------------------------------------- limbs -----

def build_limbs():
    for side, sign in (("L", 1.0), ("R", -1.0)):
        shoulder = Vector((0.360 * sign, 0, 2.00))
        elbow = Vector((0.500 * sign, 0, 1.73))
        wrist = Vector((0.575 * sign, -0.02, 1.45))
        hand = Vector((0.590 * sign, -0.045, 1.375))
        sweep(f"Sleeve_{side}", [shoulder, elbow], [0.248, 0.198],
              "green", f"upper_arm.{side}", sides=16,
              thickness=[0.232, 0.188])
        sleeve_low = elbow.lerp(wrist, 0.42)
        sweep(f"Forearm_Cloth_{side}", [elbow, sleeve_low], [0.200, 0.180],
              "green", f"forearm.{side}", sides=16,
              thickness=[0.190, 0.170])
        sweep(f"Bracer_{side}", [sleeve_low, wrist], [0.186, 0.170],
              "leather", f"forearm.{side}", sides=16,
              thickness=[0.176, 0.160])
        ring_at(f"Bracer_Strap_{side}_0", elbow, wrist, 0.34,
                0.106, 0.013, "leather_dark", f"forearm.{side}")
        ring_at(f"Bracer_Strap_{side}_1", elbow, wrist, 0.72,
                0.094, 0.012, "leather_dark", f"forearm.{side}")
        box(f"Bracer_Buckle_{side}", (0.560 * sign, -0.118, 1.545),
            (0.026, 0.018, 0.040), "gold", f"forearm.{side}",
            bevel=0.005)
        sphere(f"Glove_{side}", hand, (0.100, 0.104, 0.116),
               "leather", f"hand.{side}", 24, 14)
        sphere(f"Thumb_{side}", (0.522 * sign, -0.108, 1.365),
               (0.038, 0.052, 0.048), "leather", f"hand.{side}", 16, 10)
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
              [0.244, 0.212, 0.180], "boot", f"shin.{side}", sides=16,
              thickness=[0.232, 0.200, 0.168])
        sphere(f"Knee_Plate_{side}", (0.20 * sign, -0.086, 0.812),
               (0.124, 0.078, 0.100), "bronze", f"thigh.{side}",
               24, 14)
        sphere(f"Knee_Cap_{side}", (0.20 * sign, -0.126, 0.822),
               (0.070, 0.032, 0.062), "bronze_light", f"thigh.{side}",
               18, 10)
        front_band(f"Shin_Plate_{side}", 0.48, 0.70, 0.118, 0.104,
                   -55, 55, "bronze", f"shin.{side}", columns=12,
                   thickness=0.014)
        torus(f"Boot_Cuff_{side}", (0.204 * sign, 0, 0.760),
              0.118, 0.030, "leather_dark", f"shin.{side}",
              major_segments=28)
        torus(f"Boot_Cuff_Trim_{side}", (0.204 * sign, 0, 0.792),
              0.112, 0.014, "gold", f"shin.{side}",
              major_segments=28)
        ring_at(f"Boot_Strap_{side}", knee, ankle, 0.55,
                0.094, 0.013, "leather_dark", f"shin.{side}")
        foot_center = (0.21 * sign, -0.085, 0.110)
        sphere(f"Boot_Foot_{side}", foot_center, (0.142, 0.224, 0.106),
               "boot", f"foot.{side}", 24, 14)
        box(f"Sole_{side}", (0.21 * sign, -0.095, 0.034),
            (0.252, 0.410, 0.068), "leather_dark", f"foot.{side}",
            bevel=0.024)
        sphere(f"Toe_Cap_{side}", (0.21 * sign, -0.278, 0.100),
               (0.126, 0.074, 0.070), "bronze_light", f"foot.{side}", 20, 12)


# --------------------------------------------------------------- cloak -----

def cloak_rows(v0, v1, rows=10, columns=33):
    out = []
    for i in range(rows):
        v = v0 + (v1 - v0) * i / (rows - 1)
        row = []
        for j in range(columns):
            u = -1.0 + 2.0 * j / (columns - 1)
            x = u * (0.46 + 0.40 * v)
            y = 0.135 + 0.300 * v + 0.050 * math.sin(u * 9.0 + 0.7) * (0.25 + 0.75 * v)
            z = 2.075 - 1.72 * v + 0.060 * math.cos(u * 6.0) * v ** 5
            row.append(Vector((x, y, z)))
        out.append(row)
    return out


def build_cloak():
    PROFILE["build_cape"](builder())


# ---------------------------------------------------------------- gear -----

def build_quiver():
    # Sit the quiver on the outside of the shoulder so the fletching clears the
    # cloak: the reference reads as an archer partly because the arrows are
    # visible over the shoulder from the back and three-quarter views.
    start = Vector((-0.315, 0.130, 1.520))
    end = Vector((-0.520, 0.175, 2.060))
    sweep("Quiver", [start, end], [0.150, 0.135], "leather_dark",
          "quiver", sides=16, thickness=[0.145, 0.130])
    ring_at("Quiver_Rim", start, end, 0.97, 0.072, 0.016, "bronze", "quiver")
    axis = (end - start).normalized()
    for index in range(5):
        offset = Vector((0.030 * math.cos(index * 1.7),
                         0.020 * math.sin(index * 1.3), 0.0))
        base = end - axis * 0.10 + offset
        tip = end + axis * (0.34 + 0.022 * index) + offset
        sweep(f"Arrow_{index}", [base, tip], [0.016, 0.014],
              "bronze_light", "quiver", sides=6, thickness=[0.016, 0.014])
        fletch = tip - axis * 0.10
        sphere(f"Fletch_{index}", fletch, (0.040, 0.020, 0.110),
               "white", "quiver", 12, 8)


def build_bow():
    # The reference bow is nearly body-height and dominates the silhouette, so
    # the limbs run from above the head to below the knee with a thick luminous
    # core and a wider halo.
    # Bow curves away from the body in the X-Z plane so the C shape reads.
    up = [Vector((0.665, -0.068, 1.300)), Vector((0.805, -0.205, 1.660)),
          Vector((0.875, -0.295, 2.120)), Vector((0.805, -0.250, 2.520)),
          Vector((0.640, -0.135, 2.780))]
    down = [Vector((0.665, -0.068, 1.300)), Vector((0.805, -0.205, 0.980)),
            Vector((0.875, -0.295, 0.590)), Vector((0.805, -0.250, 0.210)),
            Vector((0.640, -0.135, -0.040))]
    widths = [0.092, 0.076, 0.062, 0.046, 0.024]
    for index, limb in enumerate((up, down)):
        sweep(f"Bow_Frame_{index}", limb, widths, "gold", "bow",
              sides=8, thickness=[w * 1.05 for w in widths], tip=True)
        inner = [point + Vector((-0.062, 0.040, 0.0)) for point in limb]
        sweep(f"Bow_Limb_{index}", inner, [w * 0.62 for w in widths],
              "energy_core", "bow", sides=6,
              thickness=[w * 0.55 for w in widths], tip=True)
        sweep(f"Bow_Glow_{index}", inner, [w * 1.08 for w in widths],
              "energy_soft", "bow", sides=6,
              thickness=[w * 0.95 for w in widths], tip=True)
    # Inner energy blades: the reference's bow has bright leaf-shaped flares
    # along the limbs that keep the weapon readable even at 96 px.
    for index, sign in ((0, 1.0), (1, -1.0)):
        sweep(f"Bow_Blade_{index}", [
            Vector((0.775, -0.58, 2.40)),
            Vector((0.750, -0.64, 2.62)),
            Vector((0.715, -0.59, 2.82)),
            Vector((0.675, -0.41, 2.96))],
            [0.066, 0.050, 0.027, 0.006], "energy", "bow", sides=5,
            thickness=[0.030, 0.020, 0.012, 0.004], tip=True)
        sweep(f"Bow_Blade_Low_{index}", [
            Vector((0.775, -0.58, 0.52)),
            Vector((0.750, -0.64, 0.30)),
            Vector((0.715, -0.59, 0.10)),
            Vector((0.675, -0.41, -0.04))],
            [0.066, 0.050, 0.027, 0.006], "energy", "bow", sides=5,
            thickness=[0.030, 0.020, 0.012, 0.004], tip=True)
    sweep("Bow_Grip", [Vector((0.60, -0.10, 1.28)),
                       Vector((0.60, -0.10, 1.56))],
          [0.098, 0.098], "leather_dark", "bow", sides=12,
          thickness=[0.098, 0.098])
    ring_at("Bow_Grip_Ring_0", Vector((0.60, -0.10, 1.28)),
            Vector((0.60, -0.10, 1.56)), 0.10, 0.058, 0.013,
            "gold", "bow")
    ring_at("Bow_Grip_Ring_1", Vector((0.60, -0.10, 1.28)),
            Vector((0.60, -0.10, 1.56)), 0.90, 0.058, 0.013,
            "gold", "bow")
    sphere("Bow_Gem", (0.60, -0.15, 1.42), (0.044, 0.040, 0.070),
           "green_bright", "bow", 16, 10)
    sweep("String_Rest", [Vector((0.632, -0.120, 2.780)),
                          Vector((0.632, -0.120, -0.040))],
          [0.010, 0.010], "string_glow", "string_rest", sides=4,
          thickness=[0.010, 0.010])
    nock = Vector((0.60, 0.30, 1.42))
    sweep("String_Drawn", [Vector((0.632, -0.120, 2.780)), nock,
                           Vector((0.632, -0.120, -0.040))],
          [0.010, 0.010, 0.010], "string_glow", "string_drawn",
          sides=4, thickness=[0.010, 0.010, 0.010])
    # Nocked energy arrow: from the drawn nock towards the bow.
    sweep("Nocked_Arrow", [Vector((0.60, 0.38, 1.42)),
                           Vector((0.60, -0.34, 1.42))],
          [0.026, 0.019], "energy_core", "fx_draw", sides=6,
          thickness=[0.026, 0.019])
    cone = bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.056,
                                           radius2=0.0, depth=0.15,
                                           location=(0.60, -0.415, 1.42),
                                           rotation=(math.radians(90), 0, 0))
    arrow_tip = bpy.context.object
    arrow_tip.name = "Arrow_Head"
    arrow_tip.data.materials.append(MATS["energy_core"])
    smooth(arrow_tip)
    attach(arrow_tip, "fx_draw")
    sphere("Draw_Glow", (0.60, 0.30, 1.42), (0.090, 0.080, 0.090),
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
        "green": toon("Cloth Primary", "green", rim="green_bright"),
        "green_light": toon("Cloth Lit", "green_light"),
        "green_deep": toon("Cloth Deep", "green_deep"),
        "green_bright": toon("Cloth Accent", "green_bright"),
        "trouser": toon("Cloth Trousers", "trouser"),
        "boot": toon("Boot Leather", "boot", rim="bronze_light"),
        "leather": toon("Leather Gear", "leather", rim="bronze_light"),
        "leather_dark": toon("Leather Dark", "leather_dark"),
        "bronze": toon("Metal Plate", "bronze", rim="bronze_light"),
        "bronze_light": toon("Metal Edge", "bronze_light"),
        "gold": toon("Brass Accent", "gold", rim="bronze_light"),
        "skin": toon("Warm Skin", "skin", shadow="skin_shadow",
                     light="skin_light", rim="skin_light"),
        "skin_shadow": toon("Skin Shadow", "skin_shadow"),
        "hair_dark": toon("Hair Roots", "hair_dark"),
        "hair_mid": toon("Hair Body", "hair_mid", rim="hair_shine"),
        "hair_light": toon("Hair Tips", "hair_light"),
        "hair_shine": toon("Hair Highlight", "hair_shine"),
        "eye_blue": toon("Iris", "eye_blue"),
        "eye_light": toon("Iris Glow", "eye_light"),
        "eye_dark": toon("Pupil", "eye_dark"),
        "eye_rim": toon("Iris Rim", "eye_rim"),
        "eye_glint": glow("Eye Sparkle", "white", 2.2),
        "white": toon("Eye White", "white"),
        "energy_core": glow("Energy Core", "bow_core", 3.2),
        "energy": glow("Energy Streak", "energy", 3.4),
        "energy_soft": glow("Energy Glow", "bow_glow", 1.5, 0.55),
        "string_glow": glow("Energy String", "bow_core", 2.0),
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
        "bow": (16, 0, -8), "cloak_a": (5, 0, 0),
    })
    drawn = merged(BASE, {
        "upper_arm.L": (-78, 0, 10), "forearm.L": (-10, 0, 0),
        "upper_arm.R": (-58, 0, -38), "forearm.R": (-112, 0, 0),
        "chest": (-2, 14, 0), "head": (2, -10, 0),
        "bow": (24, 0, -10), "cloak_a": (8, 0, 0),
    })
    release = merged(BASE, {
        "upper_arm.L": (-74, 0, 8), "forearm.L": (-14, 0, 0),
        "upper_arm.R": (-28, 0, -18), "forearm.R": (-55, 0, 0),
        "chest": (-4, 8, 0), "head": (3, -6, 0),
        "bow": (22, 0, -8), "cloak_a": (12, 0, 0),
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
            "forearm.R": (-22, 0, 0), "bow": (12, 0, -6),
            "cloak_a": (7, 0, 0),
        }))),
        (21, *P(merged(BASE, {
            "upper_arm.L": (-18, 0, 5), "upper_arm.R": (0, 0, -5),
            "bow": (6, 0, -3),
        }))),
        (25, *P(BASE)),
    ]
    charge = merged(BASE, {
        "upper_arm.L": (-96, 0, -10), "forearm.L": (-24, 0, 0),
        "upper_arm.R": (-96, 0, 10), "forearm.R": (-24, 0, 0),
        "chest": (-8, 0, 0), "head": (-10, 0, 0),
        "thigh.L": (-14, 0, 0), "thigh.R": (-14, 0, 0),
        "shin.L": (28, 0, 0), "shin.R": (28, 0, 0),
        "bow": (26, 0, 0), "cloak_a": (16, 0, 0),
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
        "bow": (18, 0, -4), "cloak_a": (22, 0, 0),
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
            "bow": (10, 0, -3), "thigh.L": (-12, 0, 0),
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
    # Melee heroes share the body mechanics but replace the archery attack and
    # skill with their own weapon choreography.
    if PROFILE.get("attack") is not None:
        attack = PROFILE["attack"](builder())
    if PROFILE.get("skill") is not None:
        skill = PROFILE["skill"](builder())
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
    final = merged(BASE, {
        "root": (-4, 0, 0),
        "thigh.L": (-8, 0, 0), "thigh.R": (-4, 0, 0),
        "shin.L": (140, 0, 0), "shin.R": (136, 0, 0),
        "foot.L": (-28, 0, 0), "foot.R": (-26, 0, 0),
        "chest": (12, 0, 0), "head": (22, 0, 0),
        "upper_arm.L": (8, 0, 10), "upper_arm.R": (8, 0, -10),
        "forearm.L": (6, 0, 0), "forearm.R": (6, 0, 0),
        "cloak_a": (28, 0, 0), "cloak_b": (38, 0, 0), "cloak_c": (48, 0, 0),
    })
    # Death is a compact forward collapse instead of a full-length fall. A
    # prone body is ~2.6 units wide in profile, and the shared sprite scale must
    # fit every state and direction, so one prone pose shrank the whole set by
    # 45%. Kneeling keeps the same weight and finality while the character stays
    # readable at gameplay size: the thighs stay near vertical, the shins fold
    # back under the hips, and the torso/head sag forward.
    death = [
        (1, *P(BASE)),
        (5, *P(merged(BASE, {
            "chest": (-14, 0, 0), "head": (-18, 0, 0),
            "upper_arm.L": (-18, 0, 26), "upper_arm.R": (-18, 0, -26),
            "forearm.L": (-12, 0, 0), "forearm.R": (-12, 0, 0),
            "cloak_a": (-10, 0, 0), "cloak_b": (-14, 0, 0), "cloak_c": (-18, 0, 0),
        }), loc={"root": (0, 0.02, 0)})),
        (9, *P(merged(BASE, {
            "thigh.L": (-30, 0, 0), "thigh.R": (-26, 0, 0),
            "shin.L": (62, 0, 0), "shin.R": (58, 0, 0),
            "foot.L": (-14, 0, 0), "foot.R": (-12, 0, 0),
            "chest": (16, 0, 0), "head": (6, 0, 0),
            "upper_arm.L": (-22, 0, 22), "upper_arm.R": (-22, 0, -22),
            "forearm.L": (10, 0, 0), "forearm.R": (10, 0, 0),
            "cloak_a": (4, 0, 0), "cloak_b": (8, 0, 0), "cloak_c": (12, 0, 0),
        }), loc={"root": (0, -0.20, 0)})),
        (13, *P(merged(BASE, {
            "root": (-3, 0, 0),
            "thigh.L": (-10, 0, 0), "thigh.R": (-6, 0, 0),
            "shin.L": (126, 0, 0), "shin.R": (122, 0, 0),
            "foot.L": (-24, 0, 0), "foot.R": (-22, 0, 0),
            "chest": (8, 0, 0), "head": (10, 0, 0),
            "upper_arm.L": (2, 0, 14), "upper_arm.R": (2, 0, -14),
            "forearm.L": (8, 0, 0), "forearm.R": (8, 0, 0),
            "cloak_a": (18, 0, 0), "cloak_b": (24, 0, 0), "cloak_c": (30, 0, 0),
        }), loc={"root": (0, -0.60, 0)})),
        (17, *P(merged(final, {"head": (18, 0, 0)}),
                loc={"root": (0, -0.78, 0)},
                scale={"bow": (0.0, 0.0, 0.0),
                       "cloak_a": (1.0, 0.86, 1.0),
                       "cloak_b": (1.0, 0.86, 1.0),
                       "cloak_c": (1.0, 0.86, 1.0)})),
        (21, *P(final, loc={"root": (0, -0.78, 0)},
                scale={"bow": (0.0, 0.0, 0.0),
                       "cloak_a": (1.0, 0.86, 1.0),
                       "cloak_b": (1.0, 0.86, 1.0),
                       "cloak_c": (1.0, 0.86, 1.0)})),
        (25, *P(merged(final, {"head": (24, 0, 2)}),
                loc={"root": (0, -0.785, 0)},
                scale={"bow": (0.0, 0.0, 0.0),
                       "cloak_a": (1.0, 0.86, 1.0),
                       "cloak_b": (1.0, 0.86, 1.0),
                       "cloak_c": (1.0, 0.86, 1.0)})),
        (29, *P(merged(final, {"head": (23, 0, -2)}),
                loc={"root": (0, -0.78, 0)},
                scale={"bow": (0.0, 0.0, 0.0),
                       "cloak_a": (1.0, 0.86, 1.0),
                       "cloak_b": (1.0, 0.86, 1.0),
                       "cloak_c": (1.0, 0.86, 1.0)})),
        (33, *P(final, loc={"root": (0, -0.78, 0)},
                scale={"bow": (0.0, 0.0, 0.0),
                       "cloak_a": (1.0, 0.86, 1.0),
                       "cloak_b": (1.0, 0.86, 1.0),
                       "cloak_c": (1.0, 0.86, 1.0)})),
    ]
    prefix = PROFILE["prefix"]
    actions = {
        f"{prefix}_Idle": idle,
        f"{prefix}_Walk": walk,
        f"{prefix}_Run": run,
        f"{prefix}_Attack": attack,
        f"{prefix}_Skill": skill,
        f"{prefix}_Dodge": dodge,
        f"{prefix}_Hit": hit,
        f"{prefix}_Death": death,
    }
    for name, keys in actions.items():
        write_action(name, keys)
    clamp_action_to_ground(f"{prefix}_Death", list(range(1, 34)))
    reset_pose()
    ARM.animation_data.action = bpy.data.actions[f"{prefix}_Idle"]
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
        points = [matrix @ Vector(corner) for corner in evaluated.bound_box]
        # FX parts are collapsed to a point by scaling their bone to zero when
        # they are not active. A collapsed aura still inherits the root bone,
        # so its degenerate bounds would otherwise be mistaken for the lowest
        # point of the character and lift a kneeling death pose off the ground.
        extent = max(
            max(point[i] for point in points) - min(point[i] for point in points)
            for i in range(3)
        )
        if extent < 1e-4:
            continue
        for point in points:
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
        scene.eevee.bloom_threshold = 0.90
        scene.eevee.bloom_intensity = 0.30
        scene.eevee.bloom_radius = 6.0
        scene.eevee.bloom_color = srgb(PALETTE["energy"])
    if hasattr(scene.eevee, "use_gtao"):
        scene.eevee.use_gtao = True

    bpy.ops.object.camera_add(location=(0, -8.0, 2.85))
    camera = bpy.context.object
    camera.name = "Hero_Orthographic_Camera"
    target = Vector((0, 0, 1.62))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.8
    scene.camera = camera

    # Crisp ink contours: the reference art has a dark line around every
    # silhouette and major crease. Freestyle keeps the line one pixel wide at
    # any render resolution, unlike an inverted hull whose world-space
    # thickness changes with the orthographic scale.
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 1.35
    view_layer = scene.view_layers[0]
    view_layer.use_freestyle = True
    freestyle = view_layer.freestyle_settings
    freestyle.crease_angle = math.radians(132.0)
    lineset = freestyle.linesets[0] if freestyle.linesets else freestyle.linesets.new("Ink")
    lineset.select_silhouette = True
    lineset.select_crease = True
    lineset.select_border = True
    lineset.select_contour = False
    lineset.select_external_contour = False
    lineset.select_material_boundary = False
    style = lineset.linestyle
    style.color = (0.015, 0.012, 0.018)
    style.thickness = 1.35

    lights = (
        ("Key_Softbox", (-4.0, -5.0, 6.0), 4.6, (1.0, 0.97, 0.90)),
        ("Fill_Softbox", (4.5, -3.0, 3.0), 2.4, (0.74, 0.86, 1.0)),
        ("Rim_Softbox", (0.0, 4.5, 5.0), 4.0, (0.88, 1.0, 0.86)),
        ("Face_Fill", (0.0, -4.0, 3.2), 1.25, (1.0, 0.94, 0.88)),
    )
    for name, location, energy, color in lights:
        bpy.ops.object.light_add(type="SUN", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.angle = math.radians(28)
        light.rotation_euler = (Vector((0, 0, 1.55)) - light.location).to_track_quat("-Z", "Y").to_euler()


def main():
    global ARM
    clear_scene()
    build_materials()
    make_armature()
    build_head()
    build_face()
    build_hair()
    if PROFILE.get("build_headgear") is not None:
        PROFILE["build_headgear"](builder())
    build_torso()
    if PROFILE.get("build_armour") is not None:
        PROFILE["build_armour"](builder())
    build_limbs()
    build_cloak()
    if PROFILE.get("build_weapon") is not None:
        PROFILE["build_weapon"](builder())
    else:
        build_quiver()
        build_bow()
    if PROFILE.get("build_fx") is not None:
        PROFILE["build_fx"](builder())
    else:
        build_fx()
    build_actions()
    setup_scene()
    scene = bpy.context.scene
    # Persist the identity so the validator (a separate Blender process) knows
    # which rig, action prefix and parts this .blend is expected to contain.
    scene["hero_id"] = ACTIVE_HERO
    scene["hero_prefix"] = PROFILE["prefix"]
    scene["rig_object"] = PROFILE["rig"]
    for name in ("root", "head", "upper_arm.L", "thigh.L", "bow", "cloak_a"):
        matrix = ARM.data.bones[name].matrix_local.to_3x3()
        print("BONE_AXES", name,
              [tuple(round(value, 3) for value in matrix.col[i]) for i in range(3)])
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    print("MESH_PARTS", len(meshes))
    missing = [name for name in PROFILE["required_parts"]
               if bpy.data.objects.get(name) is None]
    if missing:
        raise SystemExit(
            f"{ACTIVE_HERO}: required signature parts are missing: "
            + ", ".join(missing))
    if len(meshes) < hero_profiles.MIN_MESH_PARTS:
        raise SystemExit(
            f"{ACTIVE_HERO}: only {len(meshes)} mesh parts, expected at least "
            f"{hero_profiles.MIN_MESH_PARTS}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
    HERO_OUT.parent.mkdir(parents=True, exist_ok=True)
    if HERO_OUT != OUT:
        shutil.copyfile(OUT, HERO_OUT)
    # Bundle the editor source next to the renders so the read-only CI
    # artifact carries it to the machine that commits the results.
    bundle_source = BUNDLE / "source" / f"{ACTIVE_HERO}_source.blend"
    bundle_source.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(OUT, bundle_source)
    print(f"Saved {ACTIVE_HERO} source: {OUT}")
    print(f"Hero source copy: {HERO_OUT}")
    print(f"Bundled source: {bundle_source}")


if __name__ == "__main__":
    main()
