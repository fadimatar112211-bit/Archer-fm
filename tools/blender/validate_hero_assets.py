#!/usr/bin/env python3
"""Strict cross-hero validation for the checked-in directional sprite runtime."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HEROES = ("ranger", "flame", "shadow", "storm")
STATES = ("idle", "walk", "run", "attack", "skill", "dodge", "hit", "death")
DIRECTIONS = ("s", "sw", "w", "nw", "n", "ne", "e", "se")

def require(ok, message):
    if not ok:
        raise SystemExit("HERO_ASSET_VALIDATION_FAILED: " + message)

def validate(hero):
    base = ROOT / "assets" / "heroes" / hero / "renders"
    manifest_path = base / f"{hero}_manifest.json"
    require(manifest_path.is_file(), f"{hero}: missing {manifest_path.relative_to(ROOT)}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(manifest.get("hero_id") == hero, f"{hero}: manifest hero_id mismatch")
    require(manifest.get("frame_size") == {"width": 192, "height": 192},
            f"{hero}: expected 192x192 frames")
    animations = manifest.get("animations")
    atlases = manifest.get("atlases")
    require(isinstance(animations, dict), f"{hero}: animations must be an object")
    require(isinstance(atlases, list), f"{hero}: atlases must be a list")
    expected = {f"{state}_{direction}" for state in STATES for direction in DIRECTIONS}
    require(set(animations) == expected,
            f"{hero}: animation coverage mismatch; missing={sorted(expected-set(animations))}, extra={sorted(set(animations)-expected)}")
    atlas_by_animation = {entry.get("animation"): entry for entry in atlases}
    require(set(atlas_by_animation) == expected, f"{hero}: atlas entries do not cover exactly 64 clips")
    total_frames = 0
    for animation in sorted(expected):
        clip = animations[animation]
        frame_ids = clip.get("frames")
        require(isinstance(frame_ids, list) and len(frame_ids) >= 2,
                f"{hero}/{animation}: needs at least two frames")
        require(len(frame_ids) == len(set(frame_ids)),
                f"{hero}/{animation}: duplicate frame ids")
        require(all(isinstance(fid, str) and fid.startswith(hero + "_") for fid in frame_ids),
                f"{hero}/{animation}: frame id has wrong hero prefix")
        entry = atlas_by_animation[animation]
        image_path = base / entry.get("image", "")
        meta_path = base / entry.get("meta", "")
        require(image_path.is_file(), f"{hero}/{animation}: missing atlas image {image_path}")
        require(meta_path.is_file(), f"{hero}/{animation}: missing atlas metadata {meta_path}")
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        frames = meta.get("frames")
        require(isinstance(frames, dict), f"{hero}/{animation}: metadata frames missing")
        require(set(frames) == set(frame_ids),
                f"{hero}/{animation}: manifest/atlas frame ids differ")
        size = meta.get("meta", {}).get("size", {})
        require(isinstance(size.get("w"), int) and isinstance(size.get("h"), int),
                f"{hero}/{animation}: invalid atlas dimensions")
        with Image.open(image_path) as atlas:
            require(atlas.size == (size["w"], size["h"]),
                    f"{hero}/{animation}: PNG dimensions disagree with metadata")
            require(atlas.getbbox() is not None, f"{hero}/{animation}: empty atlas image")
        for frame_id, frame_data in frames.items():
            rect = frame_data.get("frame", {})
            x, y, w, h = (rect.get(k) for k in ("x", "y", "w", "h"))
            require(all(isinstance(n, int) for n in (x, y, w, h)) and w > 0 and h > 0,
                    f"{hero}/{animation}/{frame_id}: invalid frame rectangle")
            require(x >= 0 and y >= 0 and x + w <= size["w"] and y + h <= size["h"],
                    f"{hero}/{animation}/{frame_id}: frame rectangle outside atlas")
        total_frames += len(frame_ids)
    print(f"HERO_ASSETS_OK hero={hero} clips={len(expected)} atlases={len(expected)} frames={total_frames}")

def main():
    for hero in HEROES:
        validate(hero)
    print("ALL_FOUR_HEROES_VALIDATED")

if __name__ == "__main__":
    main()
