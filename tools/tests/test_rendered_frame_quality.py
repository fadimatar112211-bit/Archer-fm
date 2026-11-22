import importlib.util
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "blender"
    / "validate_rendered_frames.py"
)
SPEC = importlib.util.spec_from_file_location("validate_rendered_frames", MODULE_PATH)
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class RenderedFrameQualityTests(unittest.TestCase):
    def make_silhouette(self, height, width=52):
        image = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        top = 24
        draw.rectangle((70, top, 70 + width - 1, top + height - 1),
                       fill=(40, 150, 70, 255))
        return image

    def test_small_upright_hero_is_rejected_at_phone_scale(self):
        errors, metrics = VALIDATOR.frame_errors(
            Path("small_idle.png"), self.make_silhouette(76), "idle", 192
        )
        self.assertTrue(any("hero silhouette too small" in error for error in errors))
        self.assertAlmostEqual(metrics["height_ratio"], 76 / 192)

    def test_readable_upright_hero_passes_size_gate(self):
        errors, metrics = VALIDATOR.frame_errors(
            Path("readable_idle.png"), self.make_silhouette(77), "idle", 192
        )
        self.assertFalse(any("hero silhouette too small" in error for error in errors))
        self.assertGreater(metrics["occupancy_ratio"], 0)

    def test_horizontal_death_pose_is_exempt_from_upright_height_gate(self):
        errors, metrics = VALIDATOR.frame_errors(
            Path("death.png"), self.make_silhouette(20, width=90), "death", 192
        )
        self.assertFalse(any("hero silhouette too small" in error for error in errors))
        self.assertIsNotNone(metrics)


if __name__ == "__main__":
    unittest.main()
