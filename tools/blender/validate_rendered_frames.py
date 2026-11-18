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
import hashlib
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


def connected_component_metrics(alpha, threshold=32):
    """Measure whether a rendered hero remains one coherent silhouette.

    Tiny detached glow fragments are ignored when counting components. A
    component is significant only when it contains at least 12 pixels and at
    least 0.5% of visible pixels. All pixels still count toward the largest-
    component ratio, so a genuinely detached mesh part reduces that ratio.
    Eight-neighbour connectivity preserves diagonal anti-aliased joins.
    """
    width, height = alpha.size
    pixels = alpha.tobytes()
    visited = bytearray(width * height)
    occupied = sum(value > threshold for value in pixels)
    min_component_pixels = max(12, int(occupied * 0.005))
    largest = 0
    significant_components = 0
    for start, value in enumerate(pixels):
        if value <= threshold or visited[start]:
            continue
        stack = [start]
        visited[start] = 1
        size = 0
        while stack:
            current = stack.pop()
            size += 1
            x, y = current % width, current // width
            for ny in range(max(0, y - 1), min(height, y + 2)):
                row = ny * width
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    neighbour = row + nx
                    if (neighbour != current and not visited[neighbour]
                            and pixels[neighbour] > threshold):
                        visited[neighbour] = 1
                        stack.append(neighbour)
        largest = max(largest, size)
        if size >= min_component_pixels:
            significant_components += 1
    return significant_components, largest / max(1, occupied), largest


def frame_errors(path, image, state, resolution, hero, pivot_y):
    """Return every violation for one rendered frame plus its metrics."""
    errors = []
    if image.size != (resolution, resolution):
        return [f"{path}: wrong dimensions {image.size}"], None
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return [f"{path}: fully transparent render"], None
    width, height = bbox[2] - bbox[0], bbox[3] - bbox[1]
    alpha_histogram = alpha.histogram()
    occupied = sum(alpha_histogram[9:])
    transparent_ratio = alpha_histogram[0] / float(resolution * resolution)
    metrics = {
        "bbox": bbox,
        "width": width,
        "height": height,
        "occupied": occupied,
        "transparent_ratio": transparent_ratio,
    }
    if hero == "ranger":
        components, largest_ratio, largest_pixels = connected_component_metrics(alpha)
        metrics.update({
            "components": components,
            "largest_component_ratio": largest_ratio,
            "largest_component_pixels": largest_pixels,
        })
        if largest_ratio < 0.90:
            errors.append(
                f"{path}: fragmented silhouette; largest connected component is "
                f"only {largest_ratio:.1%} of visible pixels")
        if components > 4:
            errors.append(
                f"{path}: too many disconnected visible components ({components})")
        pivot_bottom = pivot_y * resolution
        if abs(bbox[3] - pivot_bottom) > resolution * 0.12:
            errors.append(
                f"{path}: visible ground edge drifted from pivot "
                f"({bbox[3]:.1f}px vs {pivot_bottom:.1f}px)")
    if occupied < 350:
        errors.append(f"{path}: too few visible pixels ({occupied})")
    corners = (
        alpha.getpixel((0, 0)),
        alpha.getpixel((resolution - 1, 0)),
        alpha.getpixel((0, resolution - 1)),
        alpha.getpixel((resolution - 1, resolution - 1)),
    )
    if any(value != 0 for value in corners):
        errors.append(f"{path}: background corners are not fully transparent ({corners})")
    if transparent_ratio < 0.60:
        errors.append(f"{path}: background is insufficiently transparent ({transparent_ratio:.1%})")
    min_width = max(20, round(resolution * 0.12))
    if width < min_width:
        errors.append(f"{path}: silhouette is too narrow ({width}px)")
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


def pixel_change_ratio(first, second, threshold=16):
    """Fraction of pixels whose RGBA value changes meaningfully between frames."""
    left, right = first.tobytes(), second.tobytes()
    changed = 0
    total = len(left) // 4
    for offset in range(0, len(left), 4):
        if max(abs(left[offset + channel] - right[offset + channel])
               for channel in range(4)) > threshold:
            changed += 1
    return changed / max(1, total)


def sequence_errors(paths, state, animation_name, hero):
    """Reject static or nearly static clips even when their PNGs are non-empty."""
    errors = []
    images = []
    signatures = []
    for path in paths:
        with Image.open(path) as source:
            image = source.convert("RGBA")
        images.append(image)
        signatures.append(hashlib.sha1(image.tobytes()).digest())
    unique_count = len(set(signatures))
    minimum_unique = 2 if state == "idle" else 3
    if unique_count < minimum_unique:
        errors.append(
            f"{animation_name}: only {unique_count} unique frames; expected at least {minimum_unique}")
    changes = [
        pixel_change_ratio(first, second)
        for first, second in zip(images, images[1:])
    ]
    motion = max(changes, default=0.0)
    minimum_motion = 0.003 if state == "idle" else 0.01
    if motion < minimum_motion:
        errors.append(
            f"{animation_name}: animation motion is too small ({motion:.2%} changed pixels)")
    if hero == "ranger" and changes:
        changed_transitions = sum(value >= 0.01 for value in changes)
        required_transitions = (
            (len(changes) + 1) // 2 if state == "idle"
            else (len(changes) * 3 + 3) // 4
        )
        mean_motion = sum(changes) / len(changes)
        required_mean = 0.02 if state == "idle" else 0.03
        if changed_transitions < required_transitions:
            errors.append(
                f"{animation_name}: only {changed_transitions}/{len(changes)} "
                f"transitions move; expected at least {required_transitions}")
        if mean_motion < required_mean:
            errors.append(
                f"{animation_name}: average motion is too small "
                f"({mean_motion:.2%}, expected {required_mean:.2%})")
    return errors


def configured_event_frame(hero, state, event_name):
    """Map a configured Blender source frame to the exact rendered frame index."""
    config_path = Path(__file__).resolve().parents[2] / "assets/heroes/ranger/source/render_config.json"
    if not config_path.is_file():
        return None
    raw = json.loads(config_path.read_text(encoding="utf-8"))
    config = dict(raw.get("defaults", {}))
    config.update(raw.get("heroes", {}).get(hero, {}))
    event = next(
        (item for item in config.get("events", {}).get(state, [])
         if item.get("name") == event_name),
        None,
    )
    if event is None:
        return None
    start, end = map(int, config["action_ranges"][state])
    count = int(config["frame_counts"][state])
    if count < 2:
        return None
    sampled = [round(start + (end - start) * index / (count - 1))
               for index in range(count)]
    source_frame = int(event["frame"])
    return min(range(len(sampled)), key=lambda index: abs(sampled[index] - source_frame))


def configured_pivot(hero):
    """Return the normalized pivot authored in render_config.json."""
    config_path = Path(__file__).resolve().parents[2] / "assets/heroes/ranger/source/render_config.json"
    if not config_path.is_file():
        return None
    raw = json.loads(config_path.read_text(encoding="utf-8"))
    config = dict(raw.get("defaults", {}))
    config.update(raw.get("heroes", {}).get(hero, {}))
    pivot = config.get("pivot")
    if not isinstance(pivot, dict):
        return None
    try:
        return float(pivot["x"]), float(pivot["y"])
    except (KeyError, TypeError, ValueError):
        return None


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
    animations_by = {}
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
                animations_by[(state, direction)] = animation
    pivot_y = 0.86
    if manifest is not None:
        pivot = manifest.get("pivot", {})
        if isinstance(pivot, dict) and isinstance(pivot.get("y"), (int, float)):
            pivot_y = float(pivot["y"])
        expected_pivot = configured_pivot(hero)
        if expected_pivot is None:
            errors.append("render_config.json does not define the Ranger pivot")
        else:
            actual_pivot = (float(pivot.get("x", -1)), float(pivot.get("y", -1)))
            if (abs(actual_pivot[0] - expected_pivot[0]) > 0.001
                    or abs(actual_pivot[1] - expected_pivot[1]) > 0.001):
                errors.append(
                    f"manifest pivot {actual_pivot} differs from configured pivot "
                    f"{expected_pivot}")
    if hero == "ranger" and manifest is not None:
        expected_release = configured_event_frame(hero, "attack", "projectile_release")
        if expected_release is None:
            errors.append("render_config.json does not define Ranger projectile_release")
        else:
            for direction in DIRECTIONS:
                animation = animations_by.get(("attack", direction), {})
                releases = [
                    event for event in animation.get("events", [])
                    if event.get("name") == "projectile_release"
                ]
                if len(releases) != 1:
                    errors.append(
                        f"attack_{direction}: expected exactly one projectile_release event")
                elif releases[0].get("frame") != expected_release:
                    errors.append(
                        f"attack_{direction}: projectile_release is at frame "
                        f"{releases[0].get('frame')}, expected configured frame {expected_release}")
                else:
                    release_index = releases[0]["frame"]
                    attack_frames = animation.get("frames", [])
                    idle_frames = animations_by.get(("idle", direction), {}).get("frames", [])
                    if not (0 < release_index < len(attack_frames) - 1):
                        errors.append(
                            f"attack_{direction}: projectile_release must be between "
                            "the wind-up and recovery frames")
                    elif idle_frames:
                        release_path = args.root / "attack" / direction / f"{attack_frames[release_index]}.png"
                        previous_path = args.root / "attack" / direction / f"{attack_frames[release_index - 1]}.png"
                        idle_path = args.root / "idle" / direction / f"{idle_frames[0]}.png"
                        if all(path.is_file() for path in (release_path, previous_path, idle_path)):
                            with Image.open(release_path) as source:
                                release_image = source.convert("RGBA")
                            with Image.open(previous_path) as source:
                                previous_image = source.convert("RGBA")
                            with Image.open(idle_path) as source:
                                idle_image = source.convert("RGBA")
                            release_motion = pixel_change_ratio(previous_image, release_image)
                            release_pose = pixel_change_ratio(idle_image, release_image)
                            if release_motion < 0.03 or release_pose < 0.05:
                                errors.append(
                                    f"attack_{direction}: projectile_release frame is not "
                                    f"a clearly visible release pose "
                                    f"(from previous={release_motion:.2%}, "
                                    f"from idle={release_pose:.2%})")
                        else:
                            errors.append(
                                f"attack_{direction}: missing PNG needed to inspect "
                                "the projectile_release pose")

                death = animations_by.get(("death", direction), {})
                death_events = [
                    event for event in death.get("events", [])
                    if event.get("name") == "death_complete"
                ]
                if len(death_events) != 1:
                    errors.append(
                        f"death_{direction}: expected exactly one death_complete event")
                elif death.get("frames") and death_events[0].get("frame") != len(death["frames"]) - 1:
                    errors.append(
                        f"death_{direction}: death_complete must be on the final frame")
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
                animation = animations_by.get((state, direction))
                if animation is not None:
                    ordered_paths = [
                        args.root / state / direction / f"{frame_id}.png"
                        for frame_id in animation.get("frames", [])
                    ]
                    if all(path.is_file() for path in ordered_paths):
                        errors.extend(sequence_errors(
                            ordered_paths, state, f"{state}_{direction}", hero))
            for path in frames:
                checked += 1
                try:
                    with Image.open(path) as source:
                        image = source.convert("RGBA")
                    found, metrics = frame_errors(path, image, state, args.resolution, hero, pivot_y)
                    if hero == "ranger" and state == "idle" and direction == "s" and metrics:
                        # The reference holds a bright energy bow on screen-left.
                        # Require a measurable green silhouette outside the body.
                        bow_pixels = 0
                        bow_region_end = round(args.resolution * 0.28)
                        for y in range(args.resolution):
                            for x in range(bow_region_end):
                                red, green, blue, alpha = image.getpixel((x, y))
                                if (alpha > 48 and green > 110
                                        and green > red * 1.12 and green > blue * 1.08):
                                    bow_pixels += 1
                        if metrics["bbox"][0] > bow_region_end or bow_pixels < 24:
                            found.append(
                                f"{path}: front idle energy bow is too narrow or hidden "
                                f"(left edge={metrics['bbox'][0]}, green pixels={bow_pixels})")
                    if found and first_failing is None:
                        first_failing = (path, image)
                    errors.extend(found)
                except Exception as exc:
                    errors.append(f"{path}: cannot inspect PNG: {exc}")
    # Death must visibly progress from the standing pose into a collapsed
    # final pose. Merely declaring a death Action or producing nine non-empty
    # frames is not enough: a stale idle clip can otherwise pass the silhouette
    # checks. Compare the first and final alpha bounds against the matching
    # idle direction so this remains camera-independent.
    if manifest is not None:
        for direction in DIRECTIONS:
            idle = animations_by.get(("idle", direction), {})
            death = animations_by.get(("death", direction), {})
            idle_ids = idle.get("frames", [])
            death_ids = death.get("frames", [])
            if not idle_ids or not death_ids:
                continue
            idle_path = args.root / "idle" / direction / f"{idle_ids[0]}.png"
            death_start_path = args.root / "death" / direction / f"{death_ids[0]}.png"
            death_end_path = args.root / "death" / direction / f"{death_ids[-1]}.png"
            if not all(path.is_file() for path in (idle_path, death_start_path, death_end_path)):
                continue
            with Image.open(idle_path) as source:
                idle_box = source.convert("RGBA").getchannel("A").getbbox()
            with Image.open(death_start_path) as source:
                start_box = source.convert("RGBA").getchannel("A").getbbox()
            with Image.open(death_end_path) as source:
                end_box = source.convert("RGBA").getchannel("A").getbbox()
            if not idle_box or not start_box or not end_box:
                continue
            idle_height = idle_box[3] - idle_box[1]
            start_height = start_box[3] - start_box[1]
            end_height = end_box[3] - end_box[1]
            idle_center_y = (idle_box[1] + idle_box[3]) / 2
            end_center_y = (end_box[1] + end_box[3]) / 2
            if start_height < idle_height * 0.90:
                errors.append(
                    f"death_{direction}: animation does not begin from the standing pose")
            if end_height > idle_height * 0.85:
                errors.append(
                    f"death_{direction}: final frame does not show a clear collapse "
                    f"({end_height}px vs standing {idle_height}px)")
            if end_center_y < idle_center_y + 8:
                errors.append(
                    f"death_{direction}: final body centre did not fall visibly "
                    f"({end_center_y:.1f} vs {idle_center_y:.1f})")
            if end_height < 90:
                errors.append(
                    f"death_{direction}: final pose is too small to read ({end_height}px)")

    # The eight view angles must remain distinguishable; this catches a
    # renderer that accidentally reuses one camera pose for every direction.
    for state in STATES:
        signatures = []
        for direction in DIRECTIONS:
            animation = animations_by.get((state, direction))
            if not animation or not animation.get("frames"):
                continue
            first_path = args.root / state / direction / f"{animation['frames'][0]}.png"
            if not first_path.is_file():
                continue
            with Image.open(first_path) as source:
                signatures.append(hashlib.sha1(source.convert("RGBA").tobytes()).digest())
        required_directions = len(DIRECTIONS) if hero == "ranger" else 6
        if len(signatures) == len(DIRECTIONS) and len(set(signatures)) < required_directions:
            errors.append(
                f"{state}: only {len(set(signatures))}/8 distinct direction silhouettes; "
                f"expected at least {required_directions}")

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
