#!/usr/bin/env python3
"""Pack rendered Storm frames into the runtime's 4-column atlas contract."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RENDER = ROOT / "assets/heroes/storm/renders"
FRAME_DIR = Path("/tmp/archer_storm_frames")
ATLAS_DIR = RENDER / "atlases"
ATLAS_DIR.mkdir(parents=True, exist_ok=True)
manifest_path = RENDER / "storm_manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
for animation, clip in manifest["animations"].items():
    ids = clip["frames"]
    if len(ids) < 2 or len(ids) != len(set(ids)):
        raise SystemExit(f"Invalid frame ids in {animation}")
    columns = 4
    rows = (len(ids) + columns - 1) // columns
    cell = 196
    atlas = Image.new("RGBA", (columns * cell, rows * cell), (0, 0, 0, 0))
    frames = {}
    hashes = set()
    for i, frame_id in enumerate(ids):
        src = FRAME_DIR / f"{frame_id}.png"
        if not src.is_file():
            raise SystemExit(f"Missing rendered frame {src}")
        with Image.open(src) as image:
            image = image.convert("RGBA")
            if image.size != (192, 192):
                raise SystemExit(f"Wrong frame size {src}: {image.size}")
            if image.getbbox() is None:
                raise SystemExit(f"Transparent/empty frame: {src}")
            digest = image.tobytes()
            hashes.add(hash(digest))
            x = (i % columns) * cell + 2
            y = (i // columns) * cell + 2
            atlas.paste(image, (x, y), image)
        frames[frame_id] = {
            "frame": {"x": x, "y": y, "w": 192, "h": 192},
            "rotated": False,
            "trimmed": False,
            "spriteSourceSize": {"x": 0, "y": 0, "w": 192, "h": 192},
            "sourceSize": {"w": 192, "h": 192},
        }
    if len(hashes) < 2:
        raise SystemExit(f"All frames identical in {animation}; refusing fake animation")
    image_path = ATLAS_DIR / f"{animation}.png"
    meta_path = ATLAS_DIR / f"{animation}.json"
    atlas.save(image_path, optimize=True)
    meta = {"frames": frames, "meta": {"size": {"w": atlas.width, "h": atlas.height}, "image": image_path.name}}
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"ATLAS_OK {animation} frames={len(ids)} size={atlas.width}x{atlas.height}")
print("STORM_ATLASES_COMPLETE", len(manifest["atlases"]))
