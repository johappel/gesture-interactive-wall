"""Drift guard for the committed example configuration.

`config/config.example.json` is a portable reference with generic defaults; it
is never read at runtime. These checks keep it a usable starting point: it must
cover every key the live config uses, must stay free of machine-local state, and
must stay referenced by the configuration documentation.
"""

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# Machine-local output signatures written by the screen selectors: they belong
# to one venue's display setup and must never ship in the example. The keys are
# nested paths ("section.subsection"), because the signature lives one level
# below the top-level section.
LOCAL_ONLY_NESTED_KEYS = {"station.facade": {"display"}, "station.monitor": {"display"}}


def _read(name: str) -> dict:
    return json.loads((ROOT / "config" / name).read_text(encoding="utf-8-sig"))


class ConfigExampleTest(unittest.TestCase):
    def setUp(self):
        self.example = _read("config.example.json")
        self.live = _read("config.json")
        self.prompts = _read("prompts.json")["prompts"]

    def test_example_has_the_same_sections_as_the_live_config(self):
        self.assertEqual(
            set(self.example) - {"_hinweis"},
            set(self.live),
            "config.example.json muss dieselben Abschnitte wie config/config.json haben",
        )

    def test_example_covers_every_key_of_the_live_config(self):
        for section in sorted(set(self.live)):
            live_block = self.live[section]
            example_block = self.example[section]
            if not isinstance(live_block, dict):
                self.assertEqual(type(live_block), type(example_block), section)
                continue
            local_only = LOCAL_ONLY_NESTED_KEYS.get(section, set())
            missing = set(live_block) - set(example_block) - local_only
            self.assertFalse(
                missing, f"config.example.json fehlen unter {section}: {sorted(missing)}"
            )
            for key, value in live_block.items():
                if not isinstance(value, dict):
                    continue
                nested = f"{section}.{key}"
                local_only = LOCAL_ONLY_NESTED_KEYS.get(nested, set())
                missing_nested = set(value) - set(example_block[key]) - local_only
                self.assertFalse(
                    missing_nested, f"config.example.json fehlen unter {nested}: {sorted(missing_nested)}"
                )

    def test_example_types_match_the_live_config(self):
        for section in sorted(set(self.live)):
            live_block = self.live[section]
            example_block = self.example[section]
            if not isinstance(live_block, dict):
                continue
            for key, value in live_block.items():
                if isinstance(value, dict) or key not in example_block:
                    continue
                self.assertEqual(
                    type(value),
                    type(example_block[key]),
                    f"Typ von {section}.{key} weicht ab",
                )

    def test_example_keeps_no_machine_local_state(self):
        for nested, keys in LOCAL_ONLY_NESTED_KEYS.items():
            outer, inner = nested.split(".")
            for key in keys:
                self.assertNotIn(key, self.example[outer][inner], f"{nested}.{key} ist standortgebunden")
        for key in ("name", "device_path", "vid", "pid"):
            self.assertEqual(self.example["camera"][key], "", f"camera.{key} gehoert zur lokalen Kameraauswahl")

    def test_example_switches_are_real_booleans(self):
        # The renderer warns and falls back on wrong types, but a shipped
        # example must not carry strings such as "ja" in the first place.
        self.assertIsInstance(self.example["effects"]["enabled"], bool)
        self.assertIsInstance(self.example["effects"]["minimal_mode"], bool)
        for name, block in self.example["effects"].items():
            if isinstance(block, dict) and "enabled" in block:
                self.assertIsInstance(block["enabled"], bool, f"effects.{name}.enabled")
        self.assertIsInstance(self.example["station"]["monitor"]["show_camera_image"], bool)
        self.assertFalse(self.example["station"]["monitor"]["show_camera_image"])
        self.assertIsInstance(self.example["updates"]["enabled"], bool)

    def test_example_prompt_keys_exist_in_the_curated_prompts(self):
        prompt = self.example["station"]["prompt"]
        self.assertIn(prompt["prompt_key"], self.prompts)
        for key in prompt["prompt_keys"]:
            self.assertIn(key, self.prompts)

    def test_example_follows_the_visual_grace_invariant(self):
        # Same rule as the live config: the visible light must clear well before
        # the capture-side reassociation grace ends.
        hold = self.example["renderer"]["missing_hold_seconds"]
        fade = 1.0 / self.example["renderer"]["missing_fade_rate"]
        self.assertLess(hold + fade, self.example["features"]["track_grace_period"])

    def test_documentation_references_the_example(self):
        doc = (ROOT / "docs" / "Konfiguration.md").read_text(encoding="utf-8")
        self.assertIn("config/config.example.json", doc)


if __name__ == "__main__":
    unittest.main()
