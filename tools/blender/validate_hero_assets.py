#!/usr/bin/env python3
"""Strict cross-hero validation for both legacy and schema-v2 directional manifests."""
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


def expected_clips():
    return {f"{state}_{direction}" for state in STATES for direction in DIRECTIONS}


def atlas_entries(manifest, hero):
    """Normalize both the compact legacy manifest and schema-v2 manifest."""
    animations = manifest.get("animations")
    atlases = manifest.get("atlases")
    if isinstance(animations, dict) and isinstance(atlases, list):
        require(set(animations) == expected_clips(),
                f"{hero}: animation coverage mismatch")
        by_name = {entry.get("animation"): entry for entry in atlases}
        require(len(by_name) == len(atlases), f"{hero}: duplicate atlas entries")
        require(set(by_name) == expected_clips(),
                f"{hero}: atlas entries do not cover exactly 64 clips")
        result = {}
        for name in sorted(expected_clips()):
            clip = animations[name]
            frames = clip.get("frames")
            require(isinstance(frames, list) and len(frames) >= 2,
                    f"{hero}/{name}: needs at least two frames")
            require(len(frames) == len(set(frames)),
                    f"{hero}/{name}: duplicate frame IDs")
            require(all(isinstance(fid, str) and fid.startswith(hero + "_")
                        for fid in frames),
                    f"{hero}/{name}: frame ID has wrong hero prefix")
            result[name] = (frames, by_name[name].get("image"), by_name[name].get("meta"))
        return result

    # Ranger, Flame and Shadow currently use a compact manifest that records
    # counts only; atlas names and frame IDs follow the established convention.
    require(manifest.get("clip_count") == 64, f"{hero}: legacy clip_count must be 64")
    require(manifest.get("atlas_count") == 64, f"{hero}: legacy atlas_count must be 64")
    require(manifest.get("states") == list(STATES), f"{hero}: legacy states mismatch")
    require(manifest.get("direction_coverage") == list(DIRECTIONS),
            f"{hero}: legacy direction coverage mismatch")
    per_state = manifest.get("frames_per_state")
    require(isinstance(per_state, dict) and set(per_state) == set(STATES),
            f"{hero}: legacy frames_per_state is incomplete")
    result = {}
    for state in STATES:
        count = per_state[state]
        require(isinstance(count, int) and count >= 2,
                f"{hero}/{state}: invalid frame count")
        for direction in DIRECTIONS:
            name = f"{state}_{direction}"
            ids = [f"{hero}_{name}_{index:03d}" for index in range(count)]
            result[name] = (ids, f"atlases/{name}.png", f"atlases/{name}.json")
    return result


def validate(hero):
    base = ROOT / "assets" / "heroes" / hero / "renders"
    manifest_path = base / f"{hero}_manifest.json"
    require(manifest_path.is_file(), f"{hero}: missing {manifest_path.relative_to(ROOT)}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(manifest.get("hero_id") == hero, f"{hero}: manifest hero_id mismatch")
    require(manifest.get("frame_size") == {"width": 192, "height": 192},
            f"{hero}: expected 192x192 frames")

    clips = atlas_entries(manifest, hero)
    total_frames = 0
    for animation, (frame_ids, image_name, meta_name) in clips.items():
        require(isinstance(image_name, str) and image_name,
                f"{hero}/{animation}: missing atlas image path")
        require(isinstance(meta_name, str) and meta_name,
                f"{hero}/{animation}: missing atlas metadata path")
        image_path = base / image_name
        meta_path = base / meta_name
        require(image_path.is_file(), f"{hero}/{animation}: missing atlas image {image_path}")
        require(meta_path.is_file(), f"{hero}/{animation}: missing atlas metadata {meta_path}")
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        frames = meta.get("frames")
        require(isinstance(frames, dict), f"{hero}/{animation}: metadata frames missing")
        require(set(frames) == set(frame_ids),
                f"{hero}/{animation}: manifest/atlas frame IDs differ")
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
    print(f"HERO_ASSETS_OK hero={hero} clips={len(clips)} atlases={len(clips)} frames={total_frames}")


def main():
    for hero in HEROES:
        validate(hero)
    print("ALL_FOUR_HEROES_VALIDATED")


if __name__ == "__main__":
    main()
