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
            "max_alpha", "field_strength", "fade_seconds", "smoothing",
            "min_distance", "warm_color", "hot_color",
        ):
            self.assertIn(key, self.bridge)
        self.assertGreaterEqual(self.bridge["orbs_min"], 1)
        self.assertGreaterEqual(self.bridge["orbs_max"], self.bridge["orbs_min"])
        self.assertGreater(self.bridge["fade_seconds"], 0)
        self.assertGreater(self.bridge["smoothing"], 0)
        self.assertGreater(self.bridge["min_distance"], 0)
        self.assertLessEqual(self.bridge["max_alpha"], 1.0)
        for key in ("warm_color", "hot_color"):
            self.assertRegex(self.bridge[key], r"^#[0-9a-fA-F]{6}$")

    def test_proximity_threshold_clears_real_pose_jitter(self):
        # MediaPipe torso centres wobble by a few percent of the frame between
        # samples. A threshold barely above the true separation turns that
        # jitter into bridges appearing and vanishing every second.
        self.assertGreaterEqual(self.config["features"]["proximity_threshold"], 0.40)
        self.assertGreater(
            self.config["features"]["proximity_threshold"], self.bridge["min_distance"]
        )


class ProximityBridgeRendererContractTest(unittest.TestCase):
    def setUp(self):
        self.main = (ROOT / "renderer" / "scripts" / "main.gd").read_text(encoding="utf-8")
        self.bridge = (ROOT / "renderer" / "scripts" / "proximity_bridges.gd").read_text(encoding="utf-8")

    def test_disabled_bridge_is_not_created_and_not_simulated(self):
        for marker in (
            "func _refresh_proximity_bridges() -> void:",
            'if _effect_enabled("proximity_bridges", true):',
            "ProximityBridgesScript.new()",
            "_proximity_bridges.update_pairs(_pairs, vp, delta)",
        ):
            self.assertIn(marker, self.main)
        refresh = self.main.split("func _refresh_proximity_bridges()", 1)[1].split("\nfunc ", 1)[0]
        self.assertLess(
            refresh.index('if _effect_enabled("proximity_bridges", true):'),
            refresh.index("ProximityBridgesScript.new()"),
        )
        self.assertIn("queue_free()", refresh)

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

    def test_bridge_is_smoothed_against_pose_jitter(self):
        # Endpoints and closeness are eased instead of snapped, so a jittery
        # pose centre cannot make the orbs jump between partners.
        for marker in (
            "var _smoothing := 0.15",
            'clampf(_number(config, "smoothing", 0.15), 0.01, 1.0)',
            "var blend := clampf(delta / _smoothing, 0.0, 1.0)",
            'var smoothed_pa: Vector2 = bridge["pa"]',
            "bridge[\"pa\"] = smoothed_pa.lerp(pa, blend)",
            "bridge[\"pb\"] = smoothed_pb.lerp(pb, blend)",
            'bridge["proximity"] = smoothed_prox + (proximity - smoothed_prox) * blend',
        ):
            self.assertIn(marker, self.bridge)
        # A brand-new pair is placed immediately; easing in from (0, 0) would
        # read as the orbs flying across the whole facade.
        self.assertNotIn('"pa": Vector2.ZERO', self.bridge)

    def test_pair_field_requires_real_closeness_not_the_bridge_threshold(self):
        for marker in (
            "var _min_distance := 0.22",
            'clampf(_number(config, "min_distance", 0.22), 0.0, 1.0)',
            "func _proximity_for(distance: float) -> float:",
            "return clampf(1.0 - distance / _min_distance, 0.0, 1.0)",
        ):
            self.assertIn(marker, self.bridge)
        # Closeness is derived from the smoothed endpoints, not from the raw
        # per-packet value that capture computed against its own threshold.
        self.assertIn('var dx := float(p["bx"]) - float(p["ax"])', self.bridge)
        self.assertIn("var proximity := _proximity_for(sqrt(dx * dx + dy * dy))", self.bridge)


if __name__ == "__main__":
    unittest.main()
