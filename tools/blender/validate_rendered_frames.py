#!/usr/bin/env python3
"""Reject empty, clipped, or collapsed Ranger renders before atlas packing."""
from __future__ import annotations
import argparse
from pathlib import Path
from PIL import Image

STATES = ("idle", "walk", "attack", "death")
DIRECTIONS = ("s", "sw", "w", "nw", "n", "ne", "e", "se")


def ascii_preview(image, bbox, columns=44):
    """Render the alpha silhouette as text so a failing CI run is inspectable."""
    alpha = image.getchannel("A")
    pad = 4
    crop = alpha.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                       min(image.width, bbox[2] + pad), min(image.height, bbox[3] + pad)))
    rows = max(1, round(columns * crop.height / max(1, crop.width) * 0.5))
    crop = crop.resize((columns, rows), Image.BILINEAR)
    ramp = " .:-=+*#%@"
    return ["".join(ramp[min(len(ramp) - 1, crop.getpixel((x, y)) * len(ramp) // 256)]
                    for x in range(crop.width))
            for y in range(crop.height)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--resolution", type=int, default=192)
    args = parser.parse_args()
    errors = []
    checked = 0
    previews = []
    for state in STATES:
        for direction in DIRECTIONS:
            frames = sorted((args.root / state / direction).glob("*.png"))
            if len(frames) < 2:
                errors.append(f"{state}/{direction}: expected multiple frames, found {len(frames)}")
                continue
            for path in frames:
                checked += 1
                try:
                    with Image.open(path) as source:
                        image = source.convert("RGBA")
                        if image.size != (args.resolution, args.resolution):
                            errors.append(f"{path}: wrong dimensions {image.size}")
                            continue
                        alpha = image.getchannel("A")
                        bbox = alpha.getbbox()
                        if bbox is None:
                            errors.append(f"{path}: fully transparent render")
                            continue
                        width, height = bbox[2] - bbox[0], bbox[3] - bbox[1]
                        occupied = sum(1 for value in alpha.getdata() if value > 8)
                        if path.name.endswith("_000.png") and len(previews) < 8:
                            previews.append((path, bbox, ascii_preview(image, bbox)))
                        if occupied < 350:
                            errors.append(f"{path}: too few visible pixels ({occupied})")
                        margin = max(2, round(args.resolution * 0.01))
                        if (bbox[0] <= margin or bbox[1] <= margin
                                or bbox[2] >= args.resolution - margin
                                or bbox[3] >= args.resolution - margin):
                            errors.append(f"{path}: character clipped or lacks safe edge margin ({bbox})")
                        # Bounding-box aspect ratio is not a reliable collapse test:
                        # side-facing bows, cloaks and weapon poses legitimately widen it.
                        # Require meaningful vertical extent and visible content in multiple
                        # vertical bands instead, which detects a truly flattened render.
                        if state != "death":
                            min_height = max(48, round(args.resolution * 0.28))
                            if height < min_height:
                                errors.append(f"{path}: insufficient upright silhouette height {height}px")
                            if height:
                                band_hits = 0
                                for band in range(4):
                                    y0 = bbox[1] + (height * band) // 4
                                    y1 = bbox[1] + (height * (band + 1)) // 4
                                    if y1 <= y0:
                                        continue
                                    crop = alpha.crop((bbox[0], y0, bbox[2], y1))
                                    if crop.getbbox() is not None:
                                        band_hits += 1
                                if band_hits < 4:
                                    errors.append(f"{path}: collapsed vertical silhouette ({band_hits}/4 bands occupied)")
                except Exception as exc:
                    errors.append(f"{path}: cannot inspect PNG: {exc}")
    if errors:
        for error in errors[:80]:
            print("VISUAL_ERROR: " + error)
        for path, bbox, lines in previews:
            print(f"VISUAL_PREVIEW {path.relative_to(args.root)} bbox={bbox}")
            for line in lines:
                print("  |" + line + "|")
        print(f"RANGER_VISUAL_CHECK_FAILED checked={checked} errors={len(errors)}")
        return 1
    print(f"RANGER_VISUAL_CHECK_OK checked={checked} frames across {len(STATES)} states and {len(DIRECTIONS)} directions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
