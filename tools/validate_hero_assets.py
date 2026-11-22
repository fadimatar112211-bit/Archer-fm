#!/usr/bin/env python3
"""Validate a 2.5D hero sprite manifest and TexturePacker-style atlas metadata.

Uses only the Python standard library. It validates metadata and PNG dimensions;
it does not render animations or prove visual quality/performance.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path
from typing import Any


class ValidationError(Exception):
    pass


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValidationError(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValidationError(f"{path}: root must be a JSON object")
    return value


def png_dimensions(path: Path) -> tuple[int, int]:
    try:
        with path.open("rb") as stream:
            header = stream.read(24)
    except OSError as exc:
        raise ValidationError(f"Cannot read atlas image {path}: {exc}") from exc
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValidationError(f"{path}: not a valid PNG header")
    width, height = struct.unpack(">II", header[16:24])
    if width < 1 or height < 1:
        raise ValidationError(f"{path}: PNG dimensions must be positive")
    return width, height


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def validate(manifest_path: Path) -> list[str]:
    manifest = read_json(manifest_path)
    base = manifest_path.parent
    errors: list[str] = []

    try:
        require(manifest.get("schema_version") == 1, "schema_version must be 1")
        hero_id = manifest.get("hero_id")
        require(isinstance(hero_id, str) and bool(hero_id.strip()), "hero_id is required")

        frame_size = manifest.get("frame_size")
        require(isinstance(frame_size, dict), "frame_size object is required")
        fw, fh = frame_size.get("width"), frame_size.get("height")
        require(type(fw) is int and fw > 0 and type(fh) is int and fh > 0,
                "frame_size.width/height must be positive integers")

        pivot = manifest.get("pivot")
        require(isinstance(pivot, dict), "pivot object is required")
        px, py = pivot.get("x"), pivot.get("y")
        require(isinstance(px, (int, float)) and isinstance(py, (int, float))
                and 0 <= px <= 1 and 0 <= py <= 1,
                "pivot x/y must be normalized numbers between 0 and 1")

        atlases = manifest.get("atlases")
        require(isinstance(atlases, list) and len(atlases) > 0, "atlases must be a non-empty array")
        frame_map: dict[str, dict[str, Any]] = {}
        frame_rects: list[tuple[str, int, int, int, int, Path, int | None]] = []
        seen_atlas_sources: set[tuple[str, str]] = set()
        for atlas in atlases:
            require(isinstance(atlas, dict), "each atlas entry must be an object")
            image_rel, meta_rel = atlas.get("image"), atlas.get("meta")
            # Multiple animation states may intentionally reference the same
            # atlas + metadata pair. Validate that physical atlas once; counting
            # the same frame IDs again would create false duplicate-frame errors.
            source_key = (image_rel, meta_rel)
            if source_key in seen_atlas_sources:
                continue
            seen_atlas_sources.add(source_key)
            require(isinstance(image_rel, str) and isinstance(meta_rel, str),
                    "each atlas needs image and meta paths")
            image_path, meta_path = base / image_rel, base / meta_rel
            meta = read_json(meta_path)
            width, height = png_dimensions(image_path)
            meta_info = meta.get("meta", {})
            meta_size = meta_info.get("size", {}) if isinstance(meta_info, dict) else {}
            if isinstance(meta_size, dict) and meta_size:
                require(meta_size.get("w") == width and meta_size.get("h") == height,
                        f"{meta_path}: metadata dimensions do not match PNG")
            frames = meta.get("frames")
            require(isinstance(frames, dict), f"{meta_path}: frames must be an object")
            for frame_id, entry in frames.items():
                require(frame_id not in frame_map, f"duplicate frame id: {frame_id}")
                require(isinstance(entry, dict) and isinstance(entry.get("frame"), dict),
                        f"{meta_path}: frame {frame_id} has no rectangle")
                rect = entry["frame"]
                x, y, w, h = (rect.get(k) for k in ("x", "y", "w", "h"))
                require(all(type(v) is int for v in (x, y, w, h)) and
                        x >= 0 and y >= 0 and w > 0 and h > 0 and
                        x + w <= width and y + h <= height,
                        f"{meta_path}: frame {frame_id} rectangle is outside atlas")
                require(entry.get("rotated") is not True,
                        f"{meta_path}: rotated frame {frame_id} is unsupported")
                source = entry.get("sourceSize")
                if isinstance(source, dict):
                    require(source.get("w") == fw and source.get("h") == fh,
                            f"{meta_path}: {frame_id} sourceSize differs from frame_size")
                require(entry.get("trimmed") is not True,
                        f"{meta_path}: trimmed frame {frame_id} is unsupported")
                meta_info = meta.get("meta", {})
                declared_padding = meta_info.get("padding") if isinstance(meta_info, dict) else None
                if declared_padding is not None:
                    require(type(declared_padding) is int and declared_padding >= 0,
                            f"{meta_path}: padding must be a non-negative integer")
                frame_map[frame_id] = entry
                frame_rects.append((frame_id, x, y, w, h, meta_path, declared_padding))

        animations = manifest.get("animations")
        require(isinstance(animations, dict) and len(animations) > 0,
                "animations must be a non-empty object")
        for name, animation in animations.items():
            require(isinstance(animation, dict), f"{name}: animation must be an object")
            require(type(animation.get("loop")) is bool, f"{name}: loop must be boolean")
            duration = animation.get("frame_duration_ms")
            require(type(duration) is int and duration > 0,
                    f"{name}: frame_duration_ms must be a positive integer")
            frames = animation.get("frames")
            require(isinstance(frames, list) and len(frames) > 0,
                    f"{name}: frames must be a non-empty ordered array")
            for frame_id in frames:
                require(isinstance(frame_id, str) and frame_id in frame_map,
                        f"{name}: missing atlas frame {frame_id}")
            events = animation.get("events", [])
            require(isinstance(events, list), f"{name}: events must be an array")
            event_names = [e.get("name") for e in events if isinstance(e, dict)]
            for event_name in event_names:
                require(isinstance(event_name, str) and bool(event_name.strip()),
                        f"{name}: event name is required")
            for event in events:
                require(isinstance(event, dict), f"{name}: event must be an object")
                index, event_name = event.get("frame"), event.get("name")
                require(type(index) is int and 0 <= index < len(frames),
                        f"{name}: event frame index is out of range")
                require(isinstance(event_name, str) and bool(event_name.strip()),
                        f"{name}: event name is required")
            for state in ("attack",):
                if name.startswith(state + "_"):
                    if hero_id == "ranger":
                        release_events = [e for e in events
                                          if isinstance(e, dict) and e.get("name") == "projectile_release"]
                        require(len(release_events) == 1,
                                f"{name}: attack must have exactly one projectile_release event")
                    else:
                        require(len(events) >= 1,
                                f"{name}: melee attack must declare at least one gameplay event")
        # Cross-atlas checks
        for i in range(len(frame_rects)):
            for j in range(i + 1, len(frame_rects)):
                fid_a, ax, ay, aw, ah, meta_a, pad_a = frame_rects[i]
                fid_b, bx, by, bw, bh, meta_b, pad_b = frame_rects[j]
                if meta_a == meta_b:
                    overlap = (ax < bx + bw and bx < ax + aw and
                               ay < by + bh and by < ay + ah)
                    require(not overlap,
                            f"{meta_a}: frames {fid_a} and {fid_b} overlap")
                    gap_x = max(0, max(ax - (bx + bw), bx - (ax + aw)))
                    gap_y = max(0, max(ay - (by + bh), by - (ay + ah)))
                    min_gap = min(gap_x, gap_y) if (gap_x > 0 or gap_y > 0) else 0
                    if min_gap > 0:
                        effective_pad = pad_a if pad_a is not None else 0
                        require(min_gap >= effective_pad,
                                f"{meta_a}: frames {fid_a} and {fid_b} have gap {min_gap}px "
                                f"< declared padding {effective_pad}px")
    except ValidationError as exc:
        errors.append(str(exc))

    return errors


def discover_manifests(primary: Path) -> list[Path]:
    """Every hero manifest in the repo, starting with the requested one.

    The CI step passes the ranger manifest because the workflow is fixed, but
    the pipeline renders one hero per run. Validating all siblings means a hero
    can never reach an artifact unvalidated just because it is not the Ranger.
    """
    paths = [primary]
    if len(primary.parents) >= 5:
        heroes = primary.parents[4] / "assets" / "heroes"
        for candidate in sorted(heroes.glob("*/renders/*_manifest.json")):
            if candidate.resolve() == primary.resolve():
                continue
            paths.append(candidate)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="path to hero manifest JSON")
    args = parser.parse_args()
    failed = False
    for manifest in discover_manifests(args.manifest):
        errors = validate(manifest)
        if errors:
            failed = True
            for error in errors:
                print(f"ERROR: {error}", file=sys.stderr)
        else:
            print(f"OK: {manifest} passed structural asset validation")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
