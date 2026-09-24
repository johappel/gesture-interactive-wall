"""Renderer contract checks for the tracking/visual persistence separation.

Runs without Godot. Pins the architecture rule "tracking persistence != visual
persistence": a briefly undetected body holds only for a short beat and then
fades quickly, and a bridge with an occluded partner freezes instead of
animating an unobserved person.
"""

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class VisualGraceConfigTest(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / "config" / "config.json").read_text(encoding="utf-8-sig"))

    def test_renderer_visual_grace_block_is_present_and_short(self):
        renderer = self.config["renderer"]
        # A short hold, not the whole tracking grace period.
        self.assertLessEqual(renderer["missing_hold_seconds"], 0.25)
        self.assertGreaterEqual(renderer["missing_hold_seconds"], 0.0)
        self.assertGreater(renderer["missing_fade_rate"], 1.2)

    def test_visual_fade_is_faster_than_tracking_grace(self):
        # The visible light must clear well before the track's reassociation
        # grace ends, so occlusion does not linger as a ghost.
        grace = self.config["features"]["track_grace_period"]
        fade_time = 1.0 / self.config["renderer"]["missing_fade_rate"]
        hold = self.config["renderer"]["missing_hold_seconds"]
        self.assertLess(hold + fade_time, grace)

    def test_bridge_has_a_short_occluded_fade(self):
        bridge = self.config["effects"]["proximity_bridges"]
        self.assertIn("occluded_fade_seconds", bridge)
        self.assertGreater(bridge["occluded_fade_seconds"], 0.0)
        self.assertLessEqual(bridge["occluded_fade_seconds"], bridge["fade_seconds"])


class VisualGraceRendererContractTest(unittest.TestCase):
    def setUp(self):
        self.main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.bridge = (ROOT / "renderer" / "scripts" / "proximity_bridges.gd").read_text(
            encoding="utf-8"
        )
        self.body = (ROOT / "renderer" / "scripts" / "body_light.gd").read_text(encoding="utf-8")

    def test_body_does_not_hold_for_the_whole_grace_period(self):
        # The old behaviour skipped fading entirely while temporarily_missing.
        self.assertNotIn(
            "if temporarily_missing.has(id):\n\t\t\t\tcontinue", self.main
        )
        for marker in (
            "_missing_hold_seconds",
            "_missing_fade_rate",
            "elapsed < _missing_hold_seconds",
            "_bodies[id].fade(delta, _missing_fade_rate)",
        ):
            self.assertIn(marker, self.main)

    def test_body_fade_accepts_a_configurable_rate(self):
        self.assertIn("func fade(delta: float, rate := 1.2) -> bool:", self.body)

    def test_bridge_freezes_and_damps_when_a_partner_is_occluded(self):
        for marker in (
            'var occluded := bool(p.get("occluded", false))',
            "_occluded_fade_seconds",
            "float(bridge[\"alpha\"]) - delta / _occluded_fade_seconds",
            'bridge["motion_time"] = float(bridge.get("motion_time", 0.0)) + delta',
        ):
            self.assertIn(marker, self.bridge)

    def test_bridge_motion_uses_per_bridge_frozen_clock(self):
        # Wobble must read the bridge's own motion clock (frozen when occluded),
        # not the global time that keeps advancing regardless.
        self.assertIn('var motion_time: float = float(bridge.get("motion_time", 0.0))', self.bridge)
        draw = self.bridge.split("func _draw_bridge", 1)[1].split("\nfunc ", 1)[0]
        self.assertIn("phase := motion_time * _speed", draw)
        self.assertNotIn("phase := _time * _speed", draw)


if __name__ == "__main__":
    unittest.main()
