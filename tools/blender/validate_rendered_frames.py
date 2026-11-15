#!/usr/bin/env python3
"""Reject empty, clipped, collapsed or stale hero renders before atlas packing.

The CI workflow always passes the Ranger render root because it cannot be
edited. Every hero renders there, and this gate additionally proves the frames
on disk belong to the hero named in `active_hero.txt`: a failed render pass
would otherwise leave the previous hero's frames in place and quietly ship the
wrong character under a green build.
"""
from __future__ import annotations
import argparse
import base64
import json
from pathlib import Path
from PIL import Image

STATES = ("idle", "walk", "run", "attack", "skill", "dodge", "hit", "death")
DIRECTIONS = ("s", "sw", "w", "nw", "n", "ne", "e", "se")


def active_hero(root: Path) -> tuple[str, dict | None]:
    """The hero this run must produce, plus its manifest when one exists."""
    marker = Path(__file__).resolve().parent / "active_hero.txt"
    hero = (marker.read_text(encoding="utf-8").strip().lower()
            if marker.is_file() else "ranger") or "ranger"
    path = root / "ranger_manifest.json"
    if not path.is_file():
        return hero, None
    return hero, json.loads(path.read_text(encoding="utf-8"))


def ascii_preview(image, bbox, columns=40):
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


def frame_errors(path, image, state, resolution):
    """Return every violation for one rendered frame plus its metrics."""
    errors = []
    if image.size != (resolution, resolution):
        return [f"{path}: wrong dimensions {image.size}"], None
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return [f"{path}: fully transparent render"], None
    width, height = bbox[2] - bbox[0], bbox[3] - bbox[1]
    occupied = sum(1 for value in alpha.getdata() if value > 8)
    metrics = {"bbox": bbox, "width": width, "height": height, "occupied": occupied}
    if occupied < 350:
        errors.append(f"{path}: too few visible pixels ({occupied})")
    # EEVEE renders a material whose Surface input is a colour (not a shader)
    # as flat magenta. Alpha/layout gates cannot see that, so sample the pixels.
    # `getdata()` yields RGBA tuples (not a flat channel list).
    magenta = 0
    sampled = 0
    for r, g, b, a in image.getdata():
        if a < 200:
            continue
        sampled += 1
        if r > 140 and b > 140 and g < 60:
            magenta += 1
    if sampled and magenta / sampled > 0.3:
        errors.append(f"{path}: mostly magenta pixels; material surface is not a shader")
    margin = max(2, round(resolution * 0.01))
    if (bbox[0] <= margin or bbox[1] <= margin
            or bbox[2] >= resolution - margin
            or bbox[3] >= resolution - margin):
        errors.append(f"{path}: character clipped or lacks safe edge margin ({bbox})")
    # Bounding-box aspect ratio is not a reliable collapse test: side-facing
    # bows, cloaks and weapon poses legitimately widen it. Require meaningful
    # vertical extent and visible content in multiple vertical bands instead,
    # which detects a truly flattened render. A death frame is deliberately
    # horizontal once the Ranger is on the ground, so it is exempt.
    if state != "death":
        min_height = max(48, round(resolution * 0.28))
        if height < min_height:
            errors.append(f"{path}: insufficient upright silhouette height {height}px")
        if height:
            band_hits = 0
            for band in range(4):
                y0 = bbox[1] + (height * band) // 4
                y1 = bbox[1] + (height * (band + 1)) // 4
                if y1 <= y0:
                    continue
                if alpha.crop((bbox[0], y0, bbox[2], y1)).getbbox() is not None:
                    band_hits += 1
            if band_hits < 4:
                errors.append(f"{path}: collapsed vertical silhouette ({band_hits}/4 bands occupied)")
    return errors, metrics


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--resolution", type=int, default=192)
    args = parser.parse_args()
    errors = []
    checked = 0
    frames_by = {}
    first_failing = None
    hero, manifest = active_hero(args.root)
    expected_by = {}
    if manifest is None:
        errors.append(f"no ranger_manifest.json in {args.root}; the render pass "
                      f"did not complete")
    else:
        if manifest.get("hero_id") != hero:
            errors.append(f"manifest hero_id is {manifest.get('hero_id')!r} but "
                          f"active_hero.txt asks for {hero!r}; refusing to "
                          f"validate a stale render set")
        for state in STATES:
            for direction in DIRECTIONS:
                name = f"{state}_{direction}"
                animation = manifest.get("animations", {}).get(name)
                if not isinstance(animation, dict):
                    errors.append(f"manifest is missing animation {name}")
                    continue
                expected_by[(state, direction)] = set(animation.get("frames", []))
    for state in STATES:
        for direction in DIRECTIONS:
            frames = sorted((args.root / state / direction).glob("*.png"))
            frames_by[(state, direction)] = frames
            if len(frames) < 2:
                errors.append(f"{state}/{direction}: expected multiple frames, found {len(frames)}")
                continue
            expected = expected_by.get((state, direction))
            if expected is not None:
                actual = {path.stem for path in frames}
                missing = expected - actual
                extra = actual - expected
                if missing:
                    errors.append(f"{state}/{direction}: {len(missing)} manifest "
                                  f"frames were not rendered on disk")
                if extra:
                    errors.append(f"{state}/{direction}: {len(extra)} stale frames "
                                  f"are not in the manifest (previous hero or "
                                  f"older frame count)")
                if missing or extra:
                    continue
            for path in frames:
                checked += 1
                try:
                    with Image.open(path) as source:
                        image = source.convert("RGBA")
                    found, metrics = frame_errors(path, image, state, args.resolution)
                    if found and first_failing is None:
                        first_failing = (path, image)
                    errors.extend(found)
                except Exception as exc:
                    errors.append(f"{path}: cannot inspect PNG: {exc}")
    if errors:
        for error in errors[:80]:
            print("VISUAL_ERROR: " + error)
        # Always preview the first and last sampled frame of the south and east
        # views for every state, so a flat-on-the-ground death pose is visible
        # in the log instead of being hidden behind earlier idle failures.
        for state in STATES:
            for direction in ("s", "e"):
                frames = frames_by.get((state, direction), [])
                indices = (0, -1) if state == "death" and len(frames) > 1 else (0,)
                for index in indices:
                    if not frames:
                        continue
                    path = frames[index]
                    with Image.open(path) as source:
                        image = source.convert("RGBA")
                    bbox = image.getchannel("A").getbbox()
                    if bbox is None:
                        continue
                    print(f"VISUAL_PREVIEW {path.relative_to(args.root)} bbox={bbox}")
                    for line in ascii_preview(image, bbox):
                        print("  |" + line + "|")
        if first_failing is not None:
            # Embed the first failing frame so the log alone is enough to see
            # exactly what the renderer produced.
            path, _ = first_failing
            print("VISUAL_FRAME " + str(path.relative_to(args.root)))
            print("VISUAL_B64 " + base64.b64encode(path.read_bytes()).decode("ascii"))
        print(f"HERO_VISUAL_CHECK_FAILED hero={hero} checked={checked} "
              f"errors={len(errors)}")
        return 1
    print(f"HERO_VISUAL_CHECK_OK hero={hero} checked={checked} frames across "
          f"{len(STATES)} states and {len(DIRECTIONS)} directions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
