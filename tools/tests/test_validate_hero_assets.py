"""Unit tests for strict hero atlas/manifest validation."""
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_hero_assets import validate


def write_fixture(root: Path, animation_name="idle_sw", frame_ids=None,
                  events=None, entry_overrides=None):
    """Write a real transparent atlas and matching source PNGs for a manifest."""
    frame_ids = list(frame_ids or [f"ranger_{animation_name}_000"])
    state, direction = animation_name.rsplit("_", 1)
    frame_w = frame_h = 32
    padding = 2
    columns = 2
    rows = max(1, math.ceil(len(frame_ids) / columns))
    atlas_w = columns * frame_w + (columns + 1) * padding
    atlas_h = rows * frame_h + (rows + 1) * padding
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    frames = {}

    for index, frame_id in enumerate(frame_ids):
        column, row = index % columns, index // columns
        x = padding + column * (frame_w + padding)
        y = padding + row * (frame_h + padding)
        source = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(source)
        draw.rectangle((6, 4, 25, 28), fill=(30 + index, 190, 60, 255))
        atlas.alpha_composite(source, (x, y))

        entry = {
            "frame": {"x": x, "y": y, "w": frame_w, "h": frame_h},
            "rotated": False,
            "trimmed": False,
            "sourceSize": {"w": frame_w, "h": frame_h},
        }
        if entry_overrides and frame_id in entry_overrides:
            entry.update(entry_overrides[frame_id])
        frames[frame_id] = entry

        source_path = root / state / direction / f"{frame_id}.png"
        source_path.parent.mkdir(parents=True, exist_ok=True)
        source.save(source_path)

    atlas.save(root / "atlas.png")
    (root / "atlas.json").write_text(json.dumps({
        "frames": frames,
        "meta": {
            "size": {"w": atlas_w, "h": atlas_h},
            "padding": padding,
            "frame_size": {"w": frame_w, "h": frame_h},
        },
    }), encoding="utf-8")

    manifest = {
        "schema_version": 1,
        "hero_id": "ranger",
        "frame_size": {"width": frame_w, "height": frame_h},
        "pivot": {"x": 0.5, "y": 0.86},
        "atlases": [{
            "animation": animation_name,
            "image": "atlas.png",
            "meta": "atlas.json",
        }],
        "animations": {
            animation_name: {
                "loop": not animation_name.startswith("attack_"),
                "frame_duration_ms": 75,
                "frames": frame_ids,
                "events": list(events or []),
            }
        },
    }
    manifest_path = root / "manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    return manifest_path


class HeroAssetValidatorTests(unittest.TestCase):
    def test_valid_minimal_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = write_fixture(root)
            self.assertEqual(validate(manifest), [])

    def test_rejects_missing_frame_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = write_fixture(
                root, frame_ids=["not_in_atlas"], entry_overrides={}
            )
            atlas_meta = json.loads((root / "atlas.json").read_text())
            atlas_meta["frames"] = {}
            (root / "atlas.json").write_text(json.dumps(atlas_meta))
            errors = validate(manifest)
            self.assertTrue(any("missing atlas frame" in error for error in errors),
                            f"Expected missing-frame error, got: {errors}")

    def test_rejects_missing_projectile_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            frames = [f"ranger_attack_sw_{index:03d}" for index in range(5)]
            manifest = write_fixture(root, "attack_sw", frames, events=[])
            errors = validate(manifest)
            self.assertTrue(any("exactly one projectile_release" in error for error in errors),
                            f"Expected missing projectile_release error, got: {errors}")

    def test_rejects_duplicate_projectile_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            frames = [f"ranger_attack_sw_{index:03d}" for index in range(2)]
            manifest = write_fixture(root, "attack_sw", frames, events=[
                {"frame": 0, "name": "projectile_release"},
                {"frame": 1, "name": "projectile_release"},
            ])
            errors = validate(manifest)
            self.assertTrue(any("exactly one projectile_release" in error for error in errors),
                            f"Expected duplicate projectile_release error, got: {errors}")

    def test_accepts_valid_attack_with_projectile_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            frames = [f"ranger_attack_sw_{index:03d}" for index in range(3)]
            manifest = write_fixture(root, "attack_sw", frames, events=[
                {"frame": 1, "name": "projectile_release"},
            ])
            self.assertEqual(validate(manifest), [])

    def test_rejects_trimmed_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            frame_id = "ranger_idle_sw_000"
            manifest = write_fixture(
                root, frame_ids=[frame_id],
                entry_overrides={frame_id: {"trimmed": True}},
            )
            errors = validate(manifest)
            self.assertTrue(any("trimmed frame" in error for error in errors),
                            f"Expected trimmed-frame error, got: {errors}")

    def test_rejects_rotated_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            frame_id = "ranger_idle_sw_000"
            manifest = write_fixture(
                root, frame_ids=[frame_id],
                entry_overrides={frame_id: {"rotated": True}},
            )
            errors = validate(manifest)
            self.assertTrue(any("rotated frame" in error for error in errors),
                            f"Expected rotated-frame error, got: {errors}")


if __name__ == "__main__":
    unittest.main()
