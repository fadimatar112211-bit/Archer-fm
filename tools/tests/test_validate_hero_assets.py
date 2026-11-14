import json
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

from validate_hero_assets import validate


def png_header(width: int, height: int) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)


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


if __name__ == "__main__":
    unittest.main()
