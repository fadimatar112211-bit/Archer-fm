"""Pack rendered Ranger PNG frames into deterministic grid atlases.

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

def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--columns", type=int, default=4)
    return parser.parse_args(argv)

def main():
    opt = parse_args()
    manifest_path = opt.manifest.resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    base = manifest_path.parent
    fw = int(manifest["frame_size"]["width"])
    fh = int(manifest["frame_size"]["height"])
    if opt.columns < 1:
        raise RuntimeError("--columns must be positive")
    atlas_entries = []
    for animation_name, animation in sorted(manifest["animations"].items()):
        frame_ids = animation["frames"]
        cols = min(opt.columns, len(frame_ids))
        rows = (len(frame_ids) + cols - 1) // cols
        atlas_w, atlas_h = cols * fw, rows * fh
        image = bpy.data.images.new("atlas_" + animation_name,
                                    width=atlas_w, height=atlas_h,
                                    alpha=True, float_buffer=False)
        pixels = array("f", [0.0]) * (atlas_w * atlas_h * 4)
        state, direction = animation_name.rsplit("_", 1)
        frame_meta = {}
        for index, frame_id in enumerate(frame_ids):
            source_path = base / state / direction / (frame_id + ".png")
            if not source_path.is_file():
                raise RuntimeError("Missing rendered frame: " + str(source_path))
            source = bpy.data.images.load(str(source_path), check_existing=False)
            if tuple(source.size) != (fw, fh):
                raise RuntimeError("Unexpected frame dimensions: " + str(source_path))
            src = array("f", source.pixels[:])
            col, row = index % cols, index // cols
            for y in range(fh):
                src_start = y * fw * 4
                dst_start = ((row * fh + y) * atlas_w + col * fw) * 4
                pixels[dst_start:dst_start + fw * 4] = src[src_start:src_start + fw * 4]
            frame_meta[frame_id] = {
                "frame": {"x": col * fw, "y": row * fh, "w": fw, "h": fh},
                "rotated": False, "trimmed": False,
                "spriteSourceSize": {"x": 0, "y": 0, "w": fw, "h": fh},
                "sourceSize": {"w": fw, "h": fh}
            }
            bpy.data.images.remove(source)
        image.pixels[:] = pixels
        image.file_format = "PNG"
        atlas_dir = base / "atlases"
        atlas_dir.mkdir(parents=True, exist_ok=True)
        image.filepath_raw = str(atlas_dir / (animation_name + ".png"))
        image.save()
        meta_path = atlas_dir / (animation_name + ".json")
        meta_path.write_text(json.dumps({
            "frames": frame_meta,
            "meta": {"app": "Archer FM Blender Atlas Packer",
                     "image": animation_name + ".png",
                     "size": {"w": atlas_w, "h": atlas_h}, "scale": "1"}
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
    print("Packed " + str(len(atlas_entries)) + " atlases into " + str(base / "atlases"))

if __name__ == "__main__":
    main()
