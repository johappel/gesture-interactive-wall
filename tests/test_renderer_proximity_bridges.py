"""Renderer-side contract checks for the proximity_bridges fire-orb effect.

Runs without Godot or a GPU. Pins the config contract, the isolating lifecycle
(disabled = not created, not simulated), the live redraw, and the fire-orb /
pair-field behaviour so the effect cannot silently regress to a static line.
"""

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ProximityBridgeConfigTest(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / "config" / "config.json").read_text(encoding="utf-8-sig"))
        self.bridge = self.config["effects"]["proximity_bridges"]

    def test_config_has_complete_safe_fire_orb_family(self):
        self.assertTrue(self.bridge["enabled"])
        for key in (
            "orbs_min", "orbs_max", "travel", "speed", "orb_size", "wobble",
            "max_alpha", "field_strength", "fade_seconds", "warm_color", "hot_color",
        ):
            self.assertIn(key, self.bridge)
        self.assertGreaterEqual(self.bridge["orbs_min"], 1)
        self.assertGreaterEqual(self.bridge["orbs_max"], self.bridge["orbs_min"])
        self.assertGreater(self.bridge["fade_seconds"], 0)
        self.assertLessEqual(self.bridge["max_alpha"], 1.0)
        for key in ("warm_color", "hot_color"):
            self.assertRegex(self.bridge[key], r"^#[0-9a-fA-F]{6}$")


class ProximityBridgeRendererContractTest(unittest.TestCase):
    def setUp(self):
        self.main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.bridge = (ROOT / "renderer" / "scripts" / "proximity_bridges.gd").read_text(encoding="utf-8")

    def test_disabled_bridge_is_not_created_and_not_simulated(self):
        for marker in (
            "func _setup_proximity_bridges() -> void:",
            'if not _effect_enabled("proximity_bridges", true):',
            "ProximityBridgesScript.new()",
            "_proximity_bridges.update_pairs(_pairs, vp, delta)",
        ):
            self.assertIn(marker, self.main)
        setup = self.main.split("func _setup_proximity_bridges()", 1)[1].split("func ", 1)[0]
        self.assertLess(setup.index("return"), setup.index("ProximityBridgesScript.new()"))

    def test_old_static_line_is_gone(self):
        # The inline draw_line bridge only refreshed on input and read as UI.
        self.assertNotIn("draw_line(_positions[a], _positions[b]", self.main)

    def test_effect_owns_its_motion_and_redraws_every_frame(self):
        for marker in (
            "func _process(delta: float) -> void:",
            "_time += delta",
            "queue_redraw()",
            "BLEND_MODE_ADD",
        ):
            self.assertIn(marker, self.bridge)

    def test_orbs_shuttle_and_condense_into_a_pair_field(self):
        for marker in (
            "func update_pairs(pairs: Array, viewport: Vector2, delta: float)",
            "var amplitude: float = _travel * (1.0 - 0.85 * proximity)",
            "a.lerp(b, along)",
            "smoothstep(0.55, 1.0, proximity)",
            "_warm_color.lerp(_hot_color, proximity)",
        ):
            self.assertIn(marker, self.bridge)

    def test_bridge_draws_from_pair_endpoints_so_occlusion_survives(self):
        # The bridge must not depend on both bodies being visible: it reads the
        # pair's own endpoints, so a briefly occluded partner keeps it alive.
        for marker in (
            'float(p["ax"]) * viewport.x',
            'float(p["by"]) * viewport.y',
        ):
            self.assertIn(marker, self.bridge)
        self.assertNotIn("positions.has(a)", self.bridge)

    def test_bridge_fades_pairs_in_and_out(self):
        self.assertIn('bridge["alpha"] = minf(float(bridge["alpha"]) + delta / _fade_seconds, 1.0)', self.bridge)
        self.assertIn('bridge["alpha"] = float(bridge["alpha"]) - delta / _fade_seconds', self.bridge)


if __name__ == "__main__":
    unittest.main()
