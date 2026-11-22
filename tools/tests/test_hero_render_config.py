"""Regression checks for the four-hero Blender sprite render configuration."""
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "assets/heroes/ranger/source/render_config.json"
HEROES = ("ranger", "flame", "shadow", "storm")
STATES = ("idle", "walk", "run", "attack", "skill", "dodge", "hit", "death")


class HeroRenderConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        cls.defaults = cls.config["defaults"]
        cls.heroes = cls.config["heroes"]

    def test_all_four_heroes_have_independent_complete_rigs(self):
        self.assertEqual(set(self.heroes), set(HEROES))
        for hero_id in HEROES:
            with self.subTest(hero=hero_id):
                hero = self.heroes[hero_id]
                actions = hero["actions"]
                self.assertEqual(hero["hero_id"], hero_id)
                self.assertEqual(hero["output_directory"],
                                 f"assets/heroes/{hero_id}/renders")
                self.assertEqual(set(actions), set(STATES))
                self.assertEqual(len(set(actions.values())), len(STATES),
                                 "animation states must not share Actions")
                for state, action_name in actions.items():
                    self.assertTrue(action_name.startswith(hero_id.capitalize() + "_"),
                                    f"{state} points to another hero's action: {action_name}")

    def test_all_heroes_have_frame_counts_and_action_ranges(self):
        for hero_id in HEROES:
            with self.subTest(hero=hero_id):
                hero = self.heroes[hero_id]
                for state in STATES:
                    self.assertGreaterEqual(self.defaults["frame_counts"][state], 2)
                    start, end = self.defaults["action_ranges"][state]
                    self.assertGreaterEqual(start, 1)
                    self.assertGreaterEqual(end, start)
                    self.assertLessEqual(
                        self.defaults["frame_counts"][state], end - start + 1)

    def test_gameplay_events_fit_their_source_action_ranges(self):
        for hero_id in HEROES:
            with self.subTest(hero=hero_id):
                for state, events in self.heroes[hero_id].get("events", {}).items():
                    self.assertIn(state, STATES)
                    start, end = self.defaults["action_ranges"][state]
                    for event in events:
                        self.assertGreaterEqual(event["frame"], start)
                        self.assertLessEqual(event["frame"], end)
                        self.assertTrue(event["name"].strip())

    def test_each_hero_has_its_own_output_directory(self):
        outputs = [self.heroes[hero]["output_directory"] for hero in HEROES]
        self.assertEqual(len(outputs), len(set(outputs)))


if __name__ == "__main__":
    unittest.main()
