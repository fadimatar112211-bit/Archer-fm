import json
import struct
import tempfile
import unittest
import zlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_hero_assets import validate


def png_header(width: int, height: int) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)


def make_png(width: int, height: int, color: tuple = (255, 0, 0, 255)) -> bytes:
    """Create a solid-color PNG for testing."""
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    r, g, b, a = color
    row = bytes([r, g, b, a] * width)
    raw = b"".join(b"\x00" + row for _ in range(height))
    idat = zlib.compress(raw)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


class HeroAssetValidatorTests(unittest.TestCase):
    def test_valid_minimal_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "atlas.png").write_bytes(png_header(64, 64))
            (root / "atlas.json").write_text(json.dumps({
                "frames": {
                    "ranger_idle_sw_000": {
                        "frame": {"x": 0, "y": 0, "w": 32, "h": 32},
                        "rotated": False,
                        "sourceSize": {"w": 32, "h": 32}
                    }
                },
                "meta": {"size": {"w": 64, "h": 64}}
            }), encoding="utf-8")
            (root / "manifest.json").write_text(json.dumps({
                "schema_version": 1,
                "hero_id": "ranger",
                "frame_size": {"width": 32, "height": 32},
                "pivot": {"x": 0.5, "y": 0.86},
                "atlases": [{"image": "atlas.png", "meta": "atlas.json"}],
                "animations": {
                    "idle_sw": {
                        "loop": True,
                        "frame_duration_ms": 160,
                        "frames": ["ranger_idle_sw_000"]
                    }
                }
            }), encoding="utf-8")
            self.assertEqual(validate(root / "manifest.json"), [])
            self.assertTrue(validate(root / "manifest.json", require_motion=True))

    def test_rejects_reused_action_frame_sequence(self):
        """A walk atlas must not be reused as the idle animation."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "atlas.png").write_bytes(png_header(64, 64))
            (root / "atlas.json").write_text(json.dumps({
                "frames": {
                    "shadow_walk_sw_000": {
                        "frame": {"x": 0, "y": 0, "w": 32, "h": 32},
                        "rotated": False,
                        "sourceSize": {"w": 32, "h": 32}
                    }
                },
                "meta": {"size": {"w": 64, "h": 64}}
            }), encoding="utf-8")
            (root / "manifest.json").write_text(json.dumps({
                "schema_version": 1,
                "hero_id": "shadow",
                "frame_size": {"width": 32, "height": 32},
                "pivot": {"x": 0.5, "y": 0.86},
                "atlases": [{"image": "atlas.png", "meta": "atlas.json"}],
                "animations": {
                    "idle_sw": {
                        "loop": True,
                        "frame_duration_ms": 140,
                        "frames": ["shadow_walk_sw_000"]
                    },
                    "walk_sw": {
                        "loop": True,
                        "frame_duration_ms": 100,
                        "frames": ["shadow_walk_sw_000"]
                    }
                }
            }), encoding="utf-8")

            errors = validate(root / "manifest.json")
            self.assertTrue(
                any("reuses the exact frame sequence" in error for error in errors),
                f"Expected reused-action sequence error, got: {errors}"
            )

    def test_rejects_missing_frame_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "atlas.png").write_bytes(png_header(64, 64))
            (root / "atlas.json").write_text(json.dumps({
                "frames": {}, "meta": {"size": {"w": 64, "h": 64}}
            }), encoding="utf-8")
            (root / "manifest.json").write_text(json.dumps({
                "schema_version": 1, "hero_id": "ranger",
                "frame_size": {"width": 32, "height": 32},
                "pivot": {"x": 0.5, "y": 0.86},
                "atlases": [{"image": "atlas.png", "meta": "atlas.json"}],
                "animations": {"idle_sw": {
                    "loop": True, "frame_duration_ms": 100,
                    "frames": ["not_in_atlas"]
                }}
            }), encoding="utf-8")
            errors = validate(root / "manifest.json")
            self.assertTrue(any("missing atlas frame" in error for error in errors))

    def test_rejects_missing_projectile_release(self):
        """Attack animation must have exactly one projectile_release event."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # 5 frames in 2 cols x 3 rows with 2px padding: width=2*32+3*2=70, height=3*32+4*2=104
            (root / "atlas.png").write_bytes(make_png(70, 104))
            (root / "atlas.json").write_text(json.dumps({
                "frames": {
                    "ranger_attack_sw_000": {"frame": {"x": 2, "y": 2, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                    "ranger_attack_sw_001": {"frame": {"x": 36, "y": 2, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                    "ranger_attack_sw_002": {"frame": {"x": 2, "y": 36, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                    "ranger_attack_sw_003": {"frame": {"x": 36, "y": 36, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                    "ranger_attack_sw_004": {"frame": {"x": 2, "y": 70, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                },
                "meta": {"size": {"w": 70, "h": 104}, "padding": 2, "frame_size": {"w": 32, "h": 32}}
            }), encoding="utf-8")
            (root / "manifest.json").write_text(json.dumps({
                "schema_version": 1, "hero_id": "ranger",
                "frame_size": {"width": 32, "height": 32},
                "pivot": {"x": 0.5, "y": 0.86},
                "atlases": [{"image": "atlas.png", "meta": "atlas.json"}],
                "animations": {"attack_sw": {
                    "loop": False, "frame_duration_ms": 75,
                    "frames": ["ranger_attack_sw_000", "ranger_attack_sw_001",
                               "ranger_attack_sw_002", "ranger_attack_sw_003",
                               "ranger_attack_sw_004"],
                    "events": []  # Missing projectile_release
                }}
            }), encoding="utf-8")
            errors = validate(root / "manifest.json")
            self.assertTrue(any("exactly one projectile_release" in error for error in errors),
                          f"Expected error about missing projectile_release, got: {errors}")

    def test_rejects_duplicate_projectile_release(self):
        """Attack animation must not have multiple projectile_release events."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # 2 frames in 2 cols x 1 row with 2px padding: width=2*32+3*2=70, height=1*32+2*2=36
            (root / "atlas.png").write_bytes(make_png(70, 36))
            (root / "atlas.json").write_text(json.dumps({
                "frames": {
                    "ranger_attack_sw_000": {"frame": {"x": 2, "y": 2, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                    "ranger_attack_sw_001": {"frame": {"x": 36, "y": 2, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                },
                "meta": {"size": {"w": 70, "h": 36}, "padding": 2, "frame_size": {"w": 32, "h": 32}}
            }), encoding="utf-8")
            (root / "manifest.json").write_text(json.dumps({
                "schema_version": 1, "hero_id": "ranger",
                "frame_size": {"width": 32, "height": 32},
                "pivot": {"x": 0.5, "y": 0.86},
                "atlases": [{"image": "atlas.png", "meta": "atlas.json"}],
                "animations": {"attack_sw": {
                    "loop": False, "frame_duration_ms": 75,
                    "frames": ["ranger_attack_sw_000", "ranger_attack_sw_001"],
                    "events": [
                        {"frame": 0, "name": "projectile_release"},
                        {"frame": 1, "name": "projectile_release"}  # Duplicate!
                    ]
                }}
            }), encoding="utf-8")
            errors = validate(root / "manifest.json")
            self.assertTrue(any("exactly one projectile_release" in error for error in errors),
                          f"Expected error about duplicate projectile_release, got: {errors}")

    def test_accepts_valid_attack_with_projectile_release(self):
        """Attack animation with exactly one projectile_release should pass."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # 3 frames in 2 cols x 2 rows with 2px padding: width=2*32+3*2=70, height=2*32+3*2=70
            (root / "atlas.png").write_bytes(make_png(70, 70))
            (root / "atlas.json").write_text(json.dumps({
                "frames": {
                    "ranger_attack_sw_000": {"frame": {"x": 2, "y": 2, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                    "ranger_attack_sw_001": {"frame": {"x": 36, "y": 2, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                    "ranger_attack_sw_002": {"frame": {"x": 2, "y": 36, "w": 32, "h": 32}, "rotated": False, "sourceSize": {"w": 32, "h": 32}},
                },
                "meta": {"size": {"w": 70, "h": 70}, "padding": 2, "frame_size": {"w": 32, "h": 32}}
            }), encoding="utf-8")
            (root / "manifest.json").write_text(json.dumps({
                "schema_version": 1, "hero_id": "ranger",
                "frame_size": {"width": 32, "height": 32},
                "pivot": {"x": 0.5, "y": 0.86},
                "atlases": [{"image": "atlas.png", "meta": "atlas.json"}],
                "animations": {"attack_sw": {
                    "loop": False, "frame_duration_ms": 75,
                    "frames": ["ranger_attack_sw_000", "ranger_attack_sw_001", "ranger_attack_sw_002"],
                    "events": [{"frame": 1, "name": "projectile_release"}]
                }}
            }), encoding="utf-8")
            errors = validate(root / "manifest.json")
            self.assertEqual(errors, [], f"Expected no errors, got: {errors}")

    def test_rejects_trimmed_frames(self):
        """Frames with trimmed=true should be rejected."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "atlas.png").write_bytes(make_png(64, 64))
            (root / "atlas.json").write_text(json.dumps({
                "frames": {
                    "ranger_idle_sw_000": {"frame": {"x": 0, "y": 0, "w": 32, "h": 32}, "rotated": False, "trimmed": True, "sourceSize": {"w": 32, "h": 32}},
                },
                "meta": {"size": {"w": 64, "h": 64}}
            }), encoding="utf-8")
            (root / "manifest.json").write_text(json.dumps({
                "schema_version": 1, "hero_id": "ranger",
                "frame_size": {"width": 32, "height": 32},
                "pivot": {"x": 0.5, "y": 0.86},
                "atlases": [{"image": "atlas.png", "meta": "atlas.json"}],
                "animations": {"idle_sw": {
                    "loop": True, "frame_duration_ms": 160,
                    "frames": ["ranger_idle_sw_000"]
                }}
            }), encoding="utf-8")
            errors = validate(root / "manifest.json")
            self.assertTrue(any("trimmed frame" in error for error in errors))

    def test_rejects_rotated_frames(self):
        """Frames with rotated=true should be rejected."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "atlas.png").write_bytes(make_png(64, 64))
            (root / "atlas.json").write_text(json.dumps({
                "frames": {
                    "ranger_idle_sw_000": {"frame": {"x": 0, "y": 0, "w": 32, "h": 32}, "rotated": True, "sourceSize": {"w": 32, "h": 32}},
                },
                "meta": {"size": {"w": 64, "h": 64}}
            }), encoding="utf-8")
            (root / "manifest.json").write_text(json.dumps({
                "schema_version": 1, "hero_id": "ranger",
                "frame_size": {"width": 32, "height": 32},
                "pivot": {"x": 0.5, "y": 0.86},
                "atlases": [{"image": "atlas.png", "meta": "atlas.json"}],
                "animations": {"idle_sw": {
                    "loop": True, "frame_duration_ms": 160,
                    "frames": ["ranger_idle_sw_000"]
                }}
            }), encoding="utf-8")
            errors = validate(root / "manifest.json")
            self.assertTrue(any("rotated frame" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
