"""Objective visual-gate tests for Ranger sprite validation."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "blender"))
from validate_rendered_frames import (
    connected_component_metrics,
    configured_event_frame,
    sequence_errors,
)


class RenderedFrameValidatorTests(unittest.TestCase):
    def test_connected_character_is_one_component(self):
        alpha = Image.new("L", (32, 32), 0)
        ImageDraw.Draw(alpha).rectangle((6, 4, 25, 29), fill=255)
        components, ratio, largest = connected_component_metrics(alpha)
        self.assertEqual(components, 1)
        self.assertEqual(ratio, 1.0)
        self.assertGreater(largest, 400)

    def test_detached_part_is_detected(self):
        alpha = Image.new("L", (32, 32), 0)
        draw = ImageDraw.Draw(alpha)
        draw.rectangle((2, 4, 18, 28), fill=255)
        draw.rectangle((23, 4, 30, 12), fill=255)
        components, ratio, _ = connected_component_metrics(alpha)
        self.assertEqual(components, 2)
        self.assertLess(ratio, 0.90)

    def test_tiny_detached_glow_fragments_are_ignored(self):
        alpha = Image.new("L", (32, 32), 0)
        draw = ImageDraw.Draw(alpha)
        draw.rectangle((6, 4, 25, 29), fill=255)
        for point in ((1, 1), (30, 1), (1, 30), (30, 30)):
            draw.point(point, fill=255)
        components, ratio, largest = connected_component_metrics(alpha)
        self.assertEqual(components, 1)
        self.assertGreater(ratio, 0.99)
        self.assertGreater(largest, 400)

    def test_static_clip_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            paths = []
            image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            ImageDraw.Draw(image).rectangle((20, 10, 42, 58), fill=(20, 200, 30, 255))
            for index in range(5):
                path = Path(tmp) / f"frame_{index}.png"
                image.save(path)
                paths.append(path)
            errors = sequence_errors(paths, "walk", "walk_s", "ranger")
            self.assertTrue(any("unique frames" in error for error in errors))

    def test_moving_clip_passes_transition_gate(self):
        with tempfile.TemporaryDirectory() as tmp:
            paths = []
            for index in range(5):
                image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
                ImageDraw.Draw(image).rectangle(
                    (8 + index * 8, 12, 23 + index * 8, 52),
                    fill=(20, 200, 30, 255),
                )
                path = Path(tmp) / f"frame_{index}.png"
                image.save(path)
                paths.append(path)
            self.assertEqual(sequence_errors(paths, "walk", "walk_s", "ranger"), [])

    def test_projectile_release_maps_to_rendered_frame_three(self):
        self.assertEqual(
            configured_event_frame("ranger", "attack", "projectile_release"),
            3,
        )


if __name__ == "__main__":
    unittest.main()
