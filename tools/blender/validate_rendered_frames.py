#!/usr/bin/env python3
"""Reject empty, clipped, or flattened Ranger renders before atlas packing."""
from __future__ import annotations
import argparse
from pathlib import Path
from PIL import Image

STATES = ("idle", "walk", "attack", "death")
DIRECTIONS = ("s", "sw", "w", "nw", "n", "ne", "e", "se")

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--resolution", type=int, default=192)
    args = parser.parse_args()
    errors = []
    checked = 0
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
                        if occupied < 350:
                            errors.append(f"{path}: too few visible pixels ({occupied})")
                        if bbox[0] <= 1 or bbox[1] <= 1 or bbox[2] >= args.resolution - 1 or bbox[3] >= args.resolution - 1:
                            errors.append(f"{path}: character clipped by image edge ({bbox})")
                        # The living poses must read as an upright character, not a flattened rig.
                        if state != "death" and height < width * 0.82:
                            errors.append(f"{path}: flattened silhouette {width}x{height}")
                except Exception as exc:
                    errors.append(f"{path}: cannot inspect PNG: {exc}")
    if errors:
        for error in errors[:80]:
            print("VISUAL_ERROR: " + error)
        print(f"RANGER_VISUAL_CHECK_FAILED checked={checked} errors={len(errors)}")
        return 1
    print(f"RANGER_VISUAL_CHECK_OK checked={checked} frames across {len(STATES)} states and {len(DIRECTIONS)} directions")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
