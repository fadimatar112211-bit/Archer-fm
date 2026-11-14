"""Pack rendered Ranger PNG frames into deterministic grid atlases with padding and edge extrusion.

Run:
  blender -b ranger_source.blend --python tools/blender/pack_hero_atlases.py -- --manifest assets/heroes/ranger/renders/ranger_manifest.json
"""
from __future__ import annotations
import argparse
from array import array
import json
import sys
from pathlib import Path
import bpy

DEFAULT_PADDING = 2


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--padding", type=int, default=DEFAULT_PADDING,
                        help=f"Pixel gap between frames (default: {DEFAULT_PADDING})")
    return parser.parse_args(argv)


def extrude_edges(pixels, fw, fh, atlas_w, atlas_h, col, row, padding):
    """Copy edge pixels into padding area to prevent texture filtering seams."""
    base_x = col * fw + (col + 1) * padding
    base_y = row * fh + (row + 1) * padding

    # Left edge: copy leftmost column into padding columns to the left
    for y in range(fh):
        src_y = base_y + y
        src_start = src_y * atlas_w * 4 + base_x * 4
        for p in range(padding):
            dst_x = base_x - (p + 1)
            dst_start = src_y * atlas_w * 4 + dst_x * 4
            pixels[dst_start:dst_start + 4] = pixels[src_start:src_start + 4]

    # Right edge: copy rightmost column into padding columns to the right
    for y in range(fh):
        src_y = base_y + y
        src_start = src_y * atlas_w * 4 + (base_x + fw - 1) * 4
        for p in range(padding):
            dst_x = base_x + fw + p
            dst_start = src_y * atlas_w * 4 + dst_x * 4
            pixels[dst_start:dst_start + 4] = pixels[src_start:src_start + 4]

    # Top edge: copy topmost row into padding rows above
    for x in range(fw):
        src_x = base_x + x
        src_start = base_y * atlas_w * 4 + src_x * 4
        for p in range(padding):
            dst_y = base_y - (p + 1)
            dst_start = dst_y * atlas_w * 4 + src_x * 4
            pixels[dst_start:dst_start + 4] = pixels[src_start:src_start + 4]

    # Bottom edge: copy bottommost row into padding rows below
    for x in range(fw):
        src_x = base_x + x
        src_start = (base_y + fh - 1) * atlas_w * 4 + src_x * 4
        for p in range(padding):
            dst_y = base_y + fh + p
            dst_start = dst_y * atlas_w * 4 + src_x * 4
            pixels[dst_start:dst_start + 4] = pixels[src_start:src_start + 4]


def main():
    opt = parse_args()
    manifest_path = opt.manifest.resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    base = manifest_path.parent
    fw = int(manifest["frame_size"]["width"])
    fh = int(manifest["frame_size"]["height"])
    padding = max(0, opt.padding)
    if opt.columns < 1:
        raise RuntimeError("--columns must be positive")
    atlas_entries = []
    for animation_name, animation in sorted(manifest["animations"].items()):
        frame_ids = animation["frames"]
        cols = min(opt.columns, len(frame_ids))
        rows = (len(frame_ids) + cols - 1) // cols
        atlas_w = cols * fw + (cols + 1) * padding
        atlas_h = rows * fh + (rows + 1) * padding
        image = bpy.data.images.new("atlas_" + animation_name,
                                    width=atlas_w, height=atlas_h,
                                    alpha=True, float_buffer=False)
        # The atlas is a byte-for-byte copy of the rendered PNGs. Pin both the
        # source frames and the atlas to a data colour space so Blender does
        # not round-trip the pixels through scene-linear colour, which shifts
        # anti-aliased and semi-transparent edge pixels.
        image.colorspace_settings.name = "Non-Color"
        image.alpha_mode = "STRAIGHT"
        pixels = array("f", [0.0]) * (atlas_w * atlas_h * 4)
        state, direction = animation_name.rsplit("_", 1)
        frame_meta = {}
        for index, frame_id in enumerate(frame_ids):
            source_path = base / state / direction / (frame_id + ".png")
            if not source_path.is_file():
                raise RuntimeError(f"Missing frame: {source_path}")
            source = bpy.data.images.load(str(source_path))
            source.colorspace_settings.name = "Non-Color"
            source.alpha_mode = "STRAIGHT"
            # Verify source image dimensions match expected frame size
            if source.size[0] != fw or source.size[1] != fh:
                bpy.data.images.remove(source)
                raise RuntimeError(
                    f"Frame {frame_id} has dimensions {source.size[0]}x{source.size[1]}, "
                    f"expected {fw}x{fh} (from manifest frame_size)"
                )
            src = array("f", source.pixels[:])
            bpy.data.images.remove(source)
            col, row = index % cols, index // cols
            base_x = col * fw + (col + 1) * padding
            base_y = row * fh + (row + 1) * padding
            for y in range(fh):
                src_start = y * fw * 4
                dst_start = ((base_y + y) * atlas_w + base_x) * 4
                pixels[dst_start:dst_start + fw * 4] = src[src_start:src_start + fw * 4]
            # Extrude edges into padding area to prevent texture seams
            if padding > 0:
                extrude_edges(pixels, fw, fh, atlas_w, atlas_h, col, row, padding)
            # TexturePacker-style metadata for untrimmed frames:
            # - frame: position and size in atlas (with padding offset)
            # - spriteSourceSize: position and size in original untrimmed image (0,0, fw, fh)
            # - sourceSize: original image size (fw, fh)
            # - trimmed: false
            frame_meta[frame_id] = {
                "frame": {"x": base_x, "y": base_y, "w": fw, "h": fh},
                "rotated": False, "trimmed": False,
                "spriteSourceSize": {"x": 0, "y": 0, "w": fw, "h": fh},
                "sourceSize": {"w": fw, "h": fh}
            }
        image.pixels[:] = pixels
        image.file_format = "PNG"
        atlas_dir = base / "atlases"
        atlas_dir.mkdir(parents=True, exist_ok=True)
        image.filepath_raw = str(atlas_dir / (animation_name + ".png"))
        image.save()
        meta_path = atlas_dir / (animation_name + ".json")
        meta_path.write_text(json.dumps({
            "frames": frame_meta,
            "meta": {
                "app": "Archer FM Blender Atlas Packer",
                "image": animation_name + ".png",
                "size": {"w": atlas_w, "h": atlas_h},
                "scale": "1",
                "padding": padding,
                "frame_size": {"w": fw, "h": fh},
                "pivot": manifest.get("pivot", {"x": 0.5, "y": 0.86}),
                "memory_estimate_mb": round(atlas_w * atlas_h * 4 / (1024 * 1024), 2)
            }
        }, indent=2) + "\n", encoding="utf-8")
        atlas_entries.append({
            "animation": animation_name,
            "image": "atlases/" + animation_name + ".png",
            "meta": "atlases/" + animation_name + ".json"
        })
        bpy.data.images.remove(image)
    manifest["atlases"] = atlas_entries
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                             encoding="utf-8")
    print(f"Packed {len(atlas_entries)} atlases into {base / 'atlases'}")


if __name__ == "__main__":
    main()
