"""Unit tests for pure Python atlas packer (tools/pack_hero_atlases.py)."""
from __future__ import annotations
import json
import tempfile
import unittest
import zlib
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from array import array
from pack_hero_atlases import (
    pack_atlas, make_png, read_png, read_png_bytes, read_png_dimensions,
    extrude_edges, verify_packed, publish_bundle, DEFAULT_PADDING
)


def make_test_png(width: int, height: int, color: tuple = (255, 0, 0, 255)) -> bytes:
    """Create a solid-color PNG for testing."""
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    r, g, b, a = color
    row = bytes([r, g, b, a] * width)
    raw = b"".join(b"\x00" + row for _ in range(height))
    idat = zlib.compress(raw)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def pattern_pixels(width: int, height: int) -> bytearray:
    """An asymmetric RGBA pattern where every row and column differs.

    Mirrored or shifted placement cannot accidentally match this buffer, so
    comparing it against the packed atlas pins the atlas row order.
    """
    buffer = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            i = (y * width + x) * 4
            buffer[i] = (x * 31 + 7) & 0xff
            buffer[i + 1] = (y * 47 + 11) & 0xff
            buffer[i + 2] = (x * y * 13 + 3) & 0xff
            buffer[i + 3] = 255 if (x + y) % 5 else 200
    return buffer


class AtlasPackerTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)

    def tearDown(self):
        self.tempdir.cleanup()

    def create_manifest(self, frame_size=(32, 32), animations=None, pivot=(0.5, 0.86)):
        if animations is None:
            animations = {
                "idle_sw": {
                    "loop": True,
                    "frame_duration_ms": 160,
                    "frames": ["ranger_idle_sw_000", "ranger_idle_sw_001"],
                    "events": []
                },
                "walk_sw": {
                    "loop": True,
                    "frame_duration_ms": 100,
                    "frames": ["ranger_walk_sw_000", "ranger_walk_sw_001"],
                    "events": []
                },
                "attack_sw": {
                    "loop": False,
                    "frame_duration_ms": 75,
                    "frames": ["ranger_attack_sw_000", "ranger_attack_sw_001",
                               "ranger_attack_sw_002", "ranger_attack_sw_003",
                               "ranger_attack_sw_004"],
                    "events": [{"frame": 2, "name": "projectile_release"}]
                },
                "death_sw": {
                    "loop": False,
                    "frame_duration_ms": 120,
                    "frames": ["ranger_death_sw_000", "ranger_death_sw_001"],
                    "events": []
                }
            }
        manifest = {
            "schema_version": 1,
            "hero_id": "ranger",
            "frame_size": {"width": frame_size[0], "height": frame_size[1]},
            "pivot": {"x": pivot[0], "y": pivot[1]},
            "atlases": [],
            "animations": animations
        }
        manifest_path = self.root / "ranger_manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        return manifest_path

    def create_frame_dirs(self, state: str, direction: str, frames: list[str]):
        """Create placeholder PNG frames for testing."""
        for frame_id in frames:
            frame_path = self.root / state / direction / f"{frame_id}.png"
            frame_path.parent.mkdir(parents=True, exist_ok=True)
            frame_path.write_bytes(make_test_png(32, 32))

    def create_pattern_frames(self, state: str, direction: str, frames: list[str],
                              width: int = 32, height: int = 32):
        """Create asymmetric patterned frames so wrong atlas rows cannot match."""
        for frame_id in frames:
            frame_path = self.root / state / direction / f"{frame_id}.png"
            frame_path.parent.mkdir(parents=True, exist_ok=True)
            frame_path.write_bytes(make_png(width, height, pattern_pixels(width, height)))

    def pack_single_animation(self, manifest_animations, state="idle", direction="sw",
                              columns=2, padding=2):
        """Pack one animation of patterned frames and return (manifest, atlas bytes, meta)."""
        frames = manifest_animations[f"{state}_{direction}"]["frames"]
        manifest_path = self.create_manifest(animations=manifest_animations)
        self.create_pattern_frames(state, direction, frames)
        manifest = pack_atlas(manifest_path, columns=columns, padding=padding)
        entry = manifest["atlases"][0]
        meta = json.loads((self.root / entry["meta"]).read_text(encoding="utf-8"))
        atlas_bytes = (self.root / entry["image"]).read_bytes()
        return manifest, entry, atlas_bytes, meta

    def test_publish_bundle_writes_valid_json_when_source_asset_exists(self):
        """The uploaded non-Ranger bundle manifest must remain parseable JSON."""
        render_dir = self.root / "assets" / "heroes" / "flame" / "renders"
        render_dir.mkdir(parents=True)
        source_dir = self.root / "assets" / "heroes" / "flame" / "source"
        source_dir.mkdir(parents=True)
        (source_dir / "flame_source.blend").write_bytes(b"test blend")
        manifest_path = render_dir / "flame_manifest.json"
        manifest_path.write_text(json.dumps({
            "hero_id": "flame",
            "source": {"blend_file": "temporary.blend"}
        }), encoding="utf-8")

        bundle = publish_bundle(manifest_path, {"hero_id": "flame"})
        bundled_manifest = bundle / "flame_manifest.json"
        parsed = json.loads(bundled_manifest.read_text(encoding="utf-8"))

        self.assertEqual(parsed["hero_id"], "flame")
        self.assertEqual(parsed["source"]["source_asset"], "source/flame_source.blend")
        self.assertEqual(parsed["source"]["source_asset_type"], "blend")
        self.assertTrue((bundle.parent / "source" / "flame_source.blend").is_file())

    def test_basic_packing_2x2(self):
        """Test packing 4 frames in 2x2 grid with default padding."""
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000", "ranger_idle_sw_001",
                           "ranger_idle_sw_002", "ranger_idle_sw_003"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw",
                               ["ranger_idle_sw_000", "ranger_idle_sw_001",
                                "ranger_idle_sw_002", "ranger_idle_sw_003"])

        manifest = pack_atlas(manifest_path, columns=2, padding=2)

        # Verify atlas entries created - only 1 animation in custom manifest
        self.assertEqual(len(manifest["atlases"]), 1)

        entry = manifest["atlases"][0]
        atlas_png = self.root / entry["image"]
        self.assertTrue(atlas_png.exists(), f"Missing atlas: {atlas_png}")
        w, h = read_png_dimensions(atlas_png)
        # 4 frames, 2 cols -> 2 rows
        # Each cell is 32 + 2*2 padding = 36, gap between frames is 4
        # width: 2 * (32 + 2*2) = 72
        # height: 2 * (32 + 2*2) = 72
        self.assertEqual(w, 72)
        self.assertEqual(h, 72)

    def test_padding_minimum_2px(self):
        """Test that padding is at least 2px (spec requirement)."""
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw", ["ranger_idle_sw_000"])

        # Test with default padding (2)
        manifest = pack_atlas(manifest_path, padding=2)
        entry = manifest["atlases"][0]
        w, h = read_png_dimensions(self.root / entry["image"])
        # 1 col: 32 + 2*2 = 36
        self.assertEqual(w, 36)
        self.assertEqual(h, 36)

    def test_padding_custom_value(self):
        """Test custom padding values."""
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw", ["ranger_idle_sw_000"])

        for pad in [0, 1, 2, 4, 8]:
            manifest = pack_atlas(manifest_path, padding=pad)
            entry = manifest["atlases"][0]
            w, h = read_png_dimensions(self.root / entry["image"])
            expected = 32 + 2 * pad
            self.assertEqual(w, expected, f"Padding {pad}: width={w}, expected={expected}")
            self.assertEqual(h, expected)

    def test_frame_coordinates_correct(self):
        """Test that frame coordinates in metadata are correct with padding."""
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000", "ranger_idle_sw_001"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw", ["ranger_idle_sw_000", "ranger_idle_sw_001"])

        manifest = pack_atlas(manifest_path, columns=2, padding=2)

        entry = manifest["atlases"][0]
        meta_path = self.root / entry["meta"]
        meta = json.loads(meta_path.read_text(encoding="utf-8"))

        frames = meta["frames"]
        # Frame 0 at (2, 2), Frame 1 at (2 + 32 + 2*2, 2) = (38, 2)
        self.assertEqual(frames["ranger_idle_sw_000"]["frame"], {"x": 2, "y": 2, "w": 32, "h": 32})
        self.assertEqual(frames["ranger_idle_sw_001"]["frame"], {"x": 38, "y": 2, "w": 32, "h": 32})

    def test_no_frame_overlap(self):
        """Test that packed frames don't overlap in the same atlas."""
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000", "ranger_idle_sw_001",
                           "ranger_idle_sw_002", "ranger_idle_sw_003"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw", ["ranger_idle_sw_000", "ranger_idle_sw_001",
                                               "ranger_idle_sw_002", "ranger_idle_sw_003"])

        manifest = pack_atlas(manifest_path, columns=2, padding=2)

        entry = manifest["atlases"][0]
        meta_path = self.root / entry["meta"]
        meta = json.loads(meta_path.read_text(encoding="utf-8"))

        frames = meta["frames"]
        rects = [(fid, v["frame"]["x"], v["frame"]["y"], v["frame"]["w"], v["frame"]["h"])
                 for fid, v in frames.items()]

        # Check no overlap
        for i, (fid_a, ax, ay, aw, ah) in enumerate(rects):
            for j, (fid_b, bx, by, bw, bh) in enumerate(rects):
                if i >= j:
                    continue
                overlap = (ax < bx + bw and bx < ax + aw and
                           ay < by + bh and by < ay + ah)
                self.assertFalse(overlap, f"Frames {fid_a} and {fid_b} overlap")

    def test_padding_gap_between_frames(self):
        """Test that gap between frames equals declared padding."""
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000", "ranger_idle_sw_001",
                           "ranger_idle_sw_002", "ranger_idle_sw_003"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw", ["ranger_idle_sw_000", "ranger_idle_sw_001",
                                               "ranger_idle_sw_002", "ranger_idle_sw_003"])

        manifest = pack_atlas(manifest_path, columns=2, padding=4)

        entry = manifest["atlases"][0]
        meta_path = self.root / entry["meta"]
        meta = json.loads(meta_path.read_text(encoding="utf-8"))

        frames = meta["frames"]
        # Frames own `padding` pixels on each side, so the gap is 2 * padding.
        # Frame 0 right edge at 4+32=36, frame 1 left edge at 36+8=44
        x0 = frames["ranger_idle_sw_000"]["frame"]["x"]
        w0 = frames["ranger_idle_sw_000"]["frame"]["w"]
        x1 = frames["ranger_idle_sw_001"]["frame"]["x"]
        gap_x = x1 - (x0 + w0)
        self.assertEqual(gap_x, 8, f"Horizontal gap {gap_x} != 2 * padding 4")

        # Vertical gap
        y0 = frames["ranger_idle_sw_000"]["frame"]["y"]
        y2 = frames["ranger_idle_sw_002"]["frame"]["y"]
        h0 = frames["ranger_idle_sw_000"]["frame"]["h"]
        gap_y = y2 - (y0 + h0)
        self.assertEqual(gap_y, 8, f"Vertical gap {gap_y} != 2 * padding 4")

    def test_sprite_source_size_matches_frame_when_no_trim(self):
        """Test that spriteSourceSize uses 0,0 origin when no trimming (TexturePacker spec)."""
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw", ["ranger_idle_sw_000"])

        manifest = pack_atlas(manifest_path, padding=2)

        entry = manifest["atlases"][0]
        meta_path = self.root / entry["meta"]
        meta = json.loads(meta_path.read_text(encoding="utf-8"))

        frame_meta = meta["frames"]["ranger_idle_sw_000"]
        sss = frame_meta["spriteSourceSize"]
        frame = frame_meta["frame"]
        # When trimmed=false, spriteSourceSize should be 0,0 (position in original untrimmed image)
        self.assertEqual(sss["x"], 0)
        self.assertEqual(sss["y"], 0)
        self.assertEqual(sss["w"], frame["w"])
        self.assertEqual(sss["h"], frame["h"])
        # Source size should be the frame size
        self.assertEqual(frame_meta["sourceSize"], {"w": 32, "h": 32})
        self.assertFalse(frame_meta["trimmed"])

    def test_meta_contains_padding_and_memory_estimate(self):
        """Test that atlas meta includes padding and memory estimate."""
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000", "ranger_idle_sw_001",
                           "ranger_idle_sw_002", "ranger_idle_sw_003"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw", ["ranger_idle_sw_000", "ranger_idle_sw_001",
                                               "ranger_idle_sw_002", "ranger_idle_sw_003"])

        manifest = pack_atlas(manifest_path, columns=2, padding=2)

        entry = manifest["atlases"][0]
        meta_path = self.root / entry["meta"]
        meta = json.loads(meta_path.read_text(encoding="utf-8"))

        m = meta["meta"]
        self.assertEqual(m["padding"], 2)
        self.assertIn("memory_estimate_mb", m)
        self.assertIsInstance(m["memory_estimate_mb"], (int, float))
        self.assertGreater(m["memory_estimate_mb"], 0)
        self.assertEqual(m["frame_size"], {"w": 32, "h": 32})
        self.assertEqual(m["pivot"], {"x": 0.5, "y": 0.86})

    def test_eight_directions_four_states(self):
        """Test full 8 directions x 4 states = 32 atlases."""
        manifest_path = self.create_manifest()
        directions = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
        states = ["idle", "walk", "attack", "death"]

        for direction in directions:
            for state in states:
                frames = [f"ranger_{state}_{direction}_{i:03d}" for i in range(4)]
                self.create_frame_dirs(state, direction, frames)

        # Update manifest with all 32 animations
        manifest = json.loads(manifest_path.read_text())
        new_animations = {}
        for direction in directions:
            for state in states:
                key = f"{state}_{direction}"
                frames = [f"ranger_{state}_{direction}_{i:03d}" for i in range(4)]
                new_animations[key] = {
                    "loop": state in ("idle", "walk"),
                    "frame_duration_ms": 100,
                    "frames": frames,
                    "events": [{"frame": 2, "name": "projectile_release"}] if state == "attack" else []
                }
        manifest["animations"] = new_animations
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

        result = pack_atlas(manifest_path, columns=4, padding=2)

        self.assertEqual(len(result["atlases"]), 32, "Should create 32 atlases (8 dirs * 4 states)")

        # Verify each atlas exists and has correct metadata
        for entry in result["atlases"]:
            atlas_png = self.root / entry["image"]
            meta_path = self.root / entry["meta"]
            self.assertTrue(atlas_png.exists(), f"Missing atlas: {atlas_png}")
            self.assertTrue(meta_path.exists(), f"Missing meta: {meta_path}")

    def test_attack_has_exactly_one_projectile_release(self):
        """Test that attack animations have exactly one projectile_release event."""
        manifest_path = self.create_manifest(animations={
            "attack_sw": {
                "loop": False,
                "frame_duration_ms": 75,
                "frames": ["ranger_attack_sw_000", "ranger_attack_sw_001",
                           "ranger_attack_sw_002", "ranger_attack_sw_003",
                           "ranger_attack_sw_004"],
                "events": [{"frame": 2, "name": "projectile_release"}]
            }
        })
        self.create_frame_dirs("attack", "sw",
                               ["ranger_attack_sw_000", "ranger_attack_sw_001",
                                "ranger_attack_sw_002", "ranger_attack_sw_003",
                                "ranger_attack_sw_004"])

        manifest = pack_atlas(manifest_path, padding=2)

        attack_anim = manifest["animations"]["attack_sw"]
        release_events = [e for e in attack_anim["events"]
                          if e.get("name") == "projectile_release"]
        self.assertEqual(len(release_events), 1, "Attack must have exactly one projectile_release")

    def test_extrude_edges_function(self):
        """Test the edge extrusion helper function directly."""
        fw, fh = 4, 4
        atlas_w, atlas_h = 10, 10
        padding = 2
        cols, rows = 2, 2

        # Create a simple pattern: each frame has unique color
        pixels = array("f", [0.0]) * (atlas_w * atlas_h * 4)

        # Fill frame at col=0, row=0 with red
        base_x = 0 * fw + (0 + 1) * padding  # 2
        base_y = 0 * fh + (0 + 1) * padding  # 2
        for y in range(fh):
            for x in range(fw):
                i = ((base_y + y) * atlas_w + (base_x + x)) * 4
                pixels[i] = 1.0  # R
                pixels[i + 1] = 0.0  # G
                pixels[i + 2] = 0.0  # B
                pixels[i + 3] = 1.0  # A

        # Extrude edges for this frame
        extrude_edges(pixels, fw, fh, atlas_w, atlas_h, 0, 0, padding)

        # Check left padding (x=0,1) got red
        for y in range(fh):
            for px in range(padding):
                i = ((base_y + y) * atlas_w + (base_x - 1 - px)) * 4
                self.assertAlmostEqual(pixels[i], 1.0, places=5,
                                       msg=f"Left padding not extruded at y={y}, px={px}")

        # Check right padding (x=6,7) got red
        for y in range(fh):
            for px in range(padding):
                i = ((base_y + y) * atlas_w + (base_x + fw + px)) * 4
                self.assertAlmostEqual(pixels[i], 1.0, places=5,
                                       msg=f"Right padding not extruded at y={y}, px={px}")

        # Check top padding
        for x in range(fw):
            for py in range(padding):
                i = ((base_y - 1 - py) * atlas_w + (base_x + x)) * 4
                self.assertAlmostEqual(pixels[i], 1.0, places=5,
                                       msg=f"Top padding not extruded at x={x}, py={py}")

        # Check bottom padding
        for x in range(fw):
            for py in range(padding):
                i = ((base_y + fh + py) * atlas_w + (base_x + x)) * 4
                self.assertAlmostEqual(pixels[i], 1.0, places=5,
                                       msg=f"Bottom padding not extruded at x={x}, py={py}")

    def test_metadata_matches_blender_packer_spec(self):
        """Verify Python packer metadata matches Blender packer TexturePacker spec.

        Both packers should produce identical frame metadata structure for untrimmed frames:
        - frame: position in atlas (includes padding offset)
        - spriteSourceSize: position in original image (0,0) with frame dimensions
        - sourceSize: original image size (fw, fh)
        - trimmed: false
        - rotated: false
        """
        manifest_path = self.create_manifest(animations={
            "idle_sw": {
                "loop": True,
                "frame_duration_ms": 160,
                "frames": ["ranger_idle_sw_000", "ranger_idle_sw_001"],
                "events": []
            }
        })
        self.create_frame_dirs("idle", "sw", ["ranger_idle_sw_000", "ranger_idle_sw_001"])

        manifest = pack_atlas(manifest_path, columns=2, padding=2)

        entry = manifest["atlases"][0]
        meta_path = self.root / entry["meta"]
        meta = json.loads(meta_path.read_text(encoding="utf-8"))

        frames = meta["frames"]
        for frame_id, frame_meta in frames.items():
            # frame should have padding offset
            self.assertIn("frame", frame_meta)
            frame_rect = frame_meta["frame"]
            self.assertEqual(frame_rect["w"], 32)
            self.assertEqual(frame_rect["h"], 32)
            self.assertGreaterEqual(frame_rect["x"], 2)  # padding offset
            self.assertGreaterEqual(frame_rect["y"], 2)

            # spriteSourceSize should be at 0,0 with frame dimensions (untrimmed)
            sss = frame_meta["spriteSourceSize"]
            self.assertEqual(sss["x"], 0, f"{frame_id}: spriteSourceSize.x should be 0")
            self.assertEqual(sss["y"], 0, f"{frame_id}: spriteSourceSize.y should be 0")
            self.assertEqual(sss["w"], 32, f"{frame_id}: spriteSourceSize.w should match frame width")
            self.assertEqual(sss["h"], 32, f"{frame_id}: spriteSourceSize.h should match frame height")

            # sourceSize should match frame dimensions
            source_size = frame_meta["sourceSize"]
            self.assertEqual(source_size["w"], 32)
            self.assertEqual(source_size["h"], 32)

            # Should not be trimmed or rotated
            self.assertFalse(frame_meta["trimmed"], f"{frame_id}: trimmed should be false")
            self.assertFalse(frame_meta["rotated"], f"{frame_id}: rotated should be false")

        # Meta should contain padding, frame_size, pivot, memory estimate
        m = meta["meta"]
        self.assertEqual(m["padding"], 2)
        self.assertEqual(m["frame_size"], {"w": 32, "h": 32})
        self.assertEqual(m["pivot"], {"x": 0.5, "y": 0.86})
        self.assertIn("memory_estimate_mb", m)
        self.assertIsInstance(m["memory_estimate_mb"], (int, float))
        self.assertGreater(m["memory_estimate_mb"], 0)


    def _four_frame_animations(self, state="idle", direction="sw"):
        frames = [f"ranger_{state}_{direction}_{i:03d}" for i in range(4)]
        return {
            f"{state}_{direction}": {
                "loop": True,
                "frame_duration_ms": 100,
                "frames": frames,
                "events": [],
            }
        }

    def test_make_png_round_trips_every_byte_exactly(self):
        """A decoded render must re-encode to the same bytes, not an off-by-one."""
        pixels = pattern_pixels(17, 5)
        png_path = self.root / "roundtrip.png"
        png_path.write_bytes(make_png(17, 5, pixels))

        width, height, decoded = read_png_bytes(png_path)
        self.assertEqual((width, height), (17, 5))
        self.assertEqual(bytes(decoded), bytes(pixels))

        # The float API used by older callers must quantise back to the same bytes.
        floats = array("f", [value / 255.0 for value in pixels])
        float_path = self.root / "roundtrip_float.png"
        float_path.write_bytes(make_png(17, 5, floats))
        self.assertEqual(bytes(read_png_bytes(float_path)[2]), bytes(pixels))
        _, _, floats_back = read_png(float_path)
        self.assertLessEqual(
            max(abs(floats_back[i] * 255.0 - pixels[i]) for i in range(len(pixels))), 0.01
        )

    def test_tiles_are_written_top_down_at_their_metadata_rows(self):
        """Regression: every tile used to land at atlas_h - y - h (mirrored rows).

        Blender image buffers are stored bottom-up while atlas metadata uses
        top-left PNG coordinates, so a packer that copies bpy image pixels makes
        every rectangle point at a different frame. The atlas must be a plain
        top-down copy so row 0 of a frame is at the metadata y.
        """
        animations = self._four_frame_animations()
        manifest, entry, atlas_bytes, meta = self.pack_single_animation(
            animations, columns=2, padding=2
        )
        atlas_w, atlas_h, atlas = read_png_bytes(self.root / entry["image"])
        self.assertEqual((atlas_w, atlas_h), (72, 72))

        for frame_id in animations["idle_sw"]["frames"]:
            rect = meta["frames"][frame_id]["frame"]
            x, y, w, h = rect["x"], rect["y"], rect["w"], rect["h"]
            _, _, source = read_png_bytes(self.root / "idle" / "sw" / f"{frame_id}.png")
            for row in range(h):
                atlas_row = bytes(atlas[((y + row) * atlas_w + x) * 4:
                                       ((y + row) * atlas_w + x + w) * 4])
                source_row = bytes(source[row * w * 4:(row + 1) * w * 4])
                self.assertEqual(
                    atlas_row, source_row,
                    f"{frame_id} row {row} is not stored at metadata y={y}",
                )

    def test_padding_strips_repeat_the_tile_edges(self):
        """Padding must extrude the adjacent frame edge, not transparency."""
        animations = self._four_frame_animations()
        manifest, entry, _, meta = self.pack_single_animation(animations, columns=2, padding=2)
        atlas_w, atlas_h, atlas = read_png_bytes(self.root / entry["image"])
        padding = meta["meta"]["padding"]
        self.assertGreater(padding, 0)

        def pixel(x, y):
            start = (y * atlas_w + x) * 4
            return bytes(atlas[start:start + 4])

        for frame_id in animations["idle_sw"]["frames"]:
            rect = meta["frames"][frame_id]["frame"]
            x, y, w, h = rect["x"], rect["y"], rect["w"], rect["h"]
            for row in range(h):
                for offset in range(1, padding + 1):
                    self.assertEqual(pixel(x - offset, y + row), pixel(x, y + row),
                                     f"{frame_id}: left padding at row {row}")
                    self.assertEqual(pixel(x + w - 1 + offset, y + row),
                                     pixel(x + w - 1, y + row),
                                     f"{frame_id}: right padding at row {row}")
            for column in range(w):
                for offset in range(1, padding + 1):
                    self.assertEqual(pixel(x + column, y - offset), pixel(x + column, y),
                                     f"{frame_id}: top padding at column {column}")
                    self.assertEqual(pixel(x + column, y + h - 1 + offset),
                                     pixel(x + column, y + h - 1),
                                     f"{frame_id}: bottom padding at column {column}")

    def test_verify_packed_accepts_the_packer_output(self):
        animations = self._four_frame_animations()
        manifest, _, _, _ = self.pack_single_animation(animations)
        verify_packed(manifest, self.root)

    def test_verify_packed_rejects_a_vertically_flipped_atlas(self):
        animations = self._four_frame_animations()
        manifest, entry, atlas_bytes, _ = self.pack_single_animation(animations)
        atlas_path = self.root / entry["image"]
        atlas_w, atlas_h, atlas = read_png_bytes(atlas_path)
        flipped = bytearray(atlas_w * atlas_h * 4)
        for row in range(atlas_h):
            flipped[row * atlas_w * 4:(row + 1) * atlas_w * 4] = atlas[
                (atlas_h - 1 - row) * atlas_w * 4:(atlas_h - row) * atlas_w * 4
            ]
        atlas_path.write_bytes(make_png(atlas_w, atlas_h, flipped))
        with self.assertRaises(RuntimeError):
            verify_packed(manifest, self.root)
        atlas_path.write_bytes(atlas_bytes)
        verify_packed(manifest, self.root)

    def test_verify_packed_rejects_metadata_one_row_off(self):
        animations = self._four_frame_animations()
        manifest, entry, _, meta = self.pack_single_animation(animations)
        meta_path = self.root / entry["meta"]
        frame_id = animations["idle_sw"]["frames"][0]
        meta["frames"][frame_id]["frame"]["y"] += 1
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        with self.assertRaises(RuntimeError):
            verify_packed(manifest, self.root)
        meta["frames"][frame_id]["frame"]["y"] -= 1
        meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        verify_packed(manifest, self.root)

    def test_verify_packed_rejects_unpacked_padding(self):
        animations = self._four_frame_animations()
        manifest, entry, atlas_bytes, meta = self.pack_single_animation(animations)
        atlas_path = self.root / entry["image"]
        atlas_w, atlas_h, atlas = read_png_bytes(atlas_path)
        padding = meta["meta"]["padding"]
        frame_id = animations["idle_sw"]["frames"][0]
        rect = meta["frames"][frame_id]["frame"]
        start = ((rect["y"] + rect["h"] // 2) * atlas_w + rect["x"] - padding) * 4
        atlas[start:start + padding * 4] = bytes(padding * 4)  # transparent strip
        atlas_path.write_bytes(make_png(atlas_w, atlas_h, atlas))
        with self.assertRaises(RuntimeError):
            verify_packed(manifest, self.root)
        atlas_path.write_bytes(atlas_bytes)
        verify_packed(manifest, self.root)


if __name__ == "__main__":
    unittest.main()
